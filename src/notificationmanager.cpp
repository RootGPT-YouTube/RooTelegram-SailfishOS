/*
    Copyright (C) 2020 Sebastian J. Wolf and other contributors
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), which is
    licensed under the GNU General Public License v3.0. The original
    license is available at:
    https://github.com/Wunderfitz/harbour-fernschreiber/blob/master/LICENSE

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    RooTelegram is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with RooTelegram. If not, see <http://www.gnu.org/licenses/>.
*/

#include "notificationmanager.h"
#include "rootelegramutils.h"
#include "chatmodel.h"
#include <sailfishapp.h>
#include <QListIterator>
#include <QUrl>
#include <QDateTime>
#include <QDBusConnection>
#include <QGuiApplication>

#define DEBUG_MODULE NotificationManager
#include "debuglog.h"

namespace {
    const QString _TYPE("@type");
    const QString TYPE("type");
    const QString ID("id");
    const QString EMOJI("emoji");
    const QString CHAT_ID("chat_id");
    const QString IS_CHANNEL("is_channel");
    const QString TOTAL_COUNT("total_count");
    const QString DATE("date");
    const QString TITLE("title");
    const QString CONTENT("content");
    const QString MESSAGE("message");
    const QString FIRST_NAME("first_name");
    const QString LAST_NAME("last_name");
    const QString SENDER_ID("sender_id");
    const QString USER_ID("user_id");
    const QString NOTIFICATIONS("notifications");
    const QString NOTIFICATION_GROUP_ID("notification_group_id");
    const QString ADDED_NOTIFICATIONS("added_notifications");
    const QString REMOVED_NOTIFICATION_IDS("removed_notification_ids");
    const QString UNREAD_COUNT("unread_count");
    const QString UNREAD_MENTION_COUNT("unread_mention_count");
    const QString UNREAD_REACTION_COUNT("unread_reaction_count");

    // removeNotificationGroup con id ignoto (gruppo zombie senza notifiche
    // caricabili, maxNotificationId==0): TDLib clampa internamente il valore
    // a current_notification_id, quindi INT32_MAX = "spurga tutto il gruppo".
    const int PURGE_ALL_NOTIFICATIONS_ID = 2147483647;

    const QString CHAT_TYPE_BASIC_GROUP("chatTypeBasicGroup");
    const QString CHAT_TYPE_SUPERGROUP("chatTypeSupergroup");

    const QString APP_NAME("RooTelegram");
    const QString APP_OWNER("harbour-rootelegram");
    const QString APP_ORIGIN("com.github.RootGPT_YouTube.rootelegram");
    const QString NOTIFICATION_CATEGORY("im.received");

    // Notification hints
    const QString HINT_GROUP_ID("x-rootelegram.group_id");        // int
    const QString HINT_CHAT_ID("x-rootelegram.chat_id");          // qlonglong
    const QString HINT_TOTAL_COUNT("x-rootelegram.total_count");  // int
    const QString HINT_MAX_NOTIFICATION_ID("x-rootelegram.max_notification_id"); // int

    const QString HINT_IMAGE_PATH("image-path");                    // QString
    const QString HINT_VIBRA("x-nemo-vibrate");                     // bool
    const QString HINT_SUPPRESS_SOUND("suppress-sound");            // bool
    const QString HINT_DISPLAY_ON("x-nemo-display-on");             // bool
    const QString HINT_VISIBILITY("x-nemo-visibility");             // QString
    const QString HINT_FEEDBACK("x-nemo-feedback");                 // QString
    const QString HINT_PRIORITY("x-nemo-priority");                 // int
    const QString HINT_OWNER("x-nemo-owner");                       // QString
    const QString HINT_ORIGIN("x-nemo-origin");                     // QString
    const QString VISIBILITY_PUBLIC("public");
}

class NotificationManager::ChatInfo
{
public:
    ChatInfo(const QVariantMap &info);

    void setChatInfo(const QVariantMap &info);

public:
    TDLibWrapper::ChatType type;
    bool isChannel;
    QString title;
};

NotificationManager::ChatInfo::ChatInfo(const QVariantMap &chatInfo)
{
    setChatInfo(chatInfo);
}

void NotificationManager::ChatInfo::setChatInfo(const QVariantMap &chatInfo)
{
    const QVariantMap chatTypeInformation = chatInfo.value(TYPE).toMap();
    type = TDLibWrapper::chatTypeFromString(chatTypeInformation.value(_TYPE).toString());
    isChannel = chatTypeInformation.value(IS_CHANNEL).toBool();
    title = chatInfo.value(TITLE).toString();
}

struct NotificationManager::PendingSnapshotGroup
{
    int groupId = 0;
    qlonglong chatId = 0;
    int totalCount = 0;
    QVariantList notifications;
};

