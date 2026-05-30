/*
    Copyright (C) 2020-22 Sebastian J. Wolf and other contributors
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
#ifndef TDLIBWRAPPER_H
#define TDLIBWRAPPER_H

#include <QCoreApplication>
#include <QUrl>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QNetworkAccessManager>
#include <QNetworkConfigurationManager>
#include <QHash>
#include <QSet>
#include <QByteArray>
#include <td/telegram/td_json_client.h>
#include "tdlibreceiver.h"
#include "dbusadaptor.h"
#include "dbusinterface.h"
#include "emojisearchworker.h"
#include "appsettings.h"
#include "mceinterface.h"

class TDLibWrapper : public QObject
{
    Q_OBJECT
    Q_PROPERTY(AuthorizationState authorizationState READ getAuthorizationState NOTIFY authorizationStateChanged)
    Q_PROPERTY(QVariantMap userInformation READ getUserInformation NOTIFY ownUserUpdated)

public:
    explicit TDLibWrapper(AppSettings *appSettings, MceInterface *mceInterface, QObject *parent = nullptr);
    ~TDLibWrapper();

    enum AuthorizationState {
        Closed,
        Closing,
        LoggingOut,
        AuthorizationReady,
        WaitCode,
        WaitEncryptionKey,
        WaitOtherDeviceConfirmation,
        WaitPassword,
        WaitPhoneNumber,
        WaitRegistration,
        WaitTdlibParameters,
        AuthorizationStateClosed,
        AuthorizationStateLoggingOut
    };
    Q_ENUM(AuthorizationState)

    enum ConnectionState {
        Connecting,
        ConnectingToProxy,
        ConnectionReady,
        Updating,
        WaitingForNetwork
    };
    Q_ENUM(ConnectionState)

    enum ChatType {
        ChatTypeUnknown,
        ChatTypePrivate,
        ChatTypeBasicGroup,
        ChatTypeSupergroup,
        ChatTypeSecret
    };
    Q_ENUM(ChatType)

    enum ChatMemberStatus {
        ChatMemberStatusUnknown,
        ChatMemberStatusCreator,
        ChatMemberStatusAdministrator,
        ChatMemberStatusMember,
        ChatMemberStatusRestricted,
        ChatMemberStatusLeft,
        ChatMemberStatusBanned
    };
    Q_ENUM(ChatMemberStatus)

    enum SecretChatState {
        SecretChatStateUnknown,
        SecretChatStateClosed,
        SecretChatStatePending,
        SecretChatStateReady,
    };
    Q_ENUM(SecretChatState)

    enum UserPrivacySetting {
        SettingAllowChatInvites,
        SettingAllowFindingByPhoneNumber,
        SettingShowLinkInForwardedMessages,
        SettingShowPhoneNumber,
        SettingShowProfilePhoto,
        SettingShowStatus,
        SettingUnknown
    };
    Q_ENUM(UserPrivacySetting)

    enum UserPrivacySettingRule {
        RuleAllowAll,
        RuleAllowContacts,
        RuleRestrictAll
    };
    Q_ENUM(UserPrivacySettingRule)

    enum NetworkType {
        Mobile,
        MobileRoaming,
        None,
        Other,
        WiFi
    };
    Q_ENUM(NetworkType)

    class Group {
    public:
        Group(qlonglong id) : groupId(id) { }
        ChatMemberStatus chatMemberStatus() const;
    public:
        const qlonglong groupId;
        QVariantMap groupInfo;
    };

    Q_INVOKABLE QString getVersion();
    Q_INVOKABLE TDLibWrapper::AuthorizationState getAuthorizationState();
    Q_INVOKABLE QVariantMap getAuthorizationStateData();
    Q_INVOKABLE TDLibWrapper::ConnectionState getConnectionState();
    Q_INVOKABLE QVariantMap getUserInformation();
    Q_INVOKABLE QVariantMap getUserInformation(const QString &userId);
    Q_INVOKABLE bool hasUserInformation(const QString &userId);
    Q_INVOKABLE QVariantMap getUserInformationByName(const QString &userName);
    Q_INVOKABLE UserPrivacySettingRule getUserPrivacySettingRule(UserPrivacySetting userPrivacySetting);
    Q_INVOKABLE QVariantMap getUnreadMessageInformation();
    Q_INVOKABLE QVariantMap getUnreadChatInformation();
    Q_INVOKABLE QVariantMap getBasicGroup(qlonglong groupId) const;
    Q_INVOKABLE QVariantMap getSuperGroup(qlonglong groupId) const;
    Q_INVOKABLE QVariantMap getChat(const QString &chatId);
    Q_INVOKABLE QVariantMap getSecretChatFromCache(qlonglong secretChatId);
    Q_INVOKABLE QStringList getChatReactions(const QString &chatId);
    Q_INVOKABLE QString getOptionString(const QString &optionName);
    Q_INVOKABLE void copyFileToDownloads(const QString &filePath, bool openAfterCopy = false);
    Q_INVOKABLE void copyFileToPictures(const QString &filePath);
    Q_INVOKABLE void openFileOnDevice(const QString &filePath);
    Q_INVOKABLE void controlScreenSaver(bool enabled);
    Q_INVOKABLE bool getJoinChatRequested();
    Q_INVOKABLE void registerJoinChat();

    DBusAdaptor *getDBusAdaptor();

    // Direct TDLib functions
    Q_INVOKABLE void sendRequest(const QVariantMap &requestObject);
    Q_INVOKABLE void setAuthenticationPhoneNumber(const QString &phoneNumber);
    Q_INVOKABLE void setAuthenticationCode(const QString &authenticationCode);
    Q_INVOKABLE void setAuthenticationPassword(const QString &authenticationPassword);
    Q_INVOKABLE void registerUser(const QString &firstName, const QString &lastName);
    Q_INVOKABLE void logout();
    Q_INVOKABLE void getChats();
    Q_INVOKABLE void getChatFolders();
    Q_INVOKABLE void downloadFile(int fileId);
    Q_INVOKABLE void openChat(const QString &chatId);
    Q_INVOKABLE void closeChat(const QString &chatId);
    Q_INVOKABLE void joinChat(const QString &chatId);
    Q_INVOKABLE void leaveChat(const QString &chatId);
    Q_INVOKABLE void deleteChat(qlonglong chatId);
    Q_INVOKABLE void getChatHistory(qlonglong chatId, qlonglong fromMessageId = 0, int offset = -1, int limit = 50, bool onlyLocal = false);
    Q_INVOKABLE void viewMessage(qlonglong chatId, qlonglong messageId, bool force);
    Q_INVOKABLE void pinMessage(const QString &chatId, const QString &messageId, bool disableNotification = false, bool onlyForSelf = false);
    Q_INVOKABLE void unpinMessage(const QString &chatId, const QString &messageId);
    Q_INVOKABLE void sendTextMessage(qlonglong chatId, const QString &message, qlonglong replyToMessageId = 0);
    Q_INVOKABLE void sendTextMessageWithCustomEmoji(qlonglong chatId, const QString &message, const QVariantList &customEmojiEntities, qlonglong replyToMessageId = 0);
    Q_INVOKABLE void translateText(const QString &text, const QString &toLanguageCode);
    Q_INVOKABLE void translateMessageText(qlonglong chatId, qlonglong messageId, const QString &toLanguageCode);
    Q_INVOKABLE void sendPhotoMessage(qlonglong chatId, const QString &filePath, const QString &message, qlonglong replyToMessageId = 0);
    Q_INVOKABLE void sendPhotoAlbum(qlonglong chatId, const QStringList &filePaths, const QString &caption, qlonglong replyToMessageId = 0);
    Q_INVOKABLE void sendVideoMessage(qlonglong chatId, const QString &filePath, const QString &message, qlonglong replyToMessageId = 0);
    Q_INVOKABLE void sendDocumentMessage(qlonglong chatId, const QString &filePath, const QString &message, qlonglong replyToMessageId = 0);
    Q_INVOKABLE void sendVoiceNoteMessage(qlonglong chatId, const QString &filePath, const QString &message, qlonglong replyToMessageId = 0);
    Q_INVOKABLE void sendLocationMessage(qlonglong chatId, double latitude, double longitude, double horizontalAccuracy, qlonglong replyToMessageId = 0);
    Q_INVOKABLE void sendStickerMessage(qlonglong chatId, const QString &fileId, qlonglong replyToMessageId = 0);
    Q_INVOKABLE void sendPollMessage(qlonglong chatId, const QString &question, const QVariantList &options, bool anonymous, int correctOption, bool multiple, const QString &explanation, qlonglong replyToMessageId = 0);
    Q_INVOKABLE void forwardMessages(const QString &chatId, const QString &fromChatId, const QVariantList &messageIds, bool sendCopy, bool removeCaption);
    Q_INVOKABLE void getMessage(qlonglong chatId, qlonglong messageId);
    Q_INVOKABLE void getMessageLinkInfo(const QString &url, const QString &extra = "");
    Q_INVOKABLE void getExternalLinkInfo(const QString &url, const QString &extra = "");
    Q_INVOKABLE void getCallbackQueryAnswer(const QString &chatId, const QString &messageId, const QVariantMap &payload);
    Q_INVOKABLE void getChatPinnedMessage(qlonglong chatId);
    Q_INVOKABLE void getChatSponsoredMessage(qlonglong chatId);
    Q_INVOKABLE void setOptionInteger(const QString &optionName, int optionValue);
    Q_INVOKABLE void setOptionBoolean(const QString &optionName, bool optionValue);
    Q_INVOKABLE void setChatNotificationSettings(const QString &chatId, const QVariantMap &notificationSettings);
    Q_INVOKABLE void editMessageText(const QString &chatId, const QString &messageId, const QString &message);
    Q_INVOKABLE void editMessageTextWithCustomEmoji(const QString &chatId, const QString &messageId, const QString &message, const QVariantList &customEmojiEntities);
    Q_INVOKABLE void deleteMessages(const QString &chatId, const QVariantList messageIds);
    Q_INVOKABLE void deleteChatMessagesBySender(qlonglong chatId, qlonglong senderUserId);
    Q_INVOKABLE void banChatMember(qlonglong chatId, qlonglong userId, qlonglong bannedUntilDate = 0);
    Q_INVOKABLE void unbanChatMember(qlonglong chatId, qlonglong userId);
    Q_INVOKABLE void reportChatSpam(qlonglong chatId, const QVariantList &messageIds);
    Q_INVOKABLE void getMapThumbnailFile(const QString &chatId, double latitude, double longitude, int width, int height, const QString &extra);
    Q_INVOKABLE void getRecentStickers();
    Q_INVOKABLE void getInstalledStickerSets();
    Q_INVOKABLE void getInstalledCustomEmojiSets();
    Q_INVOKABLE void getStickerSet(const QString &setId, const QString &expectedType = QString());
    Q_INVOKABLE void getCustomEmojiStickers(const QVariantList &customEmojiIds, const QString &extra = QString());
    Q_INVOKABLE void ensureCustomEmoji(const QString &customEmojiId);
    Q_INVOKABLE QString getCustomEmojiPath(const QString &customEmojiId);
    Q_INVOKABLE QString getCustomEmojiFallback(const QString &customEmojiId);
    Q_INVOKABLE void cacheCustomEmojiFromSticker(const QVariantMap &sticker);
    Q_INVOKABLE bool isCustomEmojiFileId(int fileId) const;
    Q_INVOKABLE void getSupergroupMembers(const QString &groupId, int limit, int offset, const QString &filterType = QString(), const QString &extra = QString());
    Q_INVOKABLE void getChatEventLog(qlonglong chatId, qlonglong fromEventId = 0, int limit = 50);
    Q_INVOKABLE void getChatJoinRequests(qlonglong chatId, const QString &inviteLink = QString(), const QString &query = QString(), const QVariantMap &offsetRequest = QVariantMap(), int limit = 50);
    Q_INVOKABLE void processChatJoinRequest(qlonglong chatId, qlonglong userId, bool approve);
    Q_INVOKABLE void getGroupFullInfo(const QString &groupId, bool isSuperGroup);
    Q_INVOKABLE void getUserFullInfo(const QString &userId);
    Q_INVOKABLE void createVoiceCall(const QString &userId, bool isVideo = false);
    Q_INVOKABLE void acceptVoiceCall(qlonglong callId, bool isVideo = false);
    Q_INVOKABLE void discardVoiceCall(qlonglong callId, bool isDisconnected = false, int duration = 0, bool isVideo = false, qlonglong connectionId = 0);
    Q_INVOKABLE void sendCallSignalingData(qlonglong callId, const QByteArray &data);
    Q_INVOKABLE void createPrivateChat(const QString &userId, const QString &extra);
    Q_INVOKABLE void createNewSecretChat(const QString &userId, const QString &extra);
    Q_INVOKABLE void createSupergroupChat(const QString &supergroupId, const QString &extra);
    Q_INVOKABLE void createBasicGroupChat(const QString &basicGroupId, const QString &extra);
    Q_INVOKABLE void getGroupsInCommon(const QString &userId, int limit, int offset);
    Q_INVOKABLE void getUserProfilePhotos(const QString &userId, int limit, int offset);
    Q_INVOKABLE void setChatPermissions(const QString &chatId, const QVariantMap &chatPermissions);
    Q_INVOKABLE void setChatSlowModeDelay(const QString &chatId, int delay);
    Q_INVOKABLE void setChatDescription(const QString &chatId, const QString &description);
    Q_INVOKABLE void setChatTitle(const QString &chatId, const QString &title);
    Q_INVOKABLE void setChatPhoto(const QString &chatId, const QString &filePath);
    Q_INVOKABLE void setChatDiscussionGroup(qlonglong chatId, qlonglong discussionChatId);
    Q_INVOKABLE void getSuitableDiscussionChats();
    Q_INVOKABLE void getChatStatisticsUrl(qlonglong chatId, bool isDark = false);
    Q_INVOKABLE void setChatTheme(qlonglong chatId, const QString &themeName);
    Q_INVOKABLE QVariantList getAvailableChatThemes() const;
    Q_INVOKABLE void setBio(const QString &bio);
    Q_INVOKABLE void toggleSupergroupIsAllHistoryAvailable(const QString &groupId, bool isAllHistoryAvailable);
    Q_INVOKABLE void upgradeBasicGroupChatToSupergroupChat(qlonglong chatId);
    Q_INVOKABLE void setPollAnswer(const QString &chatId, qlonglong messageId, QVariantList optionIds);
    Q_INVOKABLE void stopPoll(const QString &chatId, qlonglong messageId);
    Q_INVOKABLE void getPollVoters(const QString &chatId, qlonglong messageId, int optionId, int limit, int offset, const QString &extra);
    Q_INVOKABLE void searchPublicChat(const QString &userName, bool doOpenOnFound);
    Q_INVOKABLE void joinChatByInviteLink(const QString &inviteLink);
    Q_INVOKABLE void getDeepLinkInfo(const QString &link);
    Q_INVOKABLE void getContacts();
    Q_INVOKABLE void getSecretChat(qlonglong secretChatId);
    Q_INVOKABLE void closeSecretChat(qlonglong secretChatId);
    Q_INVOKABLE void importContacts(const QVariantList &contacts);
    Q_INVOKABLE void searchChatMessages(qlonglong chatId, const QString &query, qlonglong fromMessageId = 0);
    Q_INVOKABLE void getPinnedMessages(qlonglong chatId, qlonglong messageThreadId = 0, qlonglong fromMessageId = 0, int limit = 50);
    Q_INVOKABLE void searchPublicChats(const QString &query);
    Q_INVOKABLE void searchChatsOnServer(const QString &query, int limit = 50);
    Q_INVOKABLE void searchContacts(const QString &query, int limit = 100);
    Q_INVOKABLE void readAllChatMentions(qlonglong chatId);
    Q_INVOKABLE void readAllChatReactions(qlonglong chatId);
    Q_INVOKABLE void toggleChatIsMarkedAsUnread(qlonglong chatId, bool isMarkedAsUnread);
    Q_INVOKABLE void toggleChatIsPinned(qlonglong chatId, bool isPinned);
    Q_INVOKABLE void setChatDraftMessage(qlonglong chatId, qlonglong threadId, qlonglong replyToMessageId, const QString &draft);
    Q_INVOKABLE void getInlineQueryResults(qlonglong botUserId, qlonglong chatId, const QVariantMap &userLocation, const QString &query, const QString &offset, const QString &extra);
    Q_INVOKABLE void sendInlineQueryResultMessage(qlonglong chatId, qlonglong threadId, qlonglong replyToMessageId, const QString &queryId, const QString &resultId);
    Q_INVOKABLE void sendBotStartMessage(qlonglong botUserId, qlonglong chatId, const QString &parameter, const QString &extra);
    Q_INVOKABLE void cancelDownloadFile(int fileId);
    Q_INVOKABLE void cancelUploadFile(int fileId);
    Q_INVOKABLE void deleteFile(int fileId);
    Q_INVOKABLE void setName(const QString &firstName, const QString &lastName);
    Q_INVOKABLE void setUsername(const QString &userName);
    Q_INVOKABLE void setUserPrivacySettingRule(UserPrivacySetting setting, UserPrivacySettingRule rule);
    Q_INVOKABLE void getUserPrivacySettingRules(UserPrivacySetting setting);
    Q_INVOKABLE void setProfilePhoto(const QString &filePath);
    Q_INVOKABLE void deleteProfilePhoto(const QString &profilePhotoId);
    Q_INVOKABLE void changeStickerSet(const QString &stickerSetId, bool isInstalled, const QString &stickerType = QStringLiteral("stickerTypeRegular"));
    Q_INVOKABLE void getActiveSessions();
    Q_INVOKABLE void terminateSession(const QString &sessionId);
    Q_INVOKABLE void getMessageAvailableReactions(qlonglong chatId, qlonglong messageId);
    Q_INVOKABLE void getMessageAddedReactions(qlonglong chatId, qlonglong messageId);
    Q_INVOKABLE void getMessageThread(qlonglong chatId, qlonglong messageId);
    Q_INVOKABLE void getPageSource(const QString &address);
    Q_INVOKABLE void addMessageReaction(qlonglong chatId, qlonglong messageId, const QString &reaction);
    Q_INVOKABLE void removeMessageReaction(qlonglong chatId, qlonglong messageId, const QString &reaction);
    Q_INVOKABLE void setNetworkType(NetworkType networkType);
    Q_INVOKABLE void setInactiveSessionTtl(int days);

    // Forum Topics (Telegram Supergroup Forums)
    Q_INVOKABLE void getForumTopics(qlonglong chatId, const QString &query = QString(), qlonglong offsetDate = 0, qlonglong offsetMessageId = 0, qlonglong offsetMessageThreadId = 0, int limit = 50);
    Q_INVOKABLE void switchChatList(int chatListType, int folderId = 0);
    Q_INVOKABLE void getForumTopic(qlonglong chatId, int forumTopicId);
    Q_INVOKABLE void getMessageThreadHistory(qlonglong chatId, qlonglong messageThreadId, qlonglong fromMessageId = 0, int offset = -1, int limit = 50);
    Q_INVOKABLE void setCurrentMessageThreadId(qlonglong threadId);
    Q_INVOKABLE void setPendingScheduledSendDate(int sendDate);
    Q_INVOKABLE void getChatScheduledMessages(qlonglong chatId);
    Q_INVOKABLE void editMessageSchedulingState(qlonglong chatId, qlonglong messageId, int sendDate);
    Q_INVOKABLE qlonglong getCurrentMessageThreadId() const;
    Q_INVOKABLE void setCurrentChatIsForum(bool isForum);
    qlonglong getPendingForumTopicsChatId() const { return pendingForumTopicsChatId; }

    // Others (candidates for extraction ;))
    Q_INVOKABLE void searchEmoji(const QString &queryString);
    Q_INVOKABLE void initializeOpenWith();
    Q_INVOKABLE void removeOpenWith();

    // Stories
    Q_INVOKABLE void loadActiveStories(const QString &listType);
    Q_INVOKABLE void getChatActiveStories(const QString &chatId);
    Q_INVOKABLE void getStory(const QString &storySenderChatId, int storyId, bool onlyLocal = false);
    Q_INVOKABLE void viewStory(const QString &storySenderChatId, int storyId);
    Q_INVOKABLE void getChatArchivedStories(const QString &chatId, int fromStoryId = 0, int limit = 50, const QString &extra = QString());
    Q_INVOKABLE void getChatPostedToChatPageStories(const QString &chatId, int fromStoryId = 0, int limit = 50, const QString &extra = QString());
    Q_INVOKABLE void postStory(const QString &chatId, const QString &photoPath, const QString &caption = QString(), int activePeriod = 86400,
                               const QString &privacyMode = QStringLiteral("everyone"), const QStringList &allowedUserIds = QStringList(),
                               bool allowScreenshots = true, bool postToProfile = false);
    Q_INVOKABLE void postVideoStory(const QString &chatId, const QString &videoPath, double duration, const QString &caption = QString(), int activePeriod = 86400,
                                    const QString &privacyMode = QStringLiteral("everyone"), const QStringList &allowedUserIds = QStringList(),
                                    bool allowScreenshots = true, bool postToProfile = false);
    Q_INVOKABLE void deleteStory(const QString &storyPosterChatId, int storyId);
    Q_INVOKABLE void getStoryInteractions(int storyId, const QString &offset = QString(), int limit = 50);
    Q_INVOKABLE void setStoryReaction(const QString &storyPosterChatId, int storyId, const QString &emoji, bool updateRecent = true);
    Q_INVOKABLE void sendStoryReply(const QString &storyPosterChatId, int storyId, const QString &message);
    Q_INVOKABLE void setChatActiveStoriesList(const QString &chatId, const QString &listType);

public:
    const Group* getGroup(qlonglong groupId) const;
    static ChatType chatTypeFromString(const QString &type);
    static ChatMemberStatus chatMemberStatusFromString(const QString &status);
    static SecretChatState secretChatStateFromString(const QString &state);

signals:
    void versionDetected(const QString &version);
    void ownUserIdFound(const QString &ownUserId);
    void authorizationStateChanged(const TDLibWrapper::AuthorizationState &authorizationState, const QVariantMap &authorizationStateData);
    void optionUpdated(const QString &optionName, const QVariant &optionValue);
    void connectionStateChanged(const TDLibWrapper::ConnectionState &connectionState);
    void fileUpdated(int fileId, const QVariantMap &fileInformation);
    void newChatDiscovered(const QString &chatId, const QVariantMap &chatInformation);
    void unreadMessageCountUpdated(const QVariantMap &messageCountInformation);
    void unreadChatCountUpdated(const QVariantMap &chatCountInformation);
    void chatLastMessageUpdated(const QString &chatId, const QString &order, const QVariantMap &lastMessage);
    void chatOrderUpdated(const QString &chatId, const QString &order);
    void chatFolderPositionUpdated(const QString &chatId, int folderId, const QString &order, bool isPinned);
    void chatPinnedUpdated(qlonglong chatId, bool isPinned);
    void chatReadInboxUpdated(const QString &chatId, const QString &lastReadInboxMessageId, int unreadCount);
    void chatReadOutboxUpdated(const QString &chatId, const QString &lastReadOutboxMessageId);
    void chatAvailableReactionsUpdated(const qlonglong &chatId, const QVariantMap &availableReactions);
    void userUpdated(const QString &userId, const QVariantMap &userInformation);
    void ownUserUpdated(const QVariantMap &userInformation);
    void callUpdated(const QVariantMap &call);
    void callSignalingDataReceived(qlonglong callId, const QByteArray &data);
    void basicGroupUpdated(qlonglong groupId);
    void superGroupUpdated(qlonglong groupId);
    void chatOnlineMemberCountUpdated(const QString &chatId, int onlineMemberCount);
    void messagesReceived(const QVariantList &messages, int totalCount);
    void messagesReceivedWithExtra(const QVariantList &messages, int totalCount, const QString &extra);
    void pinnedMessagesReceived(qlonglong chatId, qlonglong messageThreadId, const QVariantList &messages);
    void sponsoredMessageReceived(qlonglong chatId, const QVariantMap &message);
    void messageLinkInfoReceived(const QString &url, const QVariantMap &messageLinkInfo, const QString &extra);
    void chatStatisticsUrlReceived(qlonglong chatId, const QString &url);
    void newMessageReceived(qlonglong chatId, const QVariantMap &message);
    void copyToDownloadsSuccessful(const QString &fileName, const QString &filePath);
    void copyToDownloadsError(const QString &fileName, const QString &filePath);
    void receivedMessage(qlonglong chatId, qlonglong messageId, const QVariantMap &message);
    void messageSendSucceeded(qlonglong messageId, qlonglong oldMessageId, const QVariantMap &message);
    void textTranslated(const QString &translatedText, const QString &toLanguageCode);
    void messageTextTranslated(qlonglong chatId, qlonglong messageId, const QString &translatedText);
    void activeNotificationsUpdated(const QVariantList notificationGroups);
    void notificationGroupUpdated(const QVariantMap notificationGroupUpdate);
    void notificationUpdated(const QVariantMap updatedNotification);
    void chatNotificationSettingsUpdated(const QString &chatId, const QVariantMap chatNotificationSettings);
    void messageContentUpdated(qlonglong chatId, qlonglong messageId, const QVariantMap &newContent);
    void messageEditedUpdated(qlonglong chatId, qlonglong messageId, const QVariantMap &replyMarkup);
    void messagesDeleted(qlonglong chatId, const QList<qlonglong> &messageIds);
    void chatsReceived(const QVariantMap &chats);
    void chatReceived(const QVariantMap &chat);
    void secretChatReceived(qlonglong secretChatId, const QVariantMap &secretChat);
    void secretChatUpdated(qlonglong secretChatId, const QVariantMap &secretChat);
    void recentStickersUpdated(const QVariantList &stickerIds);
    void stickersReceived(const QVariantList &stickers);
    void installedStickerSetsUpdated(const QVariantList &stickerSetIds);
    void installedStickerSetsUpdatedByType(const QVariantList &stickerSetIds, const QString &stickerType);
    void stickerSetsReceived(const QVariantList &stickerSets, const QString &stickerType);
    void stickerSetReceived(const QVariantMap &stickerSet);
    void customEmojiStickersReceived(const QVariantList &stickers, const QString &extra);
    void customEmojiUpdated(const QString &customEmojiId);
    void customEmojiAssetsUpdated();
    void emojiSearchSuccessful(const QVariantList &result);
    void chatMembersReceived(const QString &extra, const QVariantList &members, int totalMembers);
    void chatEventLogReceived(qlonglong chatId, const QVariantList &events);
    void chatJoinRequestsReceived(qlonglong chatId, int totalCount, const QVariantList &requests);
    void chatPendingJoinRequestsUpdated(qlonglong chatId, const QVariantMap &pendingJoinRequests);
    void newChatJoinRequest(qlonglong chatId, const QVariantMap &request, const QVariantMap &inviteLink);
    void userFullInfoReceived(const QVariantMap &userFullInfo);
    void userFullInfoUpdated(const QString &userId, const QVariantMap &userFullInfo);
    void basicGroupFullInfoReceived(const QString &groupId, const QVariantMap &groupFullInfo);
    void supergroupFullInfoReceived(const QString &groupId, const QVariantMap &groupFullInfo);
    void basicGroupFullInfoUpdated(const QString &groupId, const QVariantMap &groupFullInfo);
    void supergroupFullInfoUpdated(const QString &groupId, const QVariantMap &groupFullInfo);
    void userProfilePhotosReceived(const QString &extra, const QVariantList &photos, int totalPhotos);
    void chatPermissionsUpdated(const QString &chatId, const QVariantMap &permissions);
    void chatPhotoUpdated(qlonglong chatId, const QVariantMap &photo);
    void chatTitleUpdated(const QString &chatId, const QString &title);
    void chatPinnedMessageUpdated(qlonglong chatId, qlonglong pinnedMessageId);
    void usersReceived(const QString &extra, const QVariantList &userIds, int totalUsers);
    void messageSendersReceived(const QString &extra, const QVariantList &senders, int totalUsers);
    void errorReceived(int code, const QString &message, const QString &extra);
    void contactsImported(const QVariantList &importerCount, const QVariantList &userIds);
    void messageNotFound(qlonglong chatId, qlonglong messageId);
    void chatIsMarkedAsUnreadUpdated(qlonglong chatId, bool chatIsMarkedAsUnread);
    void chatDraftMessageUpdated(qlonglong chatId, const QVariantMap &draftMessage, const QString &order);
    void inlineQueryResults(const QString &inlineQueryId, const QString &nextOffset, const QVariantList &results, const QString &switchPmText, const QString &switchPmParameter, const QString &extra);
    void callbackQueryAnswer(const QString &text, bool alert, const QString &url);
    void userPrivacySettingUpdated(UserPrivacySetting setting, UserPrivacySettingRule rule);
    void messageInteractionInfoUpdated(qlonglong chatId, qlonglong messageId, const QVariantMap &updatedInfo);
    void okReceived(const QString &request);
    void sessionsReceived(int inactive_session_ttl_days, const QVariantList &sessions);
    void openFileExternally(const QString &filePath);
    void availableReactionsReceived(qlonglong messageId, const QStringList &reactions);
    void messageAddedReactionsReceived(qlonglong messageId, const QVariantList &reactions, int totalCount);
    void messageThreadInfoReceived(qlonglong chatId, qlonglong messageId, const QVariantMap &threadInfo);
    void forumTopicsReceived(qlonglong chatId, const QVariantList &topics, int totalCount, qlonglong nextOffsetDate, qlonglong nextOffsetMessageId, qlonglong nextOffsetMessageThreadId);
    void forumTopicReceived(qlonglong chatId, const QVariantMap &topic);
    void chatFoldersReceived(const QVariantList &folders);
    void chatFolderInfoReceived(const QVariantMap &folderInfo);
    void forumTopicInfoUpdated(qlonglong chatId, const QVariantMap &topicInfo);
    void forumTopicUpdated(qlonglong chatId, qlonglong threadId, qlonglong lastReadInboxMessageId, qlonglong lastReadOutboxMessageId, int unreadMentionCount);
    void chatUnreadMentionCountUpdated(qlonglong chatId, int unreadMentionCount);
    void chatUnreadReactionCountUpdated(qlonglong chatId, int unreadReactionCount);
    void messageUnreadReactionsUpdated(qlonglong chatId, qlonglong messageId, const QVariantList &unreadReactions, int unreadReactionCount);
    void tgUrlFound(const QString &tgUrl);
    void reactionsUpdated();
    void suitableDiscussionChatsReceived(const QVariantList &chatIds);
    void availableChatThemesUpdated(const QVariantList &themes);
    void chatActiveStoriesUpdated(const QVariantMap &activeStories);
    void activeStoryListReordered(const QString &listType, const QVariantList &chatActiveStoriesList);
    void storyListChatCountUpdated(const QString &listType, int chatCount);
    void storyReceived(const QVariantMap &story);
    void storyDeleted(qlonglong storySenderChatId, int storyId);
    void storiesListReceived(const QVariantList &stories, int totalCount, const QString &extra);
    void storyInteractionsReceived(int storyId, const QVariantList &interactions, int totalCount, int totalForwardCount, int totalReactionCount, const QString &nextOffset);

public slots:
    void handleVersionDetected(const QString &version);
    void handleAuthorizationStateChanged(const QString &authorizationState, const QVariantMap authorizationStateData);
    void handleOptionUpdated(const QString &optionName, const QVariant &optionValue);
    void handleConnectionStateChanged(const QString &connectionState);
    void handleUserUpdated(const QVariantMap &updatedUserInformation);
    void handleUserStatusUpdated(const QString &userId, const QVariantMap &userStatusInformation);
    void handleFileUpdated(const QVariantMap &fileInformation);
    void handleNewChatDiscovered(const QVariantMap &chatInformation);
    void handleChatReceived(const QVariantMap &chatInformation);
    void handleUnreadMessageCountUpdated(const QVariantMap &messageCountInformation);
    void handleUnreadChatCountUpdated(const QVariantMap &chatCountInformation);
    void handleAvailableReactionsUpdated(qlonglong chatId, const QVariantMap &availableReactions);
    void handleChatPendingJoinRequestsUpdated(qlonglong chatId, const QVariantMap &pendingJoinRequests);
    void handleNewChatJoinRequest(qlonglong chatId, const QVariantMap &request, const QVariantMap &inviteLink);
    void handleBasicGroupUpdated(qlonglong groupId, const QVariantMap &groupInformation);
    void handleSuperGroupUpdated(qlonglong groupId, const QVariantMap &groupInformation);
    void handleStickerSets(const QVariantList &stickerSets, const QString &stickerType);
    void handleCustomEmojiStickers(const QVariantList &stickers, const QString &extra);
    void handleEmojiSearchCompleted(const QString &queryString, const QVariantList &resultList);
    void handleOpenWithChanged();
    void handleSecretChatReceived(qlonglong secretChatId, const QVariantMap &secretChat);
    void handleSecretChatUpdated(qlonglong secretChatId, const QVariantMap &secretChat);
    void handleStorageOptimizerChanged();
    void handleErrorReceived(int code, const QString &message, const QString &extra);
    void handleOkReceived(const QString &extra);
    void handleMessageInformation(qlonglong chatId, qlonglong messageId, const QVariantMap &receivedInformation);
    void handleMessageIsPinnedUpdated(qlonglong chatId, qlonglong messageId, bool isPinned);
    void handleUserPrivacySettingRules(const QVariantMap &rules);
    void handleUpdatedUserPrivacySettingRules(const QVariantMap &updatedRules);
    void handleSponsoredMessage(qlonglong chatId, const QVariantMap &message);
    void handleNetworkConfigurationChanged(const QNetworkConfiguration &config);
    void handleActiveEmojiReactionsUpdated(const QStringList& emojis);
    void handleForumTopicsReceived(qlonglong chatId, const QVariantList &topics, int totalCount, qlonglong nextOffsetDate, qlonglong nextOffsetMessageId, qlonglong nextOffsetMessageThreadId);
    void handleGetPageSourceFinished();
    void handleChatsReceived(const QVariantMap &chats);
    void handleChatThemesUpdated(const QVariantList &themes);

private:
    void setOption(const QString &name, const QString &type, const QVariant &value);
    void setInitialParameters();
    void setEncryptionKey();
    void setLogVerbosityLevel();
    QVariantMap &fillTdlibParameters(QVariantMap &parameters);
    const Group *updateGroup(qlonglong groupId, const QVariantMap &groupInfo, QHash<qlonglong,Group*> *groups);
    QVariantMap newSendMessageRequest(qlonglong chatId, qlonglong replyToMessageId);
    void applyPendingScheduling(QVariantMap &request);
    void initializeTDLibReceiver();
    void updateUserInformation(const QString &userId, const QVariantMap &userInformation);
    void upsertCustomEmojiFromSticker(const QVariantMap &sticker);

private:
    void *tdLibClient;
    QNetworkAccessManager *manager;
    QNetworkConfigurationManager *networkConfigurationManager;
    AppSettings *appSettings;
    MceInterface *mceInterface;
    TDLibReceiver *tdLibReceiver;
    DBusInterface *dbusInterface;
    QString versionString;
    TDLibWrapper::AuthorizationState authorizationState;
    QVariantMap authorizationStateData;
    TDLibWrapper::ConnectionState connectionState;
    QVariantMap options;
    QVariantMap userInformation;
    QMap<UserPrivacySetting, UserPrivacySettingRule> userPrivacySettingRules;
    QVariantMap usersById;
    QVariantMap usersByName;
    QVariantMap chats;
    QMap<qlonglong, QVariantMap> secretChats;
    QHash<QString, QVariantMap> customEmojiById;
    QHash<int, QString> customEmojiByThumbnailFileId;
    QSet<QString> pendingCustomEmojiRequests;
    QSet<int> customEmojiFileIds;
    QVariantMap unreadMessageInformation;
    QVariantMap unreadChatInformation;
    QHash<qlonglong,Group*> basicGroups;
    QHash<qlonglong,Group*> superGroups;
    EmojiSearchWorker emojiSearchWorker;
    QStringList activeEmojiReactions;
    QVariantList availableChatThemes;

    int versionNumber;
    QString activeChatSearchName;
    bool joinChatRequested;
    bool isLoggingOut;
    qlonglong currentMessageThreadId;
    bool currentChatIsForum;
    qlonglong pendingForumTopicsChatId;
    int pendingScheduledSendDate;

};

#endif // TDLIBWRAPPER_H
