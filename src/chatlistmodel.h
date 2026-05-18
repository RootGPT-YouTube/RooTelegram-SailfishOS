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

#ifndef CHATLISTMODEL_H
#define CHATLISTMODEL_H

#include <QAbstractListModel>
#include "tdlibwrapper.h"
#include "appsettings.h"

class ChatListModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(bool showAllChats READ showAllChats WRITE setShowAllChats NOTIFY showAllChatsChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:

    enum Role {
        RoleDisplay = Qt::DisplayRole,
        RoleChatId,
        RoleChatType,
        RoleGroupId,
        RoleTitle,
        RolePhotoSmall,
        RoleUnreadCount,
        RoleUnreadMentionCount,
        RoleUnreadReactionCount,
        RoleAvailableReactions,
        RoleLastReadInboxMessageId,
        RoleLastMessageSenderId,
        RoleLastMessageDate,
        RoleLastMessageText,
        RoleLastMessageStatus,
        RoleChatMemberStatus,
        RoleSecretChatState,
        RoleIsVerified,
        RoleIsChannel,
        RoleIsMarkedAsUnread,
        RoleIsPinned,
        RoleFilter,
        RoleDraftMessageText,
        RoleDraftMessageDate
    };

    ChatListModel(TDLibWrapper *tdLibWrapper, AppSettings *appSettings);
    ~ChatListModel() override;

    QHash<int,QByteArray> roleNames() const Q_DECL_OVERRIDE;
    int rowCount(const QModelIndex &index = QModelIndex()) const Q_DECL_OVERRIDE;
    QVariant data(const QModelIndex &index, int role) const Q_DECL_OVERRIDE;

    Q_INVOKABLE void redrawModel();
    Q_INVOKABLE QVariantMap get(int row);
    Q_INVOKABLE QVariantMap getById(qlonglong chatId);
    Q_INVOKABLE void reset();
    Q_INVOKABLE void setActiveFolder(int folderId);

    Q_INVOKABLE void calculateUnreadState();
    Q_INVOKABLE QVariantMap getPrivateUnreadCounts() const;

    bool showAllChats() const;
    void setShowAllChats(bool showAll);

private slots:
    void handleChatDiscovered(const QString &chatId, const QVariantMap &chatInformation);
    void handleChatLastMessageUpdated(const QString &chatId, const QString &order, const QVariantMap &lastMessage);
    void handleChatOrderUpdated(const QString &chatId, const QString &order);
    void handleChatReadInboxUpdated(const QString &chatId, const QString &lastReadInboxMessageId, int unreadCount);
    void handleChatReadOutboxUpdated(const QString &chatId, const QString &lastReadOutboxMessageId);
    void handleChatPhotoUpdated(qlonglong chatId, const QVariantMap &photo);
    void handleChatPinnedMessageUpdated(qlonglong chatId, qlonglong pinnedMessageId);
    void handleMessageSendSucceeded(qlonglong messageId, qlonglong oldMessageId, const QVariantMap &message);
    void handleChatNotificationSettingsUpdated(const QString &chatId, const QVariantMap &chatNotificationSettings);
    void handleGroupUpdated(qlonglong groupId);
    void handleSecretChatUpdated(qlonglong secretChatId, const QVariantMap &secretChat);
    void handleChatTitleUpdated(const QString &chatId, const QString &title);
    void handleChatPinnedUpdated(qlonglong chatId, bool chatIsPinned);
    void handleChatIsMarkedAsUnreadUpdated(qlonglong chatId, bool chatIsMarkedAsUnread);
    void handleChatDraftMessageUpdated(qlonglong chatId, const QVariantMap &draftMessage, const QString &order);
    void handleChatUnreadMentionCountUpdated(qlonglong chatId, int unreadMentionCount);
    void handleChatUnreadReactionCountUpdated(qlonglong chatId, int unreadReactionCount);
    void handleChatAvailableReactionsUpdated(qlonglong chatId, const QVariantMap availableReactions);
    void handleChatPendingJoinRequestsUpdated(qlonglong chatId, const QVariantMap &pendingJoinRequests);
    void handleChatFolderPositionUpdated(const QString &chatId, int folderId, const QString &order, bool isPinned);
    void handleRelativeTimeRefreshTimer();

signals:
    void countChanged();
    void showAllChatsChanged();
    void chatChanged(const qlonglong &changedChatId);
    void chatJoined(const qlonglong &chatId, const QString &chatTitle);
    void unreadStateChanged(int unreadMessagesCount, int unreadChatsCount);
    void privateUnreadStateChanged();

private:
    class ChatData;
    void addVisibleChat(ChatData *chat);
    void updateChatVisibility(const TDLibWrapper::Group *group);
    void updateSecretChatVisibility(const QVariantMap secretChatDetails);
    int updateChatOrder(int chatIndex);
    void enableRefreshTimer();

private:
    TDLibWrapper *tdLibWrapper;
    AppSettings *appSettings;
    QTimer *relativeTimeRefreshTimer;
    QList<ChatData*> chatList;
    QHash<qlonglong,int> chatIndexMap;
    QHash<qlonglong,ChatData*> hiddenChats;
    QHash<qlonglong,ChatData*> folderFilteredChats; // chat escluse dalla cartella attiva
    bool showHiddenChats;
    int activeFolderId;
    QHash<qlonglong, QHash<int, QString>> folderOrders; // chatId -> folderId -> order
};

#endif // CHATLISTMODEL_H