class NotificationManager::NotificationGroup
{
public:
    NotificationGroup(int groupId, qlonglong chatId, int count, Notification *notification);
    NotificationGroup(Notification *notification);
    ~NotificationGroup();

public:
    int notificationGroupId;
    qlonglong chatId;
    int totalCount;
    // Id massimo tra le notifiche TDLib mostrate in questo gruppo: serve per
    // removeNotificationGroup quando l'utente rimuove la notifica da lipstick.
    // Persistito come hint per sopravvivere al riciclo anti-RAM (execv).
    int maxNotificationId;
    Notification *nemoNotification;
    QMap<int,QVariantMap> activeNotifications;
    QList<int> notificationOrder;
};

NotificationManager::NotificationGroup::NotificationGroup(int group, qlonglong chat, int count, Notification *notification) :
    notificationGroupId(group),
    chatId(chat),
    totalCount(count),
    maxNotificationId(0),
    nemoNotification(notification)
{
}

NotificationManager::NotificationGroup::~NotificationGroup()
{
    delete nemoNotification;
}
void NotificationManager::applyBranding(Notification *notification) const
{
    if (!notification) {
        return;
    }
    notification->setCategory(NOTIFICATION_CATEGORY);
    notification->setAppName(APP_NAME);
    notification->setAppIcon(notificationIconFile);
    notification->setIcon(notificationIconFile);
    notification->setHintValue(HINT_OWNER, APP_OWNER);
    notification->setHintValue(HINT_ORIGIN, APP_ORIGIN);
}

NotificationManager::NotificationManager(TDLibWrapper *tdLibWrapper, AppSettings *appSettings, MceInterface *mceInterface, ChatModel *chatModel) :
    notificationIconFile(SailfishApp::pathTo("images/rootelegram-notification.png").toLocalFile())
{
    LOG("Initializing...");
    this->tdLibWrapper = tdLibWrapper;
    this->appSettings = appSettings;
    this->mceInterface = mceInterface;
    this->chatModel = chatModel;

    connect(this->tdLibWrapper, SIGNAL(activeNotificationsUpdated(QVariantList)), this, SLOT(handleUpdateActiveNotifications(QVariantList)));
    connect(this->tdLibWrapper, SIGNAL(notificationGroupUpdated(QVariantMap)), this, SLOT(handleUpdateNotificationGroup(QVariantMap)));
    connect(this->tdLibWrapper, SIGNAL(notificationUpdated(QVariantMap)), this, SLOT(handleUpdateNotification(QVariantMap)));
    connect(this->tdLibWrapper, SIGNAL(newChatDiscovered(QString, QVariantMap)), this, SLOT(handleChatDiscovered(QString, QVariantMap)));
    connect(this->tdLibWrapper, SIGNAL(chatTitleUpdated(QString, QString)), this, SLOT(handleChatTitleUpdated(QString, QString)));

    // Rete di sicurezza fail-open: se la chat di un gruppo differito non arriva
    // (updateNewChat mai emesso), non perdiamo la notifica -> la pubblichiamo.
    pendingFlushTimer.setSingleShot(true);
    pendingFlushTimer.setInterval(10000);
    connect(&pendingFlushTimer, SIGNAL(timeout()), this, SLOT(flushPendingSnapshotGroups()));

    this->controlLedNotification(false);

    // Restore notifications
    QList<QObject*> notifications = Notification::notifications();
    const int n = notifications.count();
    LOG("Found" << n << "existing notifications");
    for (int i = 0; i < n; i++) {
        QObject *notificationObject = notifications.at(i);
        Notification *notification = qobject_cast<Notification *>(notificationObject);
        if (notification) {
            bool groupOk, chatOk, countOk;
            const int groupId = notification->hintValue(HINT_GROUP_ID).toInt(&groupOk);
            const qlonglong chatId = notification->hintValue(HINT_CHAT_ID).toLongLong(&chatOk);
            const int totalCount = notification->hintValue(HINT_TOTAL_COUNT).toInt(&countOk);
            if (groupOk && chatOk && countOk && !notificationGroups.contains(groupId)) {
                LOG("Restoring notification group" << groupId << "chatId" << chatId << "count" << totalCount);
                applyBranding(notification);
                NotificationGroup *group = new NotificationGroup(groupId, chatId, totalCount, notification);
                // 0 se l'hint manca (notifica pubblicata da una versione precedente)
                group->maxNotificationId = notification->hintValue(HINT_MAX_NOTIFICATION_ID).toInt();
                notificationGroups.insert(groupId, group);
                connectNotificationClosed(groupId, notification);
                continue;
            }
        }
        delete notificationObject;
    }
}

NotificationManager::~NotificationManager()
{
    LOG("Destroying myself...");
    qDeleteAll(chatMap.values());
    qDeleteAll(notificationGroups.values());
}

