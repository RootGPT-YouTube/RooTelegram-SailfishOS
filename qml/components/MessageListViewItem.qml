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
import WerkWolf.RooTelegram 1.0
import "./messageContent"
import "../js/twemoji.js" as Emoji
import "../js/functions.js" as Functions
import "../js/debug.js" as Debug

ListItem {
    id: messageListItem
    contentHeight: messageBackground.height + Theme.paddingMedium + ( reactionsColumn.visible ? reactionsColumn.height : 0 )
    Behavior on contentHeight { NumberAnimation { duration: 200 } }
    property var chatId
    property var messageId
    property int messageIndex
    property int messageViewCount
    property var myMessage
    property var messageAlbumMessageIds
    property var reactions
    property bool canReplyToMessage
    readonly property bool isAnonymous: myMessage.sender_id["@type"] === "messageSenderChat"
    readonly property var userInformation: tdLibWrapper.getUserInformation(myMessage.sender_id.user_id)
    property QtObject precalculatedValues: ListView.view.precalculatedValues
    readonly property Page page: precalculatedValues.page
    readonly property bool isSelected: messageListItem.precalculatedValues.pageIsSelecting && page.selectedMessages.some(function(existingMessage) {
        return existingMessage.id === messageId
    });
    readonly property bool isOwnMessage: page.myUserId && myMessage.sender_id ? (page.myUserId === myMessage.sender_id.user_id) : false
    readonly property bool useOutgoingLayout: isOwnMessage && !page.isChannel
    readonly property color textColor: useOutgoingLayout ? Theme.highlightColor : Theme.primaryColor
    readonly property int textAlign: useOutgoingLayout ? Text.AlignRight : Text.AlignLeft
    readonly property bool senderIsUser: myMessage.sender_id && myMessage.sender_id["@type"] === "messageSenderUser"
    readonly property var senderUserId: senderIsUser ? myMessage.sender_id.user_id : 0
    readonly property var senderInformation: senderIsUser ? tdLibWrapper.getUserInformation(senderUserId) : ({})
    readonly property string senderDisplayName: Functions.getUserName(senderInformation)
    readonly property bool isPrivateLikeChat: page.isPrivateChat || page.isSecretChat
    readonly property var groupStatus: page.chatGroupInformation ? page.chatGroupInformation.status : ({})
    readonly property var groupAdminRights: (groupStatus && groupStatus.rights) ? groupStatus.rights : ({})
    readonly property var chatPermissions: (page.chatInformation && page.chatInformation.permissions) ? page.chatInformation.permissions : ({})
    readonly property string groupStatusType: groupStatus["@type"] || ""
    readonly property bool isGroupAdmin: groupStatusType === "chatMemberStatusCreator" || groupStatusType === "chatMemberStatusAdministrator"
    readonly property bool adminCanDeleteAnyMessage: groupStatusType === "chatMemberStatusCreator" ||
        (groupStatusType === "chatMemberStatusAdministrator" &&
         (groupAdminRights.can_delete_messages === true ||
          groupStatus.can_delete_messages === true ||
          chatPermissions.can_delete_messages === true))
    readonly property bool adminCanRestrictMembers: groupStatusType === "chatMemberStatusCreator" ||
        (groupStatusType === "chatMemberStatusAdministrator" &&
         (groupAdminRights.can_restrict_members === true || groupStatus.can_restrict_members === true))
    readonly property bool canDeleteAllFromSender: (page.isBasicGroup || page.isSuperGroup) && senderIsUser && !isOwnMessage && adminCanDeleteAnyMessage
    readonly property bool canBanSender: (page.isBasicGroup || page.isSuperGroup) && senderIsUser && !isOwnMessage && adminCanRestrictMembers
    readonly property bool canReportSenderAsSpam: (page.isBasicGroup || page.isSuperGroup) && senderIsUser && !isOwnMessage && isGroupAdmin
    readonly property bool canDeleteMessage: isOwnMessage ||
        !!(myMessage.can_be_deleted_for_all_users || myMessage.can_be_deleted_only_for_self) ||
        (isPrivateLikeChat && myMessage["@type"] !== "sponsoredMessage") ||
        ((page.isBasicGroup || page.isSuperGroup) && adminCanDeleteAnyMessage)
    readonly property bool canEditMessage:
        (typeof myMessage.can_be_edited !== "undefined" && myMessage.can_be_edited === true) ||
        (isOwnMessage &&
         myMessage &&
         myMessage["@type"] !== "sponsoredMessage" &&
         myMessage.content &&
         myMessage.content["@type"] === "messageText" &&
         !myMessage.sending_state)
    readonly property bool canPinMessage:
        page.canPinMessages() &&
        myMessage &&
        myMessage["@type"] !== "sponsoredMessage" &&
        typeof myMessage.id !== "undefined"
    readonly property bool canSelectMessageText: false
    readonly property string selectedMessageText: canSelectMessageText ? (messageText.selectedText || "").replace(/\u2029/g, "\n") : ""
    readonly property bool hasSelectedMessageText: selectedMessageText.length > 0
    property bool hasContentComponent
    property bool additionalOptionsOpened
    property bool wasNavigatedTo: false
    property bool contextMenuWasOpen: false
    readonly property var additionalItemsModel: {
        var items = []
        if (extraContentLoader.item && ("extraContextMenuItems" in extraContentLoader.item)) {
            var extraItems = extraContentLoader.item.extraContextMenuItems
            for (var i = 0; i < extraItems.length; i++) {
                var extraItem = extraItems[i]
                if (extraItem.visible === undefined || extraItem.visible) {
                    items.push(extraItem)
                }
            }
        }
        if (canDeleteAllFromSender) {
            items.push({
                visible: true,
                name: senderDisplayName ? qsTr("Delete all messages from %1").arg(senderDisplayName) : qsTr("Delete all messages from this user"),
                action: function() {
                    deleteAllMessagesFromSender()
                }
            })
        }
        if (canBanSender) {
            items.push({
                visible: true,
                name: senderDisplayName ? qsTr("Ban %1").arg(senderDisplayName) : qsTr("Ban user"),
                action: function() {
                    banSender()
                }
            })
        }
        if (canReportSenderAsSpam) {
            items.push({
                visible: true,
                name: qsTr("Report as spam"),
                action: function() {
                    reportSenderAsSpam()
                }
            })
        }
        return items
    }
    readonly property int numberOfExtraOptionsOtherThanDeleteMessage:
        (showCopyMessageToClipboardMenuItem ? 0 : 1) +
        (showForwardMessageMenuItem ? 0 : 1) +
        (hasSelectedMessageText ? 2 : 0) +
        (additionalItemsModel ? additionalItemsModel.length : 0)
    readonly property bool deleteMessageIsOnlyExtraOption: canDeleteMessage && !numberOfExtraOptionsOtherThanDeleteMessage
    readonly property int maxContextMenuItemCount: page.isPortrait ? 7 : 6
    readonly property int baseContextMenuItemCount: (canReplyToMessage ? 1 : 0) +
        (canEditMessage ? 1 : 0) + 2 /* "Select Message" and "More Options..." */
    readonly property bool showCopyMessageToClipboardMenuItem: (baseContextMenuItemCount + 1) <= maxContextMenuItemCount
    readonly property bool showForwardMessageMenuItem: (baseContextMenuItemCount + 2) <= maxContextMenuItemCount
    // And don't count "More Options..." for "Delete Message" if "Delete Message" is the only extra option
    readonly property bool haveSpaceForDeleteMessageMenuItem: (baseContextMenuItemCount + 3 - (deleteMessageIsOnlyExtraOption ? 1 : 0)) <= maxContextMenuItemCount
    property var chatReactions
    property var messageReactions

    highlighted: (down || (isSelected && messageAlbumMessageIds.length === 0) || additionalOptionsOpened || wasNavigatedTo) && !menuOpen
    openMenuOnPressAndHold: !messageListItem.precalculatedValues.pageIsSelecting || !isSelected

    signal replyToMessage()
    signal editMessage()
    signal forwardMessage()
    signal quoteSelectedText(string selectedText)

    // Mappa "OFFSET-LENGTH" → true degli spoiler già rivelati in questo messaggio.
    // Su Qt 5.6 (Sailfish) il binding analyzer NON traccia in modo affidabile le
    // letture di una `property var` quando viene passata come argomento a una
    // funzione JS — quindi affianchiamo un contatore int (`revealedSpoilersVersion`)
    // che incrementiamo ad ogni modifica e che leggiamo esplicitamente dentro il
    // binding del `text:` per forzarne la rivalutazione.
    property var revealedSpoilers: ({})
    property int revealedSpoilersVersion: 0

    // Estrae le entities textEntityTypeSpoiler dal messaggio corrente. Le entities
    // possono stare in content.text.entities (messageText) o content.caption.entities
    // (messagePhoto/Video/Animation/Audio/VoiceNote/Document).
    function getMessageSpoilerEntities() {
        if (!myMessage || !myMessage.content) {
            return [];
        }
        var bag = null;
        if (myMessage.content.text && myMessage.content.text.entities) {
            bag = myMessage.content.text.entities;
        } else if (myMessage.content.caption && myMessage.content.caption.entities) {
            bag = myMessage.content.caption.entities;
        }
        if (!bag) {
            return [];
        }
        var found = [];
        for (var i = 0; i < bag.length; i++) {
            if (bag[i] && bag[i].type && bag[i].type['@type'] === "textEntityTypeSpoiler") {
                found.push(bag[i]);
            }
        }
        return found;
    }

    readonly property var spoilerEntities: getMessageSpoilerEntities()
    readonly property bool hasSpoilers: spoilerEntities.length > 0
    readonly property bool anySpoilerRevealed: {
        for (var k in revealedSpoilers) {
            if (revealedSpoilers[k]) return true;
        }
        return false;
    }

    // Toggle: se nessuno spoiler è rivelato, rivela tutti (popola revealedSpoilers
    // con tutte le entity dello spoiler del messaggio); altrimenti azzera.
    function toggleAllSpoilers() {
        if (anySpoilerRevealed) {
            revealedSpoilers = {};
            revealedSpoilersVersion++;
            return;
        }
        var next = {};
        for (var i = 0; i < spoilerEntities.length; i++) {
            var e = spoilerEntities[i];
            next[e.offset + "-" + e.length] = true;
        }
        revealedSpoilers = next;
        revealedSpoilersVersion++;
    }

    // Intercetta i link "rtspoiler://OFFSET/LENGTH" emessi dai render degli spoiler:
    // marca la coppia come rivelata e aggiorna la property per re-triggerare il
    // binding del testo. Ritorna true se il link era uno spoiler (gestito), false
    // altrimenti — il chiamante prosegue con la normale handleLink in caso false.
    function handleSpoilerLink(link) {
        if (typeof link !== "string" || link.indexOf("rtspoiler://") !== 0) {
            return false;
        }
        var rest = link.substring("rtspoiler://".length);
        var parts = rest.split("/");
        if (parts.length < 2) {
            return true;
        }
        var key = parts[0] + "-" + parts[1];
        var next = {};
        for (var k in revealedSpoilers) {
            next[k] = revealedSpoilers[k];
        }
        next[key] = true;
        revealedSpoilers = next;
        revealedSpoilersVersion++;
        return true;
    }

    function deleteMessage() {
        var chatId = page.chatInformation.id
        var messageId = myMessage.id
        Remorse.itemAction(messageListItem, qsTr("Message deleted"), function() {
            tdLibWrapper.deleteMessages(chatId, [ messageId ]);
        })
    }

    // True quando il messaggio fa parte di un album multimediale TDLib
    // (più messaggi inviati in batch con stesso media_album_id).
    readonly property bool isPartOfAlbum: !!myMessage && !!myMessage.media_album_id && myMessage.media_album_id !== "0"

    function deleteAlbum() {
        if (!isPartOfAlbum) {
            deleteMessage()
            return
        }
        var chatId = page.chatInformation.id
        var albumIds = chatModel.getMessageIdsForAlbum(myMessage.media_album_id)
        if (!albumIds || albumIds.length === 0) {
            // fallback: se il modello non ha ancora popolato l'album, cancella
            // almeno il messaggio corrente per non dare un no-op silenzioso
            albumIds = [ myMessage.id ]
        }
        var stringIds = albumIds.map(function(id) { return id.toString() })
        Remorse.popupAction(page, qsTr("%Ln messages of album deleted", "", stringIds.length), function() {
            tdLibWrapper.deleteMessages(chatId, stringIds);
        })
    }

    function deleteAllMessagesFromSender() {
        if (!senderIsUser) {
            return
        }
        var chatId = page.chatInformation.id
        Remorse.popupAction(page, qsTr("Deletion of messages started"), function() {
            tdLibWrapper.deleteChatMessagesBySender(chatId, senderUserId)
        })
    }

    function banSender() {
        if (!senderIsUser) {
            return
        }
        var chatId = page.chatInformation.id
        Remorse.popupAction(page, qsTr("User banned"), function() {
            tdLibWrapper.banChatMember(chatId, senderUserId, 0)
        })
    }

    function reportSenderAsSpam() {
        var chatId = page.chatInformation.id
        tdLibWrapper.reportChatSpam(chatId, [myMessage.id])
        appNotification.show(qsTr("Report submitted"))
    }

    function copyMessageToClipboard() {
        Clipboard.text = Functions.getMessageText(myMessage, true, userInformation.id, true)
    }

    function clearSelectedText() {
        if (messageText.selectionStart !== messageText.selectionEnd) {
            messageText.deselect();
        }
    }

    function copySelectedTextToClipboard() {
        if (!hasSelectedMessageText) {
            return;
        }
        Clipboard.text = selectedMessageText;
    }

    function quoteSelectedTextToComposer() {
        if (!hasSelectedMessageText || !canReplyToMessage) {
            return;
        }
        quoteSelectedText(selectedMessageText);
        clearSelectedText();
    }

    function requestEditMessage() {
        editMessage();
    }
    function togglePinMessage() {
        if (!canPinMessage) {
            return;
        }
        if (myMessage.is_pinned) {
            tdLibWrapper.unpinMessage(page.chatInformation.id, myMessage.id);
        } else if (typeof page.requestPinMessage === "function") {
            page.requestPinMessage(myMessage);
        } else {
            tdLibWrapper.pinMessage(page.chatInformation.id, myMessage.id, false, false);
        }
    }

    function openAdditionalOptionsDrawer() {
        messageOptionsDrawer.myMessage = myMessage;
        messageOptionsDrawer.userInformation = userInformation;
        messageOptionsDrawer.sourceItem = messageListItem;
        messageOptionsDrawer.additionalItemsModel = additionalItemsModel;
        messageOptionsDrawer.showEditMessageMenuItem = canEditMessage;
        messageOptionsDrawer.showCopyMessageToClipboardMenuItem = !showCopyMessageToClipboardMenuItem;
        messageOptionsDrawer.showForwardMessageMenuItem = !showForwardMessageMenuItem;
        messageOptionsDrawer.showDeleteMessageMenuItem = canDeleteMessage;
        messageOptionsDrawer.showCopySelectedTextMenuItem = hasSelectedMessageText;
        messageOptionsDrawer.showQuoteSelectedTextMenuItem = hasSelectedMessageText && canReplyToMessage;
        messageListItem.additionalOptionsOpened = true;
        messageOptionsDrawer.open = true;
    }

    function openContextMenu() {
        messageOptionsDrawer.open = false
        if (messageListItem.menu) {
            openMenu()
        } else {
            contextMenuLoader.active = true
        }
    }

    function getInteractionText(viewCount, reactions, size, highlightColor) {
        var interactionText = "";
        if (viewCount > 0) {
            interactionText = Emoji.emojify("👁️ ", size) + Functions.getShortenedCount(viewCount);
        }
        for (var i = 0; i < reactions.length; i++) {
            var reaction = reactions[i]
            var reactionText = ""
            if (reaction.reaction) {
                reactionText = reaction.reaction
            } else if (reaction.type && reaction.type.emoji) {
                reactionText = reaction.type.emoji
            } else if (reaction.reaction_type && reaction.reaction_type.emoji) {
                reactionText = reaction.reaction_type.emoji
            }
            if (reactionText) {
                interactionText += ( "&nbsp;" + Emoji.emojify(reactionText, size) );
                if (!chatPage.isPrivateChat) {
                    var rawCount = (typeof reaction.total_count !== "undefined") ? reaction.total_count : reaction.count
                    var count = Functions.getShortenedCount(rawCount || 0)
                    interactionText += " "
                    var isChosen = reaction.is_chosen === true || reaction.is_selected === true
                    interactionText += (isChosen ? ( "<font color='" + highlightColor + "'><b>" + count + "</b></font>" ) : count)
                }
            }
        }
        return interactionText;
    }

    function openReactions() {
        if (messageListItem.chatReactions) {
            Debug.log("Using chat reactions")
            messageListItem.messageReactions = chatReactions
            showItemCompletelyTimer.requestedIndex = index;
            showItemCompletelyTimer.start();
        } else {
            Debug.log("Obtaining message reactions")
            tdLibWrapper.getMessageAvailableReactions(messageListItem.chatId, messageListItem.messageId);
        }
        selectReactionBubble.visible = false;
    }

    function getContentWidthMultiplier() {
        return Functions.isWidescreen(appWindow) ? 0.4 : 1.0
    }
    function resolveWebPagePreviewData(messageData) {
        if (!messageData || !messageData.content) {
            return undefined;
        }
        var content = messageData.content;
        if (typeof content.web_page !== "undefined" && content.web_page !== null) {
            return content.web_page;
        }
        if (content.text && typeof content.text.web_page !== "undefined" && content.text.web_page !== null) {
            return content.text.web_page;
        }
        if (typeof content.link_preview !== "undefined" && content.link_preview !== null) {
            if (content.link_preview.web_page) {
                return content.link_preview.web_page;
            }
            return content.link_preview;
        }
        if (content.text && typeof content.text.link_preview !== "undefined" && content.text.link_preview !== null) {
            if (content.text.link_preview.web_page) {
                return content.text.link_preview.web_page;
            }
            return content.text.link_preview;
        }
        return undefined;
    }
    readonly property var resolvedWebPagePreviewData: resolveWebPagePreviewData(myMessage)

    function refreshRenderedMessageText() {
        // NON assegnare imperativamente messageText.text / messageTextDisplay.text:
        // quell'assegnazione distruggerebbe il binding QML, e dopo la prima chiamata
        // (che scatta su onMyMessageChanged molto presto) il `text:` non si rivaluterebbe
        // più al cambio di `revealedSpoilers`. Invece bumpiamo il contatore int che
        // appare esplicitamente nel binding, costringendolo a rieseguire la JS expression.
        revealedSpoilersVersion++;
    }

    onClicked: {
        if (messageListItem.precalculatedValues.pageIsSelecting) {
            if (!isSelected) {
                page.toggleMessageSelection(myMessage);
            } else if (hasSelectedMessageText) {
                openAdditionalOptionsDrawer();
            } else {
                messageText.forceActiveFocus();
            }
            return;
        }
        if (messageOptionsDrawer.sourceItem !== messageListItem) {
            messageOptionsDrawer.open = false
        }
        // Allow extra context to react to click
        var extraContent = extraContentLoader.item
        if (extraContent && extraContentLoader.contains(mapToItem(extraContentLoader, mouse.x, mouse.y))) {
            extraContent.clicked()
        } else if (webPagePreviewLoader.item) {
            webPagePreviewLoader.item.clicked()
        }

        if (messageListItem.messageReactions) {
            messageListItem.messageReactions = null;
            selectReactionBubble.visible = false;
        } else {
            selectReactionBubble.visible = !selectReactionBubble.visible;
            elementSelected(index);
        }
    }

    onDoubleClicked: {
        openReactions();
    }

    onPressAndHold: {
        if (!openMenuOnPressAndHold) {
            return;
        }
        if (typeof mouse === "undefined" ||
                typeof mouse.x === "undefined" ||
                typeof mouse.y === "undefined") {
            openContextMenu();
            return;
        }
        var messageTopLeft = messageBackground.mapToItem(messageListItem, 0, 0);
        if (typeof messageTopLeft.x === "undefined" ||
                typeof messageTopLeft.y === "undefined" ||
                messageBackground.width <= 0 ||
                messageBackground.height <= 0) {
            openContextMenu();
            return;
        }
        var pressedOnMessage = mouse.x >= messageTopLeft.x &&
                mouse.x <= (messageTopLeft.x + messageBackground.width) &&
                mouse.y >= messageTopLeft.y &&
                mouse.y <= (messageTopLeft.y + messageBackground.height);
        if (pressedOnMessage) {
            openContextMenu();
        }
    }

    onMenuOpenChanged: {
        // When opening/closing the context menu, we no longer scroll automatically
        chatView.manuallyScrolledToBottom = false;
        if (menuOpen) {
            contextMenuWasOpen = true;
        } else if (contextMenuWasOpen) {
            contextMenuWasOpen = false;
            contextMenuLoader.active = false;
            messageListItem.menu = null;
        }
    }

    Connections {
        target: additionalOptionsOpened ? messageOptionsDrawer : null
        onOpenChanged: {
            if (!messageOptionsDrawer.open) {
                additionalOptionsOpened = false
            }
        }
    }

    Connections {
        target: chatPage
        onResetElements: {
            messageListItem.messageReactions = null;
            selectReactionBubble.visible = false;
            clearSelectedText();
        }
        onElementSelected: {
            if (elementIndex !== index) {
                selectReactionBubble.visible = false;
                clearSelectedText();
            }
        }
        onNavigatedTo: {
            if (targetIndex === index) {
                messageListItem.wasNavigatedTo = true;
                restoreNormalityTimer.start();
            }
        }
    }

    Loader {
        id: contextMenuLoader
        active: false
        asynchronous: true
        onStatusChanged: {
            if(status === Loader.Ready) {
                messageListItem.menu = item;
                messageListItem.openMenu();
            }
        }
        sourceComponent: Component {
            ContextMenu {
                MenuItem {
                    visible: hasSpoilers
                    onClicked: toggleAllSpoilers()
                    text: anySpoilerRevealed ? qsTr("Hide spoiler") : qsTr("Reveal spoiler")
                }
                MenuItem {
                    visible: canReplyToMessage
                    onClicked: replyToMessage()
                    text: qsTr("Reply to Message")
                }
                MenuItem {
                    visible: showCopyMessageToClipboardMenuItem
                    onClicked: copyMessageToClipboard()
                    text: qsTr("Copy Message to Clipboard")
                }
                MenuItem {
                    visible: showForwardMessageMenuItem
                    onClicked: forwardMessage()
                    text: qsTr("Forward message")
                }
                MenuItem {
                    visible: canPinMessage
                    onClicked: togglePinMessage()
                    text: myMessage && myMessage.is_pinned ? qsTr("Unpin Message") : qsTr("Pin Message")
                }
                MenuItem {
                    visible: canEditMessage
                    onClicked: requestEditMessage()
                    text: qsTr("Edit Message")
                }
                MenuItem {
                    visible: canDeleteMessage
                    onClicked: deleteMessage()
                    text: qsTr("Delete message")
                }
                MenuItem {
                    visible: canDeleteMessage && isPartOfAlbum
                    onClicked: deleteAlbum()
                    text: qsTr("Delete album")
                }
                MenuItem {
                    onClicked: page.toggleMessageSelection(myMessage)
                    text: qsTr("Select Message")
                }
                MenuItem {
                    visible: (numberOfExtraOptionsOtherThanDeleteMessage > 0) ||
                        (canDeleteMessage && !haveSpaceForDeleteMessageMenuItem)
                    onClicked: {
                        openAdditionalOptionsDrawer();
                    }
                    text: qsTr("More Options...")
                }
            }
        }
    }

    Connections {
        target: chatModel
        onMessagesReceived: {
            messageBackground.isUnread = messageIndex > chatModel.getLastReadMessageIndex() && myMessage['@type'] !== "sponsoredMessage";
        }
        onMessagesIncrementalUpdate: {
            messageBackground.isUnread = messageIndex > chatModel.getLastReadMessageIndex() && myMessage['@type'] !== "sponsoredMessage";
        }
        onNewMessageReceived: {
            messageBackground.isUnread = messageIndex > chatModel.getLastReadMessageIndex() && myMessage['@type'] !== "sponsoredMessage";
        }
        onUnreadCountUpdated: {
            messageBackground.isUnread = messageIndex > chatModel.getLastReadMessageIndex() && myMessage['@type'] !== "sponsoredMessage";
        }
        onLastReadSentMessageUpdated: {
            Debug.log("[ChatModel] Messages in this chat were read, new last read: ", lastReadSentIndex, ", updating description for index ", index, ", status: ", (messageIndex <= lastReadSentIndex));
            messageDateText.text = getMessageStatusText(myMessage, messageIndex, lastReadSentIndex, messageDateText.useElapsed);
        }
    }

    Connections {
        target: tdLibWrapper
        onReceivedMessage: {
            if (messageId === myMessage.reply_to_message_id) {
                messageInReplyToLoader.inReplyToMessage = message;
            }
        }
        onMessageNotFound: {
            if (messageId === myMessage.reply_to_message_id) {
                messageInReplyToLoader.inReplyToMessageDeleted = true;
            }
        }
        onAvailableReactionsReceived: {
            if (messageListItem.messageId === messageId &&
                    pageStack.currentPage === chatPage) {
                Debug.log("Available reactions for this message: " + reactions);
                messageListItem.messageReactions = reactions;
                showItemCompletelyTimer.requestedIndex = messageIndex;
                showItemCompletelyTimer.start();
            } else {
                messageListItem.messageReactions = null;
            }
        }
        onReactionsUpdated: {
            chatReactions = tdLibWrapper.getChatReactions(page.chatInformation.id);
        }
        onCustomEmojiAssetsUpdated: {
            refreshRenderedMessageText();
        }
    }

    Timer {
        id: showItemCompletelyTimer

        property int requestedIndex: (chatView.count - 1)

        repeat: false
        running: false
        interval: 200
        triggeredOnStart: false
        onTriggered: {
            if (requestedIndex === messageIndex) {
                chatView.highlightMoveDuration = -1;
                chatView.highlightResizeDuration = -1;
                chatView.scrollToIndex(requestedIndex);
                chatView.highlightMoveDuration = 0;
                chatView.highlightResizeDuration = 0;
            }
            Debug.log("Show item completely timer triggered, requested index: " + requestedIndex + ", current index: " + index)
            if (requestedIndex === index) {
                var p = chatView.contentItem.mapFromItem(reactionsColumn, 0, 0)
                if (chatView.contentY > p.y || p.y + reactionsColumn.height > chatView.contentY + chatView.height) {
                    Debug.log("Moving reactions for item at", requestedIndex, "info the view")
                    chatView.highlightMoveDuration = -1
                    chatView.highlightResizeDuration = -1
                    chatView.scrollToIndex(requestedIndex, height <= chatView.height ? ListView.Contain : ListView.End)
                    chatView.highlightMoveDuration = 0
                    chatView.highlightResizeDuration = 0
                }
            }
        }
    }

    Timer {
        id: restoreNormalityTimer

        repeat: false
        running: false
        interval: 1000
        triggeredOnStart: false
        onTriggered: {
            Debug.log("Restore normality for index " + index);
            messageListItem.wasNavigatedTo = false;
        }
    }

    Component.onCompleted: {
        delegateComponentLoadingTimer.start();
        if (myMessage.reply_to_message_id) {
            tdLibWrapper.getMessage(myMessage.reply_in_chat_id ? myMessage.reply_in_chat_id : page.chatInformation.id,
                myMessage.reply_to_message_id)
        }
    }

    onMyMessageChanged: {
        Debug.log("[ChatModel] This message was updated, index", messageIndex, ", updating content...");
        messageDateText.text = getMessageStatusText(myMessage, messageIndex, chatView.lastReadSentIndex, messageDateText.useElapsed);
        refreshRenderedMessageText();
        var webPageData = messageListItem.resolvedWebPagePreviewData;
        var hasWebPagePreview = typeof webPageData !== "undefined" && webPageData !== null;
        if (!messageListItem.hasContentComponent && hasWebPagePreview) {
            if (!webPagePreviewLoader.active) {
                webPagePreviewLoader.active = true;
            }
            if (webPagePreviewLoader.item) {
                webPagePreviewLoader.item.webPageData = webPageData;
            }
        } else {
            if (webPagePreviewLoader.item) {
                webPagePreviewLoader.item.webPageData = undefined;
            }
            webPagePreviewLoader.active = false;
        }
    }

    Timer {
        id: delegateComponentLoadingTimer
        interval: 500
        repeat: false
        running: false
        onTriggered: {
            if (messageListItem.hasContentComponent) {
                webPagePreviewLoader.active = false;
                var type = myMessage.content["@type"];
                var albumComponentPart = (myMessage.media_album_id !== "0" && ['messagePhoto', 'messageVideo'].indexOf(type) !== -1) ? 'Album' : '';
                extraContentLoader.setSource(
                            "../components/messageContent/" + type.charAt(0).toUpperCase() + type.substring(1) + albumComponentPart + ".qml",
                            {
                                messageListItem: messageListItem
                            })
            } else {
                var webPageData = messageListItem.resolvedWebPagePreviewData;
                var hasWebPagePreview = typeof webPageData !== "undefined" && webPageData !== null;
                webPagePreviewLoader.active = hasWebPagePreview; // only in messageText
                if (hasWebPagePreview && webPagePreviewLoader.item) {
                    webPagePreviewLoader.item.webPageData = webPageData;
                }
            }
        }
    }

    Row {
        id: messageTextRow
        spacing: Theme.paddingSmall
        width: precalculatedValues.entryWidth
        anchors.horizontalCenter: Functions.isWidescreen(appWindow) ? undefined : parent.horizontalCenter
        anchors.left: Functions.isWidescreen(appWindow) ? parent.left : undefined
        y: Theme.paddingSmall
        anchors.leftMargin: Functions.isWidescreen(appWindow) ? Theme.paddingMedium : undefined

        Loader {
            id: profileThumbnailLoader
            active: precalculatedValues.showUserInfo
            asynchronous: true
            width: precalculatedValues.profileThumbnailDimensions
            height: width
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.paddingSmall
            sourceComponent: Component {
                ProfileThumbnail {
                    id: messagePictureThumbnail
                    photoData: messageListItem.isAnonymous ? ((typeof page.chatInformation.photo !== "undefined") ? page.chatInformation.photo.small : {}) : ((typeof messageListItem.userInformation.profile_photo !== "undefined") ? messageListItem.userInformation.profile_photo.small : ({}))
                    replacementStringHint: userText.text
                    width: Theme.itemSizeSmall
                    height: Theme.itemSizeSmall
                    visible: precalculatedValues.showUserInfo
                    MouseArea {
                        anchors.fill: parent
                        enabled: !(messageListItem.precalculatedValues.pageIsSelecting || messageListItem.isAnonymous)
                        onClicked: {
                            tdLibWrapper.createPrivateChat(messageListItem.userInformation.id, "openDirectly");
                        }
                    }
                }
            }
        }

        Item {
            id: messageTextItem

            width: precalculatedValues.textItemWidth
            height: messageBackground.height

            Rectangle {
                id: messageBackground

                anchors {
                    left: parent.left
                    leftMargin: messageListItem.useOutgoingLayout ? precalculatedValues.pageMarginDouble : 0
                    verticalCenter: parent.verticalCenter
                }
                height: messageTextColumn.height + precalculatedValues.paddingMediumDouble
                width: precalculatedValues.backgroundWidth
                property bool isUnread: messageIndex > chatModel.getLastReadMessageIndex() && myMessage['@type'] !== "sponsoredMessage"
                color: Theme.colorScheme === Theme.LightOnDark ? (isUnread ? Theme.secondaryHighlightColor : Theme.secondaryColor) : (isUnread ? Theme.backgroundGlowColor : Theme.overlayBackgroundColor)
                radius: parent.width / 50
                opacity: isUnread ? 0.5 : 0.2
                visible: appSettings.showStickersAsImages || (myMessage.content['@type'] !== "messageSticker" && myMessage.content['@type'] !== "messageAnimatedEmoji")
                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on opacity { FadeAnimation {} }
            }

            Column {
                id: messageTextColumn

                spacing: Theme.paddingSmall

                width: precalculatedValues.textColumnWidth
                anchors.centerIn: messageBackground


                Label {
                    id: userText

                    width: parent.width
                    text: messageListItem.useOutgoingLayout
                          ? qsTr("You")
                          : Emoji.emojify( myMessage['@type'] === "sponsoredMessage"
                                          ? tdLibWrapper.getChat(myMessage.sponsor_chat_id).title
                                          : ( messageListItem.isAnonymous
                                                ? page.chatInformation.title
                                                : Functions.getUserName(messageListItem.userInformation) ), font.pixelSize)
                    font.pixelSize: Theme.fontSizeExtraSmall
                    font.weight: Font.ExtraBold
                    color: messageListItem.textColor
                    maximumLineCount: 1
                    truncationMode: TruncationMode.Elide
                    textFormat: Text.StyledText
                    horizontalAlignment: messageListItem.textAlign
                    visible: precalculatedValues.showUserInfo || myMessage['@type'] === "sponsoredMessage"
                    MouseArea {
                        anchors.fill: parent
                        enabled: !(messageListItem.precalculatedValues.pageIsSelecting || messageListItem.isAnonymous)
                        onClicked: {
                            tdLibWrapper.createPrivateChat(messageListItem.userInformation.id, "openDirectly");
                        }
                    }
                }

                MessageViaLabel {
                    message: myMessage
                }

                Loader {
                    id: messageInReplyToLoader
                    active: typeof myMessage.reply_to_message_id !== "undefined" && myMessage.reply_to_message_id !== 0
                    width: parent.width
                    // text height ~= 1,28*font.pixelSize
                    height: active ? precalculatedValues.messageInReplyToHeight : 0
                    clip: true
                    property var inReplyToMessage;
                    property bool inReplyToMessageDeleted: false;
                    sourceComponent: Component {
                        Item {
                            width: messageInReplyToLoader.width
                            height: messageInReplyToRow.height
                            InReplyToRow {
                                id: messageInReplyToRow
                                myUserId: page.myUserId
                                layer.enabled: messageInReplyToMouseArea.pressed && !messageListItem.highlighted && !messageListItem.menuOpen
                                layer.effect: PressEffect { source: messageInReplyToRow }
                                inReplyToMessage: messageInReplyToLoader.inReplyToMessage
                                inReplyToMessageDeleted: messageInReplyToLoader.inReplyToMessageDeleted
                            }
                            MouseArea {
                                id: messageInReplyToMouseArea
                                anchors.fill: parent
                                onClicked: {
                                    if (precalculatedValues.pageIsSelecting) {
                                        page.toggleMessageSelection(myMessage)
                                    } else {
                                        messageOptionsDrawer.open = false
                                        if(appSettings.goToQuotedMessage) {
                                            chatPage.showMessage(messageInReplyToRow.inReplyToMessage.id, true)
                                        } else {
                                            messageOverlayLoader.active = true
                                            messageOverlayLoader.overlayMessage = messageInReplyToRow.inReplyToMessage
                                        }
                                    }
                                }
                                onPressAndHold: {
                                    if (openMenuOnPressAndHold) {
                                        openContextMenu()
                                    }
                                }
                            }
                        }
                    }
                }

                Loader {
                    id: forwardedInformationLoader
                    active: typeof myMessage.forward_info !== "undefined"
                    asynchronous: true
                    width: parent.width
                    height: active ? ( item ? item.height : Theme.itemSizeExtraSmall ) : 0
                    sourceComponent: Component {
                        Row {
                            id: forwardedMessageInformationRow
                            spacing: Theme.paddingSmall
                            width: parent.width

                            Component.onCompleted: {
                                var originType = myMessage.forward_info.origin["@type"]
                                if (originType === "messageOriginChannel" || originType === "messageForwardOriginChannel") {
                                    var otherChatInformation = tdLibWrapper.getChat(myMessage.forward_info.origin.chat_id);
                                    forwardedThumbnail.photoData = (typeof otherChatInformation.photo !== "undefined") ? otherChatInformation.photo.small : {};
                                    forwardedChannelText.text = Emoji.emojify(otherChatInformation.title, Theme.fontSizeExtraSmall);
                                } else if (originType === "messageOriginUser" || originType === "messageForwardOriginUser") {
                                    var otherUserInformation = tdLibWrapper.getUserInformation(myMessage.forward_info.origin.sender_user_id);
                                    forwardedThumbnail.photoData = (typeof otherUserInformation.profile_photo !== "undefined") ? otherUserInformation.profile_photo.small : {};
                                    forwardedChannelText.text = Emoji.emojify(Functions.getUserName(otherUserInformation), Theme.fontSizeExtraSmall);
                                } else {
                                    forwardedChannelText.text = Emoji.emojify(myMessage.forward_info.origin.sender_name, Theme.fontSizeExtraSmall);
                                    forwardedThumbnail.photoData = {};
                                }
                            }

                            ProfileThumbnail {
                                id: forwardedThumbnail
                                replacementStringHint: forwardedChannelText.text
                                width: Theme.itemSizeExtraSmall
                                height: Theme.itemSizeExtraSmall
                            }

                            Column {
                                spacing: Theme.paddingSmall
                                width: parent.width - forwardedThumbnail.width - Theme.paddingSmall
                                Label {
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    width: parent.width
                                    font.italic: true
                                    truncationMode: TruncationMode.Elide
                                    textFormat: Text.StyledText
                                    text: qsTr("Forwarded Message")
                                }
                                Label {
                                    id: forwardedChannelText
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    color: Theme.primaryColor
                                    width: parent.width
                                    font.bold: true
                                    truncationMode: TruncationMode.Elide
                                    textFormat: Text.StyledText
                                    text: Emoji.emojify(forwardedMessageInformationRow.otherChatInformation.title, font.pixelSize)
                                }
                            }
                        }
                    }
                }

                TextEdit {
                    id: messageText
                    width: parent.width
                    // Short-circuit when not in selection mode. The TextEdit is kept in the
                    // tree so the `messageText` id stays valid for selection helpers, but
                    // skipping the binding avoids the (very expensive) Emoji.emojify +
                    // RichText parse on every delegate when selection is disabled. On
                    // photo-heavy channels this cut roughly halves per-delegate cost.
                    text: messageListItem.canSelectMessageText
                          ? (messageListItem.revealedSpoilersVersion, Emoji.emojify(Functions.getMessageText(myMessage, false, page.myUserId, false, messageListItem.revealedSpoilers), Theme.fontSizeMedium))
                          : ""
                    font.pixelSize: Theme.fontSizeSmall
                    color: messageListItem.textColor
                    wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                    textFormat: TextEdit.RichText
                    readOnly: true
                    cursorVisible: false
                    activeFocusOnPress: messageListItem.canSelectMessageText
                    selectByMouse: messageListItem.canSelectMessageText
                    persistentSelection: true
                    selectionColor: Theme.highlightBackgroundColor
                    selectedTextColor: Theme.primaryColor
                    onLinkActivated: {
                        if (messageListItem.handleSpoilerLink(link)) {
                            return;
                        }
                        var chatCommand = Functions.handleLink(link);
                        if(chatCommand) {
                            tdLibWrapper.sendTextMessage(chatInformation.id, chatCommand);
                        }
                    }
                    horizontalAlignment: messageListItem.textAlign
                    visible: canSelectMessageText && (text !== "")
                }

                Text {
                    id: messageTextDisplay
                    width: parent.width
                    text: (messageListItem.revealedSpoilersVersion, Emoji.emojify(Functions.getMessageText(myMessage, false, page.myUserId, false, messageListItem.revealedSpoilers), Theme.fontSizeMedium))
                    font.pixelSize: Theme.fontSizeSmall
                    color: messageListItem.textColor
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    textFormat: Text.RichText
                    onLinkActivated: {
                        if (messageListItem.handleSpoilerLink(link)) {
                            return;
                        }
                        var chatCommand = Functions.handleLink(link);
                        if(chatCommand) {
                            tdLibWrapper.sendTextMessage(chatInformation.id, chatCommand);
                        }
                    }
                    horizontalAlignment: messageListItem.textAlign
                    visible: !canSelectMessageText && (text !== "")
                }

                Loader {
                    id: sponsoredMessageButtonLoader
                    active: myMessage['@type'] === "sponsoredMessage"
                    asynchronous: true
                    width: parent.width
                    height: (status === Loader.Ready) ? item.implicitHeight : myMessage['@type'] === "sponsoredMessage" ? Theme.itemSizeMedium : 0

                    sourceComponent: Component {
                        SponsoredMessage {
                            sponsoredMessageData: myMessage
                            width: parent.width
                        }
                    }
                }

                Loader {
                    id: webPagePreviewLoader
                    active: false
                    asynchronous: true
                    width: parent.width * getContentWidthMultiplier()
                    height: (status === Loader.Ready) ? item.implicitHeight : (messageListItem.resolvedWebPagePreviewData ? precalculatedValues.webPagePreviewHeight : 0)
                    onStatusChanged: {
                        if (status === Loader.Ready && item) {
                            item.webPageData = messageListItem.resolvedWebPagePreviewData;
                        }
                    }

                    sourceComponent: Component {
                        WebPagePreview {
                            webPageData: messageListItem.resolvedWebPagePreviewData
                            width: parent.width
                            highlighted: messageListItem.highlighted
                        }
                    }
                }

                Loader {
                    id: extraContentLoader
                    width: parent.width * getContentWidthMultiplier()
                    asynchronous: true
                    readonly property var defaultExtraContentHeight: messageListItem.hasContentComponent ? chatView.getContentComponentHeight(model.content_type, myMessage.content, width, model.album_message_ids.length) : 0
                    height: item ? item.height : defaultExtraContentHeight
                }

                Binding {
                    target: extraContentLoader.item
                    when: extraContentLoader.item && ("highlighted" in extraContentLoader.item) && (typeof extraContentLoader.item.highlighted === "boolean")
                    property: "highlighted"
                    value: messageListItem.highlighted
                }

                Loader {
                    id: replyMarkupLoader
                    width: parent.width
                    height: active ? (myMessage.reply_markup.rows.length * (Theme.itemSizeSmall + Theme.paddingSmall) - Theme.paddingSmall) : 0
                    asynchronous: true
                    active: !!myMessage.reply_markup && myMessage.reply_markup.rows
                    source: Qt.resolvedUrl("ReplyMarkupButtons.qml")
                }

                Timer {
                    id: messageDateUpdater
                    interval: 60000
                    running: true
                    repeat: true
                    onTriggered: {
                        messageDateText.text = getMessageStatusText(myMessage, messageIndex, chatView.lastReadSentIndex, messageDateText.useElapsed);
                    }
                }

                Text {
                    width: parent.width

                    property bool useElapsed: true

                    id: messageDateText
                    font.pixelSize: Theme.fontSizeTiny
                    color: messageListItem.useOutgoingLayout ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    horizontalAlignment: messageListItem.textAlign
                    text: getMessageStatusText(myMessage, messageIndex, chatView.lastReadSentIndex, messageDateText.useElapsed)
                    MouseArea {
                        anchors.fill: parent
                        enabled: !messageListItem.precalculatedValues.pageIsSelecting
                        onClicked: {
                            messageDateText.useElapsed = !messageDateText.useElapsed;
                            messageDateText.text = getMessageStatusText(myMessage, messageIndex, chatView.lastReadSentIndex, messageDateText.useElapsed);
                        }
                    }
                }

                Loader {
                    id: interactionLoader
                    width: parent.width
                    asynchronous: true
                    active: ( chatPage.isChannel && messageViewCount > 0 ) || reactions.length > 0
                    height: ( ( chatPage.isChannel && messageViewCount > 0 ) || reactions.length > 0 ) ? ( Theme.fontSizeExtraSmall + Theme.paddingSmall ) : 0
                    sourceComponent: Component {
                        Label {
                            text: getInteractionText(messageViewCount, reactions, font.pixelSize, Theme.highlightColor)
                            width: parent.width
                            font.pixelSize: Theme.fontSizeTiny
                            color: messageListItem.useOutgoingLayout ? Theme.secondaryHighlightColor : Theme.secondaryColor
                            horizontalAlignment: messageListItem.textAlign
                            textFormat: Text.StyledText
                            maximumLineCount: 1
                            elide: Text.ElideRight
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (messageListItem.messageReactions) {
                                        messageListItem.messageReactions = null;
                                        selectReactionBubble.visible = false;
                                    } else {
                                        openReactions();
                                    }
                                }
                            }
                        }
                    }
                }

            }

            Rectangle {
                id: selectReactionBubble
                visible: false
                opacity: visible ? 0.5 : 0.0
                Behavior on opacity { NumberAnimation {} }
                anchors {
                    horizontalCenter: messageListItem.useOutgoingLayout ? messageBackground.left : messageBackground.right
                    verticalCenter: messageBackground.verticalCenter
                }
                height: Theme.itemSizeExtraSmall
                width: Theme.itemSizeExtraSmall
                color: Theme.primaryColor
                radius: parent.width / 2
            }

            IconButton {
                id: selectReactionButton
                visible: selectReactionBubble.visible
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation {} }
                icon.source: "image://theme/icon-s-favorite"
                anchors.centerIn: selectReactionBubble
                onClicked: {
                    openReactions();
                }
            }

        }

    }

    Column {
        id: reactionsColumn
        width: parent.width - ( 2 * Theme.horizontalPageMargin )
        anchors.top: messageTextRow.bottom
        anchors.topMargin: Theme.paddingMedium
        anchors.horizontalCenter: parent.horizontalCenter
        visible: messageListItem.messageReactions ? ( messageListItem.messageReactions.length > 0 ? true : false ) : false
        opacity: messageListItem.messageReactions ? ( messageListItem.messageReactions.length > 0 ? 1 : 0 ) : 0
        Behavior on opacity { NumberAnimation {} }
        spacing: Theme.paddingMedium

        Flickable {
            width: parent.width
            height: reactionsResultRow.height + 2 * Theme.paddingMedium
            anchors.horizontalCenter: parent.horizontalCenter
            contentWidth: reactionsResultRow.width
            clip: true
            Row {
                id: reactionsResultRow
                spacing: Theme.paddingMedium
                Repeater {
                    model: messageListItem.messageReactions

                    Item {
                        height: singleReactionRow.height
                        width: singleReactionRow.width

                        Row {
                            id: singleReactionRow
                            spacing: Theme.paddingMedium

                            Image {
                                id: emojiPicture
                                source: Emoji.getEmojiPath(modelData)
                                width: status === Image.Ready ? Theme.fontSizeExtraLarge : 0
                                height: Theme.fontSizeExtraLarge
                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                for (var i = 0; i < reactions.length; i++) {
                                    var reaction = reactions[i]
                                    var reactionText = ""
                                    if (reaction.reaction) {
                                        reactionText = reaction.reaction
                                    } else if (reaction.type && reaction.type.emoji) {
                                        reactionText = reaction.type.emoji
                                    } else if (reaction.reaction_type && reaction.reaction_type.emoji) {
                                        reactionText = reaction.reaction_type.emoji
                                    }
                                    if (reactionText === modelData) {
                                        var isChosen = reaction.is_chosen === true || reaction.is_selected === true
                                        if (isChosen) {
                                            // Reaction is already selected
                                            tdLibWrapper.removeMessageReaction(chatId, messageId, reactionText)
                                            messageReactions = null
                                            return
                                        }
                                        break
                                    }
                                }
                                // Reaction is not yet selected
                                tdLibWrapper.addMessageReaction(chatId, messageId, modelData)
                                messageReactions = null
                            }
                        }
                    }
                }
            }
        }
    }


}
