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

#include "tdlibwrapper.h"
#include "tdlibsecrets.h"
#include <algorithm>
#include <climits>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QLocale>
#include <QProcess>
#include <QSysInfo>
#include <QJsonDocument>
#include <QStandardPaths>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QRegularExpression>
#include <QRegularExpressionMatch>
#include <QRegularExpressionMatchIterator>

#define DEBUG_MODULE TDLibWrapper
#include "debuglog.h"

#define VERSION_NUMBER(x,y,z) \
    ((((x) & 0x3ff) << 20) | (((y) & 0x3ff) << 10) | ((z) & 0x3ff))

namespace {
    const QString STATUS("status");
    const QString ID("id");
    const QString CHAT_ID("chat_id");
    const QString MESSAGE_ID("message_id");
    const QString TYPE("type");
    const QString LAST_NAME("last_name");
    const QString FIRST_NAME("first_name");
    const QString USERNAME("username");
    const QString USERNAMES("usernames");
    const QString EDITABLE_USERNAME("editable_username");
    const QString THREAD_ID("thread_id");
    const QString VALUE("value");
    const QString CHAT_LIST_TYPE("chat_list_type");
    const QString REPLY_TO_MESSAGE_ID("reply_to_message_id");
    const QString REPLY_TO("reply_to");
    const QString _TYPE("@type");
    const QString _EXTRA("@extra");
    const QString CHAT_LIST_MAIN("chatListMain");
    const QString CHAT_AVAILABLE_REACTIONS("available_reactions");
    const QString PENDING_JOIN_REQUESTS("pending_join_requests");
    const QString CHAT_AVAILABLE_REACTIONS_ALL("chatAvailableReactionsAll");
    const QString CHAT_AVAILABLE_REACTIONS_SOME("chatAvailableReactionsSome");
    const QString REACTIONS("reactions");
    const QString TOTAL_COUNT("total_count");
    const QString USER_IDS("user_ids");
    const QString USER_ID("user_id");
    const QString REACTION_TYPE("reaction_type");
    const QString REACTION_TYPE_EMOJI("reactionTypeEmoji");
    const QString EMOJI("emoji");
    const QString TYPE_MESSAGE_REPLY_TO_MESSAGE("messageReplyToMessage");
    const QString TYPE_INPUT_MESSAGE_REPLY_TO_MESSAGE("inputMessageReplyToMessage");

    QVariantMap buildCallProtocol()
    {
        QVariantList supportedLibraryVersions;
        supportedLibraryVersions.append(QStringLiteral("4.0.0"));
        supportedLibraryVersions.append(QStringLiteral("3.0.0"));
        supportedLibraryVersions.append(QStringLiteral("2.7.7"));
        supportedLibraryVersions.append(QStringLiteral("2.4.4"));

        QVariantMap callProtocol;
        callProtocol.insert(_TYPE, "callProtocol");
        callProtocol.insert("udp_p2p", true);
        callProtocol.insert("udp_reflector", true);
        callProtocol.insert("min_layer", 65);
        callProtocol.insert("max_layer", 92);
        callProtocol.insert("library_versions", supportedLibraryVersions);
        return callProtocol;
    }
}

TDLibWrapper::TDLibWrapper(AppSettings *settings, MceInterface *mce, QObject *parent)
    : QObject(parent)
    , tdLibClient(td_json_client_create())
    , manager(new QNetworkAccessManager(this))
    , networkConfigurationManager(new QNetworkConfigurationManager(this))
    , appSettings(settings)
    , mceInterface(mce)
    , authorizationState(AuthorizationState::Closed)
    , versionNumber(0)
    , joinChatRequested(false)
    , isLoggingOut(false)
    , currentMessageThreadId(0)
    , currentChatIsForum(false)
    , pendingForumTopicsChatId(0)
    , pendingScheduledSendDate(0)
{
    LOG("Initializing TD Lib...");

    initializeTDLibReceiver();

    QString tdLibDatabaseDirectoryPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/tdlib";
    QDir tdLibDatabaseDirectory(tdLibDatabaseDirectoryPath);
    if (!tdLibDatabaseDirectory.exists()) {
        tdLibDatabaseDirectory.mkpath(tdLibDatabaseDirectoryPath);
    }

    this->dbusInterface = new DBusInterface(this);
    if (this->appSettings->getUseOpenWith()) {
        this->initializeOpenWith();
    } else {
        this->removeOpenWith();
    }

    connect(&emojiSearchWorker, SIGNAL(searchCompleted(QString, QVariantList)), this, SLOT(handleEmojiSearchCompleted(QString, QVariantList)));

    connect(this->appSettings, SIGNAL(useOpenWithChanged()), this, SLOT(handleOpenWithChanged()));
    connect(this->appSettings, SIGNAL(storageOptimizerChanged()), this, SLOT(handleStorageOptimizerChanged()));

    connect(networkConfigurationManager, SIGNAL(configurationChanged(QNetworkConfiguration)), this, SLOT(handleNetworkConfigurationChanged(QNetworkConfiguration)));

    this->setLogVerbosityLevel();
    this->setOptionInteger("notification_group_count_max", 5);
}

TDLibWrapper::~TDLibWrapper()
{
    LOG("Destroying TD Lib...");
    this->tdLibReceiver->setActive(false);
    while (this->tdLibReceiver->isRunning()) {
        QCoreApplication::processEvents(QEventLoop::AllEvents, 1000);
    }
    qDeleteAll(basicGroups.values());
    qDeleteAll(superGroups.values());
    td_json_client_destroy(this->tdLibClient);
}