void NotificationManager::handleUpdateActiveNotifications(const QVariantList &activeNotificationGroups)
{
    const int n = activeNotificationGroups.size();
    LOG("Received active notifications, number of groups:" << n);

    // Snapshot iniziale dopo il (ri)avvio del client TDLib: è autoritativa.
    // I gruppi ripristinati da lipstick nel costruttore che TDLib non elenca
    // più sono già stati letti altrove → via in silenzio.
    QSet<int> snapshotGroupIds;
    for (int i = 0; i < n; i++) {
        snapshotGroupIds.insert(activeNotificationGroups.at(i).toMap().value(ID).toInt());
    }
    const QList<int> knownGroupIds = notificationGroups.keys();
    QListIterator<int> knownGroupIdIterator(knownGroupIds);
    while (knownGroupIdIterator.hasNext()) {
        const int knownGroupId = knownGroupIdIterator.next();
        if (!snapshotGroupIds.contains(knownGroupId)) {
            LOG("Group" << knownGroupId << "no longer active in TDLib, dismissing");
            dismissNotificationGroup(knownGroupId);
        }
    }

    for (int i = 0; i < n; i++) {
        const QVariantMap notificationGroupInfo(activeNotificationGroups.at(i).toMap());
        const int groupId = notificationGroupInfo.value(ID).toInt();
        const qlonglong chatId = notificationGroupInfo.value(CHAT_ID).toLongLong();
        const QVariantList notifications(notificationGroupInfo.value(NOTIFICATIONS).toList());

        // Anti-fantasma: al (ri)avvio la snapshot è autoritativa. Due segnali
        // indipendenti di gruppo zombie (stantio nel DB notifiche di TDLib,
        // tipico dopo un riciclo anti-RAM). Se ne basta uno per spurgare:
        //
        //  (a) LISTA NOTIFICHE VUOTA con total_count>0: TDLib non ha nulla di
        //      reale da mostrare. Questo segnale NON dipende dalla cache chat,
        //      ed è proprio il caso che sfuggiva su canali/gruppi: la snapshot
        //      arriva prestissimo, prima che quei chat (caricati lazy) siano
        //      in cache → getChat vuoto → la vecchia guardia (che pretendeva
        //      la chat "letta") saltava lo spurgo e pubblicava un fantasma
        //      "N messaggi non letti".
        //
        //  (b) CHAT INTERAMENTE LETTA (unread/mention/reaction == 0): il gruppo
        //      è stato letto altrove; vale solo se la chat è già in cache.
        //
        // In entrambi i casi va spurgato in TDLib, altrimenti ricompare a ogni
        // riavvio del client.
        const QVariantMap chatInformation(tdLibWrapper->getChat(QString::number(chatId)));
        const bool emptyGhostGroup = notifications.isEmpty();
        const bool chatInCache = !chatInformation.isEmpty();
        const bool fullyReadChat = chatInCache && chatFullyRead(chatInformation);

        // (a)+(b): zombie certo -> spurga senza pubblicare.
        if (emptyGhostGroup || fullyReadChat) {
            purgeSnapshotGroup(groupId, chatId, notifications);
            continue;
        }

        // (c) 4° STADIO: lista NON vuota ma chat NON in cache (canale/gruppo
        // caricato lazy). Non sappiamo sincronicamente se è già letta: pubblicare
        // ora è proprio ciò che generava il fantasma "N messaggi non letti" sui
        // messaggi letti altrove ma ancora attivi nel DB notifiche di TDLib.
        // DIFFERIAMO: handleChatDiscovered deciderà (publish se davvero non letta,
        // purge se letta) appena arriva updateNewChat per questa chat.
        if (!chatInCache) {
            PendingSnapshotGroup pending;
            pending.groupId = groupId;
            pending.chatId = chatId;
            pending.totalCount = notificationGroupInfo.value(TOTAL_COUNT).toInt();
            pending.notifications = notifications;
            pendingSnapshotGroups.insert(groupId, pending);
            pendingFlushTimer.start(); // (ri)arma il fail-open
            continue;
        }

        // Chat in cache e con contenuto non letto: pubblicazione legittima.
        updateNotificationGroup(groupId, chatId,
            notificationGroupInfo.value(TOTAL_COUNT).toInt(), notifications);
    }
}

bool NotificationManager::chatFullyRead(const QVariantMap &chatInformation)
{
    return chatInformation.value(UNREAD_COUNT).toInt() == 0
            && chatInformation.value(UNREAD_MENTION_COUNT).toInt() == 0
            && chatInformation.value(UNREAD_REACTION_COUNT).toInt() == 0;
}

void NotificationManager::purgeSnapshotGroup(int groupId, qlonglong chatId, const QVariantList &notifications)
{
    int maxNotificationId = 0;
    QListIterator<QVariant> notificationIterator(notifications);
    while (notificationIterator.hasNext()) {
        const int notificationId = notificationIterator.next().toMap().value(ID).toInt();
        if (notificationId > maxNotificationId) {
            maxNotificationId = notificationId;
        }
    }
    LOG("Group" << groupId << "for chat" << chatId << "is a ghost: purging instead of publishing");
    tdLibWrapper->removeNotificationGroup(groupId,
        maxNotificationId > 0 ? maxNotificationId : PURGE_ALL_NOTIFICATIONS_ID);
    dismissNotificationGroup(groupId);
}

