/*
    Copyright (C) 2026 RootGPT

    This file is part of RooTelegram.

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/

#include "storiesmodel.h"
#include "tdlibwrapper.h"
#include "debuglog.h"
#include <QTimer>

namespace {
QString resolveListType(const QVariantMap &storyList)
{
    const QString type = storyList.value("@type").toString();
    if (type == "storyListArchive") {
        return QStringLiteral("archive");
    }
    return QStringLiteral("main");
}
}

StoriesModel::StoriesModel(TDLibWrapper *tdLibWrapper, QObject *parent)
    : QAbstractListModel(parent)
    , m_tdLibWrapper(tdLibWrapper)
    , m_activeList(QStringLiteral("main"))
{
    if (m_tdLibWrapper) {
        connect(m_tdLibWrapper, SIGNAL(chatActiveStoriesUpdated(QVariantMap)),
                this, SLOT(handleChatActiveStoriesUpdated(QVariantMap)));
        connect(m_tdLibWrapper, SIGNAL(activeStoryListReordered(QString, QVariantList)),
                this, SLOT(handleActiveStoryListReordered(QString, QVariantList)));
        connect(m_tdLibWrapper, SIGNAL(storyListChatCountUpdated(QString, int)),
                this, SLOT(handleStoryListChatCountUpdated(QString, int)));
        connect(m_tdLibWrapper, SIGNAL(storyReceived(QVariantMap)),
                this, SLOT(handleStoryReceived(QVariantMap)));
        connect(m_tdLibWrapper, SIGNAL(storyDeleted(qlonglong, int)),
                this, SLOT(handleStoryDeleted(qlonglong, int)));
        connect(m_tdLibWrapper, SIGNAL(storiesListReceived(QVariantList, int, QString)),
                this, SLOT(handleStoriesListReceived(QVariantList, int, QString)));
    }

    // Finestra di seeding silenzioso: all'avvio TDLib invia un burst di
    // updateChatActiveStories per tutte le chat con storie attive. Durante questi
    // primi secondi registriamo soltanto gli story_id già esistenti senza
    // notificare; passato il timer, ogni storia con id superiore = storia nuova.
    QTimer::singleShot(12000, this, [this]() { m_storiesNotifyReady = true; });
}

QHash<int, QByteArray> StoriesModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles.insert(RoleChatId, "chat_id");
    roles.insert(RoleChatTitle, "chat_title");
    roles.insert(RoleChatPhotoSmall, "chat_photo_small");
    roles.insert(RoleStoryCount, "story_count");
    roles.insert(RoleHasUnread, "has_unread");
    roles.insert(RoleMaxReadStoryId, "max_read_story_id");
    roles.insert(RoleOrder, "order");
    roles.insert(RoleStories, "stories");
    roles.insert(RoleStoryId, "story_id");
    roles.insert(RoleStoryDate, "story_date");
    roles.insert(RoleStoryCaption, "story_caption");
    roles.insert(RoleStoryContent, "story_content");
    roles.insert(RoleStoryFull, "story_full");
    return roles;
}

int StoriesModel::rowCount(const QModelIndex &index) const
{
    Q_UNUSED(index)
    if (m_activeList == QStringLiteral("myArchive")) {
        return m_myArchive.size();
    }
    if (m_activeList == QStringLiteral("myProfile")) {
        return m_myProfile.size();
    }
    return currentList().size();
}

QVariant StoriesModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0) {
        return QVariant();
    }
    if (m_activeList == QStringLiteral("myArchive") || m_activeList == QStringLiteral("myProfile")) {
        const QVariantList &source = (m_activeList == QStringLiteral("myProfile")) ? m_myProfile : m_myArchive;
        if (index.row() >= source.size()) return QVariant();
        const QVariantMap story = source.at(index.row()).toMap();
        switch (role) {
        case RoleStoryId: return story.value("id").toInt();
        case RoleStoryDate: return story.value("date").toInt();
        case RoleStoryCaption: return story.value("caption").toMap().value("text").toString();
        case RoleStoryContent: return story.value("content");
        case RoleStoryFull: return story;
        case RoleChatId: {
            qlonglong cid = story.value("poster_chat_id").toLongLong();
            if (cid == 0) cid = story.value("sender_chat_id").toLongLong();
            return QVariant::fromValue<qlonglong>(cid);
        }
        }
        return QVariant();
    }
    if (index.row() >= currentList().size()) return QVariant();
    const ChatStories &cs = currentList().at(index.row());
    switch (role) {
    case RoleChatId:
        return QVariant::fromValue<qlonglong>(cs.chatId);
    case RoleChatTitle: {
        if (!m_tdLibWrapper) return QString();
        const QVariantMap chat = m_tdLibWrapper->getChat(QString::number(cs.chatId));
        return chat.value("title").toString();
    }
    case RoleChatPhotoSmall: {
        if (!m_tdLibWrapper) return QVariantMap();
        const QVariantMap chat = m_tdLibWrapper->getChat(QString::number(cs.chatId));
        return chat.value("photo").toMap().value("small").toMap();
    }
    case RoleStoryCount:
        return cs.stories.size();
    case RoleHasUnread:
        return hasUnreadForChat(cs);
    case RoleMaxReadStoryId:
        return cs.maxReadStoryId;
    case RoleOrder:
        return cs.order;
    case RoleStories:
        return cs.stories;
    }
    return QVariant();
}

QString StoriesModel::activeList() const
{
    return m_activeList;
}

void StoriesModel::setActiveList(const QString &list)
{
    QString normalized = list;
    if (normalized != QStringLiteral("archive")
            && normalized != QStringLiteral("myArchive")
            && normalized != QStringLiteral("myProfile")) {
        normalized = QStringLiteral("main");
    }
    if (normalized == m_activeList) {
        return;
    }
    beginResetModel();
    m_activeList = normalized;
    endResetModel();
    emit activeListChanged();
    emit countChanged();
    refresh();
}

int StoriesModel::mainUnreadCount() const
{
    return m_mainUnreadCount;
}

void StoriesModel::refresh()
{
    if (!m_tdLibWrapper) return;
    if (m_activeList == QStringLiteral("myArchive")) {
        const qlonglong selfId = selfUserId();
        if (selfId != 0) {
            m_tdLibWrapper->getChatArchivedStories(QString::number(selfId), 0, 50,
                                                   QStringLiteral("myArchive"));
        }
        return;
    }
    if (m_activeList == QStringLiteral("myProfile")) {
        const qlonglong selfId = selfUserId();
        if (selfId != 0) {
            m_tdLibWrapper->getChatPostedToChatPageStories(QString::number(selfId), 0, 50,
                                                          QStringLiteral("myProfile"));
        }
        return;
    }
    m_tdLibWrapper->loadActiveStories(m_activeList);
}

qlonglong StoriesModel::selfUserId() const
{
    if (!m_tdLibWrapper) return 0;
    const QVariantMap me = const_cast<TDLibWrapper *>(m_tdLibWrapper)->getUserInformation();
    return me.value("id").toLongLong();
}

void StoriesModel::handleStoriesListReceived(const QVariantList &stories, int totalCount, const QString &extra)
{
    Q_UNUSED(totalCount)
    if (extra == QStringLiteral("myArchive")) {
        const bool isActive = (m_activeList == QStringLiteral("myArchive"));
        if (isActive) beginResetModel();
        m_myArchive = stories;
        if (isActive) {
            endResetModel();
            emit countChanged();
        }
        emit myArchiveLoaded(stories);
        return;
    }
    if (extra == QStringLiteral("myProfile")) {
        const bool isActive = (m_activeList == QStringLiteral("myProfile"));
        if (isActive) beginResetModel();
        m_myProfile = stories;
        if (isActive) {
            endResetModel();
            emit countChanged();
        }
        emit myProfileLoaded(stories);
        return;
    }
}

QVariantList StoriesModel::storiesForChat(qlonglong chatId) const
{
    const int idx = indexOfChat(chatId);
    if (idx < 0) return QVariantList();
    return currentList().at(idx).stories;
}

QVariantMap StoriesModel::activeStoriesForChat(qlonglong chatId) const
{
    QVariantMap result;
    const int idx = indexOfChat(chatId);
    if (idx < 0) return result;
    const ChatStories &cs = currentList().at(idx);
    result.insert("chat_id", QVariant::fromValue<qlonglong>(cs.chatId));
    result.insert("max_read_story_id", cs.maxReadStoryId);
    result.insert("stories", cs.stories);
    return result;
}

int StoriesModel::indexOfChat(qlonglong chatId) const
{
    const QList<ChatStories> &list = currentList();
    for (int i = 0; i < list.size(); ++i) {
        if (list.at(i).chatId == chatId) {
            return i;
        }
    }
    return -1;
}

bool StoriesModel::hasUnreadForChat(const ChatStories &cs) const
{
    return unreadCountForChat(cs) > 0;
}

int StoriesModel::unreadCountForChat(const ChatStories &cs) const
{
    int count = 0;
    for (const QVariant &v : cs.stories) {
        const QVariantMap info = v.toMap();
        const int sid = info.value("story_id").toInt();
        if (sid > cs.maxReadStoryId) {
            ++count;
        }
    }
    return count;
}

QList<StoriesModel::ChatStories> &StoriesModel::currentList()
{
    return m_activeList == QStringLiteral("archive") ? m_archive : m_main;
}

const QList<StoriesModel::ChatStories> &StoriesModel::currentList() const
{
    return m_activeList == QStringLiteral("archive") ? m_archive : m_main;
}

QList<StoriesModel::ChatStories> &StoriesModel::listFor(const QString &type)
{
    return type == QStringLiteral("archive") ? m_archive : m_main;
}

void StoriesModel::rebuildMainUnreadCount()
{
    int total = 0;
    for (const ChatStories &cs : m_main) {
        if (hasUnreadForChat(cs)) {
            ++total;
        }
    }
    if (total != m_mainUnreadCount) {
        m_mainUnreadCount = total;
        emit mainUnreadCountChanged();
    }
}

void StoriesModel::requestActiveStoriesForChat(qlonglong chatId)
{
    if (m_tdLibWrapper) {
        m_tdLibWrapper->getChatActiveStories(QString::number(chatId));
    }
}

void StoriesModel::removeChatFromList(const QString &listType, qlonglong chatId)
{
    QList<ChatStories> &list = listFor(listType);
    for (int i = 0; i < list.size(); ++i) {
        if (list.at(i).chatId != chatId) continue;
        const bool isActiveTarget = (listType == m_activeList);
        if (isActiveTarget) beginRemoveRows(QModelIndex(), i, i);
        list.removeAt(i);
        if (isActiveTarget) {
            endRemoveRows();
            emit countChanged();
        }
        if (listType == QStringLiteral("main")) {
            rebuildMainUnreadCount();
        }
        break;
    }
}

void StoriesModel::handleChatActiveStoriesUpdated(const QVariantMap &activeStories)
{
    const qlonglong chatId = activeStories.value("chat_id").toLongLong();
    if (chatId == 0) return;

    const QString listType = resolveListType(activeStories.value("list").toMap());
    const QString order = activeStories.value("order").toString();
    const int maxRead = activeStories.value("max_read_story_id").toInt();
    const QVariantList stories = activeStories.value("stories").toList();

    QList<ChatStories> &targetList = listFor(listType);
    int existingIdx = -1;
    for (int i = 0; i < targetList.size(); ++i) {
        if (targetList.at(i).chatId == chatId) {
            existingIdx = i;
            break;
        }
    }

    const bool isActiveTarget = (listType == m_activeList);
    if (stories.isEmpty()) {
        if (existingIdx >= 0) {
            if (isActiveTarget) {
                beginRemoveRows(QModelIndex(), existingIdx, existingIdx);
            }
            targetList.removeAt(existingIdx);
            if (isActiveTarget) {
                endRemoveRows();
                emit countChanged();
            }
        }
        if (listType == QStringLiteral("main")) {
            rebuildMainUnreadCount();
        }
        return;
    }

    // Spostamento tra liste (main <-> archive): TDLib annuncia la chat nella
    // lista di destinazione ma NON invia un update a stories vuote per quella di
    // partenza, quindi la togliamo qui dall'altra lista. Senza questo, archiviare
    // la storia di un contatto la lascia nel Main e la duplica in Archived.
    const QString otherList = (listType == QStringLiteral("archive"))
            ? QStringLiteral("main") : QStringLiteral("archive");
    removeChatFromList(otherList, chatId);

    // Rilevamento storia NUOVA per la notifica desktop. Solo lista Main (i
    // contatti archiviati non notificano) e mai le proprie storie. Una storia è
    // "nuova" se il suo story_id supera il più alto già visto per questa chat ED
    // è ancora non letta (story_id > max_read_story_id). Durante la finestra di
    // seeding iniziale registriamo soltanto, senza notificare.
    if (listType == QStringLiteral("main") && chatId != selfUserId()) {
        int maxStoryId = 0;
        for (const QVariant &v : stories) {
            const int sid = v.toMap().value("story_id").toInt();
            if (sid > maxStoryId) maxStoryId = sid;
        }
        const int lastSeen = m_lastSeenStory.value(chatId, 0);
        if (m_storiesNotifyReady && maxStoryId > lastSeen && maxStoryId > maxRead) {
            LOG("New story for chat" << chatId << "story_id" << maxStoryId);
            emit newStoryPosted(chatId);
        }
        if (maxStoryId > lastSeen) {
            m_lastSeenStory.insert(chatId, maxStoryId);
        }
    }

    ChatStories cs;
    cs.chatId = chatId;
    cs.listType = listType;
    cs.order = order;
    cs.maxReadStoryId = maxRead;
    cs.stories = stories;

    if (existingIdx >= 0) {
        targetList[existingIdx] = cs;
        if (isActiveTarget) {
            const QModelIndex modelIdx = index(existingIdx);
            emit dataChanged(modelIdx, modelIdx);
        }
    } else {
        if (isActiveTarget) {
            beginInsertRows(QModelIndex(), targetList.size(), targetList.size());
        }
        targetList.append(cs);
        if (isActiveTarget) {
            endInsertRows();
            emit countChanged();
        }
    }
    if (listType == QStringLiteral("main")) {
        rebuildMainUnreadCount();
    }
}

void StoriesModel::handleActiveStoryListReordered(const QString &listType, const QVariantList &chatActiveStoriesList)
{
    QList<ChatStories> &targetList = listFor(listType);
    const bool isActiveTarget = (listType == m_activeList);

    QHash<qlonglong, ChatStories> snapshot;
    for (const ChatStories &cs : targetList) {
        snapshot.insert(cs.chatId, cs);
    }

    if (isActiveTarget) {
        beginResetModel();
    }
    targetList.clear();
    for (const QVariant &v : chatActiveStoriesList) {
        const QVariantMap entry = v.toMap();
        const qlonglong chatId = entry.value("chat_id").toLongLong();
        ChatStories cs = snapshot.value(chatId);
        cs.chatId = chatId;
        cs.listType = listType;
        cs.order = entry.value("order").toString();
        if (entry.contains("max_read_story_id")) {
            cs.maxReadStoryId = entry.value("max_read_story_id").toInt();
        }
        if (entry.contains("stories")) {
            cs.stories = entry.value("stories").toList();
        }
        targetList.append(cs);
    }
    if (isActiveTarget) {
        endResetModel();
        emit countChanged();
    }
    if (listType == QStringLiteral("main")) {
        rebuildMainUnreadCount();
    }
}

void StoriesModel::handleStoryListChatCountUpdated(const QString &listType, int chatCount)
{
    Q_UNUSED(listType)
    Q_UNUSED(chatCount)
    // No-op per ora: il count chat è inferibile dal model row count.
}

void StoriesModel::handleStoryReceived(const QVariantMap &story)
{
    // TDLib 1.8.62: il payload `story` usa poster_chat_id; fallback a sender_chat_id
    // per compatibilità con eventuali versioni più vecchie.
    qlonglong senderChatId = story.value("poster_chat_id").toLongLong();
    if (senderChatId == 0) {
        senderChatId = story.value("sender_chat_id").toLongLong();
    }
    const int storyId = story.value("id").toInt();
    if (senderChatId == 0 || storyId == 0) return;
    m_storyCache[senderChatId].insert(storyId, story);
    emit storyContentReady(senderChatId, storyId, story);
}

void StoriesModel::removeMyArchiveRow(int storyId)
{
    // Rimozione ottimistica: l'utente ha cancellato la storia, la togliamo subito
    // dalla vista My Archive senza dipendere da updateStoryDeleted (che sul runtime
    // 1.8.62 arriva con story_poster_chat_id, non gestito qui) né da un refresh
    // (che farebbe race con il delete async e potrebbe ri-aggiungere la storia).
    for (int i = 0; i < m_myArchive.size(); ++i) {
        if (m_myArchive.at(i).toMap().value("id").toInt() != storyId) continue;
        const bool isActive = (m_activeList == QStringLiteral("myArchive"));
        if (isActive) beginRemoveRows(QModelIndex(), i, i);
        m_myArchive.removeAt(i);
        if (isActive) {
            endRemoveRows();
            emit countChanged();
        }
        break;
    }
}

void StoriesModel::removeMyProfileRow(int storyId)
{
    // Rimozione ottimistica simmetrica a removeMyArchiveRow: l'utente ha
    // cancellato la storia, la togliamo subito dalla vista My Profile.
    for (int i = 0; i < m_myProfile.size(); ++i) {
        if (m_myProfile.at(i).toMap().value("id").toInt() != storyId) continue;
        const bool isActive = (m_activeList == QStringLiteral("myProfile"));
        if (isActive) beginRemoveRows(QModelIndex(), i, i);
        m_myProfile.removeAt(i);
        if (isActive) {
            endRemoveRows();
            emit countChanged();
        }
        break;
    }
}

void StoriesModel::removeChatRow(qlonglong chatId)
{
    // Rimozione ottimistica dalla lista corrente (Main/Archived) dopo
    // setChatActiveStoriesList: lo spostamento tra liste arriva via
    // updateChatActiveStories che popola la lista di destinazione ma NON svuota
    // quella di partenza (le stories non sono vuote), quindi togliamo subito la
    // riga dalla tab visibile senza attendere un refresh.
    if (m_activeList == QStringLiteral("myArchive") || m_activeList == QStringLiteral("myProfile")) return;
    QList<ChatStories> &list = currentList();
    for (int i = 0; i < list.size(); ++i) {
        if (list.at(i).chatId != chatId) continue;
        beginRemoveRows(QModelIndex(), i, i);
        list.removeAt(i);
        endRemoveRows();
        emit countChanged();
        if (m_activeList == QStringLiteral("main")) {
            rebuildMainUnreadCount();
        }
        break;
    }
}

void StoriesModel::handleStoryDeleted(qlonglong storySenderChatId, int storyId)
{
    if (m_storyCache.contains(storySenderChatId)) {
        m_storyCache[storySenderChatId].remove(storyId);
    }
    // Rimuovi anche dalla lista delle stories della chat se presente.
    for (QString listType : { QStringLiteral("main"), QStringLiteral("archive") }) {
        QList<ChatStories> &target = listFor(listType);
        for (int i = 0; i < target.size(); ++i) {
            if (target.at(i).chatId != storySenderChatId) continue;
            QVariantList newStories;
            for (const QVariant &v : target.at(i).stories) {
                if (v.toMap().value("story_id").toInt() != storyId) {
                    newStories.append(v);
                }
            }
            if (newStories.size() == target.at(i).stories.size()) {
                break;
            }
            const bool isActiveTarget = (listType == m_activeList);
            if (newStories.isEmpty()) {
                if (isActiveTarget) beginRemoveRows(QModelIndex(), i, i);
                target.removeAt(i);
                if (isActiveTarget) {
                    endRemoveRows();
                    emit countChanged();
                }
            } else {
                target[i].stories = newStories;
                if (isActiveTarget) {
                    const QModelIndex modelIdx = index(i);
                    emit dataChanged(modelIdx, modelIdx);
                }
            }
            break;
        }
    }
    rebuildMainUnreadCount();
}