void TDLibWrapper::initializeTDLibReceiver() {
    this->tdLibReceiver = new TDLibReceiver(this->tdLibClient, this);
    connect(this->tdLibReceiver, SIGNAL(versionDetected(QString)), this, SLOT(handleVersionDetected(QString)));
    connect(this->tdLibReceiver, SIGNAL(authorizationStateChanged(QString, QVariantMap)), this, SLOT(handleAuthorizationStateChanged(QString, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(optionUpdated(QString, QVariant)), this, SLOT(handleOptionUpdated(QString, QVariant)));
    connect(this->tdLibReceiver, SIGNAL(connectionStateChanged(QString)), this, SLOT(handleConnectionStateChanged(QString)));
    connect(this->tdLibReceiver, SIGNAL(userUpdated(QVariantMap)), this, SLOT(handleUserUpdated(QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(userStatusUpdated(QString, QVariantMap)), this, SLOT(handleUserStatusUpdated(QString, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(fileUpdated(QVariantMap)), this, SLOT(handleFileUpdated(QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(callUpdated(QVariantMap)), this, SIGNAL(callUpdated(QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(callSignalingDataReceived(qlonglong, QByteArray)), this, SIGNAL(callSignalingDataReceived(qlonglong, QByteArray)));
    connect(this->tdLibReceiver, SIGNAL(newChatDiscovered(QVariantMap)), this, SLOT(handleNewChatDiscovered(QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(unreadMessageCountUpdated(QVariantMap)), this, SLOT(handleUnreadMessageCountUpdated(QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(unreadChatCountUpdated(QVariantMap)), this, SLOT(handleUnreadChatCountUpdated(QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(chatLastMessageUpdated(QString, QString, QVariantMap)), this, SIGNAL(chatLastMessageUpdated(QString, QString, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(chatOrderUpdated(QString, QString)), this, SIGNAL(chatOrderUpdated(QString, QString)));
    connect(this->tdLibReceiver, SIGNAL(chatFolderPositionUpdated(QString, int, QString, bool)), this, SIGNAL(chatFolderPositionUpdated(QString, int, QString, bool)));
    connect(this->tdLibReceiver, SIGNAL(chatReadInboxUpdated(QString, QString, int)), this, SIGNAL(chatReadInboxUpdated(QString, QString, int)));
    connect(this->tdLibReceiver, SIGNAL(chatReadOutboxUpdated(QString, QString)), this, SIGNAL(chatReadOutboxUpdated(QString, QString)));
    connect(this->tdLibReceiver, SIGNAL(chatAvailableReactionsUpdated(qlonglong, QVariantMap)), this, SLOT(handleAvailableReactionsUpdated(qlonglong, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(basicGroupUpdated(qlonglong, QVariantMap)), this, SLOT(handleBasicGroupUpdated(qlonglong, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(superGroupUpdated(qlonglong, QVariantMap)), this, SLOT(handleSuperGroupUpdated(qlonglong, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(chatOnlineMemberCountUpdated(QString, int)), this, SIGNAL(chatOnlineMemberCountUpdated(QString, int)));
    connect(this->tdLibReceiver, SIGNAL(messagesReceived(QVariantList, int)), this, SIGNAL(messagesReceived(QVariantList, int)));
    connect(this->tdLibReceiver, SIGNAL(messagesReceivedWithExtra(QVariantList, int, QString)), this, SIGNAL(messagesReceivedWithExtra(QVariantList, int, QString)));
    connect(this->tdLibReceiver, SIGNAL(pinnedMessagesFound(qlonglong, qlonglong, QVariantList)), this, SIGNAL(pinnedMessagesReceived(qlonglong, qlonglong, QVariantList)));
    connect(this->tdLibReceiver, SIGNAL(sponsoredMessageReceived(qlonglong, QVariantMap)), this, SLOT(handleSponsoredMessage(qlonglong, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(messageLinkInfoReceived(QString, QVariantMap, QString)), this, SIGNAL(messageLinkInfoReceived(QString, QVariantMap, QString)));
    connect(this->tdLibReceiver, SIGNAL(chatStatisticsUrlReceived(qlonglong, QString)), this, SIGNAL(chatStatisticsUrlReceived(qlonglong, QString)));
    connect(this->tdLibReceiver, SIGNAL(newMessageReceived(qlonglong, QVariantMap)), this, SIGNAL(newMessageReceived(qlonglong, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(messageInformation(qlonglong, qlonglong, QVariantMap)), this, SLOT(handleMessageInformation(qlonglong, qlonglong, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(messageSendSucceeded(qlonglong, qlonglong, QVariantMap)), this, SIGNAL(messageSendSucceeded(qlonglong, qlonglong, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(activeNotificationsUpdated(QVariantList)), this, SIGNAL(activeNotificationsUpdated(QVariantList)));
    connect(this->tdLibReceiver, SIGNAL(notificationGroupUpdated(QVariantMap)), this, SIGNAL(notificationGroupUpdated(QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(notificationUpdated(QVariantMap)), this, SIGNAL(notificationUpdated(QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(chatNotificationSettingsUpdated(QString, QVariantMap)), this, SIGNAL(chatNotificationSettingsUpdated(QString, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(messageContentUpdated(qlonglong, qlonglong, QVariantMap)), this, SIGNAL(messageContentUpdated(qlonglong, qlonglong, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(messagesDeleted(qlonglong, QList<qlonglong>)), this, SIGNAL(messagesDeleted(qlonglong, QList<qlonglong>)));
    connect(this->tdLibReceiver, SIGNAL(chats(QVariantMap)), this, SIGNAL(chatsReceived(QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(chats(QVariantMap)), this, SLOT(handleChatsReceived(QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(chat(QVariantMap)), this, SLOT(handleChatReceived(QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(chatThemesUpdated(QVariantList)), this, SLOT(handleChatThemesUpdated(QVariantList)));
    connect(this->tdLibReceiver, SIGNAL(chatActiveStoriesUpdated(QVariantMap)), this, SIGNAL(chatActiveStoriesUpdated(QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(activeStoryListReordered(QString, QVariantList)), this, SIGNAL(activeStoryListReordered(QString, QVariantList)));
    connect(this->tdLibReceiver, SIGNAL(storyListChatCountUpdated(QString, int)), this, SIGNAL(storyListChatCountUpdated(QString, int)));
    connect(this->tdLibReceiver, SIGNAL(storyReceived(QVariantMap)), this, SIGNAL(storyReceived(QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(storyDeleted(qlonglong, int)), this, SIGNAL(storyDeleted(qlonglong, int)));
    connect(this->tdLibReceiver, SIGNAL(storiesListReceived(QVariantList, int, QString)), this, SIGNAL(storiesListReceived(QVariantList, int, QString)));
    connect(this->tdLibReceiver, SIGNAL(storyInteractionsReceived(int, QVariantList, int, int, int, QString)), this, SIGNAL(storyInteractionsReceived(int, QVariantList, int, int, int, QString)));
    connect(this->tdLibReceiver, SIGNAL(textTranslated(QString, QString)), this, SIGNAL(textTranslated(QString, QString)));
    connect(this->tdLibReceiver, SIGNAL(messageTextTranslated(qlonglong, qlonglong, QString)), this, SIGNAL(messageTextTranslated(qlonglong, qlonglong, QString)));
    connect(this->tdLibReceiver, SIGNAL(secretChat(qlonglong, QVariantMap)), this, SLOT(handleSecretChatReceived(qlonglong, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(secretChatUpdated(qlonglong, QVariantMap)), this, SLOT(handleSecretChatUpdated(qlonglong, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(recentStickersUpdated(QVariantList)), this, SIGNAL(recentStickersUpdated(QVariantList)));
    connect(this->tdLibReceiver, SIGNAL(stickers(QVariantList)), this, SIGNAL(stickersReceived(QVariantList)));
    connect(this->tdLibReceiver, SIGNAL(installedStickerSetsUpdated(QVariantList)), this, SIGNAL(installedStickerSetsUpdated(QVariantList)));
    connect(this->tdLibReceiver, SIGNAL(installedStickerSetsUpdatedByType(QVariantList, QString)), this, SIGNAL(installedStickerSetsUpdatedByType(QVariantList, QString)));
    connect(this->tdLibReceiver, SIGNAL(stickerSets(QVariantList, QString)), this, SLOT(handleStickerSets(QVariantList, QString)));
    connect(this->tdLibReceiver, SIGNAL(stickerSet(QVariantMap)), this, SIGNAL(stickerSetReceived(QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(customEmojiStickers(QVariantList, QString)), this, SLOT(handleCustomEmojiStickers(QVariantList, QString)));
    connect(this->tdLibReceiver, SIGNAL(customEmojiStickers(QVariantList, QString)), this, SIGNAL(customEmojiStickersReceived(QVariantList, QString)));
    connect(this->tdLibReceiver, SIGNAL(chatMembers(QString, QVariantList, int)), this, SIGNAL(chatMembersReceived(QString, QVariantList, int)));
    connect(this->tdLibReceiver, SIGNAL(chatEventLogReceived(qlonglong, QVariantList)), this, SIGNAL(chatEventLogReceived(qlonglong, QVariantList)));
    connect(this->tdLibReceiver, SIGNAL(chatJoinRequests(qlonglong, int, QVariantList)), this, SIGNAL(chatJoinRequestsReceived(qlonglong, int, QVariantList)));
    connect(this->tdLibReceiver, SIGNAL(chatPendingJoinRequestsUpdated(qlonglong, QVariantMap)), this, SLOT(handleChatPendingJoinRequestsUpdated(qlonglong, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(newChatJoinRequest(qlonglong, QVariantMap, QVariantMap)), this, SLOT(handleNewChatJoinRequest(qlonglong, QVariantMap, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(userFullInfo(QVariantMap)), this, SIGNAL(userFullInfoReceived(QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(userFullInfoUpdated(QString, QVariantMap)), this, SIGNAL(userFullInfoUpdated(QString, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(basicGroupFullInfo(QString, QVariantMap)), this, SIGNAL(basicGroupFullInfoReceived(QString, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(basicGroupFullInfoUpdated(QString, QVariantMap)), this, SIGNAL(basicGroupFullInfoUpdated(QString, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(supergroupFullInfo(QString, QVariantMap)), this, SIGNAL(supergroupFullInfoReceived(QString, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(supergroupFullInfoUpdated(QString, QVariantMap)), this, SIGNAL(supergroupFullInfoUpdated(QString, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(userProfilePhotos(QString, QVariantList, int)), this, SIGNAL(userProfilePhotosReceived(QString, QVariantList, int)));
    connect(this->tdLibReceiver, SIGNAL(chatPermissionsUpdated(QString, QVariantMap)), this, SIGNAL(chatPermissionsUpdated(QString, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(chatPhotoUpdated(qlonglong, QVariantMap)), this, SIGNAL(chatPhotoUpdated(qlonglong, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(chatTitleUpdated(QString, QString)), this, SIGNAL(chatTitleUpdated(QString, QString)));
    connect(this->tdLibReceiver, SIGNAL(chatPinnedUpdated(qlonglong, bool)), this, SIGNAL(chatPinnedUpdated(qlonglong, bool)));
    connect(this->tdLibReceiver, SIGNAL(chatPinnedMessageUpdated(qlonglong, qlonglong)), this, SIGNAL(chatPinnedMessageUpdated(qlonglong, qlonglong)));
    connect(this->tdLibReceiver, SIGNAL(messageIsPinnedUpdated(qlonglong, qlonglong, bool)), this, SLOT(handleMessageIsPinnedUpdated(qlonglong, qlonglong, bool)));
    connect(this->tdLibReceiver, SIGNAL(usersReceived(QString, QVariantList, int)), this, SIGNAL(usersReceived(QString, QVariantList, int)));
    connect(this->tdLibReceiver, SIGNAL(messageSendersReceived(QString, QVariantList, int)), this, SIGNAL(messageSendersReceived(QString, QVariantList, int)));
    connect(this->tdLibReceiver, SIGNAL(errorReceived(int, QString, QString)), this, SLOT(handleErrorReceived(int, QString, QString)));
    connect(this->tdLibReceiver, SIGNAL(contactsImported(QVariantList, QVariantList)), this, SIGNAL(contactsImported(QVariantList, QVariantList)));
    connect(this->tdLibReceiver, SIGNAL(messageEditedUpdated(qlonglong, qlonglong, QVariantMap)), this, SIGNAL(messageEditedUpdated(qlonglong, qlonglong, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(chatIsMarkedAsUnreadUpdated(qlonglong, bool)), this, SIGNAL(chatIsMarkedAsUnreadUpdated(qlonglong, bool)));
    connect(this->tdLibReceiver, SIGNAL(chatDraftMessageUpdated(qlonglong, QVariantMap, QString)), this, SIGNAL(chatDraftMessageUpdated(qlonglong, QVariantMap, QString)));
    connect(this->tdLibReceiver, SIGNAL(inlineQueryResults(QString, QString, QVariantList, QString, QString, QString)), this, SIGNAL(inlineQueryResults(QString, QString, QVariantList, QString, QString, QString)));
    connect(this->tdLibReceiver, SIGNAL(callbackQueryAnswer(QString, bool, QString)), this, SIGNAL(callbackQueryAnswer(QString, bool, QString)));
    connect(this->tdLibReceiver, SIGNAL(userPrivacySettingRules(QVariantMap)), this, SLOT(handleUserPrivacySettingRules(QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(userPrivacySettingRulesUpdated(QVariantMap)), this, SLOT(handleUpdatedUserPrivacySettingRules(QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(messageInteractionInfoUpdated(qlonglong, qlonglong, QVariantMap)), this, SIGNAL(messageInteractionInfoUpdated(qlonglong, qlonglong, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(okReceived(QString)), this, SLOT(handleOkReceived(QString)));
    connect(this->tdLibReceiver, SIGNAL(sessionsReceived(int, QVariantList)), this, SIGNAL(sessionsReceived(int, QVariantList)));
    connect(this->tdLibReceiver, SIGNAL(availableReactionsReceived(qlonglong, QStringList)), this, SIGNAL(availableReactionsReceived(qlonglong, QStringList)));
    connect(this->tdLibReceiver, SIGNAL(messageAddedReactionsReceived(qlonglong, QVariantList, int)), this, SIGNAL(messageAddedReactionsReceived(qlonglong, QVariantList, int)));
    connect(this->tdLibReceiver, SIGNAL(messageThreadInfoReceived(qlonglong, qlonglong, QVariantMap)), this, SIGNAL(messageThreadInfoReceived(qlonglong, qlonglong, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(chatUnreadMentionCountUpdated(qlonglong, int)), this, SIGNAL(chatUnreadMentionCountUpdated(qlonglong, int)));
    connect(this->tdLibReceiver, SIGNAL(chatUnreadReactionCountUpdated(qlonglong, int)), this, SIGNAL(chatUnreadReactionCountUpdated(qlonglong, int)));
    connect(this->tdLibReceiver, SIGNAL(messageUnreadReactionsUpdated(qlonglong, qlonglong, QVariantList, int)), this, SIGNAL(messageUnreadReactionsUpdated(qlonglong, qlonglong, QVariantList, int)));
    connect(this->tdLibReceiver, SIGNAL(activeEmojiReactionsUpdated(QStringList)), this, SLOT(handleActiveEmojiReactionsUpdated(QStringList)));
    connect(this->tdLibReceiver, SIGNAL(forumTopicsReceived(qlonglong, QVariantList, int, qlonglong, qlonglong, qlonglong)), this, SLOT(handleForumTopicsReceived(qlonglong, QVariantList, int, qlonglong, qlonglong, qlonglong)));
    connect(this->tdLibReceiver, SIGNAL(forumTopicReceived(qlonglong, QVariantMap)), this, SIGNAL(forumTopicReceived(qlonglong, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(forumTopicInfoUpdated(qlonglong, QVariantMap)), this, SIGNAL(forumTopicInfoUpdated(qlonglong, QVariantMap)));
    connect(this->tdLibReceiver, SIGNAL(forumTopicUpdated(qlonglong, qlonglong, qlonglong, qlonglong, int)), this, SIGNAL(forumTopicUpdated(qlonglong, qlonglong, qlonglong, qlonglong, int)));
    connect(this->tdLibReceiver, SIGNAL(chatFoldersReceived(QVariantList)), this, SIGNAL(chatFoldersReceived(QVariantList)));
    connect(this->tdLibReceiver, SIGNAL(chatFolderInfoReceived(QVariantMap)), this, SIGNAL(chatFolderInfoReceived(QVariantMap)));

    this->tdLibReceiver->start();
}

void TDLibWrapper::sendRequest(const QVariantMap &requestObject)
{
    if (this->isLoggingOut) {
        LOG("Sending request to TD Lib skipped as logging out is in progress, object type name:" << requestObject.value(_TYPE).toString());
        return;
    }
    LOG("Sending request to TD Lib, object type name:" << requestObject.value(_TYPE).toString());
    QJsonDocument requestDocument = QJsonDocument::fromVariant(requestObject);
    VERBOSE(requestDocument.toJson().constData());
    td_json_client_send(this->tdLibClient, requestDocument.toJson().constData());
}

QString TDLibWrapper::getVersion()
{
    return this->versionString;
}

TDLibWrapper::AuthorizationState TDLibWrapper::getAuthorizationState()
{
    return this->authorizationState;
}

QVariantMap TDLibWrapper::getAuthorizationStateData()
{
    return this->authorizationStateData;
}

TDLibWrapper::ConnectionState TDLibWrapper::getConnectionState()
{
    return this->connectionState;
}

void TDLibWrapper::setAuthenticationPhoneNumber(const QString &phoneNumber)
{
    LOG("Set authentication phone number " << phoneNumber);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setAuthenticationPhoneNumber");
    requestObject.insert("phone_number", phoneNumber);
    QVariantMap phoneNumberSettings;
    phoneNumberSettings.insert("allow_flash_call", false);
    phoneNumberSettings.insert("is_current_phone_number", true);
    requestObject.insert("settings", phoneNumberSettings);
    this->sendRequest(requestObject);
}

void TDLibWrapper::acceptVoiceCall(qlonglong callId, bool isVideo)
{
    if (callId <= 0) {
        LOG("Skipping acceptCall because call ID is invalid:" << callId);
        return;
    }

    QVariantMap requestObject;
    requestObject.insert(_TYPE, "acceptCall");
    requestObject.insert(_EXTRA, QStringLiteral("acceptCall:%1").arg(callId));
    requestObject.insert("call_id", callId);
    requestObject.insert("is_video", isVideo);
    requestObject.insert("protocol", buildCallProtocol());
    this->sendRequest(requestObject);
}

void TDLibWrapper::discardVoiceCall(qlonglong callId, bool isDisconnected, int duration, bool isVideo, qlonglong connectionId)
{
    if (callId <= 0) {
        LOG("Skipping discardCall because call ID is invalid:" << callId);
        return;
    }

    QVariantMap discardReason;
    discardReason.insert(_TYPE, isDisconnected ? "callDiscardReasonDisconnected" : "callDiscardReasonHangup");

    QVariantMap requestObject;
    requestObject.insert(_TYPE, "discardCall");
    requestObject.insert(_EXTRA, QStringLiteral("discardCall:%1").arg(callId));
    requestObject.insert("call_id", callId);
    requestObject.insert("is_disconnected", isDisconnected);
    requestObject.insert("duration", duration < 0 ? 0 : duration);
    requestObject.insert("is_video", isVideo);
    requestObject.insert("connection_id", connectionId < 0 ? 0 : connectionId);
    requestObject.insert("reason", discardReason);
    this->sendRequest(requestObject);
}

void TDLibWrapper::sendCallSignalingData(qlonglong callId, const QByteArray &data)
{
    if (callId <= 0 || data.isEmpty()) {
        LOG("Skipping signaling data send due to invalid payload for call:" << callId);
        return;
    }

    QVariantMap requestObject;
    requestObject.insert(_TYPE, "sendCallSignalingData");
    requestObject.insert("call_id", callId);
    requestObject.insert("data", QString::fromUtf8(data.toBase64()));
    this->sendRequest(requestObject);
}

void TDLibWrapper::setAuthenticationCode(const QString &authenticationCode)
{
    LOG("Set authentication code " << authenticationCode);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "checkAuthenticationCode");
    requestObject.insert("code", authenticationCode);
    this->sendRequest(requestObject);
}

void TDLibWrapper::setAuthenticationPassword(const QString &authenticationPassword)
{
    LOG("Set authentication password " << authenticationPassword);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "checkAuthenticationPassword");
    requestObject.insert("password", authenticationPassword);
    this->sendRequest(requestObject);
}

void TDLibWrapper::registerUser(const QString &firstName, const QString &lastName)
{
    LOG("Register User " << firstName << lastName);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "registerUser");
    requestObject.insert(FIRST_NAME, firstName);
    requestObject.insert(LAST_NAME, lastName);
    this->sendRequest(requestObject);
}

void TDLibWrapper::logout()
{
    LOG("Logging out");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "logOut");
    this->sendRequest(requestObject);
    this->isLoggingOut = true;

}

void TDLibWrapper::getChats()
{
    LOG("Getting chats");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "loadChats");
    requestObject.insert("limit", INT_MAX);
    this->sendRequest(requestObject);
}

void TDLibWrapper::getChatFolders()
{
    LOG("Getting chat folders");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getChatFolders");
    this->sendRequest(requestObject);
}

void TDLibWrapper::downloadFile(int fileId)
{
    LOG("Downloading file " << fileId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "downloadFile");
    requestObject.insert("file_id", fileId);
    requestObject.insert("synchronous", false);
    requestObject.insert("offset", 0);
    requestObject.insert("limit", 0);
    requestObject.insert("priority", 1);
    this->sendRequest(requestObject);
}

void TDLibWrapper::openChat(const QString &chatId)
{
    LOG("Opening chat " << chatId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "openChat");
    requestObject.insert(CHAT_ID, chatId);
    this->sendRequest(requestObject);
}

void TDLibWrapper::closeChat(const QString &chatId)
{
    LOG("Closing chat " << chatId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "closeChat");
    requestObject.insert(CHAT_ID, chatId);
    this->sendRequest(requestObject);
}

void TDLibWrapper::joinChat(const QString &chatId)
{
    LOG("Joining chat " << chatId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "joinChat");
    requestObject.insert(CHAT_ID, chatId);
    this->joinChatRequested = true;
    this->sendRequest(requestObject);
}

void TDLibWrapper::leaveChat(const QString &chatId)
{
    LOG("Leaving chat " << chatId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "leaveChat");
    requestObject.insert(CHAT_ID, chatId);
    this->sendRequest(requestObject);
}

void TDLibWrapper::deleteChat(qlonglong chatId)
{
    LOG("Deleting chat " << chatId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "deleteChat");
    requestObject.insert(CHAT_ID, chatId);
    this->sendRequest(requestObject);
}

void TDLibWrapper::getChatHistory(qlonglong chatId, qlonglong fromMessageId, int offset, int limit, bool onlyLocal)
{
    LOG("Retrieving chat history" << chatId << fromMessageId << offset << limit << onlyLocal);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getChatHistory");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("from_message_id", fromMessageId);
    requestObject.insert("offset", offset);
    requestObject.insert("limit", limit);
    requestObject.insert("only_local", onlyLocal);
    this->sendRequest(requestObject);
}

void TDLibWrapper::viewMessage(qlonglong chatId, qlonglong messageId, bool force)
{
    LOG("Mark message as viewed" << chatId << messageId << "thread:" << currentMessageThreadId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "viewMessages");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("force_read", force);
    QVariantMap sourceObject;
    // Se siamo in un topic forum (incluso "General" = 1), passa sempre
    // message_thread_id per aggiornare correttamente i contatori unread del topic.
    if (currentMessageThreadId > 0) {
        requestObject.insert("message_thread_id", currentMessageThreadId);
        // Forum topic vs discussion thread di canale: TDLib rifiuta
        // messageSourceForumTopicHistory su chat non-forum ("Chat is not a forum").
        sourceObject.insert(_TYPE, currentChatIsForum ? "messageSourceForumTopicHistory"
                                                      : "messageSourceMessageThreadHistory");
    } else {
        sourceObject.insert(_TYPE, "messageSourceChatHistory");
    }
    requestObject.insert("source", sourceObject);
    QVariantList messageIds;
    messageIds.append(messageId);
    requestObject.insert("message_ids", messageIds);
    this->sendRequest(requestObject);
}

void TDLibWrapper::pinMessage(const QString &chatId, const QString &messageId, bool disableNotification, bool onlyForSelf)
{
    LOG("Pin message to chat" << chatId << messageId << disableNotification << "onlyForSelf:" << onlyForSelf);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "pinChatMessage");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert(MESSAGE_ID, messageId);
    requestObject.insert("disable_notification", disableNotification);
    requestObject.insert("only_for_self", onlyForSelf);
    this->sendRequest(requestObject);
}

void TDLibWrapper::unpinMessage(const QString &chatId, const QString &messageId)
{
    LOG("Unpin message from chat" << chatId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "unpinChatMessage");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert(MESSAGE_ID, messageId);
    requestObject.insert(_EXTRA, "unpinChatMessage:" + chatId);
    this->sendRequest(requestObject);
}

static bool compareReplacements(const QVariant &replacement1, const QVariant &replacement2)
{
    const QVariantMap replacementMap1 = replacement1.toMap();
    const QVariantMap replacementMap2 = replacement2.toMap();

    if (replacementMap1.value("startIndex").toInt() < replacementMap2.value("startIndex").toInt()) {
        return true;
    } else {
        return false;
    }
}
static bool compareEntitiesByOffset(const QVariant &entity1, const QVariant &entity2)
{
    return entity1.toMap().value("offset").toInt() < entity2.toMap().value("offset").toInt();
}
static void adjustEntityOffsetsForRangeReplacement(QVariantList &entities, int replaceStart, int replacedLength, int insertedLength)
{
    const int replaceEnd = replaceStart + replacedLength;
    const int offsetDelta = insertedLength - replacedLength;
    for (int i = 0; i < entities.size(); i++) {
        QVariantMap entity = entities.at(i).toMap();
        int offset = entity.value("offset").toInt();
        int length = entity.value("length").toInt();
        const int end = offset + length;
        if (end <= replaceStart) {
            continue;
        }
        if (offset >= replaceEnd) {
            entity.insert("offset", offset + offsetDelta);
            entities[i] = entity;
            continue;
        }
        // Overlap with replaced text, entity can't be mapped reliably anymore.
        entity.insert("length", 0);
        entities[i] = entity;
    }
}
static int removedMarkerCharactersBeforePosition(int position, int openingMarkerStart, int markerLength, int closingMarkerStart)
{
    int removed = 0;
    if (position > openingMarkerStart) {
        removed += std::min(markerLength, position - openingMarkerStart);
    }
    if (position > closingMarkerStart) {
        removed += std::min(markerLength, position - closingMarkerStart);
    }
    return removed;
}
static int overlapLength(int rangeStart, int rangeEnd, int markerStart, int markerEnd)
{
    return std::max(0, std::min(rangeEnd, markerEnd) - std::max(rangeStart, markerStart));
}
static void adjustEntityOffsetsForRemovedWrapMarkers(QVariantList &entities, int markerStart, int markerLength, int innerLength)
{
    const int openingMarkerStart = markerStart;
    const int openingMarkerEnd = openingMarkerStart + markerLength;
    const int closingMarkerStart = openingMarkerEnd + innerLength;
    const int closingMarkerEnd = closingMarkerStart + markerLength;
    for (int i = 0; i < entities.size(); i++) {
        QVariantMap entity = entities.at(i).toMap();
        const int originalOffset = entity.value("offset").toInt();
        const int originalLength = entity.value("length").toInt();
        const int entityEnd = originalOffset + originalLength;

        int offset = originalOffset - removedMarkerCharactersBeforePosition(originalOffset, openingMarkerStart, markerLength, closingMarkerStart);
        int length = originalLength;

        length -= overlapLength(originalOffset, entityEnd, openingMarkerStart, openingMarkerEnd);
        length -= overlapLength(originalOffset, entityEnd, closingMarkerStart, closingMarkerEnd);
        if (length < 0) {
            length = 0;
        }
        entity.insert("offset", offset);
        entity.insert("length", length);
        entities[i] = entity;
    }
}
static void extractDelimitedEntity(QString &messageText, const QString &delimiter, const QString &entityTypeName, QVariantList &entities)
{
    const int delimiterLength = delimiter.length();
    int searchFrom = 0;
    while (searchFrom < messageText.length()) {
        const int markerStart = messageText.indexOf(delimiter, searchFrom);
        if (markerStart < 0) {
            break;
        }
        const int innerStart = markerStart + delimiterLength;
        const int markerEnd = messageText.indexOf(delimiter, innerStart);
        if (markerEnd < 0) {
            break;
        }
        if (markerEnd == innerStart) {
            searchFrom = markerEnd + delimiterLength;
            continue;
        }
        const int innerLength = markerEnd - innerStart;

        adjustEntityOffsetsForRemovedWrapMarkers(entities, markerStart, delimiterLength, innerLength);

        QVariantMap entityType;
        entityType.insert(_TYPE, entityTypeName);
        QVariantMap entity;
        entity.insert("offset", markerStart);
        entity.insert("length", innerLength);
        entity.insert(TYPE, entityType);
        entities.append(entity);

        // Remove closing marker first to preserve opening marker index
        messageText.remove(markerEnd, delimiterLength);
        messageText.remove(markerStart, delimiterLength);
        searchFrom = markerStart + innerLength;
    }
}
static QVariantMap formattedTextFromMessage(const QString &message, const QVariantList &additionalEntities = QVariantList())
{
    QString processedMessage = message;
    QVariantList entities;
    if (!additionalEntities.isEmpty()) {
        QListIterator<QVariant> customEntitiesIterator(additionalEntities);
        while (customEntitiesIterator.hasNext()) {
            const QVariantMap nextEntity = customEntitiesIterator.next().toMap();
            const int offset = nextEntity.value("offset").toInt();
            const int length = nextEntity.value("length").toInt();
            const QString customEmojiId = nextEntity.value("custom_emoji_id").toString();
            if (customEmojiId.isEmpty() || offset < 0 || length <= 0 || (offset + length) > processedMessage.length()) {
                continue;
            }
            QVariantMap entity;
            entity.insert("offset", offset);
            entity.insert("length", length);
            QVariantMap entityType;
            entityType.insert(_TYPE, "textEntityTypeCustomEmoji");
            entityType.insert("custom_emoji_id", customEmojiId);
            entity.insert(TYPE, entityType);
            entities.append(entity);
        }
    }

    // Postprocess @-mentioning with internal user IDs: @12345(John Doe)
    QVariantList replacements;
    QRegularExpression atMentionIdRegex("\\@(\\d+)\\(([^\\)]+)\\)");
    QRegularExpressionMatchIterator atMentionIdMatchIterator = atMentionIdRegex.globalMatch(processedMessage);
    while (atMentionIdMatchIterator.hasNext()) {
        QRegularExpressionMatch nextAtMentionId = atMentionIdMatchIterator.next();
        QVariantMap replacement;
        replacement.insert("startIndex", nextAtMentionId.capturedStart(0));
        replacement.insert("length", nextAtMentionId.capturedLength(0));
        replacement.insert("userId", nextAtMentionId.captured(1));
        replacement.insert("plainText", nextAtMentionId.captured(2));
        replacements.append(replacement);
    }
    if (!replacements.isEmpty()) {
        std::sort(replacements.begin(), replacements.end(), compareReplacements);
        QListIterator<QVariant> replacementsIterator(replacements);
        int offsetCorrection = 0;
        while (replacementsIterator.hasNext()) {
            QVariantMap nextReplacement = replacementsIterator.next().toMap();
            int replacementStartOffset = nextReplacement.value("startIndex").toInt();
            int replacementLength = nextReplacement.value("length").toInt();
            QString replacementPlainText = nextReplacement.value("plainText").toString();
            int actualReplacementOffset = replacementStartOffset - offsetCorrection;
            adjustEntityOffsetsForRangeReplacement(entities, actualReplacementOffset, replacementLength, replacementPlainText.length());
            processedMessage = processedMessage.replace(actualReplacementOffset, replacementLength, replacementPlainText);
            QVariantMap entity;
            entity.insert("offset", actualReplacementOffset);
            entity.insert("length", replacementPlainText.length());
            QVariantMap entityType;
            entityType.insert(_TYPE, "textEntityTypeMentionName");
            entityType.insert("user_id", nextReplacement.value("userId").toString());
            entity.insert(TYPE, entityType);
            entities.append(entity);
            offsetCorrection += replacementLength - replacementPlainText.length();
        }
    }

    // Lightweight markup support: **bold**, __italic__, ++underline++, ~~strikethrough~~, `mono`, ||spoiler||
    extractDelimitedEntity(processedMessage, "`", "textEntityTypeCode", entities);
    extractDelimitedEntity(processedMessage, "**", "textEntityTypeBold", entities);
    extractDelimitedEntity(processedMessage, "__", "textEntityTypeItalic", entities);
    extractDelimitedEntity(processedMessage, "++", "textEntityTypeUnderline", entities);
    extractDelimitedEntity(processedMessage, "~~", "textEntityTypeStrikethrough", entities);
    extractDelimitedEntity(processedMessage, "||", "textEntityTypeSpoiler", entities);

    if (!entities.isEmpty()) {
        QVariantList filteredEntities;
        QListIterator<QVariant> entitiesIterator(entities);
        while (entitiesIterator.hasNext()) {
            const QVariantMap entity = entitiesIterator.next().toMap();
            const int offset = entity.value("offset").toInt();
            const int length = entity.value("length").toInt();
            if (offset < 0 || length <= 0 || (offset + length) > processedMessage.length()) {
                continue;
            }
            filteredEntities.append(entity);
        }
        entities = filteredEntities;
        if (!entities.isEmpty()) {
            std::sort(entities.begin(), entities.end(), compareEntitiesByOffset);
        }
    }

    QVariantMap formattedText;
    formattedText.insert("text", processedMessage);
    formattedText.insert(_TYPE, "formattedText");
    if (!entities.isEmpty()) {
        formattedText.insert("entities", entities);
    }
    return formattedText;
}
static QVariantMap customEmojiThumbnailFileMap(const QVariantMap &sticker)
{
    return sticker.value("thumbnail").toMap().value("file").toMap();
}
static QVariantMap customEmojiStickerFileMap(const QVariantMap &sticker)
{
    return sticker.value("sticker").toMap();
}
static QString customEmojiIdFromSticker(const QVariantMap &sticker)
{
    QString customEmojiId = sticker.value("custom_emoji_id").toString();
    if (!customEmojiId.isEmpty()) {
        return customEmojiId;
    }
    const QVariantMap fullType = sticker.value("full_type").toMap();
    if (!fullType.isEmpty() && fullType.value(_TYPE).toString() == QLatin1String("stickerFullTypeCustomEmoji")) {
        customEmojiId = fullType.value("custom_emoji_id").toString();
        if (!customEmojiId.isEmpty()) {
            return customEmojiId;
        }
    }
    const QVariantMap stickerType = sticker.value(TYPE).toMap();
    if (!stickerType.isEmpty() && stickerType.value(_TYPE).toString() == QLatin1String("stickerTypeCustomEmoji")) {
        customEmojiId = stickerType.value("custom_emoji_id").toString();
    }
    return customEmojiId;
}
static bool customEmojiStickerSupportsInlineImage(const QVariantMap &sticker)
{
    const QString formatType = sticker.value("format").toMap().value(_TYPE).toString();
    if (formatType.isEmpty()) {
        return true;
    }
    return formatType == QLatin1String("stickerFormatWebp");
}
static QString customEmojiAssetPathFromSticker(const QVariantMap &sticker)
{
    const bool supportsInlineSticker = customEmojiStickerSupportsInlineImage(sticker);
    const QVariantMap stickerFile = customEmojiStickerFileMap(sticker);
    const QString stickerPath = stickerFile.value("local").toMap().value("path").toString();
    if (supportsInlineSticker && !stickerPath.isEmpty() && QFileInfo::exists(stickerPath)) {
        return stickerPath;
    }
    const QVariantMap thumbnailFile = customEmojiThumbnailFileMap(sticker);
    const QString thumbnailPath = thumbnailFile.value("local").toMap().value("path").toString();
    if (!thumbnailPath.isEmpty() && QFileInfo::exists(thumbnailPath)) {
        return thumbnailPath;
    }
    if (!supportsInlineSticker) {
        return QString();
    }
    if (!stickerPath.isEmpty() && QFileInfo::exists(stickerPath)) {
        return stickerPath;
    }
    return QString();
}
static QString customEmojiFallbackFromSticker(const QVariantMap &sticker)
{
    const QString emoji = sticker.value("emoji").toString();
    if (!emoji.isEmpty()) {
        return emoji;
    }
    return QStringLiteral("⬜");
}

QVariantMap TDLibWrapper::newSendMessageRequest(qlonglong chatId, qlonglong replyToMessageId)
{
    QVariantMap request;
    request.insert(_TYPE, "sendMessage");
    request.insert(CHAT_ID, chatId);
    if (currentMessageThreadId && currentMessageThreadId != 1) {
        if (currentChatIsForum) {
            QVariantMap topicId;
            topicId.insert("@type", "messageTopicForum");
            topicId.insert("forum_topic_id", (int)currentMessageThreadId);
            request.insert("topic_id", topicId);
        } else if (!replyToMessageId) {
            // Discussion thread di canale: il commento deve essere reply al root del thread.
            replyToMessageId = currentMessageThreadId;
        }
        request.insert("message_thread_id", currentMessageThreadId);
    }
    if (replyToMessageId) {
        QVariantMap replyTo;
        replyTo.insert(_TYPE, TYPE_INPUT_MESSAGE_REPLY_TO_MESSAGE);
        replyTo.insert(MESSAGE_ID, replyToMessageId);
        request.insert(REPLY_TO, replyTo);
    }
    applyPendingScheduling(request);
    return request;
}

void TDLibWrapper::applyPendingScheduling(QVariantMap &request)
{
    if (pendingScheduledSendDate <= 0) {
        return;
    }
    QVariantMap schedulingState;
    schedulingState.insert(_TYPE, "messageSchedulingStateSendAtDate");
    schedulingState.insert("send_date", pendingScheduledSendDate);
    QVariantMap options = request.value("options").toMap();
    options.insert(_TYPE, "messageSendOptions");
    options.insert("scheduling_state", schedulingState);
    request.insert("options", options);
    pendingScheduledSendDate = 0;
}

void TDLibWrapper::translateText(const QString &text, const QString &toLanguageCode)
{
    LOG("Translating text to" << toLanguageCode);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "translateText");
    QVariantMap formattedText;
    formattedText.insert(_TYPE, "formattedText");
    formattedText.insert("text", text);
    formattedText.insert("entities", QVariantList());
    requestObject.insert("text", formattedText);
    requestObject.insert("to_language_code", toLanguageCode);
    requestObject.insert(_EXTRA, QString("translateText:%1").arg(toLanguageCode));
    this->sendRequest(requestObject);
}

void TDLibWrapper::translateMessageText(qlonglong chatId, qlonglong messageId, const QString &toLanguageCode)
{
    LOG("Translating message" << messageId << "to" << toLanguageCode);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "translateMessageText");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("message_id", messageId);
    requestObject.insert("to_language_code", toLanguageCode);
    requestObject.insert(_EXTRA, QString("translateMessage:%1:%2").arg(chatId).arg(messageId));
    this->sendRequest(requestObject);
}

void TDLibWrapper::sendTextMessage(qlonglong chatId, const QString &message, qlonglong replyToMessageId)
{
    LOG("Sending text message" << chatId << message << replyToMessageId);
    QVariantMap requestObject(newSendMessageRequest(chatId, replyToMessageId));
    QVariantMap inputMessageContent;
    inputMessageContent.insert(_TYPE, "inputMessageText");
    inputMessageContent.insert("text", formattedTextFromMessage(message));
    inputMessageContent.insert("disable_web_page_preview", false);
    requestObject.insert("input_message_content", inputMessageContent);
    this->sendRequest(requestObject);
}

void TDLibWrapper::editMessageTextWithCustomEmoji(const QString &chatId, const QString &messageId, const QString &message, const QVariantList &customEmojiEntities)
{
    LOG("Editing message text with custom emojis" << chatId << messageId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "editMessageText");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert(MESSAGE_ID, messageId);
    QVariantMap inputMessageContent;
    inputMessageContent.insert(_TYPE, "inputMessageText");
    inputMessageContent.insert("text", formattedTextFromMessage(message, customEmojiEntities));
    inputMessageContent.insert("disable_web_page_preview", false);
    requestObject.insert("input_message_content", inputMessageContent);
    this->sendRequest(requestObject);
}

void TDLibWrapper::sendPhotoMessage(qlonglong chatId, const QString &filePath, const QString &message, qlonglong replyToMessageId)
{
    LOG("Sending photo message" << chatId << filePath << message << replyToMessageId);
    QVariantMap requestObject(newSendMessageRequest(chatId, replyToMessageId));
    QVariantMap inputMessageContent;
    inputMessageContent.insert(_TYPE, "inputMessagePhoto");

    inputMessageContent.insert("caption", formattedTextFromMessage(message));
    QVariantMap photoInputFile;
    photoInputFile.insert(_TYPE, "inputFileLocal");
    photoInputFile.insert("path", filePath);
    inputMessageContent.insert("photo", photoInputFile);

    requestObject.insert("input_message_content", inputMessageContent);
    this->sendRequest(requestObject);
}

void TDLibWrapper::sendPhotoAlbum(qlonglong chatId, const QStringList &filePaths, const QString &caption, qlonglong replyToMessageId)
{
    LOG("Sending photo album" << chatId << filePaths.size() << caption << replyToMessageId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "sendMessageAlbum");
    requestObject.insert(CHAT_ID, chatId);
    if (currentMessageThreadId && currentMessageThreadId != 1) {
        if (currentChatIsForum) {
            QVariantMap topicId;
            topicId.insert(_TYPE, "messageTopicForum");
            topicId.insert("forum_topic_id", (int)currentMessageThreadId);
            requestObject.insert("topic_id", topicId);
        } else if (!replyToMessageId) {
            replyToMessageId = currentMessageThreadId;
        }
        requestObject.insert("message_thread_id", currentMessageThreadId);
    }
    if (replyToMessageId) {
        QVariantMap replyTo;
        replyTo.insert(_TYPE, TYPE_INPUT_MESSAGE_REPLY_TO_MESSAGE);
        replyTo.insert(MESSAGE_ID, replyToMessageId);
        requestObject.insert(REPLY_TO, replyTo);
    }
    QVariantList inputMessageContents;
    const int maxAlbumSize = 10;
    const int count = qMin(filePaths.size(), maxAlbumSize);
    for (int i = 0; i < count; ++i) {
        QVariantMap content;
        content.insert(_TYPE, "inputMessagePhoto");
        QVariantMap photoInputFile;
        photoInputFile.insert(_TYPE, "inputFileLocal");
        photoInputFile.insert("path", filePaths.at(i));
        content.insert("photo", photoInputFile);
        if (i == 0 && !caption.isEmpty()) {
            content.insert("caption", formattedTextFromMessage(caption));
        }
        inputMessageContents.append(content);
    }
    requestObject.insert("input_message_contents", inputMessageContents);
    applyPendingScheduling(requestObject);
    this->sendRequest(requestObject);
}

void TDLibWrapper::sendVideoMessage(qlonglong chatId, const QString &filePath, const QString &message, qlonglong replyToMessageId)
{
    LOG("Sending video message" << chatId << filePath << message << replyToMessageId);
    QVariantMap requestObject(newSendMessageRequest(chatId, replyToMessageId));
    QVariantMap inputMessageContent;
    inputMessageContent.insert(_TYPE, "inputMessageVideo");
    inputMessageContent.insert("caption", formattedTextFromMessage(message));
    QVariantMap videoInputFile;
    videoInputFile.insert(_TYPE, "inputFileLocal");
    videoInputFile.insert("path", filePath);
    inputMessageContent.insert("video", videoInputFile);

    requestObject.insert("input_message_content", inputMessageContent);
    this->sendRequest(requestObject);
}

void TDLibWrapper::sendDocumentMessage(qlonglong chatId, const QString &filePath, const QString &message, qlonglong replyToMessageId)
{
    LOG("Sending document message" << chatId << filePath << message << replyToMessageId);
    QVariantMap requestObject(newSendMessageRequest(chatId, replyToMessageId));
    QVariantMap inputMessageContent;
    inputMessageContent.insert(_TYPE, "inputMessageDocument");
    inputMessageContent.insert("caption", formattedTextFromMessage(message));
    QVariantMap documentInputFile;
    documentInputFile.insert(_TYPE, "inputFileLocal");
    documentInputFile.insert("path", filePath);
    inputMessageContent.insert("document", documentInputFile);

    requestObject.insert("input_message_content", inputMessageContent);
    this->sendRequest(requestObject);
}

void TDLibWrapper::sendVoiceNoteMessage(qlonglong chatId, const QString &filePath, const QString &message, qlonglong replyToMessageId)
{
    LOG("Sending voice note message" << chatId << filePath << message << replyToMessageId);
    QVariantMap requestObject(newSendMessageRequest(chatId, replyToMessageId));
    QVariantMap inputMessageContent;
    inputMessageContent.insert(_TYPE, "inputMessageVoiceNote");
    inputMessageContent.insert("caption", formattedTextFromMessage(message));
    QVariantMap documentInputFile;
    documentInputFile.insert(_TYPE, "inputFileLocal");
    documentInputFile.insert("path", filePath);
    inputMessageContent.insert("voice_note", documentInputFile);

    requestObject.insert("input_message_content", inputMessageContent);
    this->sendRequest(requestObject);
}

void TDLibWrapper::sendLocationMessage(qlonglong chatId, double latitude, double longitude, double horizontalAccuracy, qlonglong replyToMessageId)
{
    LOG("Sending location message" << chatId << latitude << longitude << horizontalAccuracy << replyToMessageId);
    QVariantMap requestObject(newSendMessageRequest(chatId, replyToMessageId));
    QVariantMap inputMessageContent;
    inputMessageContent.insert(_TYPE, "inputMessageLocation");

    QVariantMap location;
    location.insert("latitude", latitude);
    location.insert("longitude", longitude);
    location.insert("horizontal_accuracy", horizontalAccuracy);
    location.insert(_TYPE, "location");
    inputMessageContent.insert("location", location);
    inputMessageContent.insert("live_period", 0);
    inputMessageContent.insert("heading", 0);
    inputMessageContent.insert("proximity_alert_radius", 0);

    requestObject.insert("input_message_content", inputMessageContent);
    this->sendRequest(requestObject);
}

void TDLibWrapper::sendStickerMessage(qlonglong chatId, const QString &fileId, qlonglong replyToMessageId)
{
    if (fileId.isEmpty()) {
        WARN("Sending sticker message aborted: empty sticker remote ID");
        return;
    }
    LOG("Sending sticker message" << chatId << fileId << replyToMessageId);
    QVariantMap requestObject(newSendMessageRequest(chatId, replyToMessageId));
    QVariantMap inputMessageContent;
    inputMessageContent.insert(_TYPE, "inputMessageSticker");

    QVariantMap stickerInputFile;
    stickerInputFile.insert(_TYPE, "inputFileRemote");
    stickerInputFile.insert(ID, fileId);

    inputMessageContent.insert("sticker", stickerInputFile);

    requestObject.insert("input_message_content", inputMessageContent);
    this->sendRequest(requestObject);
}

void TDLibWrapper::sendPollMessage(qlonglong chatId, const QString &question, const QVariantList &options, bool anonymous, int correctOption, bool multiple, const QString &explanation, qlonglong replyToMessageId)
{
    LOG("Sending poll message" << chatId << question << replyToMessageId);
    QVariantMap requestObject(newSendMessageRequest(chatId, replyToMessageId));
    QVariantMap inputMessageContent;
    inputMessageContent.insert(_TYPE, "inputMessagePoll");

    QVariantMap pollType;
    if(correctOption > -1) {
        pollType.insert(_TYPE, "pollTypeQuiz");
        pollType.insert("correct_option_id", correctOption);
        if(!explanation.isEmpty()) {
            QVariantMap formattedExplanation;
            formattedExplanation.insert("text", explanation);
            pollType.insert("explanation", formattedExplanation);
        }
    } else {
        pollType.insert(_TYPE, "pollTypeRegular");
        pollType.insert("allow_multiple_answers", multiple);
    }

    inputMessageContent.insert(TYPE, pollType);
    inputMessageContent.insert("question", question);
    inputMessageContent.insert("options", options);
    inputMessageContent.insert("is_anonymous", anonymous);

    requestObject.insert("input_message_content", inputMessageContent);
    this->sendRequest(requestObject);
}

void TDLibWrapper::forwardMessages(const QString &chatId, const QString &fromChatId, const QVariantList &messageIds, bool sendCopy, bool removeCaption)
{
    LOG("Forwarding messages" << chatId << fromChatId << messageIds);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "forwardMessages");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("from_chat_id", fromChatId);
    requestObject.insert("message_ids", messageIds);
    requestObject.insert("send_copy", sendCopy);
    requestObject.insert("remove_caption", removeCaption);

    this->sendRequest(requestObject);
}

void TDLibWrapper::getMessage(qlonglong chatId, qlonglong messageId)
{
    LOG("Retrieving message" << chatId << messageId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getMessage");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert(MESSAGE_ID, messageId);
    requestObject.insert(_EXTRA, QString("getMessage:%1:%2").arg(chatId).arg(messageId));
    this->sendRequest(requestObject);
}

void TDLibWrapper::getMessageLinkInfo(const QString &url, const QString &extra)
{
    LOG("Retrieving message link info" << url << extra);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getMessageLinkInfo");
    requestObject.insert("url", url);
    if (extra == "") {
        requestObject.insert(_EXTRA, url);
    } else {
        requestObject.insert(_EXTRA, url + "|" + extra);
    }

    this->sendRequest(requestObject);
}

void TDLibWrapper::getExternalLinkInfo(const QString &url, const QString &extra)
{
    LOG("Retrieving external link info" << url << extra);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getExternalLinkInfo");
    requestObject.insert("url", url);
    if (extra == "") {
        requestObject.insert(_EXTRA, url);
    } else {
        requestObject.insert(_EXTRA, url + "|" + extra);
    }

    this->sendRequest(requestObject);
}

void TDLibWrapper::getCallbackQueryAnswer(const QString &chatId, const QString &messageId, const QVariantMap &payload)
{
    LOG("Getting Callback Query Answer" << chatId << messageId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getCallbackQueryAnswer");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert(MESSAGE_ID, messageId);
    requestObject.insert("payload", payload);
    this->sendRequest(requestObject);
}

void TDLibWrapper::getChatPinnedMessage(qlonglong chatId)
{
    LOG("Retrieving pinned message" << chatId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getChatPinnedMessage");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert(_EXTRA, "getChatPinnedMessage:" + QString::number(chatId));
    this->sendRequest(requestObject);
}

void TDLibWrapper::getChatSponsoredMessage(qlonglong chatId)
{
    LOG("Retrieving sponsored message" << chatId);
    QVariantMap requestObject;
    // getChatSponsoredMessage has been replaced with getChatSponsoredMessages
    // between 1.8.7 and 1.8.8
    // See https://github.com/tdlib/td/commit/ec1310a
    requestObject.insert(_TYPE, QString((versionNumber > VERSION_NUMBER(1,8,7)) ?
        "getChatSponsoredMessages" : "getChatSponsoredMessage"));
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert(_EXTRA, chatId); // see TDLibReceiver::processSponsoredMessage
    this->sendRequest(requestObject);
}

void TDLibWrapper::setOptionInteger(const QString &optionName, int optionValue)
{
    LOG("Setting integer option" << optionName << optionValue);
    setOption(optionName, "optionValueInteger", optionValue);
}

void TDLibWrapper::setOptionBoolean(const QString &optionName, bool optionValue)
{
    LOG("Setting boolean option" << optionName << optionValue);
    setOption(optionName, "optionValueBoolean", optionValue);
}

void TDLibWrapper::setOption(const QString &name, const QString &type, const QVariant &value)
{
    QVariantMap optionValue;
    optionValue.insert(_TYPE, type);
    optionValue.insert(VALUE, value);
    QVariantMap request;
    request.insert(_TYPE, "setOption");
    request.insert("name", name);
    request.insert(VALUE, optionValue);
    sendRequest(request);
}

void TDLibWrapper::setChatNotificationSettings(const QString &chatId, const QVariantMap &notificationSettings)
{
    LOG("Notification settings for chat " << chatId << notificationSettings);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setChatNotificationSettings");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("notification_settings", notificationSettings);
    this->sendRequest(requestObject);
}

void TDLibWrapper::editMessageText(const QString &chatId, const QString &messageId, const QString &message)
{
    LOG("Editing message text" << chatId << messageId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "editMessageText");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert(MESSAGE_ID, messageId);
    QVariantMap inputMessageContent;
    inputMessageContent.insert(_TYPE, "inputMessageText");
    inputMessageContent.insert("text", formattedTextFromMessage(message));
    inputMessageContent.insert("disable_web_page_preview", false);
    requestObject.insert("input_message_content", inputMessageContent);
    this->sendRequest(requestObject);
}

void TDLibWrapper::sendTextMessageWithCustomEmoji(qlonglong chatId, const QString &message, const QVariantList &customEmojiEntities, qlonglong replyToMessageId)
{
    LOG("Sending text message with custom emojis" << chatId << message << replyToMessageId);
    QVariantMap requestObject(newSendMessageRequest(chatId, replyToMessageId));
    QVariantMap inputMessageContent;
    inputMessageContent.insert(_TYPE, "inputMessageText");
    inputMessageContent.insert("text", formattedTextFromMessage(message, customEmojiEntities));
    inputMessageContent.insert("disable_web_page_preview", false);
    requestObject.insert("input_message_content", inputMessageContent);
    this->sendRequest(requestObject);
}

void TDLibWrapper::deleteMessages(const QString &chatId, const QVariantList messageIds)
{
    LOG("Deleting some messages" << chatId << messageIds);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "deleteMessages");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("message_ids", messageIds);
    requestObject.insert("revoke", true);
    this->sendRequest(requestObject);
}
void TDLibWrapper::deleteChatMessagesBySender(qlonglong chatId, qlonglong senderUserId)
{
    LOG("Deleting chat messages by sender" << chatId << senderUserId);
    QVariantMap senderId;
    senderId.insert(_TYPE, "messageSenderUser");
    senderId.insert("user_id", senderUserId);

    QVariantMap requestObject;
    requestObject.insert(_TYPE, "deleteChatMessagesBySender");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("sender_id", senderId);
    this->sendRequest(requestObject);
}

void TDLibWrapper::banChatMember(qlonglong chatId, qlonglong userId, qlonglong bannedUntilDate)
{
    LOG("Banning chat member" << chatId << userId << bannedUntilDate);
    QVariantMap memberId;
    memberId.insert(_TYPE, "messageSenderUser");
    memberId.insert("user_id", userId);

    QVariantMap bannedStatus;
    bannedStatus.insert(_TYPE, "chatMemberStatusBanned");
    bannedStatus.insert("banned_until_date", bannedUntilDate);

    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setChatMemberStatus");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("member_id", memberId);
    requestObject.insert("status", bannedStatus);
    this->sendRequest(requestObject);
}

void TDLibWrapper::unbanChatMember(qlonglong chatId, qlonglong userId)
{
    LOG("Unbanning chat member" << chatId << userId);
    QVariantMap memberId;
    memberId.insert(_TYPE, "messageSenderUser");
    memberId.insert("user_id", userId);

    QVariantMap leftStatus;
    leftStatus.insert(_TYPE, "chatMemberStatusLeft");

    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setChatMemberStatus");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("member_id", memberId);
    requestObject.insert("status", leftStatus);
    requestObject.insert(_EXTRA, QString("unbanChatMember:%1:%2").arg(chatId).arg(userId));
    this->sendRequest(requestObject);
}

void TDLibWrapper::reportChatSpam(qlonglong chatId, const QVariantList &messageIds)
{
    LOG("Reporting chat spam" << chatId << messageIds);
    QVariantMap reason;
    reason.insert(_TYPE, "chatReportReasonSpam");

    QVariantMap requestObject;
    requestObject.insert(_TYPE, "reportChat");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("message_ids", messageIds);
    requestObject.insert("reason", reason);
    requestObject.insert("text", "");
    this->sendRequest(requestObject);
}

void TDLibWrapper::getMapThumbnailFile(const QString &chatId, double latitude, double longitude, int width, int height, const QString &extra)
{
    LOG("Getting Map Thumbnail File" << chatId);
    QVariantMap location;
    location.insert("latitude", latitude);
    location.insert("longitude", longitude);
    // ensure dimensions are in bounds (16 - 1024)
    int boundsWidth = std::min(std::max(width, 16), 1024);
    int boundsHeight = std::min(std::max(height, 16), 1024);

    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getMapThumbnailFile");
    requestObject.insert("location", location);
    requestObject.insert("zoom", 17); //13-20
    requestObject.insert("width", boundsWidth);
    requestObject.insert("height", boundsHeight);
    requestObject.insert("scale", 1); // 1-3
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert(_EXTRA, extra);

    this->sendRequest(requestObject);
}

void TDLibWrapper::getRecentStickers()
{
    LOG("Retrieving recent stickers");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getRecentStickers");
    this->sendRequest(requestObject);
}

void TDLibWrapper::getInstalledStickerSets()
{
    LOG("Retrieving installed sticker sets (regular)");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getInstalledStickerSets");
    QVariantMap stickerType;
    stickerType.insert(_TYPE, "stickerTypeRegular");
    requestObject.insert("sticker_type", stickerType);
    // tag esplicito: in TDLib 1.8.62 sticker_type è obbligatorio e ogni
    // risposta deve essere instradata al tipo corrispondente per non
    // sovrascrivere la lista sbagliata in StickerManager.
    requestObject.insert(_EXTRA, "stickerType:Regular");
    this->sendRequest(requestObject);
}

void TDLibWrapper::getInstalledCustomEmojiSets()
{
    LOG("Retrieving installed custom emoji sets");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getInstalledStickerSets");
    QVariantMap stickerType;
    stickerType.insert(_TYPE, "stickerTypeCustomEmoji");
    requestObject.insert("sticker_type", stickerType);
    requestObject.insert(_EXTRA, "stickerType:CustomEmoji");
    this->sendRequest(requestObject);
}

void TDLibWrapper::getStickerSet(const QString &setId, const QString &expectedType)
{
    LOG("Retrieving sticker set" << setId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getStickerSet");
    requestObject.insert("set_id", setId);
    // Propaghiamo il tipo via @extra ("stickerType:Regular|CustomEmoji"):
    // il receiver lo userà per iniettare sticker_type nel payload nel caso
    // TDLib non lo includa, evitando di lasciare classificare ad euristiche.
    if (expectedType == QLatin1String("stickerTypeCustomEmoji")) {
        requestObject.insert(_EXTRA, QStringLiteral("stickerType:CustomEmoji"));
    } else if (expectedType == QLatin1String("stickerTypeRegular")) {
        requestObject.insert(_EXTRA, QStringLiteral("stickerType:Regular"));
    }
    this->sendRequest(requestObject);
}

void TDLibWrapper::getCustomEmojiStickers(const QVariantList &customEmojiIds, const QString &extra)
{
    QVariantList sanitizedIds;
    QListIterator<QVariant> idsIterator(customEmojiIds);
    while (idsIterator.hasNext()) {
        const QString nextId = idsIterator.next().toString();
        if (!nextId.isEmpty()) {
            sanitizedIds.append(nextId);
        }
    }
    if (sanitizedIds.isEmpty()) {
        return;
    }
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getCustomEmojiStickers");
    requestObject.insert("custom_emoji_ids", sanitizedIds);
    if (!extra.isEmpty()) {
        requestObject.insert(_EXTRA, QString("customEmoji:%1").arg(extra));
    } else {
        requestObject.insert(_EXTRA, QStringLiteral("customEmoji:bulk"));
    }
    this->sendRequest(requestObject);
}

void TDLibWrapper::ensureCustomEmoji(const QString &customEmojiId)
{
    if (customEmojiId.isEmpty()) {
        return;
    }
    const QVariantMap cachedSticker = this->customEmojiById.value(customEmojiId);
    if (!cachedSticker.isEmpty()) {
        const QString assetPath = customEmojiAssetPathFromSticker(cachedSticker);
        if (!assetPath.isEmpty()) {
            return;
        }
        const QVariantMap thumbnailFile = customEmojiThumbnailFileMap(cachedSticker);
        const int thumbnailFileId = thumbnailFile.value(ID).toInt();
        if (thumbnailFileId > 0) {
            this->customEmojiFileIds.insert(thumbnailFileId);
            this->customEmojiByThumbnailFileId.insert(thumbnailFileId, customEmojiId);
            const QVariantMap local = thumbnailFile.value("local").toMap();
            if (!local.value("is_downloading_completed").toBool() && thumbnailFile.value("remote").toMap().value(ID).toString() != QString()) {
                this->downloadFile(thumbnailFileId);
                return;
            }
        }
    }
    if (this->pendingCustomEmojiRequests.contains(customEmojiId)) {
        return;
    }
    this->pendingCustomEmojiRequests.insert(customEmojiId);
    QVariantList customEmojiIds;
    customEmojiIds.append(customEmojiId);
    this->getCustomEmojiStickers(customEmojiIds, customEmojiId);
}

QString TDLibWrapper::getCustomEmojiPath(const QString &customEmojiId)
{
    if (customEmojiId.isEmpty()) {
        return QString();
    }
    const QVariantMap sticker = this->customEmojiById.value(customEmojiId);
    const QString path = customEmojiAssetPathFromSticker(sticker);
    if (path.isEmpty()) {
        this->ensureCustomEmoji(customEmojiId);
    }
    return path;
}

QString TDLibWrapper::getCustomEmojiFallback(const QString &customEmojiId)
{
    const QVariantMap sticker = this->customEmojiById.value(customEmojiId);
    if (sticker.isEmpty()) {
        return QStringLiteral("⬜");
    }
    return customEmojiFallbackFromSticker(sticker);
}

void TDLibWrapper::cacheCustomEmojiFromSticker(const QVariantMap &sticker)
{
    this->upsertCustomEmojiFromSticker(sticker);
}

bool TDLibWrapper::isCustomEmojiFileId(int fileId) const
{
    return this->customEmojiFileIds.contains(fileId);
}
void TDLibWrapper::getSupergroupMembers(const QString &groupId, int limit, int offset, const QString &filterType, const QString &extra)
{
    LOG("Retrieving SupergroupMembers");
    const QString resolvedFilterType = filterType.isEmpty() ? QStringLiteral("supergroupMembersFilterRecent") : filterType;
    const QString resolvedExtra = extra.isEmpty() ? groupId : extra;
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getSupergroupMembers");
    requestObject.insert(_EXTRA, resolvedExtra);
    requestObject.insert("supergroup_id", groupId);
    QVariantMap filterObject;
    filterObject.insert(_TYPE, resolvedFilterType);
    requestObject.insert("filter", filterObject);
    requestObject.insert("offset", offset);
    requestObject.insert("limit", limit);
    this->sendRequest(requestObject);
}

void TDLibWrapper::getChatEventLog(qlonglong chatId, qlonglong fromEventId, int limit)
{
    LOG("Retrieving chat event log for chat" << chatId << "from event" << fromEventId << "limit" << limit);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getChatEventLog");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("query", "");
    requestObject.insert("from_event_id", fromEventId);
    requestObject.insert("limit", limit > 0 ? limit : 50);
    QVariantMap filters;
    filters.insert(_TYPE, "chatEventLogFilters");
    filters.insert("message_edits", true);
    filters.insert("message_deletions", true);
    filters.insert("message_pins", true);
    filters.insert("member_joins", true);
    filters.insert("member_leaves", true);
    filters.insert("member_invites", true);
    filters.insert("member_promotions", true);
    filters.insert("member_restrictions", true);
    filters.insert("info_changes", true);
    filters.insert("setting_changes", true);
    filters.insert("invite_link_changes", true);
    filters.insert("video_chat_changes", true);
    requestObject.insert("filters", filters);
    requestObject.insert("user_ids", QVariantList());
    requestObject.insert(_EXTRA, QString::number(chatId));
    this->sendRequest(requestObject);
}

void TDLibWrapper::getChatJoinRequests(qlonglong chatId, const QString &inviteLink, const QString &query, const QVariantMap &offsetRequest, int limit)
{
    LOG("Retrieving chat join requests" << chatId << "query:" << query << "limit:" << limit);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getChatJoinRequests");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("invite_link", inviteLink);
    requestObject.insert("query", query);
    if (!offsetRequest.isEmpty()) {
        QVariantMap offset(offsetRequest);
        offset.insert(_TYPE, "chatJoinRequest");
        if (!offset.contains("bio")) {
            offset.insert("bio", "");
        }
        requestObject.insert("offset_request", offset);
    }
    requestObject.insert("limit", limit > 0 ? limit : 50);
    requestObject.insert(_EXTRA, QString::number(chatId));
    this->sendRequest(requestObject);
}

void TDLibWrapper::processChatJoinRequest(qlonglong chatId, qlonglong userId, bool approve)
{
    LOG("Processing chat join request" << chatId << userId << "approve:" << approve);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "processChatJoinRequest");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("user_id", userId);
    requestObject.insert("approve", approve);
    requestObject.insert(_EXTRA, QString("processChatJoinRequest:%1:%2").arg(chatId).arg(userId));
    this->sendRequest(requestObject);
}

void TDLibWrapper::getGroupFullInfo(const QString &groupId, bool isSuperGroup)
{
    LOG("Retrieving GroupFullInfo");
    QVariantMap requestObject;
    if(isSuperGroup) {
        requestObject.insert(_TYPE, "getSupergroupFullInfo");
        requestObject.insert("supergroup_id", groupId);
    } else {
        requestObject.insert(_TYPE, "getBasicGroupFullInfo");
        requestObject.insert("basic_group_id", groupId);
    }
    requestObject.insert(_EXTRA, groupId);
    this->sendRequest(requestObject);
}

void TDLibWrapper::getUserFullInfo(const QString &userId)
{
    LOG("Retrieving UserFullInfo" << userId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getUserFullInfo");
    requestObject.insert(_EXTRA, userId);
    requestObject.insert("user_id", userId);
    this->sendRequest(requestObject);
}
void TDLibWrapper::createVoiceCall(const QString &userId, bool isVideo)
{
    const qlonglong callUserId = userId.toLongLong();
    if (callUserId <= 0) {
        LOG("Skipping call creation because user ID is invalid:" << userId);
        return;
    }

    LOG("Creating call for user" << callUserId << "is video call:" << isVideo);

    QVariantMap requestObject;
    requestObject.insert(_TYPE, "createCall");
    requestObject.insert(_EXTRA, QStringLiteral("createCall:%1").arg(callUserId));
    requestObject.insert("user_id", callUserId);
    requestObject.insert("is_video", isVideo);
    requestObject.insert("protocol", buildCallProtocol());
    this->sendRequest(requestObject);
}

void TDLibWrapper::createPrivateChat(const QString &userId, const QString &extra)
{
    LOG("Creating Private Chat");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "createPrivateChat");
    requestObject.insert("user_id", userId);
    requestObject.insert(_EXTRA, extra); //"openDirectly"/"openAndSendStartToBot:[optional parameter]" gets matched in qml
    this->sendRequest(requestObject);
}

void TDLibWrapper::createNewSecretChat(const QString &userId, const QString &extra)
{
    LOG("Creating new secret chat");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "createNewSecretChat");
    requestObject.insert("user_id", userId);
    requestObject.insert(_EXTRA, extra); //"openDirectly" gets matched in qml
    this->sendRequest(requestObject);
}

void TDLibWrapper::createSupergroupChat(const QString &supergroupId, const QString &extra)
{
    LOG("Creating Supergroup Chat");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "createSupergroupChat");
    requestObject.insert("supergroup_id", supergroupId);
    requestObject.insert(_EXTRA, extra); //"openDirectly" gets matched in qml
    this->sendRequest(requestObject);
}

void TDLibWrapper::createBasicGroupChat(const QString &basicGroupId, const QString &extra)
{
    LOG("Creating Basic Group Chat");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "createBasicGroupChat");
    requestObject.insert("basic_group_id", basicGroupId);
    requestObject.insert(_EXTRA, extra); //"openDirectly"/"openAndSend:*" gets matched in qml
    this->sendRequest(requestObject);
}

void TDLibWrapper::getGroupsInCommon(const QString &userId, int limit, int offset)
{
    LOG("Retrieving Groups in Common");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getGroupsInCommon");
    requestObject.insert(_EXTRA, userId);
    requestObject.insert("user_id", userId);
    requestObject.insert("offset", offset);
    requestObject.insert("limit", limit);
    this->sendRequest(requestObject);
}

void TDLibWrapper::getUserProfilePhotos(const QString &userId, int limit, int offset)
{
    LOG("Retrieving User Profile Photos");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getUserProfilePhotos");
    requestObject.insert(_EXTRA, userId);
    requestObject.insert("user_id", userId);
    requestObject.insert("offset", offset);
    requestObject.insert("limit", limit);
    this->sendRequest(requestObject);
}

void TDLibWrapper::setChatPermissions(const QString &chatId, const QVariantMap &chatPermissions)
{
    LOG("Setting Chat Permissions");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setChatPermissions");
    requestObject.insert(_EXTRA, chatId);
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("permissions", chatPermissions);
    this->sendRequest(requestObject);
}

void TDLibWrapper::setChatSlowModeDelay(const QString &chatId, int delay)
{

    LOG("Setting Chat Slow Mode Delay");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setChatSlowModeDelay");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("slow_mode_delay", delay);
    this->sendRequest(requestObject);
}

void TDLibWrapper::setChatDescription(const QString &chatId, const QString &description)
{
    LOG("Setting Chat Description");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setChatDescription");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("description", description);
    this->sendRequest(requestObject);
}

void TDLibWrapper::setChatTitle(const QString &chatId, const QString &title)
{
    LOG("Setting Chat Title");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setChatTitle");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("title", title);
    this->sendRequest(requestObject);
}
void TDLibWrapper::setChatPhoto(const QString &chatId, const QString &filePath)
{
    LOG("Setting Chat Photo" << chatId << filePath);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setChatPhoto");
    requestObject.insert(_EXTRA, QStringLiteral("setChatPhoto:%1").arg(chatId));
    requestObject.insert(CHAT_ID, chatId);
    QVariantMap inputChatPhoto;
    inputChatPhoto.insert(_TYPE, "inputChatPhotoStatic");
    QVariantMap inputFile;
    inputFile.insert(_TYPE, "inputFileLocal");
    inputFile.insert("path", filePath);
    inputChatPhoto.insert("photo", inputFile);
    requestObject.insert("photo", inputChatPhoto);
    this->sendRequest(requestObject);
}

void TDLibWrapper::setChatDiscussionGroup(qlonglong chatId, qlonglong discussionChatId)
{
    LOG("Setting Chat Discussion Group" << chatId << "->" << discussionChatId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setChatDiscussionGroup");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("discussion_chat_id", discussionChatId);
    this->sendRequest(requestObject);
}

void TDLibWrapper::getSuitableDiscussionChats()
{
    LOG("Getting suitable discussion chats");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getSuitableDiscussionChats");
    requestObject.insert(_EXTRA, "getSuitableDiscussionChats");
    this->sendRequest(requestObject);
}

void TDLibWrapper::getChatStatisticsUrl(qlonglong chatId, bool isDark)
{
    LOG("Getting chat statistics URL" << chatId << isDark);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getChatStatisticsUrl");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("parameters", "");
    requestObject.insert("is_dark", isDark);
    requestObject.insert(_EXTRA, QStringLiteral("getChatStatisticsUrl:%1").arg(chatId));
    this->sendRequest(requestObject);
}

void TDLibWrapper::setChatTheme(qlonglong chatId, const QString &themeName)
{
    LOG("Setting Chat Theme" << chatId << themeName);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setChatTheme");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("theme_name", themeName);
    this->sendRequest(requestObject);
}

QVariantList TDLibWrapper::getAvailableChatThemes() const
{
    return availableChatThemes;
}

void TDLibWrapper::setBio(const QString &bio)
{
    LOG("Setting Bio");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setBio");
    requestObject.insert("bio", bio);
    this->sendRequest(requestObject);
}

void TDLibWrapper::upgradeBasicGroupChatToSupergroupChat(qlonglong chatId)
{
    LOG("Upgrading basic group chat to supergroup chat" << chatId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "upgradeBasicGroupChatToSupergroupChat");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert(_EXTRA, QStringLiteral("upgradeBasicGroup:%1").arg(chatId));
    this->sendRequest(requestObject);
}

void TDLibWrapper::toggleSupergroupIsAllHistoryAvailable(const QString &groupId, bool isAllHistoryAvailable)
{
    LOG("Toggling SupergroupIsAllHistoryAvailable");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "toggleSupergroupIsAllHistoryAvailable");
    requestObject.insert("supergroup_id", groupId);
    requestObject.insert("is_all_history_available", isAllHistoryAvailable);
    this->sendRequest(requestObject);
}

void TDLibWrapper::setPollAnswer(const QString &chatId, qlonglong messageId, QVariantList optionIds)
{
    LOG("Setting Poll Answer");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setPollAnswer");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert(MESSAGE_ID, messageId);
    requestObject.insert("option_ids", optionIds);
    this->sendRequest(requestObject);
}

void TDLibWrapper::stopPoll(const QString &chatId, qlonglong messageId)
{
    LOG("Stopping Poll");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "stopPoll");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert(MESSAGE_ID, messageId);
    this->sendRequest(requestObject);
}

void TDLibWrapper::getPollVoters(const QString &chatId, qlonglong messageId, int optionId, int limit, int offset, const QString &extra)
{
    LOG("Retrieving Poll Voters");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getPollVoters");
    requestObject.insert(_EXTRA, extra);
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert(MESSAGE_ID, messageId);
    requestObject.insert("option_id", optionId);
    requestObject.insert("offset", offset);
    requestObject.insert("limit", limit); //max 50
    this->sendRequest(requestObject);
}

void TDLibWrapper::searchPublicChat(const QString &userName, bool doOpenOnFound)
{
    LOG("Search public chat" << userName);
    if(doOpenOnFound) {
        this->activeChatSearchName = userName;
    }
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "searchPublicChat");
    requestObject.insert(_EXTRA, "searchPublicChat:"+userName);
    requestObject.insert(USERNAME, userName);
    this->sendRequest(requestObject);
}

void TDLibWrapper::joinChatByInviteLink(const QString &inviteLink)
{
    LOG("Join chat by invite link" << inviteLink);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "joinChatByInviteLink");
    requestObject.insert("invite_link", inviteLink);
    this->joinChatRequested = true;
    this->sendRequest(requestObject);
}

void TDLibWrapper::getDeepLinkInfo(const QString &link)
{
    LOG("Resolving TG deep link" << link);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getDeepLinkInfo");
    requestObject.insert("link", link);
    this->sendRequest(requestObject);
}

void TDLibWrapper::getContacts()
{
    LOG("Retrieving contacts");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getContacts");
    requestObject.insert(_EXTRA, "contactsRequested");
    this->sendRequest(requestObject);
}

void TDLibWrapper::getSecretChat(qlonglong secretChatId)
{
    LOG("Getting detailed information about secret chat" << secretChatId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getSecretChat");
    requestObject.insert("secret_chat_id", secretChatId);
    this->sendRequest(requestObject);
}

void TDLibWrapper::closeSecretChat(qlonglong secretChatId)
{
    LOG("Closing secret chat" << secretChatId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "closeSecretChat");
    requestObject.insert("secret_chat_id", secretChatId);
    this->sendRequest(requestObject);
}

void TDLibWrapper::importContacts(const QVariantList &contacts)
{
    LOG("Importing contacts");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "importContacts");
    requestObject.insert("contacts", contacts);
    this->sendRequest(requestObject);
}

void TDLibWrapper::searchChatMessages(qlonglong chatId, const QString &query, qlonglong fromMessageId)
{
    LOG("Searching for messages" << chatId << query << fromMessageId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "searchChatMessages");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("query", query);
    requestObject.insert("from_message_id", fromMessageId);
    requestObject.insert("offset", 0);
    requestObject.insert("limit", 50);
    requestObject.insert(_EXTRA, "searchChatMessages");
    this->sendRequest(requestObject);
}

void TDLibWrapper::getPinnedMessages(qlonglong chatId, qlonglong messageThreadId, qlonglong fromMessageId, int limit)
{
    LOG("Retrieving pinned messages" << chatId << "thread:" << messageThreadId << "from:" << fromMessageId << "limit:" << limit);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "searchChatMessages");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("query", "");
    requestObject.insert("from_message_id", fromMessageId);
    requestObject.insert("offset", 0);
    requestObject.insert("limit", limit);
    if (messageThreadId > 0) {
        requestObject.insert("message_thread_id", messageThreadId);
    }
    QVariantMap filter;
    filter.insert(_TYPE, "searchMessagesFilterPinned");
    requestObject.insert("filter", filter);
    requestObject.insert(_EXTRA, QString("getPinnedMessages:%1:%2").arg(chatId).arg(messageThreadId));
    this->sendRequest(requestObject);
}

void TDLibWrapper::searchPublicChats(const QString &query)
{
    LOG("Searching public chats" << query);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "searchPublicChats");
    requestObject.insert("query", query);
    requestObject.insert(_EXTRA, "searchPublicChats");
    this->sendRequest(requestObject);
}

void TDLibWrapper::searchChatsOnServer(const QString &query, int limit)
{
    LOG("Searching chats on server" << query << "limit" << limit);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "searchChatsOnServer");
    requestObject.insert("query", query);
    requestObject.insert("limit", limit > 0 ? limit : 50);
    requestObject.insert(_EXTRA, "searchChatsOnServer");
    this->sendRequest(requestObject);
}

void TDLibWrapper::searchContacts(const QString &query, int limit)
{
    LOG("Searching contacts" << query << "limit" << limit);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "searchContacts");
    requestObject.insert("query", query);
    requestObject.insert("limit", limit > 0 ? limit : 100);
    requestObject.insert(_EXTRA, "searchContacts");
    this->sendRequest(requestObject);
}

void TDLibWrapper::readAllChatMentions(qlonglong chatId)
{
    LOG("Read all chat mentions" << chatId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "readAllChatMentions");
    requestObject.insert(CHAT_ID, chatId);
    this->sendRequest(requestObject);
}

void TDLibWrapper::readAllChatReactions(qlonglong chatId)
{
    LOG("Read all chat reactions" << chatId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "readAllChatReactions");
    requestObject.insert(CHAT_ID, chatId);
    this->sendRequest(requestObject);
}

void TDLibWrapper::toggleChatIsMarkedAsUnread(qlonglong chatId, bool isMarkedAsUnread)
{
    LOG("Toggle chat is marked as unread" << chatId << isMarkedAsUnread);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "toggleChatIsMarkedAsUnread");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("is_marked_as_unread", isMarkedAsUnread);
    this->sendRequest(requestObject);
}

void TDLibWrapper::toggleChatIsPinned(qlonglong chatId, bool isPinned)
{
    LOG("Toggle chat is pinned" << chatId << isPinned);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "toggleChatIsPinned");
    QVariantMap chatListMap;
    chatListMap.insert(_TYPE, CHAT_LIST_MAIN);
    requestObject.insert("chat_list", chatListMap);
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("is_pinned", isPinned);
    requestObject.insert("is_marked_as_unread", isPinned);
    this->sendRequest(requestObject);
}

void TDLibWrapper::setChatDraftMessage(qlonglong chatId, qlonglong threadId, qlonglong replyToMessageId, const QString &draft)
{
    LOG("Set Draft Message" << chatId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setChatDraftMessage");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert(THREAD_ID, threadId);
    QVariantMap draftMessage;
    QVariantMap inputMessageContent;
    QVariantMap formattedText;

    formattedText.insert("text", draft);
    formattedText.insert("clear_draft", draft.isEmpty());
    formattedText.insert(_TYPE, "formattedText");
    inputMessageContent.insert(_TYPE, "inputMessageText");
    inputMessageContent.insert("text", formattedText);
    draftMessage.insert(_TYPE, "draftMessage");
    draftMessage.insert("input_message_text", inputMessageContent);

    if (versionNumber > VERSION_NUMBER(1,8,20)) {
        QVariantMap replyTo;
        replyTo.insert(_TYPE, TYPE_INPUT_MESSAGE_REPLY_TO_MESSAGE);
        replyTo.insert(CHAT_ID, chatId);
        replyTo.insert(MESSAGE_ID, replyToMessageId);
        draftMessage.insert(REPLY_TO, replyTo);
    } else {
        draftMessage.insert(REPLY_TO_MESSAGE_ID, replyToMessageId);
    }

    requestObject.insert("draft_message", draftMessage);
    this->sendRequest(requestObject);
}

void TDLibWrapper::getInlineQueryResults(qlonglong botUserId, qlonglong chatId, const QVariantMap &userLocation, const QString &query, const QString &offset, const QString &extra)
{

    LOG("Get Inline Query Results" << chatId << query);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getInlineQueryResults");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("bot_user_id", botUserId);
    if(!userLocation.isEmpty()) {
        requestObject.insert("user_location", userLocation);
    }
    requestObject.insert("query", query);
    requestObject.insert("offset", offset);
    requestObject.insert(_EXTRA, extra);

    this->sendRequest(requestObject);
}

void TDLibWrapper::sendInlineQueryResultMessage(qlonglong chatId, qlonglong threadId, qlonglong replyToMessageId, const QString &queryId, const QString &resultId)
{

    LOG("Send Inline Query Result Message" << chatId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "sendInlineQueryResultMessage");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("message_thread_id", threadId);
    requestObject.insert("reply_to_message_id", replyToMessageId);
    requestObject.insert("query_id", queryId);
    requestObject.insert("result_id", resultId);

    this->sendRequest(requestObject);
}

void TDLibWrapper::sendBotStartMessage(qlonglong botUserId, qlonglong chatId, const QString &parameter, const QString &extra)
{

    LOG("Send Bot Start Message" << botUserId << chatId << parameter << extra);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "sendBotStartMessage");
    requestObject.insert("bot_user_id", botUserId);
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("parameter", parameter);
    requestObject.insert(_EXTRA, extra);

    this->sendRequest(requestObject);
}

void TDLibWrapper::cancelDownloadFile(int fileId)
{
    LOG("Cancel Download File" << fileId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "cancelDownloadFile");
    requestObject.insert("file_id", fileId);
    requestObject.insert("only_if_pending", false);

    this->sendRequest(requestObject);
}

void TDLibWrapper::cancelUploadFile(int fileId)
{
    LOG("Cancel Upload File" << fileId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "cancelUploadFile");
    requestObject.insert("file_id", fileId);

    this->sendRequest(requestObject);
}

void TDLibWrapper::deleteFile(int fileId)
{
    LOG("Delete cached File" << fileId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "deleteFile");
    requestObject.insert("file_id", fileId);

    this->sendRequest(requestObject);
}

void TDLibWrapper::setName(const QString &firstName, const QString &lastName)
{
    LOG("Set name of current user" << firstName << lastName);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setName");
    requestObject.insert("first_name", firstName);
    requestObject.insert("last_name", lastName);

    this->sendRequest(requestObject);
}

void TDLibWrapper::setUsername(const QString &userName)
{
    LOG("Set username of current user" << userName);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setUsername");
    requestObject.insert("username", userName);

    this->sendRequest(requestObject);
}

void TDLibWrapper::setUserPrivacySettingRule(TDLibWrapper::UserPrivacySetting setting, TDLibWrapper::UserPrivacySettingRule rule)
{
    LOG("Set user privacy setting rule of current user" << setting << rule);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setUserPrivacySettingRules");

    QVariantMap settingMap;
    switch (setting) {
    case SettingShowStatus:
        settingMap.insert(_TYPE, "userPrivacySettingShowStatus");
        break;
    case SettingShowPhoneNumber:
        settingMap.insert(_TYPE, "userPrivacySettingShowPhoneNumber");
        break;
    case SettingAllowChatInvites:
        settingMap.insert(_TYPE, "userPrivacySettingAllowChatInvites");
        break;
    case SettingShowProfilePhoto:
        settingMap.insert(_TYPE, "userPrivacySettingShowProfilePhoto");
        break;
    case SettingAllowFindingByPhoneNumber:
        settingMap.insert(_TYPE, "userPrivacySettingAllowFindingByPhoneNumber");
        break;
    case SettingShowLinkInForwardedMessages:
        settingMap.insert(_TYPE, "userPrivacySettingShowLinkInForwardedMessages");
        break;
    case SettingUnknown:
        return;
    }
    requestObject.insert("setting", settingMap);


    QVariantMap ruleMap;
    switch (rule) {
    case RuleAllowAll:
        ruleMap.insert(_TYPE, "userPrivacySettingRuleAllowAll");
        break;
    case RuleAllowContacts:
        ruleMap.insert(_TYPE, "userPrivacySettingRuleAllowContacts");
        break;
    case RuleRestrictAll:
        ruleMap.insert(_TYPE, "userPrivacySettingRuleRestrictAll");
        break;
    }
    QVariantList ruleMaps;
    ruleMaps.append(ruleMap);
    QVariantMap encapsulatedRules;
    encapsulatedRules.insert(_TYPE, "userPrivacySettingRules");
    encapsulatedRules.insert("rules", ruleMaps);
    requestObject.insert("rules", encapsulatedRules);

    this->sendRequest(requestObject);
}

void TDLibWrapper::getUserPrivacySettingRules(TDLibWrapper::UserPrivacySetting setting)
{
    LOG("Getting user privacy setting rules of current user" << setting);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getUserPrivacySettingRules");
    requestObject.insert(_EXTRA, setting);

    QVariantMap settingMap;
    switch (setting) {
    case SettingShowStatus:
        settingMap.insert(_TYPE, "userPrivacySettingShowStatus");
        break;
    case SettingShowPhoneNumber:
        settingMap.insert(_TYPE, "userPrivacySettingShowPhoneNumber");
        break;
    case SettingAllowChatInvites:
        settingMap.insert(_TYPE, "userPrivacySettingAllowChatInvites");
        break;
    case SettingShowProfilePhoto:
        settingMap.insert(_TYPE, "userPrivacySettingShowProfilePhoto");
        break;
    case SettingAllowFindingByPhoneNumber:
        settingMap.insert(_TYPE, "userPrivacySettingAllowFindingByPhoneNumber");
        break;
    case SettingShowLinkInForwardedMessages:
        settingMap.insert(_TYPE, "userPrivacySettingShowLinkInForwardedMessages");
        break;
    case SettingUnknown:
        return;
    }
    requestObject.insert("setting", settingMap);

    this->sendRequest(requestObject);
}

void TDLibWrapper::setProfilePhoto(const QString &filePath)
{
    LOG("Set a profile photo" << filePath);

    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setProfilePhoto");
    requestObject.insert(_EXTRA, "setProfilePhoto");
    QVariantMap inputChatPhoto;
    inputChatPhoto.insert(_TYPE, "inputChatPhotoStatic");
    QVariantMap inputFile;
    inputFile.insert(_TYPE, "inputFileLocal");
    inputFile.insert("path", filePath);
    inputChatPhoto.insert("photo", inputFile);
    requestObject.insert("photo", inputChatPhoto);

    this->sendRequest(requestObject);
}

void TDLibWrapper::deleteProfilePhoto(const QString &profilePhotoId)
{
    LOG("Delete a profile photo" << profilePhotoId);

    QVariantMap requestObject;
    requestObject.insert(_TYPE, "deleteProfilePhoto");
    requestObject.insert(_EXTRA, "deleteProfilePhoto");
    requestObject.insert("profile_photo_id", profilePhotoId);

    this->sendRequest(requestObject);
}

void TDLibWrapper::changeStickerSet(const QString &stickerSetId, bool isInstalled, const QString &stickerType)
{
    LOG("Change sticker set" << stickerSetId << isInstalled << stickerType);

    QVariantMap requestObject;
    requestObject.insert(_TYPE, "changeStickerSet");
    // L'@extra include il tipo (Regular/CustomEmoji) per indirizzare il
    // refresh QML alla lista giusta dopo la rimozione/installazione.
    const QString typeToken = stickerType == QLatin1String("stickerTypeCustomEmoji")
        ? QStringLiteral("CustomEmoji") : QStringLiteral("Regular");
    const QString action = isInstalled ? QStringLiteral("installStickerSet") : QStringLiteral("removeStickerSet");
    requestObject.insert(_EXTRA, QString("%1:%2:%3").arg(action).arg(typeToken).arg(stickerSetId));
    requestObject.insert("set_id", stickerSetId);
    requestObject.insert("is_installed", isInstalled);

    this->sendRequest(requestObject);
}

void TDLibWrapper::getActiveSessions()
{
    LOG("Get active sessions");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getActiveSessions");
    this->sendRequest(requestObject);
}

void TDLibWrapper::terminateSession(const QString &sessionId)
{
    LOG("Terminate session" << sessionId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "terminateSession");
    requestObject.insert(_EXTRA, "terminateSession");
    requestObject.insert("session_id", sessionId);
    this->sendRequest(requestObject);
}

void TDLibWrapper::getMessageAvailableReactions(qlonglong chatId, qlonglong messageId)
{
    LOG("Get available reactions for message" << chatId << messageId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getMessageAvailableReactions");
    requestObject.insert(_EXTRA, QString::number(messageId));
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert(MESSAGE_ID, messageId);
    this->sendRequest(requestObject);
}

void TDLibWrapper::getMessageAddedReactions(qlonglong chatId, qlonglong messageId)
{
    LOG("Get added reactions for message" << chatId << messageId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getMessageAddedReactions");
    requestObject.insert(_EXTRA, QString::number(messageId));
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert(MESSAGE_ID, messageId);
    // reaction_type omesso = tutte le reaction; offset vuoto = dall'inizio.
    requestObject.insert("offset", QString());
    requestObject.insert("limit", 50);
    this->sendRequest(requestObject);
}

void TDLibWrapper::getMessageThread(qlonglong chatId, qlonglong messageId)
{
    LOG("Get message thread" << chatId << messageId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getMessageThread");
    requestObject.insert(_EXTRA, QString("getMessageThread:%1:%2").arg(chatId).arg(messageId));
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert(MESSAGE_ID, messageId);
    this->sendRequest(requestObject);
}

void TDLibWrapper::getPageSource(const QString &address)
{
    QUrl url = QUrl(address);
    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);
    request.setHeader(QNetworkRequest::UserAgentHeader, "RooTelegram Bot (Sailfish OS)");
    request.setRawHeader(QByteArray("Accept"), QByteArray("text/html,application/xhtml+xml"));
    request.setRawHeader(QByteArray("Accept-Charset"), QByteArray("utf-8"));
    request.setRawHeader(QByteArray("Connection"), QByteArray("close"));
    request.setRawHeader(QByteArray("Cache-Control"), QByteArray("max-age=0"));
    QNetworkReply *reply = manager->get(request);

    connect(reply, SIGNAL(finished()), this, SLOT(handleGetPageSourceFinished()));
}

void TDLibWrapper::addMessageReaction(qlonglong chatId, qlonglong messageId, const QString &reaction)
{
    QVariantMap requestObject;
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert(MESSAGE_ID, messageId);
    requestObject.insert("is_big", false);
    if (versionNumber > VERSION_NUMBER(1,8,5)) {
        // "reaction_type": {
        //     "@type": "reactionTypeEmoji",
        //     "emoji": "..."
        // }
        QVariantMap reactionType;
        reactionType.insert(_TYPE, REACTION_TYPE_EMOJI);
        reactionType.insert(EMOJI, reaction);
        requestObject.insert(REACTION_TYPE, reactionType);
        requestObject.insert(_TYPE, "addMessageReaction");
        LOG("Add message reaction" << chatId << messageId << reaction);
    } else {
        requestObject.insert("reaction", reaction);
        requestObject.insert(_TYPE, "setMessageReaction");
        LOG("Toggle message reaction" << chatId << messageId << reaction);
    }
    this->sendRequest(requestObject);
}

void TDLibWrapper::removeMessageReaction(qlonglong chatId, qlonglong messageId, const QString &reaction)
{
    QVariantMap requestObject;
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert(MESSAGE_ID, messageId);
    if (versionNumber > VERSION_NUMBER(1,8,5)) {
        // "reaction_type": {
        //     "@type": "reactionTypeEmoji",
        //     "emoji": "..."
        // }
        QVariantMap reactionType;
        reactionType.insert(_TYPE, REACTION_TYPE_EMOJI);
        reactionType.insert(EMOJI, reaction);
        requestObject.insert(REACTION_TYPE, reactionType);
        requestObject.insert(_TYPE, "removeMessageReaction");
        LOG("Remove message reaction" << chatId << messageId << reaction);
    } else {
        requestObject.insert("reaction", reaction);
        requestObject.insert(_TYPE, "setMessageReaction");
        LOG("Toggle message reaction" << chatId << messageId << reaction);
    }
    this->sendRequest(requestObject);
}

void TDLibWrapper::setNetworkType(NetworkType networkType)
{
    LOG("Set network type" << networkType);

    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setNetworkType");
    requestObject.insert(_EXTRA, "setNetworkType");
    QVariantMap networkTypeObject;
    switch (networkType) {
    case Mobile:
        networkTypeObject.insert(_TYPE, "networkTypeMobile");
        break;
    case MobileRoaming:
        networkTypeObject.insert(_TYPE, "networkTypeMobileRoaming");
        break;
    case None:
        networkTypeObject.insert(_TYPE, "networkTypeNone");
        break;
    case Other:
        networkTypeObject.insert(_TYPE, "networkTypeOther");
        break;
    case WiFi:
        networkTypeObject.insert(_TYPE, "networkTypeWiFi");
        break;
    default:
        networkTypeObject.insert(_TYPE, "networkTypeOther");
        break;
    }

    requestObject.insert(TYPE, networkTypeObject);

    this->sendRequest(requestObject);
}

void TDLibWrapper::setInactiveSessionTtl(int days)
{
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setInactiveSessionTtl");
    requestObject.insert("inactive_session_ttl_days", days);
    this->sendRequest(requestObject);
}

void TDLibWrapper::searchEmoji(const QString &queryString)
{
    LOG("Searching emoji" << queryString);
    while (this->emojiSearchWorker.isRunning()) {
        this->emojiSearchWorker.requestInterruption();
    }
    this->emojiSearchWorker.setParameters(queryString);
    this->emojiSearchWorker.start();
}

QVariantMap TDLibWrapper::getUserInformation()
{
    return this->userInformation;
}

QVariantMap TDLibWrapper::getUserInformation(const QString &userId)
{
    // LOG("Returning user information for ID" << userId);
    return this->usersById.value(userId).toMap();
}

bool TDLibWrapper::hasUserInformation(const QString &userId)
{
    return this->usersById.contains(userId);
}

QVariantMap TDLibWrapper::getUserInformationByName(const QString &userName)
{
    return this->usersByName.value(userName).toMap();
}

TDLibWrapper::UserPrivacySettingRule TDLibWrapper::getUserPrivacySettingRule(TDLibWrapper::UserPrivacySetting userPrivacySetting)
{
    return this->userPrivacySettingRules.value(userPrivacySetting, UserPrivacySettingRule::RuleAllowAll);
}

QVariantMap TDLibWrapper::getUnreadMessageInformation()
{
    return this->unreadMessageInformation;
}

QVariantMap TDLibWrapper::getUnreadChatInformation()
{
    return this->unreadChatInformation;
}

QVariantMap TDLibWrapper::getBasicGroup(qlonglong groupId) const
{
    const Group* group = basicGroups.value(groupId);
    if (group) {
        LOG("Returning basic group information for ID" << groupId);
        return group->groupInfo;
    } else {
        LOG("No super group information for ID" << groupId);
        return QVariantMap();
    }
}

QVariantMap TDLibWrapper::getSuperGroup(qlonglong groupId) const
{
    const Group* group = superGroups.value(groupId);
    if (group) {
        LOG("Returning super group information for ID" << groupId);
        return group->groupInfo;
    } else {
        LOG("No super group information for ID" << groupId);
        return QVariantMap();
    }
}

QVariantMap TDLibWrapper::getChat(const QString &chatId)
{
    LOG("Returning chat information for ID" << chatId);
    return this->chats.value(chatId).toMap();
}

QStringList TDLibWrapper::getChatReactions(const QString &chatId)
{
    LOG("Obtaining chat reactions for chat" << chatId);
    const QVariant available_reactions(chats.value(chatId).toMap().value(CHAT_AVAILABLE_REACTIONS));
    const QVariantMap map(available_reactions.toMap());
    const QString reactions_type(map.value(_TYPE).toString());
    if (reactions_type == CHAT_AVAILABLE_REACTIONS_ALL) {
        LOG("Chat uses all available reactions, currently available number" << activeEmojiReactions.size());
        return activeEmojiReactions;
    } else if (reactions_type == CHAT_AVAILABLE_REACTIONS_SOME) {
        LOG("Chat uses reduced set of reactions");
        const QVariantList reactions(map.value(REACTIONS).toList());
        const int n = reactions.count();
        QStringList emojis;

        // "available_reactions": {
        //     "@type": "chatAvailableReactionsSome",
        //     "reactions": [
        //         {
        //             "@type": "reactionTypeEmoji",
        //             "emoji": "..."
        //         },
        emojis.reserve(n);
        for (int i = 0; i < n; i++) {
            const QVariantMap reaction(reactions.at(i).toMap());
            if (reaction.value(_TYPE).toString() == REACTION_TYPE_EMOJI) {
                const QString emoji(reaction.value(EMOJI).toString());
                if (!emoji.isEmpty()) {
                    emojis.append(emoji);
                }
            }
        }
        LOG("Found emojis for this chat" << emojis.size());
        return emojis;
    } else if (reactions_type.isEmpty()) {
        LOG("No chat reaction type specified, using all reactions");
        return available_reactions.toStringList();
    } else {
        LOG("Unknown chat reaction type" << reactions_type);
        return QStringList();
    }
}

QVariantMap TDLibWrapper::getSecretChatFromCache(qlonglong secretChatId)
{
    return this->secretChats.value(secretChatId);
}

QString TDLibWrapper::getOptionString(const QString &optionName)
{
    return this->options.value(optionName).toString();
}

void TDLibWrapper::copyFileToDownloads(const QString &filePath, bool openAfterCopy)
{
    LOG("Copy file to downloads" << filePath << openAfterCopy);
    QFileInfo fileInfo(filePath);
    if (fileInfo.exists()) {
        QString downloadFilePath = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation) + "/" + fileInfo.fileName();
        if (QFile::exists(downloadFilePath)) {
            if (openAfterCopy) {
                this->openFileOnDevice(downloadFilePath);
            } else {
                emit copyToDownloadsSuccessful(fileInfo.fileName(), downloadFilePath);
            }
        } else {
            if (QFile::copy(filePath, downloadFilePath)) {
                if (openAfterCopy) {
                    this->openFileOnDevice(downloadFilePath);
                } else {
                    emit copyToDownloadsSuccessful(fileInfo.fileName(), downloadFilePath);
                }
            } else {
                emit copyToDownloadsError(fileInfo.fileName(), downloadFilePath);
            }
        }
    } else {
        emit copyToDownloadsError(fileInfo.fileName(), filePath);
    }
}

void TDLibWrapper::copyFileToPictures(const QString &filePath)
{
    LOG("Copy file to pictures" << filePath);
    QFileInfo fileInfo(filePath);
    if (fileInfo.exists()) {
        QString destDir = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
        if (destDir.isEmpty()) {
            destDir = QDir::homePath() + "/Pictures";
        }
        QDir().mkpath(destDir);
        QString destPath = destDir + "/" + fileInfo.fileName();
        if (QFile::exists(destPath) || QFile::copy(filePath, destPath)) {
            emit copyToDownloadsSuccessful(fileInfo.fileName(), destPath);
        } else {
            emit copyToDownloadsError(fileInfo.fileName(), destPath);
        }
    } else {
        emit copyToDownloadsError(fileInfo.fileName(), filePath);
    }
}

void TDLibWrapper::openFileOnDevice(const QString &filePath)
{
    LOG("Open file on device:" << filePath);
    emit openFileExternally(filePath);
}

void TDLibWrapper::controlScreenSaver(bool enabled)
{
    if (enabled) {
        mceInterface->displayCancelBlankingPause();
    } else {
        mceInterface->displayBlankingPause();
    }
}

bool TDLibWrapper::getJoinChatRequested()
{
    return this->joinChatRequested;
}

void TDLibWrapper::registerJoinChat()
{
    this->joinChatRequested = false;
}

DBusAdaptor *TDLibWrapper::getDBusAdaptor()
{
    return this->dbusInterface->getDBusAdaptor();
}

void TDLibWrapper::handleVersionDetected(const QString &version)
{
    this->versionString = version;
    const QStringList parts(version.split('.'));
    uint major, minor, release;
    bool ok;
    if (parts.count() >= 3 &&
       (major = parts.at(0).toInt(&ok), ok) &&
       (minor = parts.at(1).toInt(&ok), ok) &&
       (release = parts.at(2).toInt(&ok), ok)) {
        versionNumber = VERSION_NUMBER(major, minor, release);
    }
    emit versionDetected(version);
}

void TDLibWrapper::handleAuthorizationStateChanged(const QString &authorizationState, const QVariantMap authorizationStateData)
{
    if (authorizationState == "authorizationStateClosed") {
        this->authorizationState = AuthorizationState::Closed;
    }

    if (authorizationState == "authorizationStateClosing") {
        this->authorizationState = AuthorizationState::Closing;
    }

    if (authorizationState == "authorizationStateLoggingOut") {
        this->authorizationState = AuthorizationState::LoggingOut;
    }

    if (authorizationState == "authorizationStateReady") {
        this->authorizationState = AuthorizationState::AuthorizationReady;
    }

    if (authorizationState == "authorizationStateWaitCode") {
        this->authorizationState = AuthorizationState::WaitCode;
    }

    if (authorizationState == "authorizationStateWaitEncryptionKey") {
        this->setEncryptionKey();
        this->authorizationState = AuthorizationState::WaitEncryptionKey;
    }

    if (authorizationState == "authorizationStateWaitOtherDeviceConfirmation") {
        this->authorizationState = AuthorizationState::WaitOtherDeviceConfirmation;
    }

    if (authorizationState == "authorizationStateWaitPassword") {
        this->authorizationState = AuthorizationState::WaitPassword;
    }

    if (authorizationState == "authorizationStateWaitPhoneNumber") {
        this->authorizationState = AuthorizationState::WaitPhoneNumber;
    }

    if (authorizationState == "authorizationStateWaitRegistration") {
        this->authorizationState = AuthorizationState::WaitRegistration;
    }

    if (authorizationState == "authorizationStateWaitTdlibParameters") {
        this->setInitialParameters();
        this->authorizationState = AuthorizationState::WaitTdlibParameters;
    }
    if (authorizationState == "authorizationStateLoggingOut") {
        this->authorizationState = AuthorizationState::AuthorizationStateLoggingOut;
    }
    if (authorizationState == "authorizationStateClosed") {
        this->authorizationState = AuthorizationState::AuthorizationStateClosed;
        LOG("Reloading TD Lib...");
        this->basicGroups.clear();
        this->superGroups.clear();
        this->usersById.clear();
        this->usersByName.clear();
        this->tdLibReceiver->setActive(false);
        while (this->tdLibReceiver->isRunning()) {
            QCoreApplication::processEvents(QEventLoop::AllEvents, 1000);
        }
        td_json_client_destroy(this->tdLibClient);
        this->tdLibReceiver->terminate();
        QDir tdLibPath(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/tdlib");
        tdLibPath.removeRecursively();
        this->tdLibClient = td_json_client_create();
        initializeTDLibReceiver();
        this->isLoggingOut = false;
    }
    this->authorizationStateData = authorizationStateData;
    emit authorizationStateChanged(this->authorizationState, this->authorizationStateData);

}

void TDLibWrapper::handleOptionUpdated(const QString &optionName, const QVariant &optionValue)
{
    this->options.insert(optionName, optionValue);
    emit optionUpdated(optionName, optionValue);
    if (optionName == "my_id") {
        QString ownUserId = optionValue.toString();
        this->userInformation = this->getUserInformation(ownUserId);
        emit ownUserIdFound(ownUserId);

    }
}

void TDLibWrapper::handleConnectionStateChanged(const QString &connectionState)
{
    if (connectionState == "connectionStateConnecting") {
        this->connectionState = ConnectionState::Connecting;
    }
    if (connectionState == "connectionStateConnectingToProxy") {
        this->connectionState = ConnectionState::ConnectingToProxy;
    }
    if (connectionState == "connectionStateReady") {
        this->connectionState = ConnectionState::ConnectionReady;
    }
    if (connectionState == "connectionStateUpdating") {
        this->connectionState = ConnectionState::Updating;
    }
    if (connectionState == "connectionStateWaitingForNetwork") {
        this->connectionState = ConnectionState::WaitingForNetwork;
    }

    emit connectionStateChanged(this->connectionState);
}

void TDLibWrapper::handleUserUpdated(const QVariantMap &updatedUserInformation)
{
    QString updatedUserId = updatedUserInformation.value(ID).toString();
    if (updatedUserId == this->options.value("my_id").toString()) {
        LOG("Own user information updated :)");
        this->userInformation = updatedUserInformation;
        emit ownUserUpdated(updatedUserInformation);
    }
    LOG("User information updated:" << updatedUserInformation.value(USERNAMES).toMap().value(EDITABLE_USERNAME).toString() << updatedUserInformation.value(FIRST_NAME).toString() << updatedUserInformation.value(LAST_NAME).toString());
    updateUserInformation(updatedUserId, updatedUserInformation);
    emit userUpdated(updatedUserId, updatedUserInformation);
}

void TDLibWrapper::handleUserStatusUpdated(const QString &userId, const QVariantMap &userStatusInformation)
{
    if (userId == this->options.value("my_id").toString()) {
        LOG("Own user status information updated :)");
        this->userInformation.insert(STATUS, userStatusInformation);
    }
    QVariantMap updatedUserInformation = this->usersById.value(userId).toMap();
    if(updatedUserInformation[STATUS] == userStatusInformation) {
        return;
    }
    LOG("User status information updated:" << userId << userStatusInformation.value(_TYPE).toString());
    updatedUserInformation.insert(STATUS, userStatusInformation);
    updateUserInformation(userId, updatedUserInformation);
    emit userUpdated(userId, updatedUserInformation);
}

void TDLibWrapper::updateUserInformation(const QString &userId, const QVariantMap &userInformation)
{
    this->usersById.insert(userId, userInformation);
    this->usersByName.insert(userInformation.value(USERNAMES).toMap().value(EDITABLE_USERNAME).toString(), userInformation);
}

void TDLibWrapper::handleFileUpdated(const QVariantMap &fileInformation)
{
    const int fileId = fileInformation.value(ID).toInt();
    bool customEmojiChanged = false;
    QSet<QString> affectedCustomEmojiIds;
    if (this->customEmojiFileIds.contains(fileId)) {
        const QString customEmojiIdByThumb = this->customEmojiByThumbnailFileId.value(fileId);
        if (!customEmojiIdByThumb.isEmpty()) {
            QVariantMap sticker = this->customEmojiById.value(customEmojiIdByThumb);
            if (!sticker.isEmpty()) {
                QVariantMap thumbnail = sticker.value("thumbnail").toMap();
                thumbnail.insert("file", fileInformation);
                sticker.insert("thumbnail", thumbnail);
                this->customEmojiById.insert(customEmojiIdByThumb, sticker);
                affectedCustomEmojiIds.insert(customEmojiIdByThumb);
                customEmojiChanged = true;
            }
        }
        QList<QString> customEmojiIds = this->customEmojiById.keys();
        QListIterator<QString> idsIterator(customEmojiIds);
        while (idsIterator.hasNext()) {
            const QString customEmojiId = idsIterator.next();
            QVariantMap sticker = this->customEmojiById.value(customEmojiId);
            QVariantMap stickerFile = customEmojiStickerFileMap(sticker);
            if (stickerFile.value(ID).toInt() == fileId) {
                sticker.insert("sticker", fileInformation);
                this->customEmojiById.insert(customEmojiId, sticker);
                affectedCustomEmojiIds.insert(customEmojiId);
                customEmojiChanged = true;
            }
        }
    }
    if (customEmojiChanged) {
        QListIterator<QString> affectedIterator(affectedCustomEmojiIds.values());
        while (affectedIterator.hasNext()) {
            emit customEmojiUpdated(affectedIterator.next());
        }
        emit customEmojiAssetsUpdated();
    }
    emit fileUpdated(fileId, fileInformation);
}

void TDLibWrapper::handleNewChatDiscovered(const QVariantMap &chatInformation)
{
    QString chatId = chatInformation.value(ID).toString();
    this->chats.insert(chatId, chatInformation);
    emit newChatDiscovered(chatId, chatInformation);
}

void TDLibWrapper::handleChatsReceived(const QVariantMap &chats)
{
    if (chats.value(_EXTRA).toString() == QStringLiteral("getSuitableDiscussionChats")) {
        emit suitableDiscussionChatsReceived(chats.value("chat_ids").toList());
    }
}

void TDLibWrapper::handleChatThemesUpdated(const QVariantList &themes)
{
    availableChatThemes = themes;
    emit availableChatThemesUpdated(themes);
}

void TDLibWrapper::handleChatReceived(const QVariantMap &chatInformation)
{
    emit chatReceived(chatInformation);
    if (!this->activeChatSearchName.isEmpty()) {
        QVariantMap chatType = chatInformation.value(TYPE).toMap();
        ChatType receivedChatType = chatTypeFromString(chatType.value(_TYPE).toString());
        if (receivedChatType == ChatTypeBasicGroup) {
            LOG("Found basic group for active search" << this->activeChatSearchName);
            this->activeChatSearchName.clear();
            this->createBasicGroupChat(chatType.value("basic_group_id").toString(), "openDirectly");
        }
        if (receivedChatType == ChatTypeSupergroup) {
            LOG("Found supergroup for active search" << this->activeChatSearchName);
            this->activeChatSearchName.clear();
            this->createSupergroupChat(chatType.value("supergroup_id").toString(), "openDirectly");
        }
    }
}

void TDLibWrapper::handleUnreadMessageCountUpdated(const QVariantMap &messageCountInformation)
{
    if (messageCountInformation.value(CHAT_LIST_TYPE).toString() == CHAT_LIST_MAIN) {
        this->unreadMessageInformation = messageCountInformation;
        emit unreadMessageCountUpdated(messageCountInformation);
    }
}

void TDLibWrapper::handleUnreadChatCountUpdated(const QVariantMap &chatCountInformation)
{
    if (chatCountInformation.value(CHAT_LIST_TYPE).toString() == CHAT_LIST_MAIN) {
        this->unreadChatInformation = chatCountInformation;
        emit unreadChatCountUpdated(chatCountInformation);
    }
}

void TDLibWrapper::handleAvailableReactionsUpdated(qlonglong chatId, const QVariantMap &availableReactions)
{
    LOG("Updating available reactions for chat" << chatId << availableReactions);
    QString chatIdString = QString::number(chatId);
    QVariantMap chatInformation = this->getChat(chatIdString);
    chatInformation.insert(CHAT_AVAILABLE_REACTIONS, availableReactions);
    this->chats.insert(chatIdString, chatInformation);
    emit chatAvailableReactionsUpdated(chatId, availableReactions);

}

void TDLibWrapper::handleOkReceived(const QString &extra)
{
    // TDLib non emette updateChatPendingJoinRequests dopo un reject:
    // aggiorniamo la cache locale e rilanciamo il segnale così la banner
    // in ChatPage e la lista in ChatJoinRequestsPage restano coerenti.
    if (extra.startsWith(QStringLiteral("processChatJoinRequest:"))) {
        const QStringList parts = extra.split(QChar(':'));
        if (parts.size() == 3) {
            const QString chatIdString = parts.at(1);
            const qlonglong userId = parts.at(2).toLongLong();
            QVariantMap chatInformation = this->chats.value(chatIdString).toMap();
            if (!chatInformation.isEmpty()) {
                QVariantMap pendingJoinRequests = chatInformation.value(PENDING_JOIN_REQUESTS).toMap();
                QVariantList userIds = pendingJoinRequests.value(USER_IDS).toList();
                bool userWasListed = false;
                for (int i = userIds.size() - 1; i >= 0; --i) {
                    if (userIds.at(i).toLongLong() == userId) {
                        userIds.removeAt(i);
                        userWasListed = true;
                    }
                }
                int totalCount = qMax(0, pendingJoinRequests.value(TOTAL_COUNT).toInt() - 1);
                if (!userIds.isEmpty()) {
                    totalCount = qMax(totalCount, userIds.size());
                }
                pendingJoinRequests.insert(USER_IDS, userIds);
                pendingJoinRequests.insert(TOTAL_COUNT, totalCount);
                chatInformation.insert(PENDING_JOIN_REQUESTS, pendingJoinRequests);
                this->chats.insert(chatIdString, chatInformation);
                Q_UNUSED(userWasListed);
                emit chatPendingJoinRequestsUpdated(chatIdString.toLongLong(), pendingJoinRequests);
            }
        }
    }
    emit okReceived(extra);
}

void TDLibWrapper::handleChatPendingJoinRequestsUpdated(qlonglong chatId, const QVariantMap &pendingJoinRequests)
{
    LOG("Updating pending join requests for chat" << chatId << "count:" << pendingJoinRequests.value(TOTAL_COUNT).toInt());
    const QString chatIdString = QString::number(chatId);
    QVariantMap chatInformation = this->chats.value(chatIdString).toMap();
    if (chatInformation.isEmpty()) {
        LOG("Unable to cache pending join requests for unknown chat" << chatId);
    } else {
        chatInformation.insert(PENDING_JOIN_REQUESTS, pendingJoinRequests);
        this->chats.insert(chatIdString, chatInformation);
    }
    emit chatPendingJoinRequestsUpdated(chatId, pendingJoinRequests);
}

void TDLibWrapper::handleNewChatJoinRequest(qlonglong chatId, const QVariantMap &request, const QVariantMap &inviteLink)
{
    LOG("New chat join request for chat" << chatId << "user:" << request.value(USER_ID).toLongLong());
    const QString chatIdString = QString::number(chatId);
    QVariantMap chatInformation = this->chats.value(chatIdString).toMap();
    QVariantMap pendingJoinRequests = chatInformation.value(PENDING_JOIN_REQUESTS).toMap();
    QVariantList userIds = pendingJoinRequests.value(USER_IDS).toList();
    const qlonglong userId = request.value(USER_ID).toLongLong();
    bool userAlreadyPresent = false;
    if (userId > 0) {
        const int usersCount = userIds.size();
        for (int i = 0; i < usersCount; i++) {
            if (userIds.at(i).toLongLong() == userId) {
                userAlreadyPresent = true;
                break;
            }
        }
        if (!userAlreadyPresent) {
            userIds.prepend(userId);
            pendingJoinRequests.insert(USER_IDS, userIds);
        }
    }
    int totalCount = qMax(0, pendingJoinRequests.value(TOTAL_COUNT).toInt());
    if (userId <= 0 || !userAlreadyPresent) {
        totalCount += 1;
    }
    if (!userIds.isEmpty()) {
        totalCount = qMax(totalCount, userIds.size());
    }
    pendingJoinRequests.insert(TOTAL_COUNT, totalCount);
    if (chatInformation.isEmpty()) {
        LOG("Unable to cache new join request for unknown chat" << chatId);
    } else {
        chatInformation.insert(PENDING_JOIN_REQUESTS, pendingJoinRequests);
        this->chats.insert(chatIdString, chatInformation);
    }
    emit newChatJoinRequest(chatId, request, inviteLink);
    emit chatPendingJoinRequestsUpdated(chatId, pendingJoinRequests);
}

void TDLibWrapper::handleBasicGroupUpdated(qlonglong groupId, const QVariantMap &groupInformation)
{
    emit basicGroupUpdated(updateGroup(groupId, groupInformation, &basicGroups)->groupId);
    if (!this->activeChatSearchName.isEmpty() && this->activeChatSearchName == groupInformation.value(USERNAME).toString()) {
        LOG("Found basic group for active search" << this->activeChatSearchName);
        this->activeChatSearchName.clear();
        this->createBasicGroupChat(groupInformation.value(ID).toString(), "openDirectly");
    }
}

void TDLibWrapper::handleSuperGroupUpdated(qlonglong groupId, const QVariantMap &groupInformation)
{
    emit superGroupUpdated(updateGroup(groupId, groupInformation, &superGroups)->groupId);
    if (!this->activeChatSearchName.isEmpty() && this->activeChatSearchName == groupInformation.value(USERNAME).toString()) {
        LOG("Found supergroup for active search" << this->activeChatSearchName);
        this->activeChatSearchName.clear();
        this->createSupergroupChat(groupInformation.value(ID).toString(), "openDirectly");
    }
}

void TDLibWrapper::handleStickerSets(const QVariantList &stickerSets, const QString &stickerType)
{
    // Il fetch dei dettagli del singolo set è demandato a StickerManager
    // (vedi handleStickerSetsReceived), così può saltare i set già in
    // cache. Evita 56 round-trip TDLib sequenziali post-rimozione che
    // bloccavano la UI.
    emit this->stickerSetsReceived(stickerSets, stickerType);
}


void TDLibWrapper::handleCustomEmojiStickers(const QVariantList &stickers, const QString &extra)
{
    QString extraToken = extra;
    if (extraToken.startsWith("customEmoji:")) {
        extraToken = extraToken.mid(QStringLiteral("customEmoji:").length());
    }
    if (!extraToken.isEmpty()) {
        const QStringList requestedIds = extraToken.split(",", QString::SkipEmptyParts);
        QStringListIterator requestedIterator(requestedIds);
        while (requestedIterator.hasNext()) {
            this->pendingCustomEmojiRequests.remove(requestedIterator.next().trimmed());
        }
    }

    QSet<QString> updatedCustomEmojiIds;
    QListIterator<QVariant> stickersIterator(stickers);
    while (stickersIterator.hasNext()) {
        const QVariantMap sticker = stickersIterator.next().toMap();
        const QString customEmojiId = customEmojiIdFromSticker(sticker);
        this->upsertCustomEmojiFromSticker(sticker);
        if (!customEmojiId.isEmpty()) {
            updatedCustomEmojiIds.insert(customEmojiId);
            this->pendingCustomEmojiRequests.remove(customEmojiId);
        }
    }
    if (!updatedCustomEmojiIds.isEmpty()) {
        QListIterator<QString> updatedIterator(updatedCustomEmojiIds.values());
        while (updatedIterator.hasNext()) {
            emit customEmojiUpdated(updatedIterator.next());
        }
        emit customEmojiAssetsUpdated();
    }
}

void TDLibWrapper::upsertCustomEmojiFromSticker(const QVariantMap &sticker)
{
    const QString customEmojiId = customEmojiIdFromSticker(sticker);
    if (customEmojiId.isEmpty()) {
        return;
    }
    this->customEmojiById.insert(customEmojiId, sticker);

    const QVariantMap thumbnailFile = customEmojiThumbnailFileMap(sticker);
    const int thumbnailFileId = thumbnailFile.value(ID).toInt();
    if (thumbnailFileId > 0) {
        this->customEmojiByThumbnailFileId.insert(thumbnailFileId, customEmojiId);
        this->customEmojiFileIds.insert(thumbnailFileId);
        const QVariantMap thumbnailLocal = thumbnailFile.value("local").toMap();
        const bool hasThumbnailLocally = thumbnailLocal.value("is_downloading_completed").toBool()
                && !thumbnailLocal.value("path").toString().isEmpty();
        const bool canDownloadThumbnail = thumbnailFile.value("local").toMap().value("can_be_downloaded").toBool()
                || !thumbnailFile.value("remote").toMap().value(ID).toString().isEmpty();
        if (!hasThumbnailLocally && canDownloadThumbnail) {
            this->downloadFile(thumbnailFileId);
        }
    }

    const QVariantMap stickerFile = customEmojiStickerFileMap(sticker);
    const int stickerFileId = stickerFile.value(ID).toInt();
    if (stickerFileId > 0) {
        this->customEmojiFileIds.insert(stickerFileId);
        const QVariantMap stickerLocal = stickerFile.value("local").toMap();
        const bool hasStickerLocally = stickerLocal.value("is_downloading_completed").toBool()
                && !stickerLocal.value("path").toString().isEmpty();
        const bool canDownloadSticker = stickerFile.value("local").toMap().value("can_be_downloaded").toBool()
                || !stickerFile.value("remote").toMap().value(ID).toString().isEmpty();
        if (!hasStickerLocally && canDownloadSticker) {
            this->downloadFile(stickerFileId);
        }
    }
}
void TDLibWrapper::handleEmojiSearchCompleted(const QString &queryString, const QVariantList &resultList)
{
    LOG("Emoji search completed" << queryString);
    emit emojiSearchSuccessful(resultList);
}

void TDLibWrapper::handleOpenWithChanged()
{
    if (this->appSettings->getUseOpenWith()) {
        this->initializeOpenWith();
    } else {
        this->removeOpenWith();
    }
}

void TDLibWrapper::handleSecretChatReceived(qlonglong secretChatId, const QVariantMap &secretChat)
{
    this->secretChats.insert(secretChatId, secretChat);
    emit secretChatReceived(secretChatId, secretChat);
}

void TDLibWrapper::handleSecretChatUpdated(qlonglong secretChatId, const QVariantMap &secretChat)
{
    this->secretChats.insert(secretChatId, secretChat);
    emit secretChatUpdated(secretChatId, secretChat);
}

void TDLibWrapper::handleStorageOptimizerChanged()
{
    setOptionBoolean("use_storage_optimizer", appSettings->storageOptimizer());
}

void TDLibWrapper::handleErrorReceived(int code, const QString &message, const QString &extra)
{
    if (!extra.isEmpty()) {
        QStringList parts(extra.split(':'));
        if (parts.size() == 3 && parts.at(0) == QStringLiteral("getMessage")) {
            emit messageNotFound(parts.at(1).toLongLong(), parts.at(2).toLongLong());
        }
        // Bypass silenzioso degli errori per getChatScheduledMessages: la pagina
        // "Scheduled messages" globale lo invoca su TUTTE le chat e per i canali
        // dove non sei admin TDLib torna "Not enough rights to get scheduled
        // messages". Emettiamo un risultato vuoto con lo stesso extra così la
        // pagina può drenare pendingChats senza mostrare toast.
        if (extra.startsWith(QStringLiteral("getChatScheduledMessages:"))) {
            emit messagesReceivedWithExtra(QVariantList(), 0, extra);
            return;
        }
    }
    emit errorReceived(code, message, extra);
}

void TDLibWrapper::handleMessageInformation(qlonglong chatId, qlonglong messageId, const QVariantMap &receivedInformation)
{
    QString extraInformation = receivedInformation.value(_EXTRA).toString();
    if (extraInformation.startsWith("getChatPinnedMessage:")) {
        emit chatPinnedMessageUpdated(chatId, messageId);
    }
    emit receivedMessage(chatId, messageId, receivedInformation);
}

void TDLibWrapper::handleMessageIsPinnedUpdated(qlonglong chatId, qlonglong messageId, bool isPinned)
{
    if (isPinned) {
        emit chatPinnedMessageUpdated(chatId, messageId);
    } else {
        emit chatPinnedMessageUpdated(chatId, 0);
        this->getChatPinnedMessage(chatId);
    }
    this->getMessage(chatId, messageId);
}

void TDLibWrapper::handleUserPrivacySettingRules(const QVariantMap &rules)
{
    QVariantList newGivenRules = rules.value("rules").toList();
    // If nothing (or something unsupported is sent out) it is considered to be restricted completely
    UserPrivacySettingRule newAppliedRule = UserPrivacySettingRule::RuleRestrictAll;
    QListIterator<QVariant> givenRulesIterator(newGivenRules);
    while (givenRulesIterator.hasNext()) {
        QString givenRule = givenRulesIterator.next().toMap().value(_TYPE).toString();
        if (givenRule == "userPrivacySettingRuleAllowContacts") {
            newAppliedRule = UserPrivacySettingRule::RuleAllowContacts;
        }
        if (givenRule == "userPrivacySettingRuleAllowAll") {
            newAppliedRule = UserPrivacySettingRule::RuleAllowAll;
        }
    }
    UserPrivacySetting usedSetting = static_cast<UserPrivacySetting>(rules.value(_EXTRA).toInt());
    this->userPrivacySettingRules.insert(usedSetting, newAppliedRule);
    emit userPrivacySettingUpdated(usedSetting, newAppliedRule);
}

void TDLibWrapper::handleUpdatedUserPrivacySettingRules(const QVariantMap &updatedRules)
{
    QString rawSetting = updatedRules.value("setting").toMap().value(_TYPE).toString();
    UserPrivacySetting usedSetting = UserPrivacySetting::SettingUnknown;
    if (rawSetting == "userPrivacySettingAllowChatInvites") {
        usedSetting = UserPrivacySetting::SettingAllowChatInvites;
    }
    if (rawSetting == "userPrivacySettingAllowFindingByPhoneNumber") {
        usedSetting = UserPrivacySetting::SettingAllowFindingByPhoneNumber;
    }
    if (rawSetting == "userPrivacySettingShowLinkInForwardedMessages") {
        usedSetting = UserPrivacySetting::SettingShowLinkInForwardedMessages;
    }
    if (rawSetting == "userPrivacySettingShowPhoneNumber") {
        usedSetting = UserPrivacySetting::SettingShowPhoneNumber;
    }
    if (rawSetting == "userPrivacySettingShowProfilePhoto") {
        usedSetting = UserPrivacySetting::SettingShowProfilePhoto;
    }
    if (rawSetting == "userPrivacySettingShowStatus") {
        usedSetting = UserPrivacySetting::SettingShowStatus;
    }
    if (usedSetting != UserPrivacySetting::SettingUnknown) {
        QVariantMap rawRules = updatedRules.value("rules").toMap();
        rawRules.insert(_EXTRA, usedSetting);
        this->handleUserPrivacySettingRules(rawRules);
    }
}

void TDLibWrapper::handleSponsoredMessage(qlonglong chatId, const QVariantMap &message)
{
    switch (appSettings->getSponsoredMess()) {
    case AppSettings::SponsoredMessHandle:
        emit sponsoredMessageReceived(chatId, message);
        break;
    case AppSettings::SponsoredMessAutoView:
        LOG("Auto-viewing sponsored message");
        viewMessage(chatId, message.value(MESSAGE_ID).toULongLong(), false);
        break;
    case AppSettings::SponsoredMessIgnore:
        LOG("Ignoring sponsored message");
        break;
    }
}

void TDLibWrapper::handleActiveEmojiReactionsUpdated(const QStringList& emojis)
{
    if (activeEmojiReactions != emojis) {
        activeEmojiReactions = emojis;
        LOG(emojis.count() << "reaction(s) available");
        emit reactionsUpdated();
    }
}

void TDLibWrapper::handleNetworkConfigurationChanged(const QNetworkConfiguration &config)
{
    LOG("A network configuration changed: " << config.bearerTypeName() << config.state());
    LOG("Checking overall network state...");

    bool wifiFound = false;
    bool mobileFound = false;

    QList<QNetworkConfiguration> activeConfigurations = networkConfigurationManager->allConfigurations(QNetworkConfiguration::Active);
    QListIterator<QNetworkConfiguration> configurationIterator(activeConfigurations);
    while (configurationIterator.hasNext()) {
        QNetworkConfiguration activeConfiguration = configurationIterator.next();
        if (activeConfiguration.bearerType() == QNetworkConfiguration::BearerWLAN
                || activeConfiguration.bearerType() == QNetworkConfiguration::BearerEthernet) {
            LOG("Active WiFi found...");
            wifiFound = true;
        }
        if (activeConfiguration.bearerType() == QNetworkConfiguration::Bearer2G
                || activeConfiguration.bearerType() == QNetworkConfiguration::Bearer3G
                || activeConfiguration.bearerType() == QNetworkConfiguration::Bearer4G
                || activeConfiguration.bearerType() == QNetworkConfiguration::BearerCDMA2000
                || activeConfiguration.bearerType() == QNetworkConfiguration::BearerEVDO
                || activeConfiguration.bearerType() == QNetworkConfiguration::BearerHSPA
                || activeConfiguration.bearerType() == QNetworkConfiguration::BearerLTE
                || activeConfiguration.bearerType() == QNetworkConfiguration::BearerWCDMA) {
            LOG("Active mobile connection found...");
            mobileFound = true;
        }
    }
    if (wifiFound) {
        this->setNetworkType(NetworkType::WiFi);
    } else if (mobileFound) {
        this->setNetworkType(NetworkType::Mobile);
    } else {
        this->setNetworkType(NetworkType::None);
    }
}

void TDLibWrapper::handleGetPageSourceFinished()
{
    LOG("TDLibWrapper::handleGetPageSourceFinished");
    QNetworkReply *reply = qobject_cast<QNetworkReply *>(sender());
    reply->deleteLater();
    if (reply->error() != QNetworkReply::NoError) {
        return;
    }

    QString requestAddress = reply->request().url().toString();

    QVariant contentTypeHeader = reply->header(QNetworkRequest::ContentTypeHeader);
    if (!contentTypeHeader.isValid()) {
        return;
    }
    LOG("Page source content type header: " + contentTypeHeader.toString());
    if (contentTypeHeader.toString().indexOf("text/html", 0, Qt::CaseInsensitive) == -1) {
        LOG(requestAddress + " is not HTML, not searching for TG URL...");
        return;
    }

    QString charset = "UTF-8";
    QRegularExpression charsetRegularExpression("charset\\s*\\=[\\s\\\"\\\']*([^\\s\\\"\\\'\\,>]*)");
    QRegularExpressionMatchIterator matchIterator = charsetRegularExpression.globalMatch(contentTypeHeader.toString());
    QStringList availableCharsets;
    while (matchIterator.hasNext()) {
        QRegularExpressionMatch nextMatch = matchIterator.next();
        QString currentCharset = nextMatch.captured(1).toUpper();
        LOG("Available page source charset: " << currentCharset);
        availableCharsets.append(currentCharset);
    }
    if (availableCharsets.size() > 0 && !availableCharsets.contains("UTF-8")) {
        // If we haven't received the requested UTF-8, we simply use the last one which we received in the header
        charset = availableCharsets.last();
    }
    LOG("Charset for " << requestAddress << ": " << charset);

    QByteArray rawDocument = reply->readAll();
    QTextCodec *codec = QTextCodec::codecForName(charset.toUtf8());
    if (codec == nullptr){
      return;
    }
    QString resultDocument = codec->toUnicode(rawDocument);
    QRegExp urlRegex("href\\=\"(tg\\:[^\"]+)\\\"");
    if (urlRegex.indexIn(resultDocument) != -1) {
        LOG("TG URL found: " + urlRegex.cap(1));
        emit tgUrlFound(urlRegex.cap(1));
    }
}

QVariantMap& TDLibWrapper::fillTdlibParameters(QVariantMap& parameters)
{
    parameters.insert("api_id", TDLIB_API_ID);
    parameters.insert("api_hash", TDLIB_API_HASH);
    parameters.insert("database_directory", QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/tdlib");
    bool onlineOnlyMode = this->appSettings->onlineOnlyMode();
    parameters.insert("use_file_database", !onlineOnlyMode);
    parameters.insert("use_chat_info_database", !onlineOnlyMode);
    parameters.insert("use_message_database", !onlineOnlyMode);
    parameters.insert("use_secret_chats", true);
    parameters.insert("system_language_code", QLocale::system().name());
    QSettings hardwareSettings("/etc/hw-release", QSettings::NativeFormat);
    parameters.insert("device_model", hardwareSettings.value("NAME", "Unknown Mobile Device").toString());
    parameters.insert("system_version", QSysInfo::prettyProductName());
    parameters.insert("application_version", QStringLiteral("RooTelegram " APP_VERSION));
    parameters.insert("enable_storage_optimizer", appSettings->storageOptimizer());
    // parameters.insert("use_test_dc", true);
    return parameters;
}

void TDLibWrapper::setInitialParameters()
{
    LOG("Sending initial parameters to TD Lib");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setTdlibParameters");
    // tdlibParameters were inlined between 1.8.5 and 1.8.6
    // See https://github.com/tdlib/td/commit/f6a2ecd
    if (versionNumber > VERSION_NUMBER(1,8,5)) {
        fillTdlibParameters(requestObject);
    } else {
        QVariantMap initialParameters;
        fillTdlibParameters(initialParameters);
        requestObject.insert("parameters", initialParameters);
    }
    this->sendRequest(requestObject);
}

void TDLibWrapper::setEncryptionKey()
{
    LOG("Setting database encryption key");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "checkDatabaseEncryptionKey");
    // see https://github.com/tdlib/td/issues/188#issuecomment-379536139
    requestObject.insert("encryption_key", "");
    this->sendRequest(requestObject);
}

void TDLibWrapper::setLogVerbosityLevel()
{
    LOG("Setting log verbosity level to errors only");
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setLogVerbosityLevel");
    requestObject.insert("new_verbosity_level", 1);
    this->sendRequest(requestObject);
}

void TDLibWrapper::initializeOpenWith()
{
    LOG("Initialize open-with");

    const QStringList sailfishOSVersion = QSysInfo::productVersion().split(".");
    int sailfishOSMajorVersion = sailfishOSVersion.value(0).toInt();
    int sailfishOSMinorVersion = sailfishOSVersion.value(1).toInt();

    const QString applicationsLocation(QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation));

    // Niente gestione di sailfish-browser.desktop o open-url.desktop:
    // appartengono al sistema o ad altre app, non a RooTelegram.

    const QString desktopFilePath(applicationsLocation + "/harbour-rootelegram-open-url.desktop");
    QFile desktopFile(desktopFilePath);
    if (desktopFile.exists()) {
        LOG("RooTelegram open-with file existing, removing...");
        desktopFile.remove();
        QProcess::startDetached("update-desktop-database " + applicationsLocation);
    }
    LOG("Creating RooTelegram open-with file at " << desktopFile.fileName());
    if (desktopFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream fileOut(&desktopFile);
        fileOut.setCodec("UTF-8");
        fileOut << QString("[Desktop Entry]").toUtf8() << "\n";
        fileOut << QString("Type=Application").toUtf8() << "\n";
        fileOut << QString("Name=RooTelegram").toUtf8() << "\n";
        fileOut << QString("Icon=harbour-rootelegram").toUtf8() << "\n";
        fileOut << QString("NotShowIn=X-MeeGo;").toUtf8() << "\n";
        if (sailfishOSMajorVersion < 4 || ( sailfishOSMajorVersion == 4 && sailfishOSMinorVersion < 1 )) {
            fileOut << QString("MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/tg;").toUtf8() << "\n";
        } else {
            fileOut << QString("MimeType=x-url-handler/t.me;x-scheme-handler/tg;").toUtf8() << "\n";
        }
        fileOut << QString("X-Maemo-Service=com.github.RootGPT_YouTube.rootelegram").toUtf8() << "\n";
        fileOut << QString("X-Maemo-Object-Path=/com/github/RootGPT_YouTube/rootelegram").toUtf8() << "\n";
        fileOut << QString("X-Maemo-Method=com.github.RootGPT_YouTube.rootelegram.openUrl").toUtf8() << "\n";
        fileOut << QString("Hidden=true;").toUtf8() << "\n";
        fileOut.flush();
        desktopFile.close();
        QProcess::startDetached("update-desktop-database " + applicationsLocation);
    }

    QString dbusPathName = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/dbus-1/services";
    QDir dbusPath(dbusPathName);
    if (!dbusPath.exists()) {
        LOG("Creating D-Bus directory" << dbusPathName);
        dbusPath.mkpath(dbusPathName);
    }
    QString dbusServiceFileName = dbusPathName + "/com.github.RootGPT_YouTube.rootelegram.service";
    QFile dbusServiceFile(dbusServiceFileName);
    if (dbusServiceFile.exists()) {
        LOG("D-BUS service file existing, removing to ensure proper re-creation...");
        dbusServiceFile.remove();
    }
    LOG("Creating D-Bus service file at" << dbusServiceFile.fileName());
    if (dbusServiceFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream fileOut(&dbusServiceFile);
        fileOut.setCodec("UTF-8");
        fileOut << QString("[D-BUS Service]").toUtf8() << "\n";
        fileOut << QString("Name=com.github.RootGPT_YouTube.rootelegram").toUtf8() << "\n";
        fileOut << QString("Exec=sailjail -- /usr/bin/harbour-rootelegram").toUtf8() << "\n";
        fileOut.flush();
        dbusServiceFile.close();
    }
}

void TDLibWrapper::removeOpenWith()
{
    LOG("Remove open-with");
    QFile::remove(QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation) + "/harbour-rootelegram-open-url.desktop");
    QProcess::startDetached("update-desktop-database " + QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation));
}

void TDLibWrapper::loadActiveStories(const QString &listType)
{
    LOG("Loading active stories" << listType);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "loadActiveStories");
    QVariantMap storyList;
    storyList.insert(_TYPE, listType == QStringLiteral("archive") ? "storyListArchive" : "storyListMain");
    requestObject.insert("story_list", storyList);
    this->sendRequest(requestObject);
}

void TDLibWrapper::getChatActiveStories(const QString &chatId)
{
    LOG("Getting chat active stories" << chatId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getChatActiveStories");
    requestObject.insert("chat_id", chatId.toLongLong());
    this->sendRequest(requestObject);
}

void TDLibWrapper::getStory(const QString &storySenderChatId, int storyId, bool onlyLocal)
{
    // Su TDLib 1.8.62 il campo si chiama story_poster_chat_id (rinominato da
    // story_sender_chat_id in qualche versione 1.8.x). Verificato via strings.
    LOG("Getting story" << storySenderChatId << storyId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getStory");
    requestObject.insert("story_poster_chat_id", storySenderChatId.toLongLong());
    requestObject.insert("story_id", storyId);
    requestObject.insert("only_local", onlyLocal);
    this->sendRequest(requestObject);
}

void TDLibWrapper::viewStory(const QString &storySenderChatId, int storyId)
{
    // Su TDLib 1.8.62 (verificato via strings su libtdjson) la chiamata è
    // openStory (singolare). Non esiste viewStory né viewStories. Manteniamo
    // il nome QML-side per stabilità e mappiamo qui. Il campo è
    // story_poster_chat_id, non story_sender_chat_id.
    LOG("Opening story" << storySenderChatId << storyId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "openStory");
    requestObject.insert("story_poster_chat_id", storySenderChatId.toLongLong());
    requestObject.insert("story_id", storyId);
    this->sendRequest(requestObject);
}

void TDLibWrapper::getChatArchivedStories(const QString &chatId, int fromStoryId, int limit, const QString &extra)
{
    LOG("Getting chat archived stories" << chatId << fromStoryId << limit);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getChatArchivedStories");
    requestObject.insert("chat_id", chatId.toLongLong());
    requestObject.insert("from_story_id", fromStoryId);
    requestObject.insert("limit", limit);
    if (!extra.isEmpty()) {
        requestObject.insert(_EXTRA, extra);
    }
    this->sendRequest(requestObject);
}

void TDLibWrapper::getChatPostedToChatPageStories(const QString &chatId, int fromStoryId, int limit, const QString &extra)
{
    // Storie pubblicate sul profilo (chat page): equivalente di "Highlights"
    // sopravvissuti alle 24h. Funzione runtime verificata via strings sul
    // libtdjson 1.8.62 del device. Stessa shape di getChatArchivedStories.
    LOG("Getting chat posted-to-page stories" << chatId << fromStoryId << limit);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getChatPostedToChatPageStories");
    requestObject.insert("chat_id", chatId.toLongLong());
    requestObject.insert("from_story_id", fromStoryId);
    requestObject.insert("limit", limit);
    if (!extra.isEmpty()) {
        requestObject.insert(_EXTRA, extra);
    }
    this->sendRequest(requestObject);
}

namespace {
    // Costruisce privacy_settings per postStory: "everyone" oppure
    // "selected" con la lista di user_ids (int53).
    QVariantMap buildStoryPrivacySettings(const QString &mode, const QStringList &allowedUserIds)
    {
        QVariantMap privacy;
        if (mode == QStringLiteral("selected")) {
            QVariantList userIds;
            for (const QString &uid : allowedUserIds) {
                bool ok = false;
                qlonglong v = uid.toLongLong(&ok);
                if (ok && v != 0) userIds.append(v);
            }
            privacy.insert(_TYPE, "storyPrivacySettingsSelectedUsers");
            privacy.insert("user_ids", userIds);
        } else {
            privacy.insert(_TYPE, "storyPrivacySettingsEveryone");
        }
        return privacy;
    }
}

void TDLibWrapper::postStory(const QString &chatId, const QString &photoPath, const QString &caption, int activePeriod,
                             const QString &privacyMode, const QStringList &allowedUserIds,
                             bool allowScreenshots, bool postToProfile)
{
    // TDLib 1.8.62: la funzione è postStory (NON sendStory) e i campi sono
    // confermati via strings su libtdjson: content/privacy_settings/active_period/
    // is_posted_to_chat_page. Per ora solo foto (inputStoryContentPhoto).
    LOG("Posting story" << chatId << photoPath << privacyMode << allowedUserIds.size() << allowScreenshots << postToProfile);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "postStory");
    requestObject.insert(_EXTRA, "postStory");
    requestObject.insert("chat_id", chatId.toLongLong());

    QVariantMap inputFile;
    inputFile.insert(_TYPE, "inputFileLocal");
    inputFile.insert("path", photoPath);

    QVariantMap content;
    content.insert(_TYPE, "inputStoryContentPhoto");
    content.insert("photo", inputFile);
    content.insert("added_sticker_file_ids", QVariantList());
    requestObject.insert("content", content);

    QVariantMap formattedCaption;
    formattedCaption.insert(_TYPE, "formattedText");
    formattedCaption.insert("text", caption);
    formattedCaption.insert("entities", QVariantList());
    requestObject.insert("caption", formattedCaption);

    requestObject.insert("privacy_settings", buildStoryPrivacySettings(privacyMode, allowedUserIds));

    // active_period valido solo: 6h/12h/24h/48h. Default 24h.
    requestObject.insert("active_period", activePeriod > 0 ? activePeriod : 86400);
    requestObject.insert("is_posted_to_chat_page", postToProfile);
    requestObject.insert("protect_content", !allowScreenshots);
    this->sendRequest(requestObject);
}

void TDLibWrapper::postVideoStory(const QString &chatId, const QString &videoPath, double duration, const QString &caption, int activePeriod,
                                  const QString &privacyMode, const QStringList &allowedUserIds,
                                  bool allowScreenshots, bool postToProfile)
{
    // TDLib 1.8.62 (campi verificati via strings su libtdjson): content =
    // inputStoryContentVideo video:InputFile duration:double cover_frame_timestamp:double
    // is_animation:Bool added_sticker_file_ids:vector<int32>. Attenzione: TDLib NON
    // transcodifica, il server rifiuta formati incompatibili o durata > 60s
    // (errore instradato via @extra="postStory", vedi StoriesPage onErrorReceived).
    LOG("Posting video story" << chatId << videoPath << duration << privacyMode << allowedUserIds.size() << allowScreenshots << postToProfile);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "postStory");
    requestObject.insert(_EXTRA, "postStory");
    requestObject.insert("chat_id", chatId.toLongLong());

    QVariantMap inputFile;
    inputFile.insert(_TYPE, "inputFileLocal");
    inputFile.insert("path", videoPath);

    QVariantMap content;
    content.insert(_TYPE, "inputStoryContentVideo");
    content.insert("video", inputFile);
    content.insert("duration", duration);
    content.insert("cover_frame_timestamp", 0.0);
    content.insert("is_animation", false);
    content.insert("added_sticker_file_ids", QVariantList());
    requestObject.insert("content", content);

    QVariantMap formattedCaption;
    formattedCaption.insert(_TYPE, "formattedText");
    formattedCaption.insert("text", caption);
    formattedCaption.insert("entities", QVariantList());
    requestObject.insert("caption", formattedCaption);

    requestObject.insert("privacy_settings", buildStoryPrivacySettings(privacyMode, allowedUserIds));

    requestObject.insert("active_period", activePeriod > 0 ? activePeriod : 86400);
    requestObject.insert("is_posted_to_chat_page", postToProfile);
    requestObject.insert("protect_content", !allowScreenshots);
    this->sendRequest(requestObject);
}

void TDLibWrapper::deleteStory(const QString &storyPosterChatId, int storyId)
{
    // TDLib 1.8.62: deleteStory story_poster_chat_id:int53 story_id:int32 = Ok.
    LOG("Deleting story" << storyPosterChatId << storyId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "deleteStory");
    requestObject.insert("story_poster_chat_id", storyPosterChatId.toLongLong());
    requestObject.insert("story_id", storyId);
    this->sendRequest(requestObject);
}

void TDLibWrapper::getStoryInteractions(int storyId, const QString &offset, int limit)
{
    // TDLib 1.8.62/1.8.64 (schema verificato): getStoryInteractions story_id:int32
    // query:string only_contacts:Bool prefer_forwards:Bool prefer_with_reaction:Bool
    // offset:string limit:int32 = StoryInteractions. Opera implicitamente sulle
    // storie del current user. La risposta `storyInteractions` non riporta lo
    // story_id, quindi lo veicoliamo via @extra per correlarla lato QML.
    LOG("Getting story interactions" << storyId << offset << limit);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getStoryInteractions");
    requestObject.insert(_EXTRA, "storyInteractions:" + QString::number(storyId));
    requestObject.insert("story_id", storyId);
    requestObject.insert("query", QString());
    requestObject.insert("only_contacts", false);
    requestObject.insert("prefer_forwards", false);
    requestObject.insert("prefer_with_reaction", false);
    requestObject.insert("offset", offset);
    requestObject.insert("limit", limit > 0 ? limit : 50);
    this->sendRequest(requestObject);
}

void TDLibWrapper::setStoryReaction(const QString &storyPosterChatId, int storyId, const QString &emoji, bool updateRecent)
{
    // TDLib 1.8.62: setStoryReaction story_poster_chat_id:int53 story_id:int32
    // reaction_type:ReactionType update_recent_reactions:Bool = Ok. reaction_type
    // null rimuove la reaction. Errori (es. emoji non valida) instradati via
    // @extra="storyReaction" → toast nel viewer.
    LOG("Setting story reaction" << storyPosterChatId << storyId << emoji);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setStoryReaction");
    requestObject.insert(_EXTRA, "storyReaction");
    requestObject.insert("story_poster_chat_id", storyPosterChatId.toLongLong());
    requestObject.insert("story_id", storyId);
    if (emoji.isEmpty()) {
        requestObject.insert("reaction_type", QVariant()); // null = rimuove
    } else {
        QVariantMap reactionType;
        reactionType.insert(_TYPE, "reactionTypeEmoji");
        reactionType.insert("emoji", emoji);
        requestObject.insert("reaction_type", reactionType);
    }
    requestObject.insert("update_recent_reactions", updateRecent);
    this->sendRequest(requestObject);
}

void TDLibWrapper::sendStoryReply(const QString &storyPosterChatId, int storyId, const QString &message)
{
    // Reply privato a una storia altrui: sendMessage alla chat del poster con
    // reply_to = inputMessageReplyToStory (schema TL verificato). Per le storie
    // utente la chat è il poster stesso (chat_id == story_poster_chat_id).
    LOG("Sending story reply" << storyPosterChatId << storyId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "sendMessage");
    requestObject.insert(CHAT_ID, storyPosterChatId.toLongLong());

    QVariantMap replyTo;
    replyTo.insert(_TYPE, "inputMessageReplyToStory");
    replyTo.insert("story_poster_chat_id", storyPosterChatId.toLongLong());
    replyTo.insert("story_id", storyId);
    requestObject.insert(REPLY_TO, replyTo);

    QVariantMap inputMessageContent;
    inputMessageContent.insert(_TYPE, "inputMessageText");
    inputMessageContent.insert("text", formattedTextFromMessage(message));
    inputMessageContent.insert("disable_web_page_preview", false);
    requestObject.insert("input_message_content", inputMessageContent);
    this->sendRequest(requestObject);
}

void TDLibWrapper::setChatActiveStoriesList(const QString &chatId, const QString &listType)
{
    // TDLib 1.8.62: setChatActiveStoriesList chat_id:int53 story_list:StoryList = Ok.
    // Sposta le storie attive di una chat tra Main e Archived (lato utente).
    LOG("Setting chat active stories list" << chatId << listType);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "setChatActiveStoriesList");
    requestObject.insert(CHAT_ID, chatId.toLongLong());
    QVariantMap storyList;
    storyList.insert(_TYPE, listType == QStringLiteral("archive")
                            ? "storyListArchive" : "storyListMain");
    requestObject.insert("story_list", storyList);
    this->sendRequest(requestObject);
}

const TDLibWrapper::Group *TDLibWrapper::updateGroup(qlonglong groupId, const QVariantMap &groupInfo, QHash<qlonglong,Group*> *groups)
{
    Group* group = groups->value(groupId);
    if (!group) {
        group = new Group(groupId);
        groups->insert(groupId, group);
    }
    group->groupInfo = groupInfo;
    return group;
}

const TDLibWrapper::Group* TDLibWrapper::getGroup(qlonglong groupId) const
{
    if (groupId) {
        const Group* group = superGroups.value(groupId);
        return group ? group : basicGroups.value(groupId);
    }
    return Q_NULLPTR;
}

TDLibWrapper::ChatType TDLibWrapper::chatTypeFromString(const QString &type)
{
    return (type == QStringLiteral("chatTypePrivate")) ? ChatTypePrivate :
        (type == QStringLiteral("chatTypeBasicGroup")) ? ChatTypeBasicGroup :
        (type == QStringLiteral("chatTypeSupergroup")) ? ChatTypeSupergroup :
        (type == QStringLiteral("chatTypeSecret")) ?  ChatTypeSecret :
        ChatTypeUnknown;
}

TDLibWrapper::ChatMemberStatus TDLibWrapper::chatMemberStatusFromString(const QString &status)
{
    // Most common ones first
    return (status == QStringLiteral("chatMemberStatusMember")) ? ChatMemberStatusMember :
        (status == QStringLiteral("chatMemberStatusLeft")) ? ChatMemberStatusLeft :
        (status == QStringLiteral("chatMemberStatusCreator")) ? ChatMemberStatusCreator :
        (status == QStringLiteral("chatMemberStatusAdministrator")) ?  ChatMemberStatusAdministrator :
        (status == QStringLiteral("chatMemberStatusRestricted")) ? ChatMemberStatusRestricted :
        (status == QStringLiteral("chatMemberStatusBanned")) ?  ChatMemberStatusBanned :
                                                                ChatMemberStatusUnknown;
}

TDLibWrapper::SecretChatState TDLibWrapper::secretChatStateFromString(const QString &state)
{
    return (state == QStringLiteral("secretChatStateClosed")) ? SecretChatStateClosed :
        (state == QStringLiteral("secretChatStatePending")) ? SecretChatStatePending :
        (state == QStringLiteral("secretChatStateReady")) ? SecretChatStateReady :
        SecretChatStateUnknown;
}

TDLibWrapper::ChatMemberStatus TDLibWrapper::Group::chatMemberStatus() const
{
    const QString statusType(groupInfo.value(STATUS).toMap().value(_TYPE).toString());
    return statusType.isEmpty() ? ChatMemberStatusUnknown : chatMemberStatusFromString(statusType);
}

// ─── Forum Topics ────────────────────────────────────────────────────────────

void TDLibWrapper::switchChatList(int chatListType, int folderId)
{
    // chatListType: 0=main, 1=archive, 2=folder
    LOG("Switching chat list type" << chatListType << "folderId" << folderId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "loadChats");
    requestObject.insert("limit", INT_MAX);
    if (chatListType == 1) {
        QVariantMap chatList;
        chatList.insert(_TYPE, "chatListArchive");
        requestObject.insert("chat_list", chatList);
    } else if (chatListType == 2 && folderId > 0) {
        QVariantMap chatList;
        chatList.insert(_TYPE, "chatListFolder");
        chatList.insert("chat_folder_id", folderId);
        requestObject.insert("chat_list", chatList);
    } else {
        QVariantMap chatList;
        chatList.insert(_TYPE, "chatListMain");
        requestObject.insert("chat_list", chatList);
    }
    this->sendRequest(requestObject);
}

void TDLibWrapper::getForumTopics(qlonglong chatId, const QString &query, qlonglong offsetDate, qlonglong offsetMessageId, qlonglong offsetMessageThreadId, int limit)
{
    LOG("Getting forum topics for chat" << chatId << "query:" << query);
    this->pendingForumTopicsChatId = chatId;
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getForumTopics");
    requestObject.insert(CHAT_ID, chatId);
    if (!query.isEmpty()) {
        requestObject.insert("query", query);
    }
    requestObject.insert("offset_date", offsetDate);
    requestObject.insert("offset_message_id", offsetMessageId);
    requestObject.insert("offset_forum_topic_id", offsetMessageThreadId);
    // Compatibilità con versioni TDLib che usano ancora message_thread_id
    requestObject.insert("offset_message_thread_id", offsetMessageThreadId);
    requestObject.insert("limit", limit);
    this->sendRequest(requestObject);
}

void TDLibWrapper::getForumTopic(qlonglong chatId, int forumTopicId)
{
        QVariantMap requestObject;
    requestObject.insert(_TYPE, "getForumTopic");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert("forum_topic_id", forumTopicId);
    // Compatibilità con versioni TDLib che usano ancora message_thread_id
    requestObject.insert("message_thread_id", forumTopicId);
    requestObject.insert(_EXTRA, QString("getForumTopic:%1:%2").arg(chatId).arg(forumTopicId));
    this->sendRequest(requestObject);
}

void TDLibWrapper::getMessageThreadHistory(qlonglong chatId, qlonglong messageThreadId, qlonglong fromMessageId, int offset, int limit)
{
        QVariantMap requestObject;
    if (messageThreadId == 1) {
        // Il topic General non supporta getMessageThreadHistory
        requestObject.insert(_TYPE, "getChatHistory");
        requestObject.insert(CHAT_ID, chatId);
        requestObject.insert("from_message_id", fromMessageId);
        requestObject.insert("offset", fromMessageId == 0 ? 0 : offset);
        requestObject.insert("limit", limit);
        requestObject.insert("only_local", false);
    } else {
        // getMessageThreadHistory: message_id è l'anchor nel thread
        requestObject.insert(_TYPE, "getMessageThreadHistory");
        requestObject.insert(CHAT_ID, chatId);
        requestObject.insert("message_id", messageThreadId);
        requestObject.insert("from_message_id", fromMessageId);
        requestObject.insert("offset", fromMessageId == 0 ? 0 : offset);
        requestObject.insert("limit", limit);
    }
    this->sendRequest(requestObject);
}

void TDLibWrapper::setCurrentMessageThreadId(qlonglong threadId)
{
    LOG("Setting current message thread ID:" << threadId);
    this->currentMessageThreadId = threadId;
}

void TDLibWrapper::setPendingScheduledSendDate(int sendDate)
{
    this->pendingScheduledSendDate = sendDate > 0 ? sendDate : 0;
}

void TDLibWrapper::getChatScheduledMessages(qlonglong chatId)
{
    LOG("Get chat scheduled messages" << chatId);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "getChatScheduledMessages");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert(_EXTRA, QString("getChatScheduledMessages:%1").arg(chatId));
    this->sendRequest(requestObject);
}

void TDLibWrapper::editMessageSchedulingState(qlonglong chatId, qlonglong messageId, int sendDate)
{
    LOG("Edit message scheduling state" << chatId << messageId << "sendDate:" << sendDate);
    QVariantMap requestObject;
    requestObject.insert(_TYPE, "editMessageSchedulingState");
    requestObject.insert(CHAT_ID, chatId);
    requestObject.insert(MESSAGE_ID, messageId);
    if (sendDate > 0) {
        QVariantMap state;
        state.insert(_TYPE, "messageSchedulingStateSendAtDate");
        state.insert("send_date", sendDate);
        requestObject.insert("scheduling_state", state);
    }
    this->sendRequest(requestObject);
}

qlonglong TDLibWrapper::getCurrentMessageThreadId() const
{
    return this->currentMessageThreadId;
}

void TDLibWrapper::setCurrentChatIsForum(bool isForum)
{
    this->currentChatIsForum = isForum;
}

void TDLibWrapper::handleForumTopicsReceived(qlonglong, const QVariantList &topics, int totalCount, qlonglong nextOffsetDate, qlonglong nextOffsetMessageId, qlonglong nextOffsetMessageThreadId)
{
    // Il receiver non ha il chatId dalla risposta TDLib - lo aggiungiamo qui
    LOG("Forwarding forum topics for chat" << pendingForumTopicsChatId << "count:" << totalCount);
    emit forumTopicsReceived(pendingForumTopicsChatId, topics, totalCount, nextOffsetDate, nextOffsetMessageId, nextOffsetMessageThreadId);
}