void NotificationManager::flushPendingSnapshotGroups()
{
    // Fail-open: le chat differite non sono arrivate in tempo. Per non perdere
    // notifiche legittime le pubblichiamo comunque (comportamento pre-fix).
    if (pendingSnapshotGroups.isEmpty()) {
        return;
    }
    const QList<PendingSnapshotGroup> stillPending = pendingSnapshotGroups.values();
    pendingSnapshotGroups.clear();
    QListIterator<PendingSnapshotGroup> it(stillPending);
    while (it.hasNext()) {
        const PendingSnapshotGroup p = it.next();
        updateNotificationGroup(p.groupId, p.chatId, p.totalCount, p.notifications);
    }
}

void NotificationManager::handleUpdateNotificationGroup(const QVariantMap &notificationGroupUpdate)
{
    const int notificationGroupId = notificationGroupUpdate.value(NOTIFICATION_GROUP_ID).toInt();
    const int totalCount = notificationGroupUpdate.value(TOTAL_COUNT).toInt();
    LOG("Received notification group update, group ID:" << notificationGroupId << "total count" << totalCount);
    updateNotificationGroup(notificationGroupId,
        notificationGroupUpdate.value(CHAT_ID).toLongLong(), totalCount,
        notificationGroupUpdate.value(ADDED_NOTIFICATIONS).toList(),
        notificationGroupUpdate.value(REMOVED_NOTIFICATION_IDS).toList(),
        appSettings->notificationFeedback());
}

void NotificationManager::updateNotificationGroup(int groupId, qlonglong chatId, int totalCount,
    const QVariantList &addedNotifications, const QVariantList & removedNotificationIds,
    AppSettings::NotificationFeedback feedback)
{
    bool needFeedback = false;
    NotificationGroup* notificationGroup = notificationGroups.value(groupId);

    LOG("Received notification group update, group ID:" << groupId << "total count" << totalCount);
    if (totalCount) {
        if (notificationGroup) {
            // Notification group already exists
            notificationGroup->totalCount = totalCount;
        } else {
            // New notification
            Notification *notification = new Notification(this);
            applyBranding(notification);
            notification->setHintValue(HINT_GROUP_ID, groupId);
            notification->setHintValue(HINT_CHAT_ID, chatId);
            notification->setHintValue(HINT_TOTAL_COUNT, totalCount);
            notification->setHintValue(HINT_FEEDBACK, "chat_exists");
            notification->setHintValue(HINT_PRIORITY, 120);
            notificationGroups.insert(groupId, notificationGroup =
                new NotificationGroup(groupId, chatId, totalCount, notification));
            connectNotificationClosed(groupId, notification);
        }

        QListIterator<QVariant> addedNotificationIterator(addedNotifications);
        while (addedNotificationIterator.hasNext()) {
            const QVariantMap addedNotification = addedNotificationIterator.next().toMap();
            const int addedId = addedNotification.value(ID).toInt();
            notificationGroup->activeNotifications.insert(addedId, addedNotification);
            notificationGroup->notificationOrder.append(addedId);
            if (addedId > notificationGroup->maxNotificationId) {
                notificationGroup->maxNotificationId = addedId;
            }
        }

        QListIterator<QVariant> removedNotificationIdsIterator(removedNotificationIds);
        while (removedNotificationIdsIterator.hasNext()) {
            const int removedId = removedNotificationIdsIterator.next().toInt();
            notificationGroup->activeNotifications.remove(removedId);
            notificationGroup->notificationOrder.removeOne(removedId);
        }

        // Make sure that if there's no notifications, order is empty too.
        // That's usually already the case but double-check won't wort. It's cheap.
        if (notificationGroup->activeNotifications.isEmpty()) {
            notificationGroup->notificationOrder.clear();
        }

        // 5° STADIO anti-fantasma (path LIVE): per certi canali/gruppi, DOPO la
        // lettura TDLib manda updateNotificationGroup con total_count>0 ma NESSUNA
        // notifica reale (added 0 e activeNotifications vuoto). Pubblicare qui
        // produce il fantasma "N messaggi non letti" senza contenuto, che ricompare
        // a ogni update finché non si spurga il gruppo in TDLib. Se non c'è nulla di
        // reale da mostrare, spurga invece di pubblicare (VERIFICATO sul device con
        // Prezz.one/Linux Mint: total 1, added 0 dopo la lettura).
        if (notificationGroup->activeNotifications.isEmpty()) {
            LOG("Live group" << groupId << "chat" << chatId << "total" << totalCount
                << "but no real notifications: purging instead of publishing");
            const int maxId = notificationGroup->maxNotificationId;
            tdLibWrapper->removeNotificationGroup(groupId,
                maxId > 0 ? maxId : PURGE_ALL_NOTIFICATIONS_ID);
            dismissNotificationGroup(groupId); // rimuove dalla mappa, chiude, gestisce il LED
            return;
        }

        // Decide if we need a bzzz
        switch (feedback) {
        case AppSettings::NotificationFeedbackNone:
            break;
        case AppSettings::NotificationFeedbackNew:
            // Non-zero replacesId means that notification has already been published
            needFeedback = !notificationGroup->nemoNotification->replacesId();
            break;
        case AppSettings::NotificationFeedbackAll:
            // Even in this case don't alert the user just about removals
            needFeedback = !addedNotifications.isEmpty();
            break;
        }

        // Publish new or update the existing notification
        LOG("Feedback" << needFeedback);
        publishNotification(notificationGroup, needFeedback);
    } else if (notificationGroup) {
        // No active notifications left in this group.
        dismissNotificationGroup(groupId);
    }

    if (notificationGroups.isEmpty()) {
        // No active notifications left at all
        controlLedNotification(false);
    } else if (needFeedback) {
        controlLedNotification(true);
    }
}

