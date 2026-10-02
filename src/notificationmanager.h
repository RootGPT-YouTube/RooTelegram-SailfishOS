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

#ifndef NOTIFICATIONMANAGER_H
#define NOTIFICATIONMANAGER_H

#include <QObject>
#include <QHash>
#include <QSet>
#include <QTimer>
#include <nemonotifications-qt5/notification.h>
#include "tdlibwrapper.h"
#include "appsettings.h"
#include "mceinterface.h"

class ChatModel;

class NotificationManager : public QObject
{
    Q_OBJECT
    class ChatInfo;
    class NotificationGroup;
    struct PendingSnapshotGroup;

public:

    NotificationManager(TDLibWrapper *tdLibWrapper, AppSettings *appSettings, MceInterface *mceInterface, ChatModel *chatModel);
    ~NotificationManager() override;

public slots:

    void handleUpdateActiveNotifications(const QVariantList &notificationGroups);
    void handleUpdateNotificationGroup(const QVariantMap &notificationGroupUpdate);
    void handleUpdateNotification(const QVariantMap &updatedNotification);
    void handleChatDiscovered(const QString &chatId, const QVariantMap &chatInformation);
    void handleChatTitleUpdated(const QString &chatId, const QString &title);
    void flushPendingSnapshotGroups();
    void handleNewStory(qlonglong chatId);
    void handleMessageReaction(qlonglong chatId, qlonglong messageId, const QVariantList &unreadReactions, int unreadReactionCount);
    // A reply written in the notification's text field (D-Bus: replyToChat).
    void handleReplyToChat(const QString &chatId, const QString &message);

private:

    void applyBranding(Notification *notification) const;
    void publishNotification(const NotificationGroup *notificationGroup, bool needFeedback);
    void controlLedNotification(bool enabled);
    void connectNotificationClosed(int groupId, Notification *notification);
    void handleNotificationClosed(int groupId);
    void dismissNotificationGroup(int groupId);
    // Anti-fantasma 4° stadio: spurga in TDLib un gruppo zombie della snapshot
    // senza pubblicarlo (lista notifiche o id ignoto -> PURGE_ALL).
    void purgeSnapshotGroup(int groupId, qlonglong chatId, const QVariantList &notifications);
    // True se la chat (già in cache) risulta interamente letta.
    static bool chatFullyRead(const QVariantMap &chatInformation);
    // True if we may write in this chat: decides whether the notification
    // offers the "Reply" action (same logic as hasSendPrivilege() in
    // ChatPage.qml, but in C++ and only for text messages).
    bool canSendToChat(qlonglong chatId, const ChatInfo *chatInformation) const;
    void sendReply(qlonglong chatId, const QString &message);
    void flushPendingReplies();
    // Id of the last notified message of that chat (0 if unknown): needed
    // to mark it as viewed when the reply comes from the notification.
    qlonglong lastNotifiedMessageId(qlonglong chatId) const;
    void updateNotificationGroup(int groupId, qlonglong chatId, int totalCount,
        const QVariantList &addedNotifications,
        const QVariantList &removedNotificationIds = QVariantList(),
        AppSettings::NotificationFeedback feedback = AppSettings::NotificationFeedbackNone);

private:

    TDLibWrapper *tdLibWrapper;
    AppSettings *appSettings;
    MceInterface *mceInterface;
    ChatModel *chatModel;
    QMap<qlonglong,ChatInfo*> chatMap;
    QMap<int,NotificationGroup*> notificationGroups;
    QString notificationIconFile;
    // Gruppi della snapshot d'avvio la cui chat (canale/gruppo lazy) NON era
    // ancora in cache: decisione pubblica/spurga DIFFERITA a handleChatDiscovered
    // (o al flush fail-open). Chiave = groupId. Evita il fantasma dei gruppi con
    // lista notifiche NON vuota su chat non ancora note.
    QHash<int,PendingSnapshotGroup> pendingSnapshotGroups;
    QTimer pendingFlushTimer;
    // Dedup notifiche reaction: per messaggio ("chatId:messageId") l'insieme
    // delle firme (autore|emoji) già notificate — evita doppioni quando TDLib
    // ri-emette updateMessageUnreadReactions con lo stesso stato.
    QHash<QString, QSet<QString> > notifiedReactions;
    // Replies that arrived before TDLib was authorized: happens when the
    // notification action itself started the daemon (D-Bus activation).
    // They are sent at the first AuthorizationReady.
    QList<QPair<qlonglong,QString> > pendingReplies;

};

#endif // NOTIFICATIONMANAGER_H
