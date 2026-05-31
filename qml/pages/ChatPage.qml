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
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import Nemo.Thumbnailer 1.0
import WerkWolf.RooTelegram 1.0
import "../components"
import "../js/debug.js" as Debug
import "../js/twemoji.js" as Emoji
import "../js/functions.js" as Functions

Page {
    id: chatPage
    allowedOrientations: Orientation.All
    backNavigation: !stickerPickerLoader.active

    property bool loading: true;
    property bool isInitialized: false;
    readonly property int myUserId: tdLibWrapper.getUserInformation().id;
    property var chatInformation;
    property var secretChatDetails;
    property alias chatPicture: chatPictureThumbnail.photoData
    property bool isPrivateChat: false;
    property bool isSecretChat: false;
    property bool isSecretChatReady: false;
    property bool isBasicGroup: false;
    property bool isSuperGroup: false;
    property bool isChannel: false;
    property bool isDeletedUser: false;
    property bool containsSponsoredMessages: false;
    property var chatPartnerInformation;
    property var botInformation;
    property var chatGroupInformation;
    property int chatOnlineMemberCount: 0;
    property var emojiProposals;
    property bool iterativeInitialization: false;
    property var messageToShow;
    property string messageIdToShow;
    property string messageIdToScrollTo;
    readonly property bool userIsMember: ((isPrivateChat || isSecretChat) && chatInformation["@type"]) || // should be optimized
                                (isBasicGroup || isSuperGroup) && (
                                    (chatGroupInformation.status["@type"] === "chatMemberStatusMember")
                                    || (chatGroupInformation.status["@type"] === "chatMemberStatusAdministrator")
                                    || (chatGroupInformation.status["@type"] === "chatMemberStatusRestricted" && chatGroupInformation.status.is_member)
                                    || (chatGroupInformation.status["@type"] === "chatMemberStatusCreator" && chatGroupInformation.status.is_member)
                                    )
    property var selectedMessages: []
    readonly property bool isSelecting: selectedMessages.length > 0
    // Testo selezionato nel singolo messaggio attivo (popolato dal delegate
    // MessageListViewItem); guida l'icona "copia testo selezionato" nella barra azioni.
    property string activeSelectedText: ""
    onSelectedMessagesChanged: {
        // Al cambio della selezione, azzera: il delegate ripopola se c'è una selezione di testo.
        activeSelectedText = "";
    }
    readonly property bool canSendMessages: hasSendPrivilege("can_send_basic_messages")
    property bool doSendBotStartMessage
    property string sendBotStartMessageParameter
    property var messageThreadId: 0
    // Messaggi ricevuti: traduci nella lingua di sistema del telefono (per capirli)
    property string translateTargetLanguage: Qt.locale().name.substring(0, 2) || "en"
    // Testo da inviare: traduci sempre in inglese (per i gruppi internazionali)
    property string translateOutgoingLanguage: "en"
    property var topicLastMessageId: 0
    property var currentTopicInfo: null
    property var pinnedMessagesByThread: ({})
    property var availableReactions
    property var pendingSharedResources: []
    readonly property bool canManageJoinRequests: !!(userIsMember
                                                  && isSuperGroup
                                                  && chatGroupInformation
                                                  && chatGroupInformation.status
                                                  && (chatGroupInformation.status["@type"] === "chatMemberStatusCreator"
                                                      || chatGroupInformation.status.can_invite_users
                                                      || (chatGroupInformation.status.rights && chatGroupInformation.status.rights.can_invite_users)))
    readonly property int pendingJoinRequestsCount: {
        var pendingJoinRequests = (chatInformation && chatInformation.pending_join_requests) ? chatInformation.pending_join_requests : null;
        if (!pendingJoinRequests) {
            return 0;
        }
        var count = Number(pendingJoinRequests.total_count);
        if (isNaN(count) || count < 0) {
            return 0;
        }
        return count;
    }
    readonly property bool showJoinRequestsBanner: canManageJoinRequests
                                                   && pendingJoinRequestsCount > 0
                                                   && chatOverviewItem.visible
                                                   && !chatPage.isSelecting
    signal resetElements()
    signal elementSelected(int elementIndex)
    signal navigatedTo(int targetIndex)

    onMessageThreadIdChanged: {
        resolvePinnedMessageFromCache();
        schedulePinnedMessagesRefresh();
    }

    states: [
        State {
            name: "selectMessages"
            when: isSelecting
            PropertyChanges {
                target: chatNameText
                text: qsTr("Select Messages")
            }
            PropertyChanges {
                target: chatStatusText
                text: qsTr("%Ln messages selected", "number of messages selected", chatPage.selectedMessages.length)
            }
            PropertyChanges {
                target: newMessageTextField
                focus: false
            }
        }

    ]

    function toggleMessageSelection(message) {
        var selectionArray = selectedMessages;
        var foundIndex = -1
        if(selectionArray.length > 0) {
            for(var i = 0; i < selectionArray.length; i += 1) {
                if(selectionArray[i].id === message.id) {
                    foundIndex = i;
                    continue;
                }
            }
        }
        if(foundIndex > -1) {
            selectionArray.splice(foundIndex, 1);
        } else {
            selectionArray.push(message);
        }
        selectedMessages = selectionArray;
    }

    function updateChatPartnerStatusText() {
        if (chatPage.isSelecting) {
            return
        }
        var statusText = Functions.getChatPartnerStatusText(chatPartnerInformation.status['@type'], chatPartnerInformation.status.was_online);
        if (chatPage.secretChatDetails) {
            var secretChatStatus = Functions.getSecretChatStatus(chatPage.secretChatDetails);
            if (statusText && secretChatStatus) {
                statusText += " - ";
            }
            if (secretChatStatus) {
                statusText += secretChatStatus;
            }
        }
        if (statusText) {
            chatStatusText.text = statusText;
        }
        if (chatPartnerInformation.type['@type'] === "userTypeDeleted") {
            chatNameText.text = qsTr("Deleted User");
            chatPage.isDeletedUser = true;
        }
    }

    function updateGroupStatusText() {
        if (chatPage.isSelecting) {
            return
        }
        if (chatOnlineMemberCount > 0) {
            chatStatusText.text = qsTr("%1, %2", "combination of '[x members], [y online]', which are separate translations")
                .arg(qsTr("%1 members", "", chatGroupInformation.member_count)
                    .arg(Functions.getShortenedCount(chatGroupInformation.member_count)))
                .arg(qsTr("%1 online", "", chatOnlineMemberCount)
                    .arg(Functions.getShortenedCount(chatOnlineMemberCount)));
        } else {
            if (isChannel) {
                chatStatusText.text = qsTr("%1 subscribers", "", chatGroupInformation.member_count).arg(Functions.getShortenedCount(chatGroupInformation.member_count));
            } else {
                chatStatusText.text = qsTr("%1 members", "", chatGroupInformation.member_count).arg(Functions.getShortenedCount(chatGroupInformation.member_count));
            }
        }
        joinLeaveChatMenuItem.text = chatPage.userIsMember ? qsTr("Leave Chat") : qsTr("Join Chat");
    }

    function setPendingJoinRequests(pendingJoinRequests) {
        if (!chatInformation) {
            return;
        }
        var updatedChatInformation = {};
        for (var key in chatInformation) {
            updatedChatInformation[key] = chatInformation[key];
        }
        updatedChatInformation.pending_join_requests = pendingJoinRequests || ({});
        chatInformation = updatedChatInformation;
    }

    function decrementPendingJoinRequestForUser(userId) {
        var pendingJoinRequests = (chatInformation && chatInformation.pending_join_requests) ? chatInformation.pending_join_requests : ({});
        var userIds = pendingJoinRequests.user_ids ? pendingJoinRequests.user_ids.slice(0) : [];
        var processedUserId = Number(userId);
        if (!isNaN(processedUserId) && processedUserId > 0) {
            for (var i = userIds.length - 1; i >= 0; i--) {
                if (Number(userIds[i]) === processedUserId) {
                    userIds.splice(i, 1);
                }
            }
        }
        var totalCount = Number(pendingJoinRequests.total_count);
        if (isNaN(totalCount) || totalCount < 0) {
            totalCount = 0;
        } else if (totalCount > 0) {
            totalCount -= 1;
        }
        if (userIds.length > 0) {
            totalCount = Math.max(totalCount, userIds.length);
        }
        pendingJoinRequests.user_ids = userIds;
        pendingJoinRequests.total_count = totalCount;
        setPendingJoinRequests(pendingJoinRequests);
    }

    function requestPinMessage(message) {
        if (!message || !chatInformation || typeof message.id === "undefined") {
            return;
        }
        if (chatPage.isPrivateChat && !chatPage.isSecretChat
                && chatInformation.id !== chatPage.myUserId) {
            var partnerName = chatPartnerInformation ? Functions.getUserName(chatPartnerInformation) : "";
            var dialog = pageStack.push(Qt.resolvedUrl("PinScopeDialog.qml"), {
                "partnerName": partnerName
            });
            dialog.accepted.connect(function() {
                tdLibWrapper.pinMessage(chatInformation.id, message.id, false, dialog.selectedScope === "self");
            });
            return;
        }
        tdLibWrapper.pinMessage(chatInformation.id, message.id, false, false);
    }

    function openJoinRequestsPage() {
        if (!chatInformation || !chatInformation.id) {
            return;
        }
        pageStack.push(Qt.resolvedUrl("../pages/ChatJoinRequestsPage.qml"), {
            "chatId": chatInformation.id,
            "chatTitle": chatInformation.title
        });
    }

    function refreshChatInformationFromModel() {
        var previousPendingJoinRequests = chatInformation ? chatInformation.pending_join_requests : null;
        var latestChatInformation = chatModel.getChatInformation();
        if (!latestChatInformation) {
            return;
        }
        chatInformation = latestChatInformation;
        if ((!chatInformation.pending_join_requests || typeof chatInformation.pending_join_requests.total_count === "undefined") && previousPendingJoinRequests) {
            var updatedChatInformation = {};
            for (var key in chatInformation) {
                updatedChatInformation[key] = chatInformation[key];
            }
            updatedChatInformation.pending_join_requests = previousPendingJoinRequests;
            chatInformation = updatedChatInformation;
        }
    }

    function initializePage() {
        Debug.log("[ChatPage] Initializing chat page...");
        chatView.currentIndex = -1;
        chatView.lastReadSentIndex = -1;
        var chatType = chatInformation.type['@type'];
        isPrivateChat = chatType === "chatTypePrivate";
        isSecretChat = chatType === "chatTypeSecret";
        isBasicGroup = ( chatType === "chatTypeBasicGroup" );
        isSuperGroup = ( chatType === "chatTypeSupergroup" );
        if (isPrivateChat || isSecretChat) {
            chatPartnerInformation = tdLibWrapper.getUserInformation(chatInformation.type.user_id);
            updateChatPartnerStatusText();
            if (isSecretChat) {
                tdLibWrapper.getSecretChat(chatInformation.type.secret_chat_id);
            }
            if(chatPartnerInformation.type["@type"] === "userTypeBot") {
                tdLibWrapper.getUserFullInfo(chatPartnerInformation.id)
            }
        }
        else if (isBasicGroup) {
            chatGroupInformation = tdLibWrapper.getBasicGroup(chatInformation.type.basic_group_id);
            updateGroupStatusText();
        }
        else if (isSuperGroup) {
            chatGroupInformation = tdLibWrapper.getSuperGroup(chatInformation.type.supergroup_id);
            isChannel = chatGroupInformation.is_channel;
            updateGroupStatusText();
        }
        if (stickerManager.needsReload()) {
            Debug.log("[ChatPage] Recent stickers will be reloaded!");
            tdLibWrapper.getRecentStickers();
            stickerManager.setNeedsReload(false);
        }
        chatPage.pinnedMessagesByThread = ({});
        pinnedMessageItem.pinnedMessages = [];
        pinnedMessageItem.pinnedMessage = undefined;
        tdLibWrapper.getChatPinnedMessage(chatInformation.id);
        schedulePinnedMessagesRefresh();
        tdLibWrapper.toggleChatIsMarkedAsUnread(chatInformation.id, false);
        availableReactions = tdLibWrapper.getChatReactions(chatInformation.id);
        var cachedChatInformation = tdLibWrapper.getChat(chatInformation.id.toString());
        if (cachedChatInformation && cachedChatInformation.pending_join_requests) {
            setPendingJoinRequests(cachedChatInformation.pending_join_requests);
        }
        // Verifica autoritativa via TDLib: se la cache mostra richieste
        // pendenti ma sono state già evase da un altro client, il banner
        // resterebbe visibile a vuoto. Il timer dà un istante al resto
        // dell'init prima di interrogare TDLib.
        joinRequestsVerifyTimer.restart();
    }

    Timer {
        id: joinRequestsVerifyTimer
        interval: 250
        repeat: false
        onTriggered: {
            if (!chatInformation || !chatInformation.id) {
                return;
            }
            if (!chatPage.canManageJoinRequests) {
                return;
            }
            if (chatPage.pendingJoinRequestsCount <= 0) {
                return;
            }
            tdLibWrapper.getChatJoinRequests(chatInformation.id, "", "", ({}), 1);
        }
    }

    function getMessageStatusText(message, listItemIndex, lastReadSentIndex, useElapsed) {
        Debug.log("Last read sent index: " + lastReadSentIndex);
        var messageStatusSuffix = "";
        if(!message) {
            return "";
        }

        if (message['@type'] === "sponsoredMessage") {
            return qsTr("Sponsored Message");
        }

        if (message.edit_date > 0) {
            messageStatusSuffix += " - " + qsTr("edited");
        }

        if (chatPage.myUserId === message.sender_id.user_id) {
            messageStatusSuffix += "&nbsp;&nbsp;"
            if (listItemIndex <= lastReadSentIndex) {
                // Read by other party
                messageStatusSuffix += Emoji.emojify("✅", Theme.fontSizeTiny);
            } else {
                // Not yet read by other party
                if (message.sending_state) {
                    if (message.sending_state['@type'] === "messageSendingStatePending") {
                        messageStatusSuffix += Emoji.emojify("🕙", Theme.fontSizeTiny);
                    } else {
                        // Sending failed...
                        messageStatusSuffix += Emoji.emojify("❌", Theme.fontSizeTiny);
                    }
                } else {
                    messageStatusSuffix += Emoji.emojify("☑️", Theme.fontSizeTiny);
                }
            }
        }
        return ( useElapsed ? Functions.getDateTimeElapsed(message.date) : Functions.getDateTimeTranslated(message.date) ) + messageStatusSuffix;
    }

    function clearAttachmentPreviewRow() {
        attachmentPreviewRow.isPicture = false;
        attachmentPreviewRow.isVideo = false;
        attachmentPreviewRow.isDocument = false;
        attachmentPreviewRow.isVoiceNote = false;
        attachmentPreviewRow.isLocation = false;
        attachmentPreviewRow.fileProperties = null;
        attachmentPreviewRow.locationData = null;
        attachmentPreviewRow.attachmentDescription = "";
        attachmentPreviewRow.imagePaths = [];
        rootelegramUtils.stopGeoLocationUpdates();
    }

    function controlSendButton() {
        var hasContent = newMessageTextField.text.length !== 0
                || attachmentPreviewRow.isPicture
                || attachmentPreviewRow.isDocument
                || attachmentPreviewRow.isVideo
                || attachmentPreviewRow.isVoiceNote
                || attachmentPreviewRow.isLocation;
        // Manteniamo il bottone sempre enabled per intercettare il long-press
        // (apertura ScheduleMessageDialog per gestire scheduled esistenti),
        // ma riduciamo l'opacità a 0.4 quando vuoto come visual feedback.
        newMessageSendButton.enabled = true;
        newMessageSendButton.opacity = hasContent ? 1.0 : 0.4;
        newMessageSendButton.hasContent = hasContent;
    }

    function sendMessage(sendDate) {
        var customEmojiEntities = getComposerCustomEmojiEntitiesForSend();
        tdLibWrapper.setPendingScheduledSendDate(sendDate ? Math.floor(sendDate) : 0);
        if (newMessageColumn.editMessageId !== "0") {
            if (customEmojiEntities.length > 0) {
                tdLibWrapper.editMessageTextWithCustomEmoji(chatInformation.id, newMessageColumn.editMessageId, newMessageTextField.text, customEmojiEntities);
            } else {
                tdLibWrapper.editMessageText(chatInformation.id, newMessageColumn.editMessageId, newMessageTextField.text);
            }
        } else {
            if (attachmentPreviewRow.visible) {
                if (attachmentPreviewRow.isPicture) {
                    if (attachmentPreviewRow.imagePaths && attachmentPreviewRow.imagePaths.length > 1) {
                        tdLibWrapper.sendPhotoAlbum(chatInformation.id, attachmentPreviewRow.imagePaths, newMessageTextField.text, newMessageColumn.replyToMessageId);
                    } else {
                        tdLibWrapper.sendPhotoMessage(chatInformation.id, attachmentPreviewRow.fileProperties.filePath, newMessageTextField.text, newMessageColumn.replyToMessageId);
                    }
                }
                if (attachmentPreviewRow.isVideo) {
                    tdLibWrapper.sendVideoMessage(chatInformation.id, attachmentPreviewRow.fileProperties.filePath, newMessageTextField.text, newMessageColumn.replyToMessageId);
                }
                if (attachmentPreviewRow.isDocument) {
                    tdLibWrapper.sendDocumentMessage(chatInformation.id, attachmentPreviewRow.fileProperties.filePath, newMessageTextField.text, newMessageColumn.replyToMessageId);
                }
                if (attachmentPreviewRow.isVoiceNote) {
                    tdLibWrapper.sendVoiceNoteMessage(chatInformation.id, rootelegramUtils.voiceNotePath(), newMessageTextField.text, newMessageColumn.replyToMessageId);
                }
                if (attachmentPreviewRow.isLocation) {
                    tdLibWrapper.sendLocationMessage(chatInformation.id, attachmentPreviewRow.locationData.latitude, attachmentPreviewRow.locationData.longitude, attachmentPreviewRow.locationData.horizontalAccuracy, newMessageColumn.replyToMessageId);
                }
                clearAttachmentPreviewRow();
            } else {
                if (customEmojiEntities.length > 0) {
                    tdLibWrapper.sendTextMessageWithCustomEmoji(chatInformation.id, newMessageTextField.text, customEmojiEntities, newMessageColumn.replyToMessageId);
                } else {
                    tdLibWrapper.sendTextMessage(chatInformation.id, newMessageTextField.text, newMessageColumn.replyToMessageId);
                }
            }

            if(appSettings.focusTextAreaAfterSend) {
                lostFocusTimer.start();
            }
        }
        controlSendButton();
        newMessageInReplyToRow.inReplyToMessage = null;
        newMessageColumn.editMessageId = "0";
        rootelegramUtils.stopGeoLocationUpdates();
        attachmentOptionsFlickable.isNeeded = false;
        newMessageColumn.quickEmojiPickerVisible = false;
        newMessageColumn.quickPremiumEmojiPickerVisible = false;
        newMessageColumn.customEmojiEntities = [];
        newMessageColumn.previousComposerText = newMessageTextField.text || "";
    }

    function getWordBoundaries(text, cursorPosition) {
        var wordBoundaries = { beginIndex : 0, endIndex : text.length};
        var currentIndex = 0;
        for (currentIndex = (cursorPosition - 1); currentIndex > 0; currentIndex--) {
            if (text.charAt(currentIndex) === ' ') {
                wordBoundaries.beginIndex = currentIndex + 1;
                break;
            }
        }
        for (currentIndex = cursorPosition; currentIndex < text.length; currentIndex++) {
            if (text.charAt(currentIndex) === ' ') {
                wordBoundaries.endIndex = currentIndex;
                break;
            }
        }
        return wordBoundaries;
    }

    function handleMessageTextReplacement(text, cursorPosition) {
        if(!newMessageTextField.focus) {
            return;
        }

        var wordBoundaries = getWordBoundaries(text, cursorPosition);

        var currentWord = text.substring(wordBoundaries.beginIndex, wordBoundaries.endIndex);
        if (currentWord.length > 1 && currentWord.charAt(0) === ':') {
            tdLibWrapper.searchEmoji(currentWord.substring(1));
        } else {
            chatPage.emojiProposals = null;
        }
        if (currentWord.length > 1 && currentWord.charAt(0) === '@') {
            knownUsersRepeater.model = knownUsersProxyModel;
            knownUsersProxyModel.setFilterWildcard("*" + currentWord.substring(1) + "*");
        } else {
            knownUsersRepeater.model = undefined;
        }

    }

    function replaceMessageText(text, cursorPosition, newText) {
        var wordBoundaries = getWordBoundaries(text, cursorPosition);
        var newCompleteText = text.substring(0, wordBoundaries.beginIndex) + newText + " " + text.substring(wordBoundaries.endIndex);
        var newIndex = wordBoundaries.beginIndex + newText.length + 1;
        newMessageTextField.text = newCompleteText;
        newMessageTextField.cursorPosition = newIndex;
        lostFocusTimer.start();
    }

    function insertTextAtCursor(newText) {
        var currentText = newMessageTextField.text || "";
        var position = Number(newMessageTextField.cursorPosition);
        if (position < 0 || position > currentText.length) {
            position = currentText.length;
        }
        newMessageTextField.text = currentText.substring(0, position) + newText + currentText.substring(position);
        newMessageTextField.cursorPosition = position + newText.length;
        lostFocusTimer.start();
    }

    function extractCustomEmojiEntitiesFromFormattedText(formattedText) {
        var extractedEntities = [];
        if (!formattedText || !formattedText.entities) {
            return extractedEntities;
        }
        for (var i = 0; i < formattedText.entities.length; i++) {
            var entity = formattedText.entities[i];
            if (!entity || entity['@type'] !== "textEntity" || !entity.type || entity.type['@type'] !== "textEntityTypeCustomEmoji") {
                continue;
            }
            var customEmojiId = entity.type.custom_emoji_id ? entity.type.custom_emoji_id.toString() : "";
            var offset = Number(entity.offset);
            var length = Number(entity.length);
            if (customEmojiId !== "" && !isNaN(offset) && !isNaN(length) && offset >= 0 && length > 0) {
                extractedEntities.push({ "offset": offset, "length": length, "custom_emoji_id": customEmojiId });
            }
        }
        extractedEntities.sort(function(a, b) { return a.offset - b.offset; });
        return extractedEntities;
    }

    function getComposerCustomEmojiEntitiesForSend() {
        var messageText = newMessageTextField.text || "";
        var result = [];
        var customEmojiEntities = newMessageColumn.customEmojiEntities || [];
        for (var i = 0; i < customEmojiEntities.length; i++) {
            var entity = customEmojiEntities[i];
            if (!entity) {
                continue;
            }
            var customEmojiId = entity.custom_emoji_id ? entity.custom_emoji_id.toString() : "";
            var offset = Number(entity.offset);
            var length = Number(entity.length);
            if (customEmojiId === "" || isNaN(offset) || isNaN(length)) {
                continue;
            }
            if (offset < 0 || length <= 0 || (offset + length) > messageText.length) {
                continue;
            }
            result.push({ "offset": offset, "length": length, "custom_emoji_id": customEmojiId });
        }
        result.sort(function(a, b) { return a.offset - b.offset; });
        return result;
    }

    function adjustComposerCustomEmojiEntities(oldText, newText) {
        if (newMessageColumn.suspendCustomEmojiTracking) {
            return;
        }
        var previousText = oldText || "";
        var currentText = newText || "";
        if (previousText === currentText) {
            return;
        }
        var entities = newMessageColumn.customEmojiEntities || [];
        if (entities.length === 0) {
            return;
        }

        var prefixLength = 0;
        while (prefixLength < previousText.length
               && prefixLength < currentText.length
               && previousText.charAt(prefixLength) === currentText.charAt(prefixLength)) {
            prefixLength++;
        }

        var previousSuffixIndex = previousText.length - 1;
        var currentSuffixIndex = currentText.length - 1;
        while (previousSuffixIndex >= prefixLength
               && currentSuffixIndex >= prefixLength
               && previousText.charAt(previousSuffixIndex) === currentText.charAt(currentSuffixIndex)) {
            previousSuffixIndex--;
            currentSuffixIndex--;
        }

        var replacedOldLength = Math.max(0, previousSuffixIndex - prefixLength + 1);
        var insertedLength = Math.max(0, currentSuffixIndex - prefixLength + 1);
        var offsetDelta = insertedLength - replacedOldLength;
        var replacedEndInOld = prefixLength + replacedOldLength;

        var adjustedEntities = [];
        for (var i = 0; i < entities.length; i++) {
            var entity = entities[i];
            if (!entity || !entity.custom_emoji_id) {
                continue;
            }
            var offset = Number(entity.offset);
            var length = Number(entity.length);
            if (isNaN(offset) || isNaN(length) || length <= 0) {
                continue;
            }
            var entityEnd = offset + length;
            if (entityEnd <= prefixLength) {
                adjustedEntities.push({ "offset": offset, "length": length, "custom_emoji_id": entity.custom_emoji_id });
            } else if (offset >= replacedEndInOld) {
                adjustedEntities.push({ "offset": offset + offsetDelta, "length": length, "custom_emoji_id": entity.custom_emoji_id });
            }
        }
        adjustedEntities.sort(function(a, b) { return a.offset - b.offset; });
        newMessageColumn.customEmojiEntities = adjustedEntities;
    }

    function insertCustomEmojiAtCursor(customEmojiId, fallbackEmoji) {
        if (!customEmojiId || customEmojiId === "") {
            return;
        }
        var customEmojiFallback = fallbackEmoji && fallbackEmoji.length > 0 ? fallbackEmoji : tdLibWrapper.getCustomEmojiFallback(customEmojiId);
        if (!customEmojiFallback || customEmojiFallback.length === 0) {
            customEmojiFallback = "⬜";
        }
        var currentText = newMessageTextField.text || "";
        var cursorPosition = Number(newMessageTextField.cursorPosition);
        if (isNaN(cursorPosition) || cursorPosition < 0 || cursorPosition > currentText.length) {
            cursorPosition = currentText.length;
        }

        var shiftedEntities = [];
        var customEmojiEntities = newMessageColumn.customEmojiEntities || [];
        for (var i = 0; i < customEmojiEntities.length; i++) {
            var entity = customEmojiEntities[i];
            if (!entity || !entity.custom_emoji_id) {
                continue;
            }
            var offset = Number(entity.offset);
            var length = Number(entity.length);
            if (isNaN(offset) || isNaN(length) || length <= 0) {
                continue;
            }
            if (offset >= cursorPosition) {
                offset += customEmojiFallback.length;
            }
            shiftedEntities.push({ "offset": offset, "length": length, "custom_emoji_id": entity.custom_emoji_id });
        }
        shiftedEntities.push({ "offset": cursorPosition, "length": customEmojiFallback.length, "custom_emoji_id": customEmojiId });
        shiftedEntities.sort(function(a, b) { return a.offset - b.offset; });

        newMessageColumn.suspendCustomEmojiTracking = true;
        newMessageTextField.text = currentText.substring(0, cursorPosition) + customEmojiFallback + currentText.substring(cursorPosition);
        newMessageTextField.cursorPosition = cursorPosition + customEmojiFallback.length;
        newMessageColumn.suspendCustomEmojiTracking = false;

        newMessageColumn.customEmojiEntities = shiftedEntities;
        newMessageColumn.previousComposerText = newMessageTextField.text || "";
        tdLibWrapper.ensureCustomEmoji(customEmojiId);
        controlSendButton();
        lostFocusTimer.start();
    }

    function beginMessageEdit(messageId, message) {
        newMessageColumn.editMessageId = messageId;
        newMessageInReplyToRow.inReplyToMessage = null;
        var editText = Functions.getMessageText(message, false, chatPage.myUserId, true);
        newMessageColumn.suspendCustomEmojiTracking = true;
        newMessageTextField.text = editText;
        newMessageTextField.cursorPosition = editText.length;
        newMessageColumn.suspendCustomEmojiTracking = false;
        newMessageColumn.customEmojiEntities = extractCustomEmojiEntitiesFromFormattedText(message && message.content ? message.content.text : null);
        newMessageColumn.previousComposerText = newMessageTextField.text || "";
        newMessageTextField.focus = true;
        controlSendButton();
    }

    // translateText di Telegram restituisce la formattazione come tag HTML
    // (<b>, <i>, ...). Li riconvertiamo nei marcatori markdown del composer
    // (**, __, ++, ~~, `, ||) così il messaggio tradotto resta formattabile/inviabile.
    function translatedHtmlToComposerMarkdown(html) {
        if (!html) return html;
        var s = html;
        s = s.replace(/<\/?(?:b|strong)>/gi, "**");
        s = s.replace(/<\/?(?:i|em)>/gi, "__");
        s = s.replace(/<\/?(?:u|ins)>/gi, "++");
        s = s.replace(/<\/?(?:s|strike|del)>/gi, "~~");
        s = s.replace(/<\/?(?:code|pre)>/gi, "`");
        s = s.replace(/<tg-spoiler>|<\/tg-spoiler>/gi, "||");
        s = s.replace(/<span[^>]*tg-spoiler[^>]*>|<\/span>/gi, "||");
        // Link: tieni solo il testo visibile
        s = s.replace(/<a\b[^>]*>([\s\S]*?)<\/a>/gi, "$1");
        // Rimuovi eventuali tag residui non gestiti
        s = s.replace(/<[^>]+>/g, "");
        // Unescape entità HTML (&amp; per ultimo)
        s = s.replace(/&lt;/g, "<").replace(/&gt;/g, ">")
             .replace(/&quot;/g, '"').replace(/&#0?39;/g, "'")
             .replace(/&amp;/g, "&");
        return s;
    }

    function applyInlineFormatting(prefix, suffix) {
        var currentText = newMessageTextField.text || "";
        var selectionStart = Number(newMessageTextField.selectionStart);
        var selectionEnd = Number(newMessageTextField.selectionEnd);
        var cursorPosition = Number(newMessageTextField.cursorPosition);
        if (isNaN(cursorPosition) || cursorPosition < 0) {
            cursorPosition = currentText.length;
        }
        if (cursorPosition > currentText.length) {
            cursorPosition = currentText.length;
        }
        if (isNaN(selectionStart) || selectionStart < 0) {
            selectionStart = cursorPosition;
        }
        if (isNaN(selectionEnd) || selectionEnd < 0) {
            selectionEnd = cursorPosition;
        }
        if (selectionStart > selectionEnd) {
            var tmp = selectionStart;
            selectionStart = selectionEnd;
            selectionEnd = tmp;
        }
        if (selectionStart === selectionEnd) {
            var insertion = prefix + suffix;
            newMessageTextField.text = currentText.substring(0, selectionStart) + insertion + currentText.substring(selectionEnd);
            newMessageTextField.cursorPosition = selectionStart + prefix.length;
        } else {
            var selectedText = currentText.substring(selectionStart, selectionEnd);
            var replacement = prefix + selectedText + suffix;
            newMessageTextField.text = currentText.substring(0, selectionStart) + replacement + currentText.substring(selectionEnd);
            var newSelectionStart = selectionStart + prefix.length;
            var newSelectionEnd = newSelectionStart + selectedText.length;
            if (typeof newMessageTextField.select === "function") {
                newMessageTextField.select(newSelectionStart, newSelectionEnd);
            } else {
                newMessageTextField.cursorPosition = newSelectionEnd;
            }
        }
        controlSendButton();
        lostFocusTimer.start();
    }

    function toQuotedBlock(rawText) {
        var sanitized = (rawText || "").replace(/\u2029/g, "\n").replace(/\r\n/g, "\n").trim();
        if (sanitized === "") {
            return "";
        }
        var lines = sanitized.split("\n");
        for (var i = 0; i < lines.length; i++) {
            lines[i] = "> " + lines[i];
        }
        return lines.join("\n");
    }

    function quoteSelectedText(message, selectedText) {
        var quotedBlock = toQuotedBlock(selectedText);
        if (quotedBlock === "") {
            return;
        }
        newMessageColumn.editMessageId = "0";
        newMessageInReplyToRow.inReplyToMessage = message;
        if (newMessageTextField.text && newMessageTextField.text.length > 0) {
            newMessageTextField.text = newMessageTextField.text + "\n\n" + quotedBlock + "\n";
        } else {
            newMessageTextField.text = quotedBlock + "\n";
        }
        newMessageTextField.cursorPosition = newMessageTextField.text.length;
        controlSendButton();
        lostFocusTimer.start();
    }

    function setMessageText(text, doSend) {
        if(doSend) {
            tdLibWrapper.sendTextMessage(chatInformation.id, text, "0");
        }
        else {
            newMessageColumn.customEmojiEntities = [];
            newMessageColumn.previousComposerText = text || "";
            newMessageTextField.text = text
            newMessageTextField.cursorPosition = text.length
            lostFocusTimer.start();
        }

    }

    function normalizeSharedFilePath(filePath) {
        if (!filePath) {
            return "";
        }
        var normalizedPath = filePath.toString();
        if (normalizedPath.indexOf("file://") === 0) {
            var encodedPath = normalizedPath.substring(7);
            try {
                normalizedPath = decodeURIComponent(encodedPath);
            } catch (error) {
                normalizedPath = encodedPath;
            }
        }
        return normalizedPath;
    }

    function getSharedFileName(filePath) {
        if (!filePath) {
            return "";
        }
        var slashIndex = filePath.lastIndexOf("/");
        if (slashIndex === -1 || slashIndex === (filePath.length - 1)) {
            return filePath;
        }
        return filePath.substring(slashIndex + 1);
    }

    function isSharedPicture(filePath) {
        return /\.(jpg|jpeg|png|gif|webp|bmp|heic|heif)$/i.test(filePath);
    }

    function isSharedVideo(filePath) {
        return /\.(mp4|m4v|mov|mkv|webm|avi|3gp|mpeg|mpg)$/i.test(filePath);
    }

    function prepareSharedAttachment(filePath) {
        var normalizedPath = normalizeSharedFilePath(filePath);
        if (normalizedPath === "") {
            return false;
        }
        clearAttachmentPreviewRow();
        attachmentPreviewRow.fileProperties = {
            filePath: normalizedPath,
            fileName: getSharedFileName(normalizedPath),
            mimeType: "",
            url: "file://" + encodeURI(normalizedPath)
        };
        if (isSharedPicture(normalizedPath)) {
            attachmentPreviewRow.isPicture = true;
        } else if (isSharedVideo(normalizedPath)) {
            attachmentPreviewRow.isVideo = true;
        } else {
            attachmentPreviewRow.isDocument = true;
        }
        return true;
    }

    function handleSharedResources(resources) {
        if (!resources || resources.length === 0) {
            return;
        }
        var sharedTextParts = [];
        var sharedFilePath = "";
        var extraFilesCount = 0;
        for (var i = 0; i < resources.length; i += 1) {
            var resource = resources[i];
            if (!resource || !resource.type) {
                continue;
            }
            if (resource.type === "text") {
                var textData = resource.data ? resource.data.toString().trim() : "";
                if (textData !== "") {
                    sharedTextParts.push(textData);
                }
            } else if (resource.type === "file") {
                var currentPath = resource.filePath ? resource.filePath.toString() : "";
                if (currentPath !== "") {
                    if (sharedFilePath === "") {
                        sharedFilePath = currentPath;
                    } else {
                        extraFilesCount += 1;
                    }
                }
            }
        }
        if (sharedTextParts.length > 0) {
            setMessageText(sharedTextParts.join("\n"), false);
        }
        if (sharedFilePath !== "") {
            if (prepareSharedAttachment(sharedFilePath) && extraFilesCount > 0) {
                appNotification.show(qsTr("Only the first shared file has been prepared."));
            }
        }
        controlSendButton();
    }

    function startForwardingMessages(messages) {
        var ids = Functions.getMessagesArrayIds(messages);
        var neededPermissions = Functions.getMessagesNeededForwardPermissions(messages);
        var chatId = chatInformation.id;
        pageStack.push(Qt.resolvedUrl("../pages/ChatSelectionPage.qml"), {
            myUserId: chatPage.myUserId,
            headerDescription: qsTr("Forward %Ln messages", "dialog header", ids.length),
            payload: {fromChatId: chatId, messageIds:ids, neededPermissions: neededPermissions},
            state: "forwardMessages"
        });
    }

    function forwardMessages(fromChatId, messageIds) {
        forwardMessagesTimer.fromChatId = fromChatId;
        forwardMessagesTimer.messageIds = messageIds;
        forwardMessagesTimer.start();
    }
    function hasSendPrivilege(privilege) {
        var groupStatus = chatGroupInformation ? chatGroupInformation.status : null
        var groupStatusType = groupStatus ? groupStatus["@type"] : null
        return chatPage.isPrivateChat
                    || (groupStatusType === "chatMemberStatusMember" && chatInformation.permissions[privilege])
                    || groupStatusType === "chatMemberStatusAdministrator"
                    || groupStatusType === "chatMemberStatusCreator"
                    || (groupStatusType === "chatMemberStatusRestricted" && groupStatus.permissions[privilege])
                    || (chatPage.isSecretChat && chatPage.isSecretChatReady)
    }
    function canPinMessages() {
        Debug.log("Can we pin messages?");
        if (chatPage.chatInformation && chatPage.chatInformation.id === chatPage.myUserId) {
            Debug.log("Saved Messages: Yes!");
            return true;
        }
        if (chatPage.isSecretChat) {
            Debug.log("Secret Chat: No!");
            return false;
        }
        if (chatPage.isPrivateChat) {
            Debug.log("Private Chat: Yes (con scelta per entrambi/solo me)!");
            return true;
        }
        var groupInfo = chatPage.chatGroupInformation || {};
        var status = groupInfo.status || {};
        var statusType = status["@type"] || "";
        var statusRights = status.rights || {};
        var chatPermissions = (chatPage.chatInformation && chatPage.chatInformation.permissions) ? chatPage.chatInformation.permissions : {};

        if (statusType === "chatMemberStatusCreator") {
            Debug.log("Creator of this chat: Yes!");
            return true;
        }
        if (chatPermissions.can_pin_messages === true) {
            Debug.log("All people can pin: Yes!");
            return true;
        }
        if (statusType === "chatMemberStatusAdministrator") {
            Debug.log("Admin with privileges? ", status.can_pin_messages, statusRights.can_pin_messages);
            return status.can_pin_messages === true || statusRights.can_pin_messages === true;
        }
        if (statusType === "chatMemberStatusRestricted") {
            var restrictedPermissions = status.permissions || {};
            Debug.log("Restricted, but can pin messages? ", restrictedPermissions.can_pin_messages);
            return restrictedPermissions.can_pin_messages === true;
        }
        Debug.log("Something else: No!");
        return false;
    }
    function getMessageForumTopicId(message) {
        if (!message) {
            return "0";
        }
        var topicId = "0";
        if (message.topic_id && typeof message.topic_id.forum_topic_id !== "undefined") {
            topicId = String(message.topic_id.forum_topic_id);
        }
        if ((topicId === "0" || topicId === "") && typeof message.message_thread_id !== "undefined") {
            topicId = String(message.message_thread_id);
        }
        return topicId || "0";
    }

    function pinnedMessageMatchesCurrentThread(message) {
        if (!message || !message.is_pinned) {
            return false;
        }
        var currentThreadId = String(chatPage.messageThreadId || 0);
        if (currentThreadId === "0") {
            return true;
        }
        var pinnedThreadId = getMessageForumTopicId(message);
        if (currentThreadId === "1") {
            return pinnedThreadId === "0" || pinnedThreadId === "1";
        }
        return pinnedThreadId === currentThreadId;
    }

    function pinnedMessageListContains(messageId) {
        if (!messageId) {
            return false;
        }
        var messages = pinnedMessageItem.pinnedMessages || [];
        for (var i = 0; i < messages.length; i++) {
            var message = messages[i];
            if (message && String(message.id) === String(messageId)) {
                return true;
            }
        }
        return false;
    }

    function pinnedMessagesForThread(threadId) {
        var messages = chatPage.pinnedMessagesByThread[String(threadId)];
        var filtered = [];
        if (!messages || !messages.length) {
            return [];
        }
        for (var i = 0; i < messages.length; i++) {
            var message = messages[i];
            if (message && pinnedMessageMatchesCurrentThread(message)) {
                filtered.push(message);
            }
        }
        return filtered;
    }

    function resolvePinnedMessageFromCache() {
        var currentThreadId = String(chatPage.messageThreadId || 0);
        var selectedMessages = pinnedMessagesForThread(currentThreadId);
        if ((!selectedMessages || !selectedMessages.length) && currentThreadId === "1") {
            selectedMessages = pinnedMessagesForThread("0");
        }
        pinnedMessageItem.pinnedMessages = selectedMessages || [];
    }

    function requestPinnedMessagesRefresh() {
        if (!chatInformation || !chatInformation.id) {
            return;
        }
        var threadId = Number(chatPage.messageThreadId || 0);
        tdLibWrapper.getPinnedMessages(chatInformation.id, 0, 0, 50);
        if (threadId > 0) {
            tdLibWrapper.getPinnedMessages(chatInformation.id, threadId, 0, 50);
        }
    }

    function schedulePinnedMessagesRefresh() {
        pinnedMessagesRefreshTimer.restart();
    }

    function resetFocus() {
        if (searchInChatField.text === "") {
            chatOverviewItem.visible = true;
        }
        searchInChatField.focus = false;
        chatPage.focus = true;
    }
    function mapSourceIndexToProxyIndex(sourceIndex) {
        if (sourceIndex < 0) {
            return -1;
        }
        var proxyIndex = chatProxyModel.mapRowFromSource(sourceIndex, -1);
        if (proxyIndex !== -1) {
            return proxyIndex;
        }

        var sourceMessage = chatModel.getMessage(sourceIndex);
        var albumId = sourceMessage && sourceMessage.media_album_id ? sourceMessage.media_album_id : "0";
        if (String(albumId) === "0") {
            return -1;
        }

        var albumMessageIds = chatModel.getMessageIdsForAlbum(albumId);
        for (var i = 0; i < albumMessageIds.length; i++) {
            var albumSourceIndex = chatModel.getMessageIndex(albumMessageIds[i]);
            if (albumSourceIndex === -1) {
                continue;
            }
            var albumProxyIndex = chatProxyModel.mapRowFromSource(albumSourceIndex, -1);
            if (albumProxyIndex !== -1) {
                return albumProxyIndex;
            }
        }
        return -1;
    }

    function showMessage(messageId, initialRun) {
        // Means we tapped a quoted message and had to load it.
        if(initialRun) {
            chatPage.messageIdToScrollTo = messageId
        }
        if (chatPage.messageIdToScrollTo && chatPage.messageIdToScrollTo != "") {
            var sourceIndex = chatModel.getMessageIndex(chatPage.messageIdToScrollTo);
            if(sourceIndex !== -1) {
                var proxyIndex = mapSourceIndexToProxyIndex(sourceIndex);
                if (proxyIndex === -1) {
                    return;
                }
                chatPage.messageIdToScrollTo = "";
                chatView.scrollToIndex(proxyIndex);
                navigatedTo(proxyIndex);
            } else if(initialRun) {
                // we only want to do this once.
                chatModel.triggerLoadHistoryForMessage(chatPage.messageIdToScrollTo)
            }
        }
    }

    Timer {
        id: forwardMessagesTimer
        interval: 200

        property string fromChatId
        property var messageIds
        onTriggered: {
            if(chatPage.loading) {
                forwardMessagesTimer.start()
            } else {
                var forwardedToSecretChat = chatInformation.type["@type"] === "chatTypeSecret";
                tdLibWrapper.forwardMessages(chatInformation.id, fromChatId, messageIds, forwardedToSecretChat, false);
            }
        }
    }

    Timer {
        id: searchInChatTimer
        interval: 300
        running: false
        repeat: false
        onTriggered: {
            Debug.log("Searching for '" + searchInChatField.text + "'");
            chatModel.setSearchQuery(searchInChatField.text);
        }
    }

    Timer {
        id: pinnedMessagesRefreshTimer
        interval: 120
        running: false
        repeat: false
        onTriggered: {
            requestPinnedMessagesRefresh();
        }
    }

    Component.onCompleted: {
        initializePage();
    }

    Component.onDestruction: {
        if (chatPage.canSendMessages && !chatPage.isDeletedUser) {
            tdLibWrapper.setChatDraftMessage(chatInformation.id, 0, newMessageColumn.replyToMessageId, newMessageTextField.text,
                newMessageInReplyToRow.inReplyToMessage ? newMessageInReplyToRow.inReplyToMessage.id : 0);
        }
        rootelegramUtils.stopGeoLocationUpdates();
        tdLibWrapper.closeChat(chatInformation.id);
    }

    onStatusChanged: {
        switch(status) {
        case PageStatus.Activating:
            tdLibWrapper.openChat(chatInformation.id);
            if(!chatPage.isInitialized) {
                if(chatInformation.draft_message) {
                    if(chatInformation.draft_message && chatInformation.draft_message.input_message_text) {
                        newMessageTextField.text = chatInformation.draft_message.input_message_text.text.text;
                        if(chatInformation.draft_message.reply_to_message_id) {
                            tdLibWrapper.getMessage(chatInformation.id, chatInformation.draft_message.reply_to_message_id);
                        }
                    }
                }
            }
            break;
        case PageStatus.Deactivating:
            messageOptionsDrawer.open = false
            break;
        case PageStatus.Active:
            // Imposta SEMPRE il messageThreadId corretto quando la pagina è attiva
            tdLibWrapper.setCurrentMessageThreadId(chatPage.messageThreadId);
            // is_forum vero solo per supergruppi forum (topics); per i discussion thread
            // di canale (linked supergroup non-forum) deve essere false: il send deve
            // mettere reply_to=threadId, non topic_id forum.
            tdLibWrapper.setCurrentChatIsForum(!!(chatGroupInformation && chatGroupInformation.is_forum));
            if (chatPage.messageThreadId > 0 && chatPage.topicLastMessageId > 0) {
                // Mark-as-read immediato nel topic: evita dipendenza esclusiva dal timer UI
                tdLibWrapper.viewMessage(chatInformation.id, chatPage.topicLastMessageId, true);
            }
            // chatModel è un singleton C++ condiviso da tutte le ChatPage nello stack:
            // se una pagina figlio (es. discussion chat dei commenti) lo ha riassegnato,
            // tornando qui dobbiamo re-inizializzarlo per la nostra chat/thread.
            var modelMismatch = chatPage.isInitialized && (
                String(chatModel.chatId) !== String(chatInformation.id)
                || Number(chatModel.messageThreadId || 0) !== Number(chatPage.messageThreadId || 0)
            );
            if (!chatPage.isInitialized || modelMismatch) {
                chatModel.messageThreadId = chatPage.messageThreadId;
                chatModel.topicLastMessageId = chatPage.topicLastMessageId;
                chatModel.initialize(chatInformation);
            }
            if (!chatPage.isInitialized) {
                pageStack.pushAttached(Qt.resolvedUrl("ChatInformationPage.qml"), { "chatInformation" : chatInformation, "privateChatUserInformation": chatPartnerInformation, "groupInformation": chatGroupInformation, "chatOnlineMemberCount": chatOnlineMemberCount});

                if(doSendBotStartMessage) {
                    tdLibWrapper.sendBotStartMessage(chatInformation.id, chatInformation.id, sendBotStartMessageParameter, "")
                }
            }
            if (chatPage.pendingSharedResources && chatPage.pendingSharedResources.length > 0) {
                chatPage.handleSharedResources(chatPage.pendingSharedResources);
                chatPage.pendingSharedResources = [];
            }
            break;
        case PageStatus.Inactive:
            if (pageStack.depth === 1) {
                // Solo quando si torna alla overview: azzera threadId e pulisci il modello
                tdLibWrapper.setCurrentMessageThreadId(0);
                tdLibWrapper.setCurrentChatIsForum(false);
                chatModel.clear();
            } else {
                resetElements();
            }

            break;
        }
    }

    Connections {
        target: tdLibWrapper
        onUserUpdated: {
            if ((isPrivateChat || isSecretChat) && chatPartnerInformation.id.toString() === userId ) {
                chatPartnerInformation = userInformation;
                updateChatPartnerStatusText();
            }
        }
        onBasicGroupUpdated: {
            if (isBasicGroup && chatGroupInformation.id.toString() === groupId ) {
                chatGroupInformation = groupInformation;
                updateGroupStatusText();
            }
        }
        onSuperGroupUpdated: {
            if (isSuperGroup && chatGroupInformation.id.toString() === groupId ) {
                chatGroupInformation = groupInformation;
                updateGroupStatusText();
            }
        }
        onChatOnlineMemberCountUpdated: {
            Debug.log(isSuperGroup, "/", isBasicGroup, "/", chatInformation.id.toString(), "/", chatId);
            if ((isSuperGroup || isBasicGroup) && chatInformation.id.toString() === chatId) {
                chatOnlineMemberCount = onlineMemberCount;
                updateGroupStatusText();
            }
        }
        onFileUpdated: {
            uploadStatusRow.visible = fileInformation.remote.is_uploading_active;
            if (uploadStatusRow.visible) {
                uploadingProgressBar.maximumValue = fileInformation.size;
                uploadingProgressBar.value = fileInformation.remote.uploaded_size;
            }
        }
        onEmojiSearchSuccessful: {
            chatPage.emojiProposals = result;
        }
        onErrorReceived: {
            Functions.handleErrorMessage(code, message);
        }
        onChatPendingJoinRequestsUpdated: {
            if (!chatInformation || chatId.toString() !== chatInformation.id.toString()) {
                return;
            }
            setPendingJoinRequests(pendingJoinRequests);
        }
        onChatJoinRequestsReceived: {
            // Risposta alla verifica autoritativa: se TDLib dichiara 0
            // richieste pendenti per questa chat, puliamo lo stato locale
            // così il banner sparisce anche se la cache lo teneva attivo.
            if (!chatInformation || chatId.toString() !== chatInformation.id.toString()) {
                return;
            }
            var actualCount = Number(totalCount);
            if (isNaN(actualCount)) {
                actualCount = 0;
            }
            if (actualCount === 0 || !requests || requests.length === 0) {
                setPendingJoinRequests({ total_count: 0, user_ids: [] });
            }
        }
        onOkReceived: {
            // L'aggiornamento del banner pending_join_requests è gestito
            // da onChatPendingJoinRequestsUpdated, che il wrapper C++
            // emette anche dopo un reject (TDLib non lo invia da solo).
        }
        onReceivedMessage: {
            if (message && (message.is_pinned || pinnedMessageListContains(message.id))) {
                schedulePinnedMessagesRefresh();
            }
            if (chatInformation.draft_message && messageId === chatInformation.draft_message.reply_to_message_id) {
                newMessageInReplyToRow.inReplyToMessage = message;
            }
            Debug.log("Received message ID: " + messageId + ", message ID to show: " + chatPage.messageIdToShow)
            if (chatPage.messageIdToShow && chatPage.messageIdToShow === String(messageId)) {
                messageOverlayLoader.overlayMessage = message;
                messageOverlayLoader.active = true;
            }
        }
        onPinnedMessagesReceived: {
            if (!chatInformation || Number(chatInformation.id) !== Number(chatId)) {
                return;
            }
            var cache = chatPage.pinnedMessagesByThread || {};
            cache[String(messageThreadId)] = messages || [];
            chatPage.pinnedMessagesByThread = cache;
            resolvePinnedMessageFromCache();
        }
        onSecretChatReceived: {
            if (secretChatId === chatInformation.type.secret_chat_id) {
                Debug.log("[ChatPage] Received detailed information about this secret chat");
                chatPage.secretChatDetails = secretChat;
                updateChatPartnerStatusText();
                chatPage.isSecretChatReady = chatPage.secretChatDetails.state["@type"] === "secretChatStateReady";
            }
        }
        onSecretChatUpdated: {
            if (secretChatId.toString() === chatInformation.type.secret_chat_id.toString()) {
                Debug.log("[ChatPage] Detailed information about this secret chat was updated");
                chatPage.secretChatDetails = secretChat;
                updateChatPartnerStatusText();
                chatPage.isSecretChatReady = chatPage.secretChatDetails.state["@type"] === "secretChatStateReady";
            }
        }
        onCallbackQueryAnswer: {
            if(text.length > 0) { // ignore bool "alert", just show as notification:
                appNotification.show(Emoji.emojify(text, Theme.fontSizeSmall));
            }
            if(url.length > 0) {
                Functions.handleLink(url);
            }
        }
        onUserFullInfoReceived: {
            if ((isPrivateChat || isSecretChat) && userFullInfo["@extra"] === chatPartnerInformation.id.toString()) {
                chatPage.botInformation = userFullInfo;
            }
        }
        onUserFullInfoUpdated: {
            if ((isPrivateChat || isSecretChat) && userId === chatPartnerInformation.id) {
                chatPage.botInformation = userFullInfo;
            }
        }
        onSponsoredMessageReceived: {
            chatPage.containsSponsoredMessages = true;
        }
        onReactionsUpdated: {
            availableReactions = tdLibWrapper.getChatReactions(chatInformation.id);
        }
    }

    Connections {
        target: chatModel
        onMessagesReceived: {
            var proxyIndex = chatProxyModel.mapRowFromSource(modelIndex, -1);
            Debug.log("[ChatPage] Messages received, view has ", chatView.count, " messages, last known message index ", proxyIndex, "("+modelIndex+"), own messages were read before index ", lastReadSentIndex);
            if (totalCount === 0) {
                if (chatPage.iterativeInitialization) {
                    chatPage.iterativeInitialization = false;
                    Debug.log("[ChatPage] actually, skipping that: No Messages in Chat.");
                    chatView.positionViewAtEnd();
                    chatPage.loading = false;
                    return;
                } else {
                    chatPage.iterativeInitialization = true;
                }
            }

            chatView.lastReadSentIndex = lastReadSentIndex;
            chatView.scrollToIndex(proxyIndex);
            chatPage.loading = false;
            if (chatOverviewItem.visible && proxyIndex >= (chatView.count - 10)) {
                chatView.inCooldown = true;
                chatModel.triggerLoadMoreFuture();
            }

            if (chatView.height > chatView.contentHeight) {
                Debug.log("[ChatPage] Chat content quite small...");
                viewMessageTimer.queueViewMessage(chatView.count - 1);
            }

            chatViewCooldownTimer.restart();
            chatViewStartupReadTimer.restart();

            /*
            // Double-tap for reactions is currently disabled, let's see if we'll ever need it again
            var remainingDoubleTapHints = appSettings.remainingDoubleTapHints;
            Debug.log("Remaining double tap hints: " + remainingDoubleTapHints);
            if (remainingDoubleTapHints > 0) {
                doubleTapHintTimer.start();
                tapHint.visible = true;
                tapHintLabel.visible = true;
                appSettings.remainingDoubleTapHints = remainingDoubleTapHints - 1;
            }
             */

        }
        onNewMessageReceived: {
            if (( chatView.manuallyScrolledToBottom && Qt.application.state === Qt.ApplicationActive ) || message.sender_id.user_id === chatPage.myUserId) {
                Debug.log("[ChatPage] Own message received or was scrolled to bottom, scrolling down to see it...");
                chatView.scrollToIndex(chatView.count - 1);
                viewMessageTimer.queueViewMessage(chatView.count - 1);
            }
        }
        onUnreadCountUpdated: {
            Debug.log("[ChatPage] Unread count updated, new count: ", unreadCount);
            chatInformation.unread_count = unreadCount;
            chatUnreadMessagesItem.visible = ( !chatPage.loading && unreadCount > 0 && chatOverviewItem.visible );
            chatUnreadMessagesCount.text = Functions.formatUnreadCount(unreadCount)
        }
        onLastReadSentMessageUpdated: {
            Debug.log("[ChatPage] Updating last read sent index, new index: ", lastReadSentIndex);
            chatView.lastReadSentIndex = lastReadSentIndex;
        }
        onMessagesIncrementalUpdate: {
            var proxyIndex = chatProxyModel.mapRowFromSource(modelIndex, -1);
            Debug.log("Incremental update received. View now has ", chatView.count, " messages, view is on index ", proxyIndex, "("+modelIndex+"), own messages were read before index ", lastReadSentIndex);
            chatView.lastReadSentIndex = lastReadSentIndex;
            if (!chatPage.isInitialized) {
                if (proxyIndex > -1) {
                    chatView.scrollToIndex(proxyIndex);
                }
            }
            if (chatView.height > chatView.contentHeight) {
                Debug.log("[ChatPage] Chat content quite small...");
                viewMessageTimer.queueViewMessage(chatView.count - 1);
            } else if (chatPage.messageIdToScrollTo && chatPage.messageIdToScrollTo != "") {
                showMessage(chatPage.messageIdToScrollTo, false)
            }
            chatViewCooldownTimer.restart();
            chatViewStartupReadTimer.restart();
        }
        onNotificationSettingsUpdated: {
            refreshChatInformationFromModel();
            muteChatMenuItem.text = chatInformation.notification_settings.mute_for > 0 ? qsTr("Unmute Chat") : qsTr("Mute Chat");
        }
        onPinnedMessageChanged: {
            refreshChatInformationFromModel();
            pinnedMessageItem.pinnedMessages = [];
            pinnedMessageItem.pinnedMessage = undefined;
            schedulePinnedMessagesRefresh();
        }
    }

    Connections {
        target: chatListModel
        onChatJoined: {
            appNotification.show(qsTr("You joined the chat %1").arg(chatTitle));
        }
    }

    Connections {
        target: tdLibWrapper
        onForumTopicInfoUpdated: {
            if (chatId === chatPage.chatInformation.id) {
                chatPage.currentTopicInfo = topicInfo;
            }
        }
    }

    Timer {
        id: lostFocusTimer
        interval: 200
        running: false
        repeat: false
        onTriggered: {
            newMessageTextField.forceActiveFocus();
        }
    }

    Timer {
        id: textReplacementTimer
        interval: 600
        running: false
        repeat: false
        onTriggered: {
            handleMessageTextReplacement(newMessageTextField.text, newMessageTextField.cursorPosition);
        }
    }

    Timer {
        id: chatContactTimeUpdater
        interval: 60000
        running: isPrivateChat || isSecretChat
        repeat: true
        onTriggered: {
            updateChatPartnerStatusText();
        }
    }
    Timer {
        id: viewMessageTimer
        interval: appSettings.delayMessageRead ? 1000 : 0
        property int lastQueuedIndex: -1
        function queueViewMessage(index) {
            if (index > lastQueuedIndex) {
                lastQueuedIndex = index;
                start();
            }
        }

        onTriggered: {
            Debug.log("scroll position changed, message index: ", lastQueuedIndex);
            Debug.log("unread count: ", chatInformation.unread_count);
            if (lastQueuedIndex < 0) {
                return;
            }
            var modelIndex = chatProxyModel.mapRowToSource(lastQueuedIndex);
            if (modelIndex === undefined || modelIndex === null || modelIndex < 0) {
                lastQueuedIndex = -1
                return;
            }
            var messageToRead = chatModel.getMessage(modelIndex);
            if (!messageToRead || !messageToRead.id) {
                lastQueuedIndex = -1
                return;
            }
            if (messageToRead['@type'] === "sponsoredMessage") {
                Debug.log("sponsored message to read: ", messageToRead.id);
                tdLibWrapper.viewMessage(chatInformation.id, messageToRead.message_id, false);
            } else {
                Debug.log("message to read: ", messageToRead.id);
                var messageId = messageToRead.id;
                if (messageToRead.media_album_id !== '0') {
                    var albumIds = chatModel.getMessageIdsForAlbum(messageToRead.media_album_id);
                    if (albumIds.length > 0) {
                        messageId = albumIds[albumIds.length - 1];
                        Debug.log("message to read last album message id: ", messageId);
                    }
                }
                if (messageId) {
                    tdLibWrapper.viewMessage(chatInformation.id, messageId, false);
                }
            }
            lastQueuedIndex = -1
            if (chatInformation.unread_count === 0) {
                tdLibWrapper.readAllChatMentions(chatInformation.id);
                tdLibWrapper.readAllChatReactions(chatInformation.id);
            }
        }
    }

    Drawer {
        id: messageOptionsDrawer

        property var myMessage: ({})
        property var userInformation: ({})
        property var additionalItemsModel: 0
        property var sourceItem
        property bool showCopyMessageToClipboardMenuItem
        property bool showForwardMessageMenuItem
        property bool showDeleteMessageMenuItem
        property bool showEditMessageMenuItem
        property bool showCopySelectedTextMenuItem
        property bool showQuoteSelectedTextMenuItem

        property list<NamedAction> messageOptionsModel: [
            NamedAction {
                visible: messageOptionsDrawer.showCopySelectedTextMenuItem
                name: qsTr("Copy Selected Text")
                action: function() {
                    if (messageOptionsDrawer.sourceItem) {
                        messageOptionsDrawer.sourceItem.copySelectedTextToClipboard()
                    }
                }
            },
            NamedAction {
                visible: messageOptionsDrawer.showQuoteSelectedTextMenuItem
                name: qsTr("Quote Selected Text")
                action: function() {
                    if (messageOptionsDrawer.sourceItem) {
                        messageOptionsDrawer.sourceItem.quoteSelectedTextToComposer()
                    }
                }
            },
            NamedAction {
                visible: messageOptionsDrawer.showEditMessageMenuItem
                name: qsTr("Edit Message")
                action: function() {
                    if (messageOptionsDrawer.sourceItem) {
                        messageOptionsDrawer.sourceItem.requestEditMessage()
                    }
                }
            },
            NamedAction {
                visible: messageOptionsDrawer.showCopyMessageToClipboardMenuItem
                name: qsTr("Copy Message to Clipboard")
                action: function() {
                    if (messageOptionsDrawer.sourceItem) {
                        messageOptionsDrawer.sourceItem.copyMessageToClipboard()
                    }
                }
            },
            NamedAction {
                visible: messageOptionsDrawer.showForwardMessageMenuItem && messageOptionsDrawer.myMessage.can_be_forwarded
                name: qsTr("Forward message")
                action: function () {
                    startForwardingMessages([messageOptionsDrawer.myMessage])
                }
            },
            NamedAction {
                visible: canPinMessages() &&
                    messageOptionsDrawer.myMessage &&
                    messageOptionsDrawer.myMessage["@type"] !== "sponsoredMessage" &&
                    typeof messageOptionsDrawer.myMessage.id !== "undefined"
                name: (messageOptionsDrawer.myMessage && messageOptionsDrawer.myMessage.is_pinned) ? qsTr("Unpin Message") : qsTr("Pin Message")
                action: function () {
                    if (!messageOptionsDrawer.myMessage ||
                            messageOptionsDrawer.myMessage["@type"] === "sponsoredMessage" ||
                            typeof messageOptionsDrawer.myMessage.id === "undefined") {
                        return;
                    }
                    if (messageOptionsDrawer.myMessage.is_pinned) {
                        Remorse.popupAction(page, qsTr("Message unpinned"), function() { tdLibWrapper.unpinMessage(chatPage.chatInformation.id, messageOptionsDrawer.myMessage.id);
                                                                                         pinnedMessageItem.requestCloseMessage(); } );
                    } else {
                        requestPinMessage(messageOptionsDrawer.myMessage);
                    }
                }
            },
            NamedAction {
                visible: messageOptionsDrawer.showDeleteMessageMenuItem
                name: qsTr("Delete message")
                action: function() {
                    if (messageOptionsDrawer.sourceItem) {
                        messageOptionsDrawer.sourceItem.deleteMessage()
                    }
                }
            }
        ]

        onOpenChanged: {
            if (open) {
                var jointModel = [];
                for (var j = 0; j < additionalItemsModel.length; j++) {
                    jointModel.push(additionalItemsModel[j]);
                }
                for (var i = 0; i < messageOptionsModel.length; i++) {
                    var item = messageOptionsModel[i]
                    if (item.visible) jointModel.push(item)
                }
                drawerListView.model = jointModel;
                focus = true // Take the focus away from the text field
            }
        }

        anchors.fill: parent
        dock: chatPage.isPortrait ? Dock.Bottom : Dock.Right
        backgroundSize: chatPage.isPortrait ? height / 3 : width / 2

        background: SilicaListView {
            id: drawerListView

            anchors.fill: parent
            clip: true

            VerticalScrollDecorator {}

            header: Row {
                id: drawerHeaderRow
                width: parent.width - ( 2 * Theme.horizontalPageMargin)
                height: messageOptionsLabel.height + Theme.paddingLarge + ( chatPage.isPortrait ? ( 2 * Theme.paddingSmall ) : 0 )
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingMedium
                Label {
                    id: messageOptionsLabel
                    text: qsTr("Additional Options")
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeLarge
                    width: parent.width - closeMessageOptionsButton.width - Theme.paddingMedium
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight

                }
                IconButton {
                    id: closeMessageOptionsButton
                    icon.source: "image://theme/icon-m-clear"
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: {
                        messageOptionsDrawer.open = false
                    }
                }
            }

            delegate: ListItem {
                Label {
                    width: parent.width - ( 2 * Theme.horizontalPageMargin )
                    text: modelData.name
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                }
                onClicked: {
                    modelData.action();
                    messageOptionsDrawer.open = false
                }
                hidden: !modelData.visible
            }
        }

        SilicaFlickable {
            id: chatContainer

            onContentYChanged: {
                // For some strange reason contentY sometimes is > 0 which doesn't make sense without a PushUpMenu (?)
                // That leads to the problem that the whole flickable is moved slightly (or sometimes considerably) up
                // which creates UX issues... As a workaround we are setting it to 0 in such cases.
                // Better solutions are highly appreciated, contributions always welcome! ;)
                if (contentY > 0) {
                    contentY = 0;
                }
            }

            anchors.fill: parent
            contentHeight: height
            contentWidth: width

            PullDownMenu {
                visible: chatInformation.id !== chatPage.myUserId && !stickerPickerLoader.active && !voiceNoteOverlayLoader.active && !messageOverlayLoader.active && !stickerSetOverlayLoader.active

                MenuItem {
                    id: deleteChatMenuItem
                    visible: chatPage.isPrivateChat
                    onClicked: {
                        var privateChatId = chatInformation.id;
                        Remorse.popupAction(chatPage, qsTr("Deleting chat"), function() {
                            tdLibWrapper.deleteChat(privateChatId);
                            pageStack.pop(pageStack.find( function(page){ return(page._depth === 0)} ));
                        }, 10000);
                    }
                    text: qsTr("Delete Chat")
                }

                MenuItem {
                    id: closeSecretChatMenuItem
                    visible: chatPage.isSecretChat && chatPage.secretChatDetails.state["@type"] !== "secretChatStateClosed"
                    onClicked: {
                        var secretChatId = chatPage.secretChatDetails.id;
                        Remorse.popupAction(chatPage, qsTr("Closing chat"), function() { tdLibWrapper.closeSecretChat(secretChatId) });
                    }
                    text: qsTr("Close Chat")
                }

                MenuItem {
                    id: joinLeaveChatMenuItem
                    visible: (chatPage.isSuperGroup || chatPage.isBasicGroup) && chatGroupInformation && chatGroupInformation.status["@type"] !== "chatMemberStatusBanned"
                    onClicked: {
                        if (chatPage.userIsMember) {
                            var chatId = chatInformation.id;
                            Remorse.popupAction(chatPage, qsTr("Leaving chat"), function() {
                                tdLibWrapper.leaveChat(chatId);
                                // this does not care about the response (ideally type "ok" without further reference) for now
                                pageStack.pop(pageStack.find( function(page){ return(page._depth === 0)} ));
                            });
                        } else {
                            tdLibWrapper.joinChat(chatInformation.id);
                        }
                    }
                    text: chatPage.userIsMember ? qsTr("Leave Chat") : qsTr("Join Chat")
                }

                MenuItem {
                    id: muteChatMenuItem
                    visible: chatPage.userIsMember
                    onClicked: {
                        var newNotificationSettings = chatInformation.notification_settings;
                        if (newNotificationSettings.mute_for > 0) {
                            newNotificationSettings.mute_for = 0;
                        } else {
                            newNotificationSettings.mute_for = 6666666;
                        }
                        newNotificationSettings.use_default_mute_for = false;
                        tdLibWrapper.setChatNotificationSettings(chatInformation.id, newNotificationSettings);
                    }
                    text: chatInformation.notification_settings.mute_for > 0 ? qsTr("Unmute Chat") : qsTr("Mute Chat")
                }

                MenuItem {
                    id: searchInChatMenuItem
                    visible: !chatPage.isSecretChat && chatOverviewItem.visible
                    onClicked: {
                        // This automatically shows the search field as well
                        chatOverviewItem.visible = false;
                        searchInChatField.focus = true;
                    }
                    text: qsTr("Search in Chat")
                }
            }

            BackgroundItem {
                id: headerMouseArea
                height: headerRow.height
                width: parent.width
                onClicked: {
                    if (chatPage.isSelecting) {
                        chatPage.selectedMessages = [];
                    } else {
                        pageStack.navigateForward();
                    }
                }
            }

            Column {
                id: chatColumn
                width: parent.width
                height: parent.height

                Row {
                    id: headerRow
                    width: parent.width - (3 * Theme.horizontalPageMargin)
                    height: chatOverviewItem.height + ( chatPage.isPortrait ? (2 * Theme.paddingMedium) : (2 * Theme.paddingSmall) )
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.paddingMedium

                    Item {
                        width: chatOverviewItem.height
                        height: chatOverviewItem.height
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: chatPage.isPortrait ? Theme.paddingMedium : Theme.paddingSmall

                        ProfileThumbnail {
                            id: chatPictureThumbnail
                            replacementStringHint: chatNameText.text
                            width: parent.height
                            height: parent.height

                            // Setting it directly may cause an stale state for the thumbnail in case the chat page
                            // was previously loaded with a picture and now it doesn't have one. Instead setting it
                            // when the ChatModel indicates a change. This also avoids flickering when the page is loaded...
                            Connections {
                                target: chatModel
                                onSmallPhotoChanged: {
                                    chatPictureThumbnail.photoData = chatModel.smallPhoto;
                                }
                            }
                        }

                        Rectangle {
                            id: chatSecretBackground
                            color: Theme.rgba(Theme.overlayBackgroundColor, Theme.opacityFaint)
                            width: chatPage.isPortrait ? Theme.fontSizeLarge : Theme.fontSizeMedium
                            height: width
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            radius: parent.width / 2
                            visible: chatPage.isSecretChat
                        }

                        Image {
                            source: "image://theme/icon-s-secure"
                            width: chatPage.isPortrait ? Theme.fontSizeSmall : Theme.fontSizeExtraSmall
                            height: width
                            anchors.centerIn: chatSecretBackground
                            visible: chatPage.isSecretChat
                        }

                    }

                    Item {
                        id: chatOverviewItem
                        opacity: visible ? 1 : 0
                        Behavior on opacity { FadeAnimation {} }
                        width: parent.width - chatPictureThumbnail.width - Theme.paddingMedium
                        height: chatNameText.height + (topicNameText.visible ? topicNameText.height : 0) + chatStatusText.height
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: chatPage.isPortrait ? Theme.paddingMedium : Theme.paddingSmall
                        Label {
                            id: chatNameText
                            width: Math.min(implicitWidth, parent.width)
                            anchors.right: parent.right
                            anchors.top: parent.top
                            text: chatInformation.title !== "" ? Emoji.emojify(chatInformation.title, font.pixelSize) : qsTr("Unknown")
                            textFormat: Text.StyledText
                            font.pixelSize: chatPage.isPortrait ? Theme.fontSizeLarge : Theme.fontSizeMedium
                            font.family: Theme.fontFamilyHeading
                            color: Theme.highlightColor
                            truncationMode: TruncationMode.Fade
                            maximumLineCount: 1
                        }
                        Label {
                            id: topicNameText
                            visible: chatPage.messageThreadId !== 0
                            width: Math.min(implicitWidth, parent.width)
                            anchors.right: parent.right
                            anchors.top: chatNameText.bottom
                            text: chatPage.currentTopicInfo ? Emoji.emojify("# " + (chatPage.currentTopicInfo.name || ""), font.pixelSize) : "# …"
                            textFormat: Text.StyledText
                            font.pixelSize: chatPage.isPortrait ? Theme.fontSizeSmall : Theme.fontSizeTiny
                            font.family: Theme.fontFamilyHeading
                            color: Theme.highlightColor
                            truncationMode: TruncationMode.Fade
                            maximumLineCount: 1
                        }
                        Label {
                            id: chatStatusText
                            width: Math.min(implicitWidth, parent.width)
                            anchors {
                                right: parent.right
                                bottom: parent.bottom
                            }
                            text: ""
                            textFormat: Text.StyledText
                            font.pixelSize: chatPage.isPortrait ? Theme.fontSizeExtraSmall : Theme.fontSizeTiny
                            font.family: Theme.fontFamilyHeading
                            color: headerMouseArea.pressed ? Theme.secondaryHighlightColor : Theme.secondaryColor
                            truncationMode: TruncationMode.Fade
                            maximumLineCount: 1
                        }
                    }

                    Item {
                        id: searchInChatItem
                        visible: !chatOverviewItem.visible
                        opacity: visible ? 1 : 0
                        Behavior on opacity { FadeAnimation {} }
                        width: parent.width - chatPictureThumbnail.width - Theme.paddingMedium
                        height: searchInChatField.height
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: chatPage.isPortrait ? Theme.paddingSmall : 0

                        SearchField {
                            id: searchInChatField
                            visible: false
                            width: visible ? parent.width : 0
                            placeholderText: qsTr("Search in chat...")
                            active: searchInChatItem.visible
                            canHide: text === ""

                            onTextChanged: {
                                searchInChatTimer.restart();
                            }

                            onHideClicked: {
                                resetFocus();
                            }

                            EnterKey.iconSource: "image://theme/icon-m-enter-close"
                            EnterKey.onClicked: {
                                resetFocus();
                            }
                        }
                    }
                }


                PinnedMessageItem {
                    id: pinnedMessageItem
                    onRequestShowMessage: {
                        if (messageId && messageId !== "0") {
                            messageOverlayLoader.overlayMessage = undefined;
                            messageOverlayLoader.active = false;
                            chatPage.showMessage(String(messageId), true);
                        }
                    }
                    onRequestCloseMessage: {
                        messageOverlayLoader.overlayMessage = undefined;
                        messageOverlayLoader.active = false;
                        pinnedMessageItem.pinnedMessages = [];
                        pinnedMessageItem.pinnedMessage = undefined;
                    }
                }
                BackgroundItem {
                    id: joinRequestsBanner
                    width: parent.width
                    height: showJoinRequestsBanner ? Theme.itemSizeSmall : 0
                    visible: height > 0
                    opacity: showJoinRequestsBanner ? 1.0 : 0.0
                    Behavior on height { SmoothedAnimation { duration: 160 } }
                    Behavior on opacity { FadeAnimation {} }
                    onClicked: {
                        openJoinRequestsPage();
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: Theme.rgba(Theme.highlightBackgroundColor, 0.20)
                    }
                    Row {
                        width: parent.width - (2 * Theme.horizontalPageMargin)
                        height: parent.height
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.paddingSmall
                        layoutDirection: Qt.RightToLeft
                        Image {
                            source: "image://theme/icon-m-right"
                            width: Theme.iconSizeSmall
                            height: Theme.iconSizeSmall
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Label {
                            width: parent.width - Theme.iconSizeSmall - Theme.paddingSmall
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("%Ln join requests", "", pendingJoinRequestsCount)
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeSmall
                            truncationMode: TruncationMode.Fade
                            maximumLineCount: 1
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                Item {
                    id: chatViewItem
                    width: parent.width
                    height: parent.height - headerRow.height - pinnedMessageItem.height - joinRequestsBanner.height - newMessageColumn.height - selectedMessagesActions.height

                    property int previousHeight;

                    Component.onCompleted: {
                        previousHeight = height;
                    }

                    onHeightChanged: {
                        if (previousHeight > height) {
                            var deltaHeight = previousHeight - height;
                            chatView.contentY = chatView.contentY + deltaHeight;
                        } else {
                            chatView.handleScrollPositionChanged();
                        }
                        previousHeight = height;
                    }

                    Timer {
                        id: chatViewCooldownTimer
                        interval: 2000
                        repeat: false
                        running: false
                        onTriggered: {
                            Debug.log("[ChatPage] Cooldown completed...");
                            chatView.inCooldown = false;

                            if (!chatPage.isInitialized) {
                                Debug.log("Page is initialized!");
                                chatPage.isInitialized = true;
                                chatView.handleScrollPositionChanged();
                            }
                        }
                    }

                    Timer {
                        id: chatViewStartupReadTimer
                        interval: 200
                        repeat: false
                        running: false
                        onTriggered: {
                            if (!chatPage.isInitialized) {
                                Debug.log("Page is initialized!");
                                chatPage.isInitialized = true;
                                chatView.handleScrollPositionChanged();
                                if (chatPage.isChannel) {
                                    tdLibWrapper.getChatSponsoredMessage(chatInformation.id);
                                }
                                if (typeof chatPage.messageToShow !== "undefined" && chatPage.messageToShow !== {}) {
                                    messageOverlayLoader.overlayMessage = chatPage.messageToShow;
                                    messageOverlayLoader.active = true;
                                }
                                if (chatPage.messageIdToShow) {
                                    tdLibWrapper.getMessage(chatPage.chatInformation.id, chatPage.messageIdToShow);
                                }
                            }
                        }
                    }

                    Loader {
                        asynchronous: true
                        active: chatView.blurred
                        anchors.fill: chatView
                        sourceComponent: Component {
                            Rectangle {
                                color: Theme.overlayBackgroundColor
                                opacity: 0.7
                            }
                        }
                    }

                    SilicaListView {
                        id: chatView

                        visible: !blurred
                        property bool blurred: messageOverlayLoader.item || stickerPickerLoader.item || voiceNoteOverlayLoader.item || inlineQuery.hasOverlay || stickerSetOverlayLoader.item

                        anchors.fill: parent
                        opacity: chatPage.loading ? 0 : 1
                        Behavior on opacity { FadeAnimation {} }
                        clip: true
                        highlightMoveDuration: 0
                        highlightResizeDuration: 0
                        property int lastReadSentIndex: -1
                        property bool inCooldown: false
                        property bool manuallyScrolledToBottom
                        property QtObject precalculatedValues: QtObject {
                            readonly property alias page: chatPage
                            readonly property bool showUserInfo: page.isBasicGroup || ( page.isSuperGroup && !page.isChannel)
                            readonly property int profileThumbnailDimensions: showUserInfo ? Theme.itemSizeSmall : 0
                            readonly property int pageMarginDouble: 2 * Theme.horizontalPageMargin
                            readonly property int paddingMediumDouble: 2 * Theme.paddingMedium
                            readonly property int entryWidth: chatView.width - 6
                            readonly property int textItemWidth: entryWidth - profileThumbnailDimensions - Theme.paddingSmall
                            readonly property int backgroundWidth: page.isChannel ? textItemWidth : textItemWidth - pageMarginDouble
                            readonly property int backgroundRadius: textItemWidth/50
                            readonly property int textColumnWidth: backgroundWidth - Theme.horizontalPageMargin
                            readonly property int messageInReplyToHeight: Theme.fontSizeExtraSmall * 2.571428571 + Theme.paddingSmall;
                            readonly property int webPagePreviewHeight: ( (textColumnWidth * 2 / 3) + (6 * Theme.fontSizeExtraSmall) + ( 7 * Theme.paddingSmall) )
                            readonly property bool pageIsSelecting: chatPage.isSelecting
                        }

                        function handleScrollPositionChanged() {
                            Debug.log("Current position: ", chatView.contentY);
                            Debug.log("Contains sponsored messages?", chatPage.containsSponsoredMessages);
                            if (chatOverviewItem.visible && ( chatInformation.unread_count > 0 || chatPage.containsSponsoredMessages ) ) {
                                var bottomIndex = chatView.indexAt(chatView.contentX, ( chatView.contentY + chatView.height - Theme.horizontalPageMargin ));
                                if (bottomIndex > -1) {
                                    viewMessageTimer.queueViewMessage(bottomIndex)
                                }
                            } else {
                                tdLibWrapper.readAllChatMentions(chatInformation.id);
                                tdLibWrapper.readAllChatReactions(chatInformation.id);
                            }
                            manuallyScrolledToBottom = chatView.atYEnd
                        }

                        function scrollToIndex(index, mode) {
                            if(index >= 0 && index < chatView.count) {
                                positionViewAtIndex(index, (mode === undefined) ? ListView.Contain : mode)
                                if(index === chatView.count - 1) {
                                    manuallyScrolledToBottom = true;
                                    if(!chatView.atYEnd) {
                                        chatView.positionViewAtEnd();
                                    }
                                }
                            }
                        }

                        onContentYChanged: {
                            if (!chatPage.loading && !chatView.inCooldown) {
                                if (chatView.indexAt(chatView.contentX, chatView.contentY) < 10) {
                                    Debug.log("[ChatPage] Trying to get older history items...");
                                    chatView.inCooldown = true;
                                    chatModel.triggerLoadMoreHistory();
                                } else if (chatOverviewItem.visible && chatView.indexAt(chatView.contentX, chatView.contentY) > ( count - 10)) {
                                    Debug.log("[ChatPage] Trying to get newer history items...");
                                    chatView.inCooldown = true;
                                    chatModel.triggerLoadMoreFuture();
                                }
                            }
                        }

                        onMovementEnded: {
                            handleScrollPositionChanged();
                        }

                        onQuickScrollAnimatingChanged: {
                            if (!quickScrollAnimating) {
                                handleScrollPositionChanged();
                                if(atYEnd) { // handle some false guesses from quick scroll
                                    chatView.scrollToIndex(chatView.count - 2)
                                    chatView.scrollToIndex(chatView.count - 1)
                                }
                            }
                        }

                        BoolFilterModel {
                            id: chatProxyModel
                            sourceModel: chatModel
                            filterRoleName: "album_entry_filter"
                            filterValue: false
                        }
                        model: chatProxyModel
                        header: Component {
                            Loader {
                                active: !!chatPage.botInformation
                                        && !!chatPage.botInformation.bot_info && chatPage.botInformation.bot_info.description.length > 0
                                asynchronous: true
                                width: chatView.width
                                sourceComponent: Component {
                                    Label {
                                        id: botInfoLabel
                                        topPadding: Theme.paddingLarge
                                        bottomPadding: Theme.paddingLarge
                                        leftPadding: Theme.horizontalPageMargin
                                        rightPadding: Theme.horizontalPageMargin
                                        text: Emoji.emojify(chatPage.botInformation.bot_info.description, font.pixelSize)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.highlightColor
                                        wrapMode: Text.Wrap
                                        textFormat: Text.StyledText
                                        horizontalAlignment: Text.AlignHCenter
                                        onLinkActivated: {
                                            var chatCommand = Functions.handleLink(link);
                                            if(chatCommand) {
                                                tdLibWrapper.sendTextMessage(chatInformation.id, chatCommand);
                                            }
                                        }
                                        linkColor: Theme.primaryColor
                                        visible: (text !== "")
                                    }
                                }
                            }
                        }

                        function getContentComponentHeight(contentType, content, parentWidth, albumEntries) {
                            var unit;
                            switch(contentType) {
                            case "messageAnimatedEmoji":
                                return content.animated_emoji.sticker.height;
                            case "messageAnimation":
                                return Functions.getVideoHeight(parentWidth, content.animation);
                            case "messageAudio":
                            case "messageVoiceNote":
                            case "messageDocument":
                                return Theme.itemSizeLarge;
                            case "messageGame":
                                return parentWidth * 0.66666666 + Theme.itemSizeLarge; // 2 / 3;
                            case "messageLocation":
                            case "messageVenue":
                                return parentWidth * 0.66666666; // 2 / 3;
                            case "messagePhoto":
                                if(albumEntries > 0) {
                                    unit = (parentWidth * 0.66666666)
                                    return (albumEntries % 2 !== 0 ? unit * 0.75 : 0) + unit * albumEntries * 0.25
                                }
                                var biggest = content.photo.sizes[content.photo.sizes.length - 1];
                                if ((biggest.width === 0 || biggest.height === 0) && content.photo.sizes.length > 1) {
                                    for (var pictureSizeIndex = (content.photo.sizes.length - 2); pictureSizeIndex >= 0; pictureSizeIndex--) {
                                        biggest = content.photo.sizes[pictureSizeIndex];
                                        if (biggest.width > 0 && biggest.height > 0) {
                                            break;
                                        }
                                    }
                                }
                                var aspectRatio = (biggest.width > 0 && biggest.height > 0) ? (biggest.width / biggest.height) : 1;
                                var targetAspectRatio = aspectRatio < 1 ? (9.0 / 16.0) : (16.0 / 9.0);
                                var previewAreaBase = parentWidth * (parentWidth * 0.66666666);
                                var previewWidth = Math.min(parentWidth, Math.sqrt(previewAreaBase * targetAspectRatio));
                                return Math.max(Theme.itemSizeExtraSmall, Math.round(previewWidth / targetAspectRatio));
                            case "messagePoll":
                                return Theme.itemSizeSmall * (4 + content.poll.options);
                            case "messageSticker":
                                return content.sticker.height;
                            case "messageVideo":
                                if(albumEntries > 0) {
                                    unit = (parentWidth * 0.66666666)
                                    return (albumEntries % 2 !== 0 ? unit * 0.75 : 0) + unit * albumEntries * 0.25
                                }
                                return Functions.getVideoHeight(parentWidth, content.video);
                            case "messageVideoNote":
                                return parentWidth
                            }
                        }

                        readonly property var delegateMessagesContent: [
                            "messageAnimatedEmoji",
                            "messageAnimation",
                            "messageAudio",
                            // "messageContact",
                            // "messageDice"
                            "messageDocument",
                            "messageGame",
                            // "messageInvoice",
                            "messageLocation",
                            // "messagePassportDataSent",
                            // "messagePaymentSuccessful",
                            "messagePhoto",
                            "messagePoll",
                            // "messageProximityAlertTriggered",
                            "messageSticker",
                            "messageVenue",
                            "messageVideo",
                            "messageVideoNote",
                            "messageVoiceNote"
                        ]

                        readonly property var simpleDelegateMessages: ["messageBasicGroupChatCreate",
                                                                       "messageChatAddMembers",
                                                                       "messageChatChangePhoto",
                                                                       "messageChatChangeTitle",
                                                                       "messageChatDeleteMember",
                                                                       "messageChatDeletePhoto",
                                                                       "messageChatJoinByLink",
                                                                       "messageChatSetTtl",
                                                                       "messageChatUpgradeFrom",
                                                                       "messageContactRegistered",
                                                                       // "messageExpiredPhoto", "messageExpiredVideo","messageWebsiteConnected"
                                                                       "messageGameScore",
                                                                       "messageChatUpgradeTo",
                                                                       "messageCustomServiceAction",
                                                                       "messagePinMessage",
                                                                       "messageScreenshotTaken",
                                                                       "messageSupergroupChatCreate",
                                                                       "messageUnsupported"]
                        delegate: Loader {
                            width: chatView.width
                            Component {
                                id: messageListViewItemComponent
                                MessageListViewItem {
                                    precalculatedValues: chatView.precalculatedValues
                                    chatId: chatModel.chatId
                                    myMessage: model.display
                                    messageId: model.message_id
                                    messageAlbumMessageIds: model.album_message_ids
                                    messageViewCount: model.view_count
                                    reactions: model.reactions
                                    chatReactions: availableReactions
                                    messageIndex: chatProxyModel.mapRowToSource(model.index)
                                    hasContentComponent: !!myMessage.content && chatView.delegateMessagesContent.indexOf(model.content_type) > -1
                                    canReplyToMessage: chatPage.canSendMessages
                                    onReplyToMessage: {
                                        newMessageInReplyToRow.inReplyToMessage = myMessage
                                        newMessageTextField.focus = true
                                    }
                                    onEditMessage: {
                                        beginMessageEdit(messageId, myMessage)
                                    }
                                    onForwardMessage: {
                                        startForwardingMessages([myMessage])
                                    }
                                    onQuoteSelectedText: {
                                        chatPage.quoteSelectedText(myMessage, selectedText)
                                    }
                                }
                            }
                            Component {
                                id: messageListViewItemSimpleComponent
                                MessageListViewItemSimple {}
                            }
                            Component {
                                id: messageListViewItemHiddenComponent
                                Item {
                                    property var myMessage: display
                                    property bool senderIsUser: myMessage.sender_id["@type"] === "messageSenderUser"
                                    property var userInformation: senderIsUser ? tdLibWrapper.getUserInformation(myMessage.sender_id.user_id) : null
                                    property bool isOwnMessage: senderIsUser && chatPage.myUserId === myMessage.sender_id.user_id
                                    height: 1
                                }
                            }
                            sourceComponent: chatView.simpleDelegateMessages.indexOf(model.content_type) > -1
                                               ? messageListViewItemSimpleComponent
                                               : messageListViewItemComponent
                        }
                        VerticalScrollDecorator { flickable: chatView }

                        ViewPlaceholder {
                            id: chatViewPlaceholder
                            enabled: chatView.count === 0
                            text: (chatPage.isSecretChat && !chatPage.isSecretChatReady) ? qsTr("This secret chat is not yet ready. Your chat partner needs to go online first.") : qsTr("This chat is empty.")
                        }
                    }

                    Column {
                        width: parent.width
                        height: loadingLabel.height + loadingBusyIndicator.height + Theme.paddingMedium
                        spacing: Theme.paddingMedium
                        anchors.verticalCenter: parent.verticalCenter

                        opacity: chatPage.loading ? 1 : 0
                        Behavior on opacity { FadeAnimation {} }
                        visible: chatPage.loading

                        InfoLabel {
                            id: loadingLabel
                            text: qsTr("Loading messages...")
                        }

                        BusyIndicator {
                            id: loadingBusyIndicator
                            anchors.horizontalCenter: parent.horizontalCenter
                            running: chatPage.loading
                            size: BusyIndicatorSize.Large
                        }
                    }

                    Item {
                        id: chatUnreadMessagesItem
                        width: Theme.fontSizeHuge
                        height: Theme.fontSizeHuge
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.paddingMedium
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Theme.paddingMedium
                        // Nei commenti dei canali (thread mode) il contatore globale
                        // della chat canale è fuorviante: l'utente è nel thread, non
                        // nella history broadcast. Lo nascondiamo.
                        visible: !chatPage.loading && chatInformation.unread_count > 0 && chatOverviewItem.visible && (!chatPage.messageThreadId || chatPage.messageThreadId === 0)
                        Rectangle {
                            id: chatUnreadMessagesCountBackground
                            color: Theme.highlightBackgroundColor
                            anchors.fill: parent
                            radius: width / 2
                            visible: chatUnreadMessagesItem.visible
                        }

                        Text {
                            id: chatUnreadMessagesCount
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                            color: Theme.primaryColor
                            anchors.centerIn: chatUnreadMessagesCountBackground
                            visible: chatUnreadMessagesItem.visible
                            text: Functions.formatUnreadCount(chatInformation.unread_count)
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                chatView.scrollToIndex(chatView.count - 1 - chatInformation.unread_count)
                            }
                        }
                    }

                    Loader {
                        id: stickerPickerLoader
                        active: false
                        asynchronous: true
                        width: parent.width
                        height: active ? parent.height : 0
                        source: "../components/StickerPicker.qml"
                    }

                    Connections {
                        target: stickerPickerLoader.item
                        onStickerPicked: {
                            if (!stickerId || stickerId === "") {
                                appNotification.show(qsTr("Unable to send this sticker."));
                                return;
                            }
                            Debug.log("Sticker picked: " + stickerId);
                            stickerManager.setNeedsReload(true);
                            tdLibWrapper.sendStickerMessage(chatInformation.id, stickerId, newMessageColumn.replyToMessageId);
                            stickerPickerLoader.active = false;
                            attachmentOptionsFlickable.isNeeded = false;
                            newMessageInReplyToRow.inReplyToMessage = null;
                            newMessageColumn.editMessageId = "0";
                            newMessageColumn.quickEmojiPickerVisible = false;
                            newMessageColumn.quickPremiumEmojiPickerVisible = false;
                        }
                        onCustomEmojiPicked: {
                            insertCustomEmojiAtCursor(customEmojiId, fallbackEmoji);
                            stickerPickerLoader.active = false;
                            attachmentOptionsFlickable.isNeeded = false;
                            newMessageColumn.quickEmojiPickerVisible = false;
                            newMessageColumn.quickPremiumEmojiPickerVisible = false;
                        }
                    }

                    Loader {
                        id: messageOverlayLoader

                        property var overlayMessage;

                        active: false
                        asynchronous: true
                        width: parent.width
                        height: active ? parent.height : 0
                        sourceComponent: Component {
                            MessageOverlayFlickable {
                                overlayMessage: messageOverlayLoader.overlayMessage
                                showHeader: !chatPage.isChannel
                                onRequestClose: {
                                    messageOverlayLoader.active = false;
                                }
                            }
                        }
                    }

                    Loader {
                        id: voiceNoteOverlayLoader
                        active: false
                        asynchronous: true
                        width: parent.width
                        height: active ? parent.height : 0
                        source: "../components/VoiceNoteOverlay.qml"
                        onActiveChanged: {
                            if (!active) {
                                rootelegramUtils.stopRecordingVoiceNote();
                            }
                        }
                    }

                    Loader {
                        id: stickerSetOverlayLoader

                        property string stickerSetId;

                        active: false
                        asynchronous: true
                        width: parent.width
                        height: active ? parent.height : 0
                        sourceComponent: Component {
                            StickerSetOverlay {
                                stickerSetId: stickerSetOverlayLoader.stickerSetId
                                onRequestClose: {
                                    stickerSetOverlayLoader.active = false;
                                }
                            }
                        }

                        onActiveChanged: {
                            if (active) {
                                attachmentOptionsFlickable.isNeeded = false;
                            }
                        }
                    }

                    InlineQuery {
                        id: inlineQuery
                        textField: newMessageTextField
                        chatId: chatInformation.id
                    }
                }

                Column {
                    id: newMessageColumn
                    spacing: Theme.paddingSmall
                    topPadding: Theme.paddingSmall + inlineQuery.buttonPadding
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: height > 0 && !(chatPage.currentTopicInfo && chatPage.currentTopicInfo.is_closed)
                    property bool translatingInput: false
                    property string originalInputText: ""

                    Connections {
                        target: tdLibWrapper
                        onTextTranslated: {
                            newMessageColumn.translatingInput = false
                            if (translatedText !== "") {
                                var converted = chatPage.translatedHtmlToComposerMarkdown(translatedText)
                                // Telegram rileva la lingua di origine lato server: se la rileva
                                // uguale alla destinazione (es. testo con anglicismi "emoji",
                                // "reaction"…) rimanda il testo identico. Avvisa invece di
                                // sembrare un blocco.
                                if (converted.trim() === newMessageColumn.originalInputText.trim()) {
                                    appNotification.show(qsTr("RooTelegram couldn't detect the language of the text — maybe you wrote a multilingual message?"))
                                } else {
                                    newMessageTextField.text = converted
                                }
                            }
                        }
                        onErrorReceived: {
                            // Sblocca il pulsante se la traduzione del testo in uscita fallisce.
                            if (extra === "translateText:" + chatPage.translateOutgoingLanguage) {
                                newMessageColumn.translatingInput = false
                            }
                        }
                    }

                // Banner topic chiuso
                Rectangle {
                    visible: chatPage.currentTopicInfo && chatPage.currentTopicInfo.is_closed
                    width: parent.width
                    height: closedLabel.height + Theme.paddingMedium * 2
                    color: Theme.overlayBackgroundColor
                    opacity: 0.9

                    Label {
                        id: closedLabel
                        anchors.centerIn: parent
                        text: qsTr("Topic is closed")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
                    width: parent.width - ( 2 * Theme.horizontalPageMargin )
                    height: isNeeded ? implicitHeight : 0
                    Behavior on height { SmoothedAnimation { duration: 200 } }

                    readonly property bool isNeeded: !chatPage.isSelecting && chatPage.canSendMessages
                    property string replyToMessageId: "0";
                    property string editMessageId: "0";
                    property bool quickEmojiPickerVisible: false;
                    property bool quickPremiumEmojiPickerVisible: false;
                    property bool quickStickerPickerVisible: false;
                    property var quickStickerSets: [];
                    property int quickStickerSelectedSetIndex: -1;
                    function refreshQuickStickerSets() {
                        if (typeof stickerManager !== "undefined" && stickerManager) {
                            quickStickerSets = stickerManager.getInstalledStickerSets();
                            if (quickStickerSelectedSetIndex >= quickStickerSets.length) quickStickerSelectedSetIndex = -1;
                        }
                    }
                    function selectedQuickStickerList() {
                        if (quickStickerSelectedSetIndex < 0) {
                            return (typeof stickerManager !== "undefined" && stickerManager) ? stickerManager.getRecentStickers() : [];
                        }
                        if (quickStickerSelectedSetIndex >= quickStickerSets.length) return [];
                        var s = quickStickerSets[quickStickerSelectedSetIndex];
                        return (s && s.stickers) ? s.stickers : [];
                    }
                    function stickerRemoteIdFromSticker(sticker) {
                        if (!sticker || !sticker.sticker || !sticker.sticker.remote || !sticker.sticker.remote.id) return "";
                        return sticker.sticker.remote.id.toString();
                    }
                    property var customEmojiEntities: [];
                    property string previousComposerText: "";
                    property bool suspendCustomEmojiTracking: false;
                    property var installedCustomEmojiSets: stickerManager.getInstalledCustomEmojiSets();
                    property var quickPremiumEmojiSets: [];
                    property int quickPremiumSelectedSetIndex: 0;
                    // 0 = nessun limite: mostra tutti i set custom emoji
                    // installati nel quick picker premium (prima era cap a 8).
                    property int quickPremiumSetLimit: 0;
                    property int quickPremiumPerSetLimit: 120;
                    readonly property real compactAttachmentButtonSize: Math.max(Math.round(Theme.itemSizeSmall * 0.6), Theme.itemSizeExtraSmall)
                    readonly property real compactAttachmentSpacing: Math.max(Math.round(Theme.paddingSmall * 0.5), 4)

                    function customEmojiIdFromSticker(sticker) {
                        if (!sticker) {
                            return "";
                        }
                        if (sticker.custom_emoji_id) {
                            return sticker.custom_emoji_id.toString();
                        }
                        if (sticker.full_type
                                && sticker.full_type["@type"] === "stickerFullTypeCustomEmoji"
                                && sticker.full_type.custom_emoji_id) {
                            return sticker.full_type.custom_emoji_id.toString();
                        }
                        if (sticker.type
                                && sticker.type["@type"] === "stickerTypeCustomEmoji"
                                && sticker.type.custom_emoji_id) {
                            return sticker.type.custom_emoji_id.toString();
                        }
                        return "";
                    }

                    function selectedQuickPremiumSet() {
                        if (quickPremiumEmojiSets.length === 0) {
                            return null;
                        }
                        var selectedIndex = quickPremiumSelectedSetIndex;
                        if (selectedIndex < 0 || selectedIndex >= quickPremiumEmojiSets.length) {
                            selectedIndex = 0;
                        }
                        return quickPremiumEmojiSets[selectedIndex];
                    }

                    function refreshQuickPremiumEmojiSets() {
                        var result = [];
                        var sets = installedCustomEmojiSets || [];
                        var maxSets = quickPremiumSetLimit > 0 ? quickPremiumSetLimit : sets.length;
                        var maxPerSet = quickPremiumPerSetLimit > 0 ? quickPremiumPerSetLimit : 120;
                        for (var i = 0; i < sets.length && result.length < maxSets; i++) {
                            var currentSet = sets[i];
                            if (!currentSet || !currentSet.stickers) {
                                continue;
                            }
                            var setStickers = [];
                            var stickers = currentSet.stickers;
                            for (var j = 0; j < stickers.length && setStickers.length < maxPerSet; j++) {
                                var sticker = stickers[j];
                                var customEmojiId = customEmojiIdFromSticker(sticker);
                                if (customEmojiId === "") {
                                    continue;
                                }
                                sticker.custom_emoji_id = customEmojiId;
                                setStickers.push(sticker);
                            }
                            if (setStickers.length > 0) {
                                result.push({
                                    "id": currentSet.id ? currentSet.id.toString() : ("" + i),
                                    "title": currentSet.title ? currentSet.title : qsTr("Premium set"),
                                    "thumbnail": currentSet.thumbnail,
                                    "stickers": setStickers
                                });
                            }
                        }
                        quickPremiumEmojiSets = result;
                        if (quickPremiumSelectedSetIndex < 0 || quickPremiumSelectedSetIndex >= quickPremiumEmojiSets.length) {
                            quickPremiumSelectedSetIndex = 0;
                        }
                    }

                    // NIENTE listener su onInstalledCustomEmojiSetsChanged:
                    // l'assegnamento dentro il debounce sotto la fa "scattare"
                    // e si crea un feedback loop che rieseguiva il refresh
                    // ogni 80ms indefinitamente, causando lag visibile anche
                    // sulle animazioni delle custom emoji. La sincronizzazione
                    // viene fatta solo via signal dello StickerManager.

                    // Nessun pre-warming all'apertura: iterare 80 set × 120
                    // sticker (~9600 elementi) è sincrono e blocca la chat per
                    // 1-2s anche con Timer deferred (la chunked-yield non
                    // l'abbiamo). Il fallback lazy esiste già: al primo click
                    // sul bottone "premium emoji" (vedi sotto), se
                    // quickPremiumEmojiSets è vuoto, il refresh parte on-demand.
                    // Il debounce su onCustomEmojiStickerSetsReceived continua
                    // a coprire l'arrivo asincrono di nuovi set durante la
                    // sessione.

                    // Debounce: la rimozione di un set genera N response in
                    // cascata (una per ogni set restante che TDLib ci rimanda).
                    // Senza coalescenza, refreshQuickPremiumEmojiSets veniva
                    // chiamata N volte di fila e bloccava la UI. Coalesciamo
                    // a 80ms come fa StickerPicker.qml.
                    Timer {
                        id: refreshQuickPremiumDebounce
                        interval: 80
                        repeat: false
                        onTriggered: {
                            newMessageColumn.installedCustomEmojiSets = stickerManager.getInstalledCustomEmojiSets();
                            newMessageColumn.refreshQuickPremiumEmojiSets();
                        }
                    }
                    Connections {
                        target: stickerManager
                        onCustomEmojiStickerSetsReceived: {
                            refreshQuickPremiumDebounce.restart();
                        }
                        onStickerSetsReceived: {
                            newMessageColumn.refreshQuickStickerSets();
                        }
                    }

                    InReplyToRow {
                        onInReplyToMessageChanged: {
                            if (inReplyToMessage) {
                                newMessageColumn.replyToMessageId = newMessageInReplyToRow.inReplyToMessage.id.toString()
                                newMessageInReplyToRow.visible = true;
                            } else {
                                newMessageInReplyToRow.visible = false;
                                newMessageColumn.replyToMessageId = "0";
                            }
                        }

                        editable: true

                        onClearRequested: {
                            newMessageInReplyToRow.inReplyToMessage = null;
                        }

                        id: newMessageInReplyToRow
                        myUserId: chatPage.myUserId
                        visible: false
                    }

                    Flickable {
                        id: attachmentOptionsFlickable

                        property bool isNeeded: false
                        width: chatPage.width
                        x: -Theme.horizontalPageMargin
                        height: isNeeded && !inlineQuery.userNameIsValid ? attachmentOptionsRow.height : 0
                        Behavior on height { SmoothedAnimation { duration: 200 } }
                        visible: height > 0
                        contentHeight: attachmentOptionsRow.height
                        contentWidth: Math.max(width, attachmentOptionsRow.width)
                        property bool fadeRight: (attachmentOptionsRow.width-contentX) > width
                        property bool fadeLeft: !fadeRight && contentX > 0
                        layer.enabled: fadeRight || fadeLeft
                        layer.effect: OpacityRampEffectBase {
                            direction: attachmentOptionsFlickable.fadeRight ? OpacityRamp.LeftToRight : OpacityRamp.RightToLeft
                            source: attachmentOptionsFlickable
                            slope: 4
                            offset: 0.75
                        }


                        Row {
                            id: attachmentOptionsRow

                            height: attachImageIconButton.height
                            x: width <= parent.width ? ((parent.width - width) / 2) : (parent.width - width)
                            layoutDirection: Qt.RightToLeft
                            spacing: newMessageColumn.compactAttachmentSpacing
                            leftPadding: Theme.paddingSmall
                            rightPadding: Theme.paddingSmall

                            IconButton {
                                id: attachImageIconButton
                                visible: chatPage.hasSendPrivilege("can_send_photos")
                                width: newMessageColumn.compactAttachmentButtonSize
                                height: width
                                icon.source: "image://theme/icon-m-image"
                                onClicked: {
                                    var picker = pageStack.push("Sailfish.Pickers.MultiImagePickerDialog", {
                                        allowedOrientations: chatPage.allowedOrientations
                                    })
                                    var maxAlbumSize = 10;
                                    picker.accepted.connect(function() {
                                        if (!picker.selectedContent || picker.selectedContent.count === 0) {
                                            return;
                                        }
                                        var paths = [];
                                        var firstProps = null;
                                        var totalCount = picker.selectedContent.count;
                                        var count = Math.min(totalCount, maxAlbumSize);
                                        for (var i = 0; i < count; i++) {
                                            var entry = picker.selectedContent.get(i);
                                            if (entry && entry.filePath) {
                                                paths.push(entry.filePath);
                                                if (!firstProps) {
                                                    firstProps = {
                                                        filePath: entry.filePath,
                                                        fileName: entry.fileName,
                                                        url: entry.url,
                                                        mimeType: entry.mimeType,
                                                        fileSize: entry.fileSize
                                                    };
                                                }
                                            }
                                        }
                                        if (paths.length === 0) {
                                            return;
                                        }
                                        if (totalCount > maxAlbumSize) {
                                            appNotification.show(qsTr("Telegram allows up to %1 images per album.").arg(maxAlbumSize));
                                        }
                                        attachmentOptionsFlickable.isNeeded = false;
                                        newMessageColumn.quickEmojiPickerVisible = false;
                                        newMessageColumn.quickPremiumEmojiPickerVisible = false;
                                        Debug.log("Selected images: ", paths.length, paths[0]);
                                        attachmentPreviewRow.fileProperties = firstProps;
                                        attachmentPreviewRow.imagePaths = paths;
                                        attachmentPreviewRow.isPicture = true;
                                        controlSendButton();
                                    });
                                }
                            }
                            IconButton {
                                visible: !(chatPage.isPrivateChat || chatPage.isSecretChat) && chatPage.hasSendPrivilege("can_send_polls")
                                width: newMessageColumn.compactAttachmentButtonSize
                                height: width
                                icon.source: "image://theme/icon-m-question"
                                onClicked: {
                                    pageStack.push(Qt.resolvedUrl("../pages/PollCreationPage.qml"), { "chatId" : chatInformation.id, groupName: chatInformation.title});
                                    attachmentOptionsFlickable.isNeeded = false;
                                    newMessageColumn.quickEmojiPickerVisible = false;
                                    newMessageColumn.quickPremiumEmojiPickerVisible = false;
                                }
                            }
                            IconButton {
                                visible: chatPage.hasSendPrivilege("can_send_videos")
                                width: newMessageColumn.compactAttachmentButtonSize
                                height: width
                                icon.source: "image://theme/icon-m-video"
                                onClicked: {
                                    var picker = pageStack.push("Sailfish.Pickers.VideoPickerPage", {
                                        allowedOrientations: chatPage.allowedOrientations
                                    })
                                    picker.selectedContentPropertiesChanged.connect(function(){
                                        attachmentOptionsFlickable.isNeeded = false;
                                        newMessageColumn.quickEmojiPickerVisible = false;
                                        newMessageColumn.quickPremiumEmojiPickerVisible = false;
                                        Debug.log("Selected video: ", picker.selectedContentProperties.filePath );
                                        attachmentPreviewRow.fileProperties = picker.selectedContentProperties;
                                        attachmentPreviewRow.isVideo = true;
                                        controlSendButton();
                                    })
                                }
                            }
                            IconButton {
                                visible: chatPage.hasSendPrivilege("can_send_voice_notes")
                                width: newMessageColumn.compactAttachmentButtonSize
                                height: width
                                icon.source: "image://theme/icon-m-mic"
                                icon.sourceSize {
                                    width: Theme.iconSizeMedium
                                    height: Theme.iconSizeMedium
                                }
                                highlighted: down || voiceNoteOverlayLoader.active
                                onClicked: {
                                    voiceNoteOverlayLoader.active = !voiceNoteOverlayLoader.active;
                                    stickerPickerLoader.active = false;
                                    newMessageColumn.quickEmojiPickerVisible = false;
                                    newMessageColumn.quickPremiumEmojiPickerVisible = false;
                                }
                            }
                            IconButton {
                                visible: chatPage.hasSendPrivilege("can_send_documents")
                                width: newMessageColumn.compactAttachmentButtonSize
                                height: width
                                icon.source: "image://theme/icon-m-document"
                                onClicked: {
                                    var picker = pageStack.push("Sailfish.Pickers.FilePickerPage", {
                                        allowedOrientations: chatPage.allowedOrientations
                                    })
                                    picker.selectedContentPropertiesChanged.connect(function(){
                                        attachmentOptionsFlickable.isNeeded = false;
                                        newMessageColumn.quickEmojiPickerVisible = false;
                                        newMessageColumn.quickPremiumEmojiPickerVisible = false;
                                        Debug.log("Selected document: ", picker.selectedContentProperties.filePath );
                                        attachmentPreviewRow.fileProperties = picker.selectedContentProperties;
                                        attachmentPreviewRow.isDocument = true;
                                        controlSendButton();
                                    })
                                }
                            }
                            IconButton {
                                visible: chatPage.hasSendPrivilege("can_send_other_messages")
                                width: newMessageColumn.compactAttachmentButtonSize
                                height: width
                                icon.source: "../../images/icon-m-sticker.svg"
                                icon.sourceSize {
                                    width: Theme.iconSizeMedium
                                    height: Theme.iconSizeMedium
                                }
                                highlighted: down || newMessageColumn.quickStickerPickerVisible
                                onClicked: {
                                    if (!newMessageColumn.quickStickerPickerVisible) {
                                        newMessageColumn.refreshQuickStickerSets();
                                    }
                                    newMessageColumn.quickStickerPickerVisible = !newMessageColumn.quickStickerPickerVisible;
                                    stickerPickerLoader.active = false;
                                    voiceNoteOverlayLoader.active = false;
                                    newMessageColumn.quickEmojiPickerVisible = false;
                                    newMessageColumn.quickPremiumEmojiPickerVisible = false;
                                }
                            }
                            IconButton {
                                id: attachPremiumEmojiIconButton
                                visible: chatPage.canSendMessages
                                width: newMessageColumn.compactAttachmentButtonSize
                                height: width
                                icon.source: "../../images/icon-m-emoji.svg"
                                icon.sourceSize {
                                    width: Theme.iconSizeMedium
                                    height: Theme.iconSizeMedium
                                }
                                highlighted: down || newMessageColumn.quickPremiumEmojiPickerVisible
                                onClicked: {
                                    if (newMessageColumn.quickPremiumEmojiSets.length === 0) {
                                        newMessageColumn.refreshQuickPremiumEmojiSets();
                                    }
                                    if (!newMessageColumn.installedCustomEmojiSets
                                            || newMessageColumn.installedCustomEmojiSets.length === 0) {
                                        tdLibWrapper.getInstalledCustomEmojiSets();
                                    }
                                    newMessageColumn.quickPremiumEmojiPickerVisible = !newMessageColumn.quickPremiumEmojiPickerVisible;
                                    stickerPickerLoader.active = false;
                                    voiceNoteOverlayLoader.active = false;
                                    newMessageColumn.quickEmojiPickerVisible = false;
                                    newMessageColumn.quickStickerPickerVisible = false;
                                }
                                Label {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    text: "★"
                                    color: Theme.highlightColor
                                    font.pixelSize: Theme.fontSizeTiny
                                }
                            }
                            IconButton {
                                id: attachEmojiIconButton
                                visible: chatPage.canSendMessages
                                width: newMessageColumn.compactAttachmentButtonSize
                                height: width
                                icon.source: "../../images/icon-m-emoji.svg"
                                icon.sourceSize {
                                    width: Theme.iconSizeMedium
                                    height: Theme.iconSizeMedium
                                }
                                highlighted: down || newMessageColumn.quickEmojiPickerVisible
                                onClicked: {
                                    newMessageColumn.quickEmojiPickerVisible = !newMessageColumn.quickEmojiPickerVisible;
                                    newMessageColumn.quickPremiumEmojiPickerVisible = false;
                                    newMessageColumn.quickStickerPickerVisible = false;
                                    stickerPickerLoader.active = false;
                                    voiceNoteOverlayLoader.active = false;
                                }
                            }
                            IconButton {
                                visible: rootelegramUtils.supportsGeoLocation() && newMessageTextField.text === ""
                                width: newMessageColumn.compactAttachmentButtonSize
                                height: width
                                icon.source: "image://theme/icon-m-location"
                                icon.sourceSize {
                                    width: Theme.iconSizeMedium
                                    height: Theme.iconSizeMedium
                                }
                                onClicked: {
                                    rootelegramUtils.startGeoLocationUpdates();
                                    attachmentOptionsFlickable.isNeeded = false;
                                    newMessageColumn.quickEmojiPickerVisible = false;
                                    newMessageColumn.quickPremiumEmojiPickerVisible = false;
                                    attachmentPreviewRow.isLocation = true;
                                    attachmentPreviewRow.attachmentDescription = qsTr("Location: Obtaining position...");
                                    controlSendButton();
                                }
                            }
                        }

                    }


                    Item {
                        id: quickEmojiPickerContainer
                        width: parent.width
                        visible: newMessageColumn.quickEmojiPickerVisible && !inlineQuery.userNameIsValid
                        height: visible ? emojiPickerLoader.height : 0
                        clip: true
                        Behavior on height { SmoothedAnimation { duration: 160 } }

                        Loader {
                            id: emojiPickerLoader
                            width: parent.width
                            active: quickEmojiPickerContainer.visible
                            sourceComponent: EmojiPicker {
                                onEmojiPicked: {
                                    insertTextAtCursor(emoji);
                                    attachmentOptionsFlickable.isNeeded = false;
                                    newMessageColumn.quickEmojiPickerVisible = false;
                                    newMessageColumn.quickPremiumEmojiPickerVisible = false;
                                }
                            }
                        }
                    }

                    Item {
                        id: quickPremiumEmojiPickerContainer
                        width: parent.width
                        visible: newMessageColumn.quickPremiumEmojiPickerVisible && !inlineQuery.userNameIsValid
                        height: visible ? quickPremiumEmojiPanelColumn.height : 0
                        clip: true
                        Behavior on height { SmoothedAnimation { duration: 160 } }
                        Column {
                            id: quickPremiumEmojiPanelColumn
                            width: parent.width
                            height: childrenRect.height
                            spacing: Theme.paddingSmall

                            Flickable {
                                id: quickPremiumSetFlickable
                                width: parent.width
                                height: newMessageColumn.quickPremiumEmojiSets.length > 0 ? (newMessageColumn.compactAttachmentButtonSize + Theme.paddingSmall) : 0
                                visible: newMessageColumn.quickPremiumEmojiSets.length > 0
                                contentWidth: Math.max(width, quickPremiumSetRow.width)
                                contentHeight: quickPremiumSetRow.height
                                clip: true

                                Row {
                                    id: quickPremiumSetRow
                                    height: newMessageColumn.compactAttachmentButtonSize
                                    // LTR: il primo set (index 0, alfabeticamente "A") va a sinistra.
                                    // Quando la Row è più stretta della Flickable la centriamo;
                                    // quando è più larga la lasciamo allineata a sinistra (scrolla a destra).
                                    x: width <= parent.width ? ((parent.width - width) / 2) : 0
                                    spacing: newMessageColumn.compactAttachmentSpacing
                                    leftPadding: Theme.paddingSmall
                                    rightPadding: Theme.paddingSmall

                                    Repeater {
                                        model: newMessageColumn.quickPremiumEmojiSets
                                        BackgroundItem {
                                            id: quickPremiumSetButton
                                            width: Math.min(Math.max(setTitleLabel.implicitWidth + Theme.paddingMedium * 2, Theme.itemSizeMedium), Theme.itemSizeExtraLarge * 2)
                                            height: newMessageColumn.compactAttachmentButtonSize
                                            readonly property bool isCurrentSet: index === newMessageColumn.quickPremiumSelectedSetIndex

                                            onClicked: {
                                                newMessageColumn.quickPremiumSelectedSetIndex = index;
                                            }
                                            onPressAndHold: {
                                                if (!modelData || !modelData.id) return;
                                                chatPage.requestDeleteSet(modelData.id, "stickerTypeCustomEmoji", modelData.title);
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: height / 2
                                                color: quickPremiumSetButton.isCurrentSet ? Theme.rgba(Theme.highlightColor, 0.28) : Theme.rgba(Theme.primaryColor, 0.12)
                                            }

                                            Label {
                                                id: setTitleLabel
                                                anchors.centerIn: parent
                                                width: parent.width - Theme.paddingSmall
                                                text: modelData && modelData.title ? modelData.title : qsTr("Premium set")
                                                color: quickPremiumSetButton.isCurrentSet ? Theme.highlightColor : Theme.primaryColor
                                                font.pixelSize: Theme.fontSizeExtraSmall
                                                maximumLineCount: 1
                                                truncationMode: TruncationMode.Elide
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                    }
                                }
                            }

                            GridView {
                                id: quickPremiumEmojiGridView
                                width: parent.width
                                height: newMessageColumn.quickPremiumEmojiSets.length > 0 ? ((newMessageColumn.compactAttachmentButtonSize * 3) + Theme.paddingSmall) : 0
                                cellWidth: newMessageColumn.compactAttachmentButtonSize
                                cellHeight: newMessageColumn.compactAttachmentButtonSize
                                clip: true
                                model: {
                                    var selectedSet = newMessageColumn.selectedQuickPremiumSet();
                                    return selectedSet && selectedSet.stickers ? selectedSet.stickers : [];
                                }
                                delegate: BackgroundItem {
                                    id: quickPremiumEmojiButton
                                    width: quickPremiumEmojiGridView.cellWidth
                                    height: quickPremiumEmojiGridView.cellHeight
                                    property var stickerData: modelData
                                    property string customEmojiId: newMessageColumn.customEmojiIdFromSticker(stickerData)
                                    property string fallbackEmoji: stickerData && stickerData.emoji ? stickerData.emoji : "⭐"

                                    onClicked: {
                                        if (customEmojiId === "") {
                                            return;
                                        }
                                        insertCustomEmojiAtCursor(customEmojiId, fallbackEmoji);
                                        attachmentOptionsFlickable.isNeeded = false;
                                        newMessageColumn.quickPremiumEmojiPickerVisible = false;
                                        newMessageColumn.quickEmojiPickerVisible = false;
                                    }

                                    TDLibThumbnail {
                                        anchors.fill: parent
                                        thumbnail: stickerData ? stickerData.thumbnail : null
                                        highlighted: quickPremiumEmojiButton.highlighted
                                    }

                                    Label {
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        font.pixelSize: Theme.fontSizeTiny
                                        text: Emoji.emojify(fallbackEmoji, font.pixelSize)
                                    }
                                }

                                VerticalScrollDecorator {}
                            }

                            Label {
                                width: parent.width - Theme.paddingMedium * 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: newMessageColumn.quickPremiumEmojiSets.length === 0
                                text: qsTr("No premium emoji set available")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    Item {
                        id: quickStickerPickerContainer
                        width: parent.width
                        visible: newMessageColumn.quickStickerPickerVisible && !inlineQuery.userNameIsValid
                        height: visible ? quickStickerPanelColumn.height : 0
                        clip: true
                        Behavior on height { SmoothedAnimation { duration: 160 } }
                        Column {
                            id: quickStickerPanelColumn
                            width: parent.width
                            height: childrenRect.height
                            spacing: Theme.paddingSmall

                            Flickable {
                                id: quickStickerSetFlickable
                                width: parent.width
                                height: newMessageColumn.compactAttachmentButtonSize + Theme.paddingSmall
                                contentWidth: Math.max(width, quickStickerSetRow.width)
                                contentHeight: quickStickerSetRow.height
                                clip: true

                                Row {
                                    id: quickStickerSetRow
                                    height: newMessageColumn.compactAttachmentButtonSize
                                    x: width <= parent.width ? ((parent.width - width) / 2) : 0
                                    spacing: newMessageColumn.compactAttachmentSpacing
                                    leftPadding: Theme.paddingSmall
                                    rightPadding: Theme.paddingSmall

                                    BackgroundItem {
                                        id: quickStickerRecentsChip
                                        width: Math.max(recentsChipLabel.implicitWidth + Theme.paddingMedium * 2, Theme.itemSizeMedium)
                                        height: newMessageColumn.compactAttachmentButtonSize
                                        readonly property bool isCurrent: newMessageColumn.quickStickerSelectedSetIndex === -1
                                        onClicked: newMessageColumn.quickStickerSelectedSetIndex = -1
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: height / 2
                                            color: quickStickerRecentsChip.isCurrent ? Theme.rgba(Theme.highlightColor, 0.28) : Theme.rgba(Theme.primaryColor, 0.12)
                                        }
                                        Label {
                                            id: recentsChipLabel
                                            anchors.centerIn: parent
                                            text: qsTr("Recent")
                                            color: quickStickerRecentsChip.isCurrent ? Theme.highlightColor : Theme.primaryColor
                                            font.pixelSize: Theme.fontSizeExtraSmall
                                        }
                                    }

                                    Repeater {
                                        model: newMessageColumn.quickStickerSets
                                        BackgroundItem {
                                            id: quickStickerSetButton
                                            width: Math.min(Math.max(stickerSetLabel.implicitWidth + Theme.paddingMedium * 2, Theme.itemSizeMedium), Theme.itemSizeExtraLarge * 2)
                                            height: newMessageColumn.compactAttachmentButtonSize
                                            readonly property bool isCurrent: index === newMessageColumn.quickStickerSelectedSetIndex
                                            onClicked: newMessageColumn.quickStickerSelectedSetIndex = index
                                            onPressAndHold: {
                                                if (!modelData || !modelData.id) return;
                                                var stype = (modelData.sticker_type && modelData.sticker_type["@type"])
                                                            ? modelData.sticker_type["@type"] : "stickerTypeRegular";
                                                chatPage.requestDeleteSet(modelData.id, stype, modelData.title);
                                            }
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: height / 2
                                                color: quickStickerSetButton.isCurrent ? Theme.rgba(Theme.highlightColor, 0.28) : Theme.rgba(Theme.primaryColor, 0.12)
                                            }
                                            Label {
                                                id: stickerSetLabel
                                                anchors.centerIn: parent
                                                width: parent.width - Theme.paddingSmall
                                                text: modelData && modelData.title ? modelData.title : qsTr("Sticker set")
                                                color: quickStickerSetButton.isCurrent ? Theme.highlightColor : Theme.primaryColor
                                                font.pixelSize: Theme.fontSizeExtraSmall
                                                maximumLineCount: 1
                                                truncationMode: TruncationMode.Elide
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                    }
                                }
                            }

                            GridView {
                                id: quickStickerGridView
                                width: parent.width
                                height: (newMessageColumn.compactAttachmentButtonSize * 3) + Theme.paddingSmall
                                cellWidth: newMessageColumn.compactAttachmentButtonSize
                                cellHeight: newMessageColumn.compactAttachmentButtonSize
                                clip: true
                                model: newMessageColumn.selectedQuickStickerList()
                                delegate: BackgroundItem {
                                    id: quickStickerButton
                                    width: quickStickerGridView.cellWidth
                                    height: quickStickerGridView.cellHeight
                                    onClicked: {
                                        var sid = newMessageColumn.stickerRemoteIdFromSticker(modelData);
                                        if (sid === "") return;
                                        stickerManager.setNeedsReload(true);
                                        tdLibWrapper.sendStickerMessage(chatInformation.id, sid, newMessageColumn.replyToMessageId);
                                        attachmentOptionsFlickable.isNeeded = false;
                                        newMessageInReplyToRow.inReplyToMessage = null;
                                        newMessageColumn.editMessageId = "0";
                                        newMessageColumn.quickStickerPickerVisible = false;
                                    }
                                    TDLibThumbnail {
                                        anchors.fill: parent
                                        thumbnail: modelData ? modelData.thumbnail : null
                                        highlighted: quickStickerButton.highlighted
                                    }
                                    Label {
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        font.pixelSize: Theme.fontSizeTiny
                                        text: modelData && modelData.emoji ? Emoji.emojify(modelData.emoji, font.pixelSize) : ""
                                    }
                                }
                                VerticalScrollDecorator {}
                            }

                            Label {
                                width: parent.width - Theme.paddingMedium * 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: quickStickerGridView.count === 0
                                text: newMessageColumn.quickStickerSelectedSetIndex === -1
                                      ? qsTr("No recent stickers")
                                      : qsTr("No stickers in this set")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    Row {
                        id: attachmentPreviewRow
                        visible: (!!locationData || !!fileProperties || isVoiceNote) && !inlineQuery.userNameIsValid
                        spacing: Theme.paddingMedium
                        width: parent.width
                        layoutDirection: Qt.RightToLeft
                        anchors.right: parent.right

                        property bool isPicture: false;
                        property bool isVideo: false;
                        property bool isDocument: false;
                        property bool isVoiceNote: false;
                        property bool isLocation: false;
                        property var locationData: null;
                        property var geocodedAddress: qsTr("Unknown address")
                        property var fileProperties: null;
                        property var imagePaths: [];
                        property string attachmentDescription: "";
                        property real landscapePreviewAspectRatio: (16.0 / 9.0);
                        property real portraitPreviewAspectRatio: (9.0 / 16.0);
                        property real picturePreviewAspectRatio: landscapePreviewAspectRatio;
                        readonly property real previewAreaBase: Theme.itemSizeMedium * Theme.itemSizeMedium;
                        readonly property real picturePreviewWidth: Math.round(Math.sqrt(previewAreaBase * picturePreviewAspectRatio));
                        readonly property real picturePreviewHeight: Math.round(Math.sqrt(previewAreaBase / picturePreviewAspectRatio));

                        function getLocationDescription() {
                            return qsTr("Location (%1/%2)").arg(attachmentPreviewRow.locationData.latitude).arg(attachmentPreviewRow.locationData.longitude) + " | "
                                    + qsTr("Accuracy: %1m").arg(attachmentPreviewRow.locationData.horizontalAccuracy) + "\n"
                                    + attachmentPreviewRow.geocodedAddress;
                        }
                        function getAttachmentFileUrl() {
                            if (!attachmentPreviewRow.fileProperties) {
                                return "";
                            }
                            var directUrl = attachmentPreviewRow.fileProperties.url ? attachmentPreviewRow.fileProperties.url.toString() : "";
                            if (directUrl !== "") {
                                return directUrl;
                            }
                            var filePath = attachmentPreviewRow.fileProperties.filePath ? attachmentPreviewRow.fileProperties.filePath.toString() : "";
                            if (filePath === "") {
                                return "";
                            }
                            if (filePath.indexOf("file://") === 0) {
                                return filePath;
                            }
                            return "file://" + encodeURI(filePath);
                        }

                        function updatePicturePreviewAspectRatio() {
                            if (!attachmentPreviewRow.isPicture || !attachmentPreviewRow.fileProperties) {
                                attachmentPreviewRow.picturePreviewAspectRatio = attachmentPreviewRow.landscapePreviewAspectRatio;
                                return;
                            }

                            var pixelWidth = Number(attachmentPreviewRow.fileProperties.width || attachmentPreviewRow.fileProperties.imageWidth || attachmentPreviewRow.fileProperties.pixelWidth || 0);
                            var pixelHeight = Number(attachmentPreviewRow.fileProperties.height || attachmentPreviewRow.fileProperties.imageHeight || attachmentPreviewRow.fileProperties.pixelHeight || 0);
                            var orientationValue = Number(
                                        attachmentPreviewRow.fileProperties.orientation
                                        || attachmentPreviewRow.fileProperties.imageOrientation
                                        || attachmentPreviewRow.fileProperties.exifOrientation
                                        || 0);

                            if (orientationValue >= 5 && orientationValue <= 8) {
                                var swappedWidth = pixelWidth;
                                pixelWidth = pixelHeight;
                                pixelHeight = swappedWidth;
                            }

                            if (!(pixelWidth > 0 && pixelHeight > 0) && attachmentPreviewOrientationProbe.status === Image.Ready) {
                                pixelWidth = Number(attachmentPreviewOrientationProbe.implicitWidth || attachmentPreviewOrientationProbe.sourceSize.width || 0);
                                pixelHeight = Number(attachmentPreviewOrientationProbe.implicitHeight || attachmentPreviewOrientationProbe.sourceSize.height || 0);
                            }

                            if (!(pixelWidth > 0 && pixelHeight > 0)) {
                                attachmentPreviewRow.picturePreviewAspectRatio = attachmentPreviewRow.landscapePreviewAspectRatio;
                                return;
                            }

                            attachmentPreviewRow.picturePreviewAspectRatio = (pixelHeight > pixelWidth)
                                    ? attachmentPreviewRow.portraitPreviewAspectRatio
                                    : attachmentPreviewRow.landscapePreviewAspectRatio;
                        }

                        onFilePropertiesChanged: updatePicturePreviewAspectRatio()
                        onIsPictureChanged: updatePicturePreviewAspectRatio()

                        Connections {
                            target: rootelegramUtils
                            onNewPositionInformation: {
                                attachmentPreviewRow.locationData = positionInformation;
                                if (attachmentPreviewRow.isLocation) {
                                    attachmentPreviewRow.attachmentDescription = attachmentPreviewRow.getLocationDescription();
                                }
                            }
                            onNewGeocodedAddress: {
                                attachmentPreviewRow.geocodedAddress = geocodedAddress;
                                if (attachmentPreviewRow.isLocation) {
                                    attachmentPreviewRow.attachmentDescription = attachmentPreviewRow.getLocationDescription();
                                }
                            }
                        }

                        Image {
                            id: attachmentPreviewOrientationProbe
                            visible: false
                            asynchronous: true
                            autoTransform: true
                            source: (attachmentPreviewRow.isPicture && !!attachmentPreviewRow.fileProperties) ? attachmentPreviewRow.getAttachmentFileUrl() : ""
                            onStatusChanged: attachmentPreviewRow.updatePicturePreviewAspectRatio()
                        }
                        IconButton {
                            id: removeAttachmentsIconButton
                            icon.source: "image://theme/icon-m-clear"
                            onClicked: {
                                clearAttachmentPreviewRow();
                                controlSendButton();
                            }
                        }

                        Thumbnail {
                            id: attachmentPreviewImage
                            width: attachmentPreviewRow.isPicture ? attachmentPreviewRow.picturePreviewWidth : Theme.itemSizeMedium
                            height: attachmentPreviewRow.isPicture ? attachmentPreviewRow.picturePreviewHeight : Theme.itemSizeMedium
                            sourceSize.width: width
                            sourceSize.height: height

                            fillMode: Thumbnail.PreserveAspectCrop
                            mimeType: !!attachmentPreviewRow.fileProperties ? attachmentPreviewRow.fileProperties.mimeType || "" : ""
                            source: !!attachmentPreviewRow.fileProperties ? attachmentPreviewRow.getAttachmentFileUrl() : ""
                            visible: attachmentPreviewRow.isPicture || attachmentPreviewRow.isVideo

                            Rectangle {
                                id: albumCountBadge
                                visible: attachmentPreviewRow.isPicture && attachmentPreviewRow.imagePaths && attachmentPreviewRow.imagePaths.length > 1
                                anchors {
                                    right: parent.right
                                    bottom: parent.bottom
                                    margins: Theme.paddingSmall
                                }
                                width: albumCountLabel.implicitWidth + Theme.paddingMedium
                                height: albumCountLabel.implicitHeight + Theme.paddingSmall
                                radius: height / 2
                                color: Theme.rgba(Theme.highlightBackgroundColor, Theme.opacityHigh)

                                Label {
                                    id: albumCountLabel
                                    anchors.centerIn: parent
                                    text: "+" + (attachmentPreviewRow.imagePaths ? attachmentPreviewRow.imagePaths.length : 0)
                                    color: Theme.primaryColor
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    font.bold: true
                                }
                            }
                        }

                        Label {
                            id: attachmentPreviewText
                            font.pixelSize: Theme.fontSizeSmall
                            text: ( attachmentPreviewRow.isVoiceNote || attachmentPreviewRow.isLocation ) ? attachmentPreviewRow.attachmentDescription : ( !!attachmentPreviewRow.fileProperties ? attachmentPreviewRow.fileProperties.fileName || "" : "" );
                            anchors.verticalCenter: parent.verticalCenter

                            width: parent.width - removeAttachmentsIconButton.width - Theme.paddingMedium
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                            truncationMode: TruncationMode.Fade
                            color: Theme.secondaryColor
                            visible: attachmentPreviewRow.isDocument || attachmentPreviewRow.isVoiceNote || attachmentPreviewRow.isLocation
                        }
                    }

                    Row {
                        id: uploadStatusRow
                        visible: false
                        spacing: Theme.paddingMedium
                        width: parent.width
                        anchors.right: parent.right

                        Text {
                            id: uploadingText
                            font.pixelSize: Theme.fontSizeSmall
                            text: qsTr("Uploading...")
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.secondaryColor
                            visible: uploadStatusRow.visible
                        }

                        ProgressBar {
                            id: uploadingProgressBar
                            minimumValue: 0
                            maximumValue: 100
                            value: 0
                            visible: uploadStatusRow.visible
                            width: parent.width - uploadingText.width - Theme.paddingMedium
                        }

                    }

                    Column {
                        id: emojiColumn
                        width: parent.width
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: emojiProposals ? ( emojiProposals.length > 0 ? true : false ) : false
                        opacity: emojiProposals ? ( emojiProposals.length > 0 ? 1 : 0 ) : 0
                        Behavior on opacity { NumberAnimation {} }
                        spacing: Theme.paddingMedium

                        Flickable {
                            width: parent.width
                            height: emojiResultRow.height + Theme.paddingSmall
                            anchors.horizontalCenter: parent.horizontalCenter
                            contentWidth: emojiResultRow.width
                            clip: true
                            Row {
                                id: emojiResultRow
                                spacing: Theme.paddingMedium
                                Repeater {
                                    model: emojiProposals

                                    Item {
                                        height: singleEmojiRow.height
                                        width: singleEmojiRow.width

                                        Row {
                                            id: singleEmojiRow
                                            spacing: Theme.paddingSmall

                                            Image {
                                                id: emojiPicture
                                                source: "../js/emoji/" + modelData.file_name +".svg"
                                                width: Theme.fontSizeLarge
                                                height: Theme.fontSizeLarge
                                            }

                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                replaceMessageText(newMessageTextField.text, newMessageTextField.cursorPosition, modelData.emoji);
                                                emojiProposals = null;
                                            }
                                        }
                                    }

                                }
                            }
                        }
                    }

                    Column {
                        id: atMentionColumn
                        width: parent.width
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: opacity > 0
                        opacity: knownUsersRepeater.count > 0 ? 1 : 0
                        Behavior on opacity { NumberAnimation {} }
                        height: knownUsersRepeater.count > 0 ? childrenRect.height : 0
                        Behavior on height { SmoothedAnimation { duration: 200 } }
                        spacing: Theme.paddingMedium

                        Flickable {
                            width: parent.width
                            height: atMentionResultRow.height + Theme.paddingSmall
                            anchors.horizontalCenter: parent.horizontalCenter
                            contentWidth: atMentionResultRow.width
                            clip: true
                            Row {
                                id: atMentionResultRow
                                spacing: Theme.paddingMedium
                                Repeater {
                                    id: knownUsersRepeater

                                    Item {
                                        id: knownUserItem
                                        height: singleAtMentionRow.height
                                        width: singleAtMentionRow.width

                                        property string atMentionText: "@" + (user_name ? user_name : user_id + "(" + title + ")");

                                        Row {
                                            id: singleAtMentionRow
                                            spacing: Theme.paddingSmall

                                            Item {
                                                width: Theme.fontSizeHuge
                                                height: Theme.fontSizeHuge
                                                anchors.verticalCenter: parent.verticalCenter
                                                ProfileThumbnail {
                                                    id: atMentionThumbnail
                                                    replacementStringHint: title
                                                    width: parent.width
                                                    height: parent.width
                                                    photoData: photo_small
                                                }
                                            }

                                            Column {
                                                Text {
                                                    text: Emoji.emojify(title, Theme.fontSizeExtraSmall)
                                                    textFormat: Text.StyledText
                                                    color: Theme.primaryColor
                                                    font.pixelSize: Theme.fontSizeExtraSmall
                                                    font.bold: true
                                                }
                                                Text {
                                                    id: userHandleText
                                                    text: user_handle
                                                    textFormat: Text.StyledText
                                                    color: Theme.primaryColor
                                                    font.pixelSize: Theme.fontSizeExtraSmall
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                replaceMessageText(newMessageTextField.text, newMessageTextField.cursorPosition, knownUserItem.atMentionText);
                                                knownUsersRepeater.model = undefined;
                                            }
                                        }
                                    }

                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingSmall
                        visible: newMessageColumn.editMessageId !== "0"

                        Text {
                            width: parent.width - Theme.paddingSmall - removeEditMessageIconButton.width

                            anchors.verticalCenter: parent.verticalCenter

                            id: editMessageText
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            text: qsTr("Edit Message")
                            color: Theme.secondaryColor
                        }

                        IconButton {
                            id: removeEditMessageIconButton
                            icon.source: "image://theme/icon-m-clear"
                            onClicked: {
                                newMessageColumn.editMessageId = "0";
                                newMessageColumn.customEmojiEntities = [];
                                newMessageColumn.previousComposerText = "";
                                newMessageTextField.text = "";
                            }
                        }
                    }

                    Item {
                        id: formattingRow
                        width: parent.width
                        height: Theme.itemSizeExtraSmall
                        visible: chatPage.canSendMessages && !inlineQuery.userNameIsValid

                        // Globo traduzione: staccato dai tasti formato, allineato a sinistra,
                        // stessa dimensione. Sempre visibile; toast se il testo è vuoto.
                        Item {
                            id: translateFormatButton
                            width: newMessageColumn.compactAttachmentButtonSize
                            height: width
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: newMessageColumn.translatingInput ? 0.4 : 1.0
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Theme.rgba(Theme.primaryColor, 0.16)
                            }
                            Image {
                                anchors.centerIn: parent
                                source: "image://theme/icon-m-website?" + Theme.primaryColor
                                width: parent.width * 0.62
                                height: width
                                sourceSize.width: width
                                sourceSize.height: height
                                smooth: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: !newMessageColumn.translatingInput
                                onClicked: {
                                    if (newMessageTextField.text.length > 0) {
                                        newMessageColumn.translatingInput = true
                                        newMessageColumn.originalInputText = newMessageTextField.text
                                        tdLibWrapper.translateText(newMessageTextField.text, chatPage.translateOutgoingLanguage)
                                    } else {
                                        appNotification.show(qsTr("Type your message first, then tap this button to translate it to English!"))
                                    }
                                }
                            }
                        }

                        Row {
                            id: formattingButtonsRow
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: Theme.itemSizeExtraSmall
                            layoutDirection: Qt.RightToLeft
                            spacing: newMessageColumn.compactAttachmentSpacing

                        Item {
                            width: newMessageColumn.compactAttachmentButtonSize
                            height: width
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Theme.rgba(Theme.primaryColor, 0.16)
                            }
                            Label {
                                anchors.centerIn: parent
                                text: "B"
                                font.bold: true
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.primaryColor
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    applyInlineFormatting("**", "**");
                                }
                            }
                        }

                        Item {
                            width: newMessageColumn.compactAttachmentButtonSize
                            height: width
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Theme.rgba(Theme.primaryColor, 0.16)
                            }
                            Label {
                                anchors.centerIn: parent
                                text: "I"
                                font.italic: true
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.primaryColor
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    applyInlineFormatting("__", "__");
                                }
                            }
                        }
                        Item {
                            width: newMessageColumn.compactAttachmentButtonSize
                            height: width
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Theme.rgba(Theme.primaryColor, 0.16)
                            }
                            Label {
                                anchors.centerIn: parent
                                text: "U"
                                font.underline: true
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.primaryColor
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    applyInlineFormatting("++", "++");
                                }
                            }
                        }

                        Item {
                            width: newMessageColumn.compactAttachmentButtonSize
                            height: width
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Theme.rgba(Theme.primaryColor, 0.16)
                            }
                            Label {
                                anchors.centerIn: parent
                                text: "S"
                                font.strikeout: true
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.primaryColor
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    applyInlineFormatting("~~", "~~");
                                }
                            }
                        }

                        Item {
                            width: newMessageColumn.compactAttachmentButtonSize
                            height: width
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Theme.rgba(Theme.primaryColor, 0.16)
                            }
                            Label {
                                anchors.centerIn: parent
                                text: "{ }"
                                font.pixelSize: Theme.fontSizeTiny
                                color: Theme.primaryColor
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    applyInlineFormatting("`", "`");
                                }
                            }
                        }

                        Item {
                            width: newMessageColumn.compactAttachmentButtonSize
                            height: width
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Theme.rgba(Theme.primaryColor, 0.16)
                            }
                            Label {
                                anchors.centerIn: parent
                                text: "||"
                                font.bold: true
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.primaryColor
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    applyInlineFormatting("||", "||");
                                }
                            }
                        }
                        }
                    }

                    Row {
                        id: newMessageRow
                        width: parent.width
                        anchors.horizontalCenter: parent.horizontalCenter

                        TextArea {
                            id: newMessageTextField
                            width: parent.width - (attachmentIconButton.visible ? attachmentIconButton.width : 0) - (newMessageSendButton.visible ? newMessageSendButton.width : 0) - (cancelInlineQueryButton.visible ? cancelInlineQueryButton.width : 0)
                            height: Math.min(chatContainer.height / 3, implicitHeight)
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: Theme.fontSizeSmall
                            placeholderText: qsTr("Your message")
                            labelVisible: false
                            textLeftMargin: 0
                            textTopMargin: 0
                            enabled: !attachmentPreviewRow.isLocation
                            focus: appSettings.focusTextAreaOnChatOpen
                            EnterKey.onClicked: {
                                if (appSettings.sendByEnter) {
                                    var messageText = newMessageTextField.text;
                                    newMessageTextField.text = messageText.substring(0, newMessageTextField.cursorPosition -1) + messageText.substring(newMessageTextField.cursorPosition);
                                    sendMessage();
                                    newMessageTextField.text = "";
                                    if(!appSettings.focusTextAreaAfterSend) {
                                        newMessageTextField.focus = false;
                                    }
                                }
                            }

                            EnterKey.enabled: !inlineQuery.userNameIsValid && (!appSettings.sendByEnter || text.length)
                            EnterKey.iconSource: appSettings.sendByEnter ? "image://theme/icon-m-chat" : "image://theme/icon-m-enter"

                            onTextChanged: {
                                adjustComposerCustomEmojiEntities(newMessageColumn.previousComposerText, newMessageTextField.text);
                                newMessageColumn.previousComposerText = newMessageTextField.text || "";
                                controlSendButton();
                                textReplacementTimer.restart();
                            }
                            onActiveFocusChanged: {
                                if (activeFocus) {
                                    messageOptionsDrawer.open = false
                                }
                            }
                        }

                        IconButton {
                            id: attachmentIconButton
                            icon.source: "image://theme/icon-m-attach?" +  (attachmentOptionsFlickable.isNeeded ? Theme.highlightColor : Theme.primaryColor)
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Theme.paddingSmall
                            enabled: !attachmentPreviewRow.visible && !stickerSetOverlayLoader.item
                            visible: !inlineQuery.userNameIsValid
                            onClicked: {
                                if (attachmentOptionsFlickable.isNeeded) {
                                    attachmentOptionsFlickable.isNeeded = false;
                                    stickerPickerLoader.active = false;
                                    voiceNoteOverlayLoader.active = false;
                                    newMessageColumn.quickEmojiPickerVisible = false;
                                    newMessageColumn.quickPremiumEmojiPickerVisible = false;
                                } else {
                                    attachmentOptionsFlickable.isNeeded = true;
                                    newMessageColumn.quickEmojiPickerVisible = false;
                                    newMessageColumn.quickPremiumEmojiPickerVisible = false;
                                }
                            }
                        }

                        IconButton {
                            id: newMessageSendButton
                            icon.source: "image://theme/icon-m-enter"
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Theme.paddingSmall
                            visible: !inlineQuery.userNameIsValid && (!appSettings.sendByEnter || attachmentPreviewRow.visible)
                            enabled: true
                            opacity: 0.4
                            property bool hasContent: false
                            onClicked: {
                                if (!hasContent) return;
                                sendMessage();
                                newMessageTextField.text = "";
                                if(!appSettings.focusTextAreaAfterSend) {
                                    newMessageTextField.focus = false;
                                }
                            }
                            onPressAndHold: {
                                var dialog = pageStack.push(Qt.resolvedUrl("ScheduleMessageDialog.qml"), {
                                    chatIdString: chatInformation.id ? chatInformation.id.toString() : "0"
                                });
                                dialog.accepted.connect(function() {
                                    var ts = Math.floor(dialog.selectedDateTime.getTime() / 1000);
                                    sendMessage(ts);
                                    newMessageTextField.text = "";
                                    if(!appSettings.focusTextAreaAfterSend) {
                                        newMessageTextField.focus = false;
                                    }
                                    if (typeof appNotification !== 'undefined') {
                                        appNotification.show(qsTr("Scheduled for %1").arg(Qt.formatDateTime(dialog.selectedDateTime, "d MMM hh:mm")));
                                    }
                                });
                            }
                        }

                        Item {
                            width: cancelInlineQueryButton.width
                            height: cancelInlineQueryButton.height
                            visible: inlineQuery.userNameIsValid
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Theme.paddingSmall

                            IconButton {
                                id: cancelInlineQueryButton
                                icon.source: "image://theme/icon-m-cancel"
                                visible: parent.visible
                                opacity: inlineQuery.isLoading ? 0.2 : 1
                                Behavior on opacity { FadeAnimation {} }
                                onClicked: {
                                    if(inlineQuery.query !== "") {
                                        newMessageTextField.text = "@" + inlineQuery.userName + " "
                                        newMessageTextField.cursorPosition = newMessageTextField.text.length
                                        lostFocusTimer.start();
                                    } else {
                                        newMessageTextField.text = ""
                                    }
                                }
                                onPressAndHold: {
                                    newMessageTextField.text = ""
                                }
                            }

                            BusyIndicator {
                                size: BusyIndicatorSize.Small
                                anchors.centerIn: parent
                                running: inlineQuery.isLoading
                            }
                        }


                    }
                }
            }
        }


    }


    Loader {
        id: selectedMessagesActions
        asynchronous: true
        anchors.bottom: parent.bottom
        readonly property bool isNeeded: chatPage.isSelecting
        active: height > 0
        width: parent.width
        height: isNeeded ? Theme.itemSizeMedium : 0
        Behavior on height { SmoothedAnimation { duration: 200 } }
        sourceComponent: Component {
            Item {
                clip: true

                IconButton {
                    anchors {
                        left: parent.left
                        leftMargin: Theme.horizontalPageMargin
                        verticalCenter: parent.verticalCenter
                    }
                    icon.source: "image://theme/icon-m-cancel"
                    onClicked: {
                        chatPage.selectedMessages = [];
                    }
                }

                Row {
                    spacing: Theme.paddingSmall
                    anchors {
                        right: parent.right
                        rightMargin: Theme.horizontalPageMargin
                        verticalCenter: parent.verticalCenter
                    }

                    IconButton {
                        icon.source: "image://theme/icon-m-edit"
                        visible: selectedMessages.length === 1 &&
                                 selectedMessages[0] &&
                                 (selectedMessages[0].can_be_edited === true ||
                                  ((selectedMessages[0].sender_id && selectedMessages[0].sender_id.user_id === chatPage.myUserId) &&
                                   selectedMessages[0].content &&
                                   selectedMessages[0].content["@type"] === "messageText"))
                        icon.sourceSize: Qt.size(Theme.iconSizeMedium, Theme.iconSizeMedium)
                        onClicked: {
                            var selectedMessage = selectedMessages[0];
                            chatPage.beginMessageEdit(selectedMessage.id.toString(), selectedMessage);
                            chatPage.selectedMessages = [];
                        }
                    }

                    // Copia SOLO il testo selezionato del singolo messaggio attivo.
                    // Collocata tra la penna (edit) e l'icona "copia intero messaggio".
                    IconButton {
                        icon.source: "image://theme/icon-m-clipboard"
                        icon.sourceSize: Qt.size(Theme.iconSizeMedium, Theme.iconSizeMedium)
                        visible: selectedMessages.length === 1 && chatPage.activeSelectedText.length > 0
                        onClicked: {
                            Clipboard.text = chatPage.activeSelectedText;
                            appNotification.show(qsTr("Selected text copied to clipboard"));
                            chatPage.selectedMessages = [];
                        }
                    }

                    IconButton {
                        icon.source: "../../images/icon-m-copy.svg"
                        icon.sourceSize: Qt.size(Theme.iconSizeMedium, Theme.iconSizeMedium)
                        onClicked: {
                            Clipboard.text = Functions.getMessagesArrayText(chatPage.selectedMessages);
                            appNotification.show(qsTr("%Ln messages have been copied", "", selectedMessages.length));
                            chatPage.selectedMessages = [];
                        }
                    }

                    IconButton {
                        visible: !chatPage.isSecretChat && selectedMessages.every(function(message){
                            return message.can_be_forwarded
                        })
                        icon.sourceSize: Qt.size(Theme.iconSizeMedium, Theme.iconSizeMedium)
                        icon.source: "image://theme/icon-m-forward"
                        onClicked: {
                            startForwardingMessages(chatPage.selectedMessages);
                        }

                    }
                    IconButton {
                        icon.source: "image://theme/icon-m-delete"
                        visible: chatInformation.id === chatPage.myUserId || chatPage.isPrivateChat || chatPage.isSecretChat || selectedMessages.every(function(message){
                            return message.can_be_deleted_for_all_users ||
                                   message.can_be_deleted_only_for_self ||
                                   (message.sender_id && message.sender_id.user_id === chatPage.myUserId)
                        })
                        icon.sourceSize: Qt.size(Theme.iconSizeMedium, Theme.iconSizeMedium)
                        onClicked: {
                            var ids = Functions.getMessagesArrayIds(selectedMessages);
                            var chatId = chatInformation.id
                            var wrapper = tdLibWrapper;
                            Remorse.popupAction(chatPage, qsTr("%Ln Messages deleted", "", ids.length), function() {
                                wrapper.deleteMessages(chatId, ids);
                            });
                            chatPage.selectedMessages = [];
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: doubleTapHintTimer
        running: true
        triggeredOnStart: false
        repeat: false
        interval: 6000
        onTriggered: {
            tapHint.visible = false;
            tapHintLabel.visible = false;
        }
    }

    property string pendingDeleteSetId: ""
    property string pendingDeleteSetType: ""
    property string pendingDeleteSetName: ""

    function requestDeleteSet(setId, setType, setName) {
        if (!setId) return;
        chatPage.pendingDeleteSetId = setId;
        chatPage.pendingDeleteSetType = setType || "stickerTypeRegular";
        chatPage.pendingDeleteSetName = setName || "";
    }

    MouseArea {
        id: deleteSetDismiss
        anchors.fill: parent
        visible: chatPage.pendingDeleteSetId !== ""
        z: 150
        onClicked: chatPage.pendingDeleteSetId = ""
    }

    Rectangle {
        id: deleteSetPanel
        z: 200
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 2 * Theme.horizontalPageMargin
        color: Theme.highlightBackgroundColor
        radius: Theme.paddingMedium
        visible: chatPage.pendingDeleteSetId !== ""
        height: visible ? deleteSetColumn.height + 2 * Theme.paddingLarge : 0

        Column {
            id: deleteSetColumn
            anchors.top: parent.top
            anchors.topMargin: Theme.paddingLarge
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Theme.paddingMedium

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: chatPage.pendingDeleteSetName !== ""
                      ? qsTr("Do you want to delete \"%1\"?").arg(chatPage.pendingDeleteSetName)
                      : qsTr("Do you want to delete this set?")
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeMedium
            }

            Separator {
                width: parent.width
                color: Theme.primaryColor
                horizontalAlignment: Qt.AlignHCenter
            }

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeSmall
                onClicked: {
                    var sid = chatPage.pendingDeleteSetId;
                    var stype = chatPage.pendingDeleteSetType;
                    var sname = chatPage.pendingDeleteSetName;
                    chatPage.pendingDeleteSetId = "";
                    Remorse.popupAction(chatPage,
                        sname !== "" ? qsTr("Deleting \"%1\"").arg(sname) : qsTr("Deleting set"),
                        function() {
                            tdLibWrapper.changeStickerSet(sid, false, stype);
                        });
                }
                Label {
                    anchors.centerIn: parent
                    text: qsTr("Yes")
                    color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeLarge
                }
            }

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeSmall
                onClicked: chatPage.pendingDeleteSetId = ""
                Label {
                    anchors.centerIn: parent
                    text: qsTr("No")
                    color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeLarge
                }
            }
        }
    }

    TapInteractionHint {
        id: tapHint
        loops: Animation.Infinite
        taps: 2
        anchors.centerIn: parent
        visible: false
    }

    InteractionHintLabel {
        id: tapHintLabel
        anchors.bottom: parent.bottom
        text: qsTr("Double-tap on a message to choose a reaction")
        visible: false
    }
}