void NotificationManager::handleUpdateNotification(const QVariantMap &updatedNotification)
{
    LOG("Received notification update, group ID:" << updatedNotification.value(NOTIFICATION_GROUP_ID).toInt());
}

void NotificationManager::handleChatDiscovered(const QString &chatId, const QVariantMap &chatInformation)
{
    const qlonglong id = chatId.toLongLong();
    ChatInfo *chat = chatMap.value(id);
    if (chat) {
        chat->setChatInfo(chatInformation);
        LOG("Updated chat information" << id << chat->title);
    } else {
        chat = new ChatInfo(chatInformation);
        chatMap.insert(id, chat);
        LOG("New chat" << id << chat->title);
    }

    // 4° STADIO: risolvi i gruppi della snapshot differiti perché questa chat
    // (canale/gruppo lazy) non era ancora in cache. Ora conosciamo lo stato di
    // lettura: se interamente letta è un fantasma -> purge, altrimenti publish.
    if (!pendingSnapshotGroups.isEmpty()) {
        const QList<int> pendingIds = pendingSnapshotGroups.keys();
        QListIterator<int> pendingIt(pendingIds);
        while (pendingIt.hasNext()) {
            const int groupId = pendingIt.next();
            const PendingSnapshotGroup p = pendingSnapshotGroups.value(groupId);
            if (p.chatId != id) {
                continue;
            }
            pendingSnapshotGroups.remove(groupId);
            if (chatFullyRead(chatInformation)) {
                purgeSnapshotGroup(groupId, id, p.notifications);
            } else {
                updateNotificationGroup(groupId, id, p.totalCount, p.notifications);
            }
        }
        if (pendingSnapshotGroups.isEmpty()) {
            pendingFlushTimer.stop();
        }
    }
}

void NotificationManager::handleChatTitleUpdated(const QString &chatId, const QString &title)
{
    const qlonglong id = chatId.toLongLong();
    ChatInfo *chat = chatMap.value(id);
    if (chat) {
        LOG("Chat" << id << "title changed to" << title);
        chat->title = title;

        // Silently update notification summary
        QListIterator<NotificationGroup*> groupsIterator(notificationGroups.values());
        while (groupsIterator.hasNext()) {
            const NotificationGroup *group = groupsIterator.next();
            if (group->chatId == id) {
                LOG("Updating summary for group ID" << group->notificationGroupId);
                publishNotification(group, false);
                break;
            }
        }
    }
}

void NotificationManager::handleNewStory(qlonglong chatId)
{
    // Subordinata al master notifiche + al toggle dedicato storie.
    if (!appSettings || !appSettings->notificationsEnabled() || !appSettings->notificationStoriesEnabled()) {
        return;
    }

    const QVariantMap chat = tdLibWrapper->getChat(QString::number(chatId));
    QString title = chat.value(TITLE).toString();
    if (title.isEmpty()) {
        const ChatInfo *info = chatMap.value(chatId);
        if (info) title = info->title;
    }
    LOG("New story notification for" << chatId << title);

    const QString body = tr("posted a new story");
    const bool appActive = (qGuiApp->applicationState() == Qt::ApplicationActive);

    // Fire-and-forget: la notifica pubblicata vive nel daemon di sistema, il
    // wrapper C++ può essere distrutto subito dopo publish() senza chiuderla.
    Notification *notification = new Notification(this);
    applyBranding(notification);
    notification->setTimestamp(QDateTime::currentDateTime());
    notification->setSummary(title);
    notification->setBody(body);
    notification->setHintValue(HINT_IMAGE_PATH, notificationIconFile);

    // Tap = apri l'app E naviga alla pagina Storie (deep-link openStories,
    // gestito in OverviewPage.qml onPleaseOpenStories; pattern come openMessage).
    notification->setRemoteAction(Notification::remoteAction("default", "openStories",
        APP_ORIGIN, "/com/github/RootGPT_YouTube/rootelegram", APP_ORIGIN, "openStories"));

    if (appActive) {
        // L'utente sta già usando l'app: notifica silenziosa, niente popup.
        notification->setHintValue(HINT_SUPPRESS_SOUND, true);
        notification->setHintValue(HINT_DISPLAY_ON, false);
        notification->setHintValue(HINT_VISIBILITY, QString());
        notification->setUrgency(Notification::Low);
    } else {
        notification->setPreviewSummary(title);
        notification->setPreviewBody(body);
        notification->setHintValue(HINT_SUPPRESS_SOUND, !appSettings->notificationSoundsEnabled());
        notification->setHintValue(HINT_DISPLAY_ON, appSettings->notificationTurnsDisplayOn());
        notification->setHintValue(HINT_VISIBILITY, VISIBILITY_PUBLIC);
        notification->setUrgency(Notification::Normal);
    }

    notification->publish();
    notification->deleteLater();
}

