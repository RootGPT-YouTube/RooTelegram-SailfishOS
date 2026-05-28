/*
    Copyright (C) 2026 RootGPT

    This file is part of RooTelegram.

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/

#ifndef STORIESMODEL_H
#define STORIESMODEL_H

#include <QAbstractListModel>
#include <QHash>
#include <QList>
#include <QVariantList>
#include <QVariantMap>

class TDLibWrapper;

class StoriesModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QString activeList READ activeList WRITE setActiveList NOTIFY activeListChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(int mainUnreadCount READ mainUnreadCount NOTIFY mainUnreadCountChanged)

public:
    enum Role {
        RoleChatId = Qt::UserRole + 1,
        RoleChatTitle,
        RoleChatPhotoSmall,
        RoleStoryCount,
        RoleHasUnread,
        RoleMaxReadStoryId,
        RoleOrder,
        RoleStories,
        // Roles per myArchive (one row = one story full object)
        RoleStoryId,
        RoleStoryDate,
        RoleStoryCaption,
        RoleStoryContent,
        RoleStoryFull
    };

    explicit StoriesModel(TDLibWrapper *tdLibWrapper, QObject *parent = nullptr);
    ~StoriesModel() override = default;

    QHash<int, QByteArray> roleNames() const override;
    int rowCount(const QModelIndex &index = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;

    QString activeList() const;
    void setActiveList(const QString &list);
    int mainUnreadCount() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE QVariantList storiesForChat(qlonglong chatId) const;
    Q_INVOKABLE QVariantMap activeStoriesForChat(qlonglong chatId) const;
    Q_INVOKABLE QVariantList myArchiveStories() const { return m_myArchive; }
    Q_INVOKABLE QVariantList myProfileStories() const { return m_myProfile; }
    Q_INVOKABLE void removeMyArchiveRow(int storyId);   // rimozione ottimistica post-delete
    Q_INVOKABLE void removeMyProfileRow(int storyId);   // rimozione ottimistica post-delete (profilo)
    Q_INVOKABLE void removeChatRow(qlonglong chatId);   // rimozione ottimistica post-archive/unarchive

signals:
    void activeListChanged();
    void countChanged();
    void mainUnreadCountChanged();
    void storyContentReady(qlonglong chatId, int storyId, QVariantMap story);
    void myArchiveLoaded(const QVariantList &stories);
    void myProfileLoaded(const QVariantList &stories);
    // Emesso quando un contatto pubblica una storia NUOVA (non al boot):
    // il NotificationManager decide se pubblicare la notifica desktop.
    void newStoryPosted(qlonglong chatId);

private slots:
    void handleChatActiveStoriesUpdated(const QVariantMap &activeStories);
    void handleActiveStoryListReordered(const QString &listType, const QVariantList &chatActiveStoriesList);
    void handleStoryListChatCountUpdated(const QString &listType, int chatCount);
    void handleStoryReceived(const QVariantMap &story);
    void handleStoryDeleted(qlonglong storySenderChatId, int storyId);
    void handleStoriesListReceived(const QVariantList &stories, int totalCount, const QString &extra);

private:
    struct ChatStories {
        qlonglong chatId = 0;
        QString listType;          // "main" or "archive"
        QString order;             // TDLib order string for sorting
        int maxReadStoryId = 0;
        QVariantList stories;      // raw storyInfo entries: {story_id, date, is_for_close_friends}
    };

    int indexOfChat(qlonglong chatId) const;
    bool hasUnreadForChat(const ChatStories &cs) const;
    int unreadCountForChat(const ChatStories &cs) const;
    QList<ChatStories> &currentList();
    const QList<ChatStories> &currentList() const;
    QList<ChatStories> &listFor(const QString &type);
    void removeChatFromList(const QString &listType, qlonglong chatId);
    void rebuildMainUnreadCount();
    void requestActiveStoriesForChat(qlonglong chatId);
    qlonglong selfUserId() const;

    TDLibWrapper *m_tdLibWrapper;
    QString m_activeList;
    QList<ChatStories> m_main;
    QList<ChatStories> m_archive;
    QHash<qlonglong, QHash<int, QVariantMap>> m_storyCache;  // chatId -> (storyId -> story)
    int m_mainUnreadCount = 0;
    QVariantList m_myArchive;   // list of full story objects (self user)
    QVariantList m_myProfile;   // list of full story objects pinned to profile

    // Rilevamento storie nuove per le notifiche desktop:
    // m_lastSeenStory tiene il story_id più alto già visto per chat; finché
    // m_storiesNotifyReady è false (finestra iniziale) facciamo solo seeding
    // silenzioso per non spammare al boot con le storie già esistenti.
    QHash<qlonglong, int> m_lastSeenStory;
    bool m_storiesNotifyReady = false;
};

#endif // STORIESMODEL_H