void NotificationManager::handleMessageReaction(qlonglong chatId, qlonglong messageId, const QVariantList &unreadReactions, int unreadReactionCount)
{
    // Subordinata al master notifiche + al toggle dedicato reaction.
    if (!appSettings || !appSettings->notificationsEnabled() || !appSettings->notificationReactionsEnabled()) {
        return;
    }
    // updateMessageUnreadReactions arriva anche quando la reaction viene letta
    // (count torna a 0) o rimossa: notifichiamo solo quando c'è una nuova
    // reaction non letta.
    const QString reactionKey = QString::number(chatId) + QLatin1Char(':') + QString::number(messageId);
    if (unreadReactionCount <= 0 || unreadReactions.isEmpty()) {
        notifiedReactions.remove(reactionKey);
        return;
    }

    // Dedup: TDLib può ri-emettere lo stesso stato di reaction non lette (es.
    // dopo un resync o il riciclo anti-RAM). Notifichiamo solo se compare una
    // firma (autore|emoji) mai vista per questo messaggio; lo stato salvato
    // viene comunque riallineato (dimentica anche le reaction rimosse).
    QSet<QString> currentSignatures;
    QVariantMap newestUnseenReaction;
    const QSet<QString> seenSignatures = notifiedReactions.value(reactionKey);
    for (int i = 0; i < unreadReactions.size(); i++) {
        const QVariantMap reaction = unreadReactions.at(i).toMap();
        const QVariantMap rType = reaction.value(TYPE).toMap();
        const QVariantMap rSender = reaction.value(SENDER_ID).toMap();
        const QString signature = rSender.value(USER_ID).toString() + QLatin1Char('|')
            + rSender.value(CHAT_ID).toString() + QLatin1Char('|')
            + rType.value(EMOJI).toString() + QLatin1Char('|')
            + rType.value("custom_emoji_id").toString();
        currentSignatures.insert(signature);
        if (!seenSignatures.contains(signature)) {
            newestUnseenReaction = reaction; // l'ultima nuova in ordine di lista = la più recente
        }
    }
    notifiedReactions.insert(reactionKey, currentSignatures);
    if (newestUnseenReaction.isEmpty()) {
        LOG("Reaction state already notified for" << chatId << messageId << "- skipping duplicate");
        return;
    }

    // Prendiamo l'ultima reaction non letta nuova (la più recente) per emoji + autore.
    const QVariantMap lastReaction = newestUnseenReaction;
    const QVariantMap reactionType = lastReaction.value(TYPE).toMap();
    const QString emoji = reactionType.value(EMOJI).toString(); // vuoto per custom emoji

    // Autore della reaction: se è un utente, mostriamo il suo nome; altrimenti
    // ripieghiamo sul titolo della chat.
    QString reactorName;
    const QVariantMap senderId = lastReaction.value(SENDER_ID).toMap();
    const qlonglong reactorUserId = senderId.value(USER_ID).toLongLong();
    if (reactorUserId != 0) {
        // Self-reaction: improbabile, ma evitiamo di notificare noi stessi.
        const qlonglong ownUserId = tdLibWrapper->getUserInformation().value(ID).toLongLong();
        if (reactorUserId == ownUserId) {
            return;
        }
        const QVariantMap reactor = tdLibWrapper->getUserInformation(QString::number(reactorUserId));
        reactorName = (reactor.value(FIRST_NAME).toString() + " " + reactor.value(LAST_NAME).toString()).trimmed();
    }
    if (reactorName.isEmpty()) {
        const QVariantMap chat = tdLibWrapper->getChat(QString::number(chatId));
        reactorName = chat.value(TITLE).toString();
        if (reactorName.isEmpty()) {
            const ChatInfo *info = chatMap.value(chatId);
            if (info) reactorName = info->title;
        }
    }
    LOG("New reaction notification for" << chatId << messageId << reactorName << emoji);

    const QString body = emoji.isEmpty()
        ? tr("reacted to your message")
        : tr("reacted %1 to your message").arg(emoji);
    const bool appActive = (qGuiApp->applicationState() == Qt::ApplicationActive);

    // Fire-and-forget come handleNewStory: la notifica vive nel daemon di sistema.
    Notification *notification = new Notification(this);
    applyBranding(notification);
    notification->setTimestamp(QDateTime::currentDateTime());
    notification->setSummary(reactorName);
    notification->setBody(body);
    notification->setHintValue(HINT_IMAGE_PATH, notificationIconFile);

    // Tap = apri la chat e scrolla al messaggio reazionato (deep-link openMessage,
    // identico a publishNotification).
    QVariantList remoteActionArguments;
    remoteActionArguments.append(QString::number(chatId));
    remoteActionArguments.append(QString::number(messageId));
    notification->setRemoteAction(Notification::remoteAction("default", "openMessage",
        APP_ORIGIN, "/com/github/RootGPT_YouTube/rootelegram", APP_ORIGIN,
        "openMessage", remoteActionArguments));

    if (appActive) {
        notification->setHintValue(HINT_SUPPRESS_SOUND, true);
        notification->setHintValue(HINT_DISPLAY_ON, false);
        notification->setHintValue(HINT_VISIBILITY, QString());
        notification->setUrgency(Notification::Low);
    } else {
        notification->setPreviewSummary(reactorName);
        notification->setPreviewBody(body);
        notification->setHintValue(HINT_SUPPRESS_SOUND, !appSettings->notificationSoundsEnabled());
        notification->setHintValue(HINT_DISPLAY_ON, appSettings->notificationTurnsDisplayOn());
        notification->setHintValue(HINT_VISIBILITY, VISIBILITY_PUBLIC);
        notification->setUrgency(Notification::Normal);
    }

    notification->publish();
    notification->deleteLater();
}

void NotificationManager::publishNotification(const NotificationGroup *notificationGroup, bool needFeedback)
{
    // Gate sulle notifiche desktop: il toggle UI dell'utente.
    if (appSettings && !appSettings->notificationsEnabled()) {
        return;
    }
    QVariantMap messageMap;
    const ChatInfo *chatInformation = chatMap.value(notificationGroup->chatId);
    if (!notificationGroup->notificationOrder.isEmpty()) {
        const int lastNotificationId = notificationGroup->notificationOrder.last();
        const QVariantMap lastNotification(notificationGroup->activeNotifications.value(lastNotificationId));
#ifdef RT_VOICE_CALLS
        // Le chiamate entranti hanno già la loro schermata in-app (+ suoneria e
        // vibrazione): la notifica-messaggio "ti sta chiamando" di TDLib sarebbe
        // ridondante, la sopprimiamo.
        if (lastNotification.value(TYPE).toMap().value("@type").toString() == QLatin1String("notificationTypeNewCall")) {
            LOG("Skipping new-call notification (handled by in-app call UI)");
            return;
        }
#endif
        messageMap = lastNotification.value(TYPE).toMap().value(MESSAGE).toMap();
    }

    Notification *nemoNotification = notificationGroup->nemoNotification;
    applyBranding(nemoNotification);
    if (!messageMap.isEmpty()) {
        nemoNotification->setTimestamp(QDateTime::fromMSecsSinceEpoch(messageMap.value(DATE).toLongLong() * 1000));

        QVariantList remoteActionArguments;
        remoteActionArguments.append(QString::number(notificationGroup->chatId));
        remoteActionArguments.append(messageMap.value(ID).toString());
        nemoNotification->setRemoteAction(Notification::remoteAction("default", "openMessage",
            APP_ORIGIN, "/com/github/RootGPT_YouTube/rootelegram", APP_ORIGIN,
            "openMessage", remoteActionArguments));
    }

    QString notificationBody;
    const QVariantMap senderInformation = messageMap.value(SENDER_ID).toMap();
    bool outputMessageCount = notificationGroup->totalCount > 1;
    bool messageIsEmpty = messageMap.isEmpty();
    if (outputMessageCount || messageIsEmpty) {
        // Either we have more than one notification or we have no content to display
        LOG("Group" << notificationGroup->notificationGroupId << "has" << notificationGroup->totalCount << "notifications");
        notificationBody = tr("%Ln unread messages", "", notificationGroup->totalCount);
    }
    if ((!outputMessageCount || appSettings->notificationAlwaysShowPreview()) && !messageIsEmpty) {
        LOG("Group" << notificationGroup->notificationGroupId << "has 1 notification");
        if (outputMessageCount) {
            notificationBody += "; ";
        }
        if (chatInformation && (chatInformation->type == TDLibWrapper::ChatTypeBasicGroup ||
           (chatInformation->type == TDLibWrapper::ChatTypeSupergroup && !chatInformation->isChannel))) {
            // Add author
            QString fullName;
            if (senderInformation.value(_TYPE).toString() == "messageSenderChat") {
                fullName = tdLibWrapper->getChat(senderInformation.value(CHAT_ID).toString()).value(TITLE).toString();
            } else {
                fullName = RooTelegramUtils::getUserName(tdLibWrapper->getUserInformation(senderInformation.value(USER_ID).toString()));
            }
            notificationBody += fullName.trimmed() + ": ";
        }
        notificationBody += RooTelegramUtils::getMessageShortText(tdLibWrapper, messageMap.value(CONTENT).toMap(), (chatInformation ? chatInformation->isChannel : false), tdLibWrapper->getUserInformation().value(ID).toLongLong(), senderInformation );
    }

    const QString summary(chatInformation ? chatInformation->title : QString());
    nemoNotification->setBody(notificationBody);
    nemoNotification->setSummary(summary);
    nemoNotification->setHintValue(HINT_VIBRA, needFeedback);
    nemoNotification->setHintValue(HINT_IMAGE_PATH, notificationIconFile);
    // Persistito per poter fare removeNotificationGroup anche dopo un riavvio
    // del processo (riciclo anti-RAM), quando la mappa in RAM è andata persa.
    nemoNotification->setHintValue(HINT_MAX_NOTIFICATION_ID, notificationGroup->maxNotificationId);

    // Don't show popup for the currently open chat
    if (!needFeedback || (chatModel->getChatId() == notificationGroup->chatId &&
            qGuiApp->applicationState() == Qt::ApplicationActive)) {
        nemoNotification->setHintValue(HINT_SUPPRESS_SOUND, true);
        nemoNotification->setHintValue(HINT_DISPLAY_ON, false);
        nemoNotification->setHintValue(HINT_VISIBILITY, QString());
        nemoNotification->setUrgency(Notification::Low);
    } else {
        if (!appSettings->notificationSuppressContent()) {
            nemoNotification->setPreviewBody(notificationBody);
        } else {
            nemoNotification->setPreviewBody(tr("%Ln unread messages", "", notificationGroup->totalCount));
        }
        nemoNotification->setPreviewSummary(summary);
        nemoNotification->setHintValue(HINT_SUPPRESS_SOUND, !appSettings->notificationSoundsEnabled());
        nemoNotification->setHintValue(HINT_DISPLAY_ON, appSettings->notificationTurnsDisplayOn());
        nemoNotification->setHintValue(HINT_VISIBILITY, VISIBILITY_PUBLIC);
        nemoNotification->setUrgency(Notification::Normal);
    }

    nemoNotification->publish();
}

void NotificationManager::dismissNotificationGroup(int groupId)
{
    NotificationGroup *notificationGroup = notificationGroups.value(groupId);
    if (!notificationGroup) {
        return;
    }
    // Prima fuori dalla mappa, POI close(): se closed() venisse emesso in
    // modo sincrono, handleNotificationClosed non deve più trovare il gruppo
    // (lo tratterebbe come rimozione utente → doppio delete).
    notificationGroups.remove(groupId);
    notificationGroup->nemoNotification->close();
    delete notificationGroup;
    if (notificationGroups.isEmpty()) {
        controlLedNotification(false);
    }
}

void NotificationManager::controlLedNotification(bool enabled)
{
    static const QString PATTERN("PatternCommunicationIM");
    if (enabled) {
        mceInterface->ledPatternActivate(PATTERN);
    } else {
        mceInterface->ledPatternDeactivate(PATTERN);
    }
}

void NotificationManager::connectNotificationClosed(int groupId, Notification *notification)
{
    // Lipstick emette NotificationClosed quando la notifica sparisce dallo
    // schermo: tap dell'utente, clear dalla vista eventi, o il nostro close().
    // La lookup per groupId nel gestore distingue i casi: se il gruppo è ancora
    // in mappa la rimozione NON è partita da noi → è stato l'utente.
    connect(notification, &Notification::closed, this, [this, groupId](uint reason) {
        LOG("Notification closed by daemon, group" << groupId << "reason" << reason);
        handleNotificationClosed(groupId);
    });
    // Cintura: il tap invoca la remote action e lipstick rimuove la notifica;
    // se closed() non arrivasse, clicked() copre comunque il caso tap.
    connect(notification, &Notification::clicked, this, [this, groupId]() {
        LOG("Notification clicked, group" << groupId);
        handleNotificationClosed(groupId);
    });
}

void NotificationManager::handleNotificationClosed(int groupId)
{
    NotificationGroup *notificationGroup = notificationGroups.value(groupId);
    if (!notificationGroup) {
        // Chiusa da noi (close() dopo che TDLib ha rimosso il gruppo): il
        // gruppo è già stato tolto dalla mappa, niente da fare.
        return;
    }
    // Rimossa dall'utente (tap o clear): informa TDLib, altrimenti il gruppo
    // resta attivo nel suo DB e viene ri-pubblicato in updateActiveNotifications
    // al prossimo avvio del client (= a ogni riciclo anti-RAM) → la stessa
    // notifica "ricompare" dopo un po' anche se già vista.
    LOG("Notification group" << groupId << "removed by user, informing TDLib up to id" << notificationGroup->maxNotificationId);
    // maxNotificationId==0 = gruppo zombie ripubblicato senza contenuto (o
    // hint di una versione vecchia): senza id noto si spurga tutto il gruppo,
    // altrimenti TDLib non viene mai informato e la notifica ricompare a
    // ogni riciclo anti-RAM.
    tdLibWrapper->removeNotificationGroup(groupId, notificationGroup->maxNotificationId > 0
        ? notificationGroup->maxNotificationId : PURGE_ALL_NOTIFICATIONS_ID);
    notificationGroups.remove(groupId);
    // Se lipstick non l'avesse già rimossa (percorso clicked()), chiudila:
    // per una notifica già rimossa dal daemon è un no-op innocuo.
    notificationGroup->nemoNotification->close();
    // Siamo dentro un segnale del Notification stesso: mai delete diretto del
    // sender, si usa deleteLater e si sgancia dal distruttore del gruppo.
    notificationGroup->nemoNotification->deleteLater();
    notificationGroup->nemoNotification = nullptr;
    delete notificationGroup;
    if (notificationGroups.isEmpty()) {
        controlLedNotification(false);
    }
}
