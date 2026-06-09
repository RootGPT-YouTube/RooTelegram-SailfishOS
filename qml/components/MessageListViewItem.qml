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
    contentHeight: messageBackground.height + Theme.paddingMedium + ( topInfoVisible ? topInfoHeight + Theme.paddingSmall : 0 ) + ( translationItem.visible ? translationItem.height + Theme.paddingSmall : 0 ) + ( transcriptionItem.visible ? transcriptionItem.height + Theme.paddingSmall : 0 ) + ( reactionsColumn.visible ? reactionsColumn.height : 0 ) + ( commentsButton.visible ? commentsButton.height + Theme.paddingSmall : 0 )
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
    // I tipi modificabili: testo e i media con didascalia (foto/video/animazione/
    // audio/documento/vocale). Il fallback can_be_edited di TDLib da solo non basta
    // (spesso assente/false sui media), quindi per i messaggi PROPRI abilitiamo
    // esplicitamente questi tipi: l'eventuale rifiuto (es. troppo vecchio) arriva
    // poi dal server, come già accade per il testo.
    readonly property var editableContentTypes: ["messageText", "messagePhoto",
        "messageVideo", "messageAnimation", "messageAudio", "messageDocument", "messageVoiceNote"]
    readonly property bool canEditMessage:
        (typeof myMessage.can_be_edited !== "undefined" && myMessage.can_be_edited === true) ||
        (isOwnMessage &&
         myMessage &&
         myMessage["@type"] !== "sponsoredMessage" &&
         myMessage.content &&
         editableContentTypes.indexOf(myMessage.content["@type"]) !== -1 &&
         !myMessage.sending_state)
    readonly property bool canPinMessage:
        page.canPinMessages() &&
        myMessage &&
        myMessage["@type"] !== "sponsoredMessage" &&
        typeof myMessage.id !== "undefined"
    // Media singolo foto/video (NON album): il fumetto si stringe sul media (cornice
    // minima) e il media è mostrato completo, ridotto all'80% schermo (#5). Il
    // componente media espone `preferredWidth`.
    readonly property bool isSingleMedia:
        myMessage &&
        myMessage.content &&
        (myMessage.content["@type"] === "messagePhoto" || myMessage.content["@type"] === "messageVideo") &&
        (typeof myMessage.media_album_id === "undefined" || myMessage.media_album_id === "0")
    // On-demand: la selezione del testo (e il costoso Emoji.emojify + parse RichText
    // del TextEdit) si attiva SOLO sul messaggio selezionato in modalit\u00e0 selezione,
    // non su tutti i delegate insieme (preserva la performance su canali photo-heavy).
    readonly property bool canSelectMessageText: !!(messageListItem.precalculatedValues && messageListItem.precalculatedValues.pageIsSelecting) && isSelected
    readonly property string selectedMessageText: canSelectMessageText ? (messageText.selectedText || "").replace(/\u2029/g, "\n") : ""
    readonly property bool hasSelectedMessageText: selectedMessageText.length > 0
    // Propaga il testo selezionato a ChatPage cos\u00ec la barra azioni in basso pu\u00f2
    // offrire "copia testo selezionato" accanto a "copia intero messaggio".
    onSelectedMessageTextChanged: {
        if (canSelectMessageText && isSelected) {
            page.activeSelectedText = selectedMessageText;
        }
    }
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
    // Lista "chi ha reagito e con quale reaction" (addedReaction[]), mostrata nel
    // pannello stellina sotto al picker delle reaction disponibili.
    property var messageAddedReactions: null

    // Chi ha VISTO il messaggio (messageViewer[] = {user_id, view_date}); disponibile solo
    // per i propri messaggi in gruppi piccoli/recenti (flag can_get_viewers del messaggio).
    property var messageViewers: null
    function messageViewersText() {
        if (!messageViewers || messageViewers.length === 0) return "";
        var names = [];
        for (var i = 0; i < messageViewers.length; i++) {
            names.push(Functions.getUserName(tdLibWrapper.getUserInformation(messageViewers[i].user_id)));
        }
        return names.join(", ");
    }
    // Banda info in cima al bubble (reaction a sx + visualizzatori a dx): altezza = la più alta.
    readonly property bool topInfoVisible: addedReactionsAbove.visible || messageViewersRow.visible
    readonly property real topInfoHeight: Math.max(addedReactionsAbove.visible ? addedReactionsAbove.height : 0,
                                                    messageViewersRow.visible ? messageViewersRow.height : 0)

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

    // Intercetta i link "rtcopy://OFFSET/LENGTH" emessi dai render dei blocchi
    // monospace (code/pre/preCode): al tap copia in clipboard quella sottostringa
    // del testo del messaggio (come Telegram). Gli offset TDLib sono in unità UTF-16,
    // coerenti con String.substring di JS. Ritorna true se gestito.
    function handleCopyLink(link) {
        if (typeof link !== "string" || link.indexOf("rtcopy://") !== 0) {
            return false;
        }
        var parts = link.substring("rtcopy://".length).split("/");
        if (parts.length < 2) {
            return true;
        }
        var offset = parseInt(parts[0], 10);
        var length = parseInt(parts[1], 10);
        var ft = myMessage.content.text ? myMessage.content.text
               : (myMessage.content.caption ? myMessage.content.caption : null);
        if (ft && typeof ft.text === "string") {
            var code = ft.text.substring(offset, offset + length);
            if (code.length > 0) {
                Clipboard.text = code;
                appNotification.show(qsTr("Code copied to clipboard"));
            }
        }
        return true;
    }

    // Cancellazione (#1). In TDLib 1.8.62 le capability (can_be_deleted_for_all_users
    // / only_for_self) NON sono più inline nel messaggio: si ottengono async con
    // getMessageProperties. Al tap su "Cancella" chiediamo le proprietà; alla
    // risposta (onMessagePropertiesReceived) se entrambe possibili mostriamo la
    // scelta "per tutti"/"solo per me", altrimenti cancelliamo diretto. Remorse sempre.
    property bool deletePending: false
    property bool deletePendingAlbum: false

    function requestDelete(album) {
        deletePendingAlbum = album;
        deletePending = true;
        tdLibWrapper.getMessageProperties(page.chatInformation.id, myMessage.id);
    }

    function performDelete(album, revoke) {
        if (album) {
            deleteAlbum(revoke);
        } else {
            deleteMessage(revoke);
        }
    }

    // revoke=true → cancella per tutti; false → solo per me. Il Remorse resta.
    function deleteMessage(revoke) {
        var chatId = page.chatInformation.id
        var messageId = myMessage.id
        Remorse.itemAction(messageListItem, qsTr("Message deleted"), function() {
            tdLibWrapper.deleteMessages(chatId, [ messageId ], revoke);
        })
    }

    // Traduzione del messaggio (API nativa TDLib, nessun servizio esterno).
    property string translatedText: ""
    property bool translating: false
    // Traducibile se ha testo (messageText) OPPURE una didascalia (foto/video/
    // ecc. → content.caption). Prima il gate guardava solo content.text.text,
    // quindi le didascalie dei media non erano traducibili (#13).
    readonly property bool hasTranslatableText: !!(myMessage && myMessage.content
        && ((myMessage.content.text && myMessage.content.text.text)
            || (myMessage.content.caption && myMessage.content.caption.text)))

    // Trascrizione vocale (Premium): letta direttamente dal messaggio (reattiva agli
    // updateMessageContent). Pending = in corso, Text = pronta.
    readonly property var speechResult: (myMessage && myMessage.content && myMessage.content.voice_note && myMessage.content.voice_note.speech_recognition_result)
                                        ? myMessage.content.voice_note.speech_recognition_result : null
    readonly property string transcribedText: (speechResult && speechResult['@type'] === "speechRecognitionResultText" && speechResult.text) ? speechResult.text : ""
    readonly property bool transcribing: !!(speechResult && speechResult['@type'] === "speechRecognitionResultPending")

    function translateMessage() {
        translating = true
        translatedText = ""
        tdLibWrapper.translateMessageText(page.chatInformation.id, myMessage.id, page.translateTargetLanguage)
    }

    // True quando il messaggio fa parte di un album multimediale TDLib
    // (più messaggi inviati in batch con stesso media_album_id).
    readonly property bool isPartOfAlbum: !!myMessage && !!myMessage.media_album_id && myMessage.media_album_id !== "0"

    function deleteAlbum(revoke) {
        if (!isPartOfAlbum) {
            deleteMessage(revoke)
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
            tdLibWrapper.deleteMessages(chatId, stringIds, revoke);
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
    // Info messaggio (#1): apre la pagina con i metadati (date, mittente, inoltro,
    // dati tecnici). Sostituisce il vecchio tap relativo/assoluto sulla data.
    function showMessageInfo() {
        pageStack.push(Qt.resolvedUrl("../pages/MessageInfoPage.qml"),
                       { messageObject: myMessage, chatId: page.chatInformation.id });
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

    // Menù neon a comparsa (NeonMenuOverlay) della ChatPage: se impostato, il
    // long-press apre quello (stile arancio/rosso) invece del ContextMenu Silica.
    property var neonMenu: null

    // Azioni del menù long-press messaggio per il NeonMenuOverlay.
    function buildMessageMenuActions() {
        var actions = [];
        actions.push({ text: anySpoilerRevealed ? qsTr("Hide spoiler") : qsTr("Reveal spoiler"), visible: hasSpoilers, callback: function() { toggleAllSpoilers(); }});
        actions.push({ text: qsTr("Reply to Message"), visible: canReplyToMessage, callback: function() { replyToMessage(); }});
        actions.push({ text: qsTr("Copy Message to Clipboard"), visible: showCopyMessageToClipboardMenuItem, callback: function() { copyMessageToClipboard(); }});
        actions.push({ text: qsTr("Forward message"), visible: showForwardMessageMenuItem, callback: function() { forwardMessage(); }});
        actions.push({ text: qsTr("Translate message"), visible: hasTranslatableText, callback: function() { messageListItem.translateMessage(); }});
        actions.push({ text: (myMessage && myMessage.is_pinned) ? qsTr("Unpin Message") : qsTr("Pin Message"), visible: canPinMessage, callback: function() { togglePinMessage(); }});
        actions.push({ text: qsTr("Edit Message"), visible: canEditMessage, callback: function() { requestEditMessage(); }});
        actions.push({ text: qsTr("Delete message"), visible: canDeleteMessage, callback: function() { requestDelete(false); }});
        actions.push({ text: qsTr("Delete album"), visible: canDeleteMessage && isPartOfAlbum, callback: function() { requestDelete(true); }});
        actions.push({ text: qsTr("Select Message"), visible: true, callback: function() { page.toggleMessageSelection(myMessage); }});
        actions.push({ text: qsTr("More Options..."), visible: (numberOfExtraOptionsOtherThanDeleteMessage > 0) || (canDeleteMessage && !haveSpaceForDeleteMessageMenuItem), callback: function() { openAdditionalOptionsDrawer(); }});
        actions.push({ text: qsTr("Message info"), visible: myMessage && myMessage["@type"] !== "sponsoredMessage", callback: function() { showMessageInfo(); }});
        return actions;
    }

    function openContextMenu() {
        messageOptionsDrawer.open = false
        if (neonMenu) {
            neonMenu.open(buildMessageMenuActions());
        } else if (messageListItem.menu) {
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
                // 2.0 (#2): emoji della reaction RICEVUTA RADDOPPIATA (più leggibile).
                // NB emojify applica un fattore 0.8 alla size → per raddoppiare l'emoji
                // visibile passo size*2 (1.2 non cambiava nulla: 1.2*0.8≈1).
                // La 👁️ del conteggio visualizzazioni resta alla dimensione base.
                interactionText += ( "&nbsp;" + Emoji.emojify(reactionText, Math.round(size * 2)) );
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
        // I messaggi non ancora inviati (sending_state valorizzato), sponsorizzati
        // o senza id valido hanno un message_id che TDLib rifiuta con
        // MSG_ID_INVALID: evitiamo di interrogarlo (causava un toast d'errore).
        var canQueryReactions = !!messageListItem.messageId
                && messageListItem.messageId.toString() !== "0"
                && !(myMessage && myMessage.sending_state);
        if (messageListItem.chatReactions) {
            Debug.log("Using chat reactions")
            messageListItem.messageReactions = chatReactions
            showItemCompletelyTimer.requestedIndex = index;
            showItemCompletelyTimer.start();
        } else if (canQueryReactions) {
            Debug.log("Obtaining message reactions")
            tdLibWrapper.getMessageAvailableReactions(messageListItem.chatId, messageListItem.messageId);
        }
        // Chi ha reagito e con cosa (asincrono: arriva via onMessageAddedReactionsReceived).
        // La interroghiamo per ogni messaggio con id valido: dove TDLib non la
        // espone (gruppi grandi) risponde MSG_ID_INVALID, ora ignorato a livello
        // di handleErrorMessage (niente toast), senza rompere la lista reattori
        // nelle chat dove invece è disponibile.
        messageListItem.messageAddedReactions = null;
        if (canQueryReactions) {
            tdLibWrapper.getMessageAddedReactions(messageListItem.chatId, messageListItem.messageId);
        }
        // Chi ha VISTO il messaggio: solo dove TDLib lo consente (can_get_viewers =
        // propri messaggi in gruppi piccoli/recenti). Altrimenti non interroghiamo.
        messageListItem.messageViewers = null;
        if (canQueryReactions && myMessage && myMessage.can_get_viewers) {
            tdLibWrapper.getMessageViewers(messageListItem.chatId, messageListItem.messageId);
        }
        selectReactionBubble.visible = false;
    }

    function addedReactionEmoji(reactionType) {
        if (reactionType && reactionType.emoji) {
            return reactionType.emoji;
        }
        return ""; // custom emoji: nessuna emoji standard renderizzabile
    }

    function addedReactionSenderName(senderId) {
        if (!senderId) {
            return qsTr("Someone");
        }
        if (senderId.user_id) {
            var user = tdLibWrapper.getUserInformation("" + senderId.user_id);
            if (user) {
                var name = ((user.first_name ? user.first_name : "") + " " + (user.last_name ? user.last_name : "")).trim();
                if (name.length > 0) {
                    return name;
                }
            }
        }
        if (senderId.chat_id) {
            var chat = tdLibWrapper.getChat("" + senderId.chat_id);
            if (chat && chat.title) {
                return chat.title;
            }
        }
        return qsTr("Someone");
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

        if (messageListItem.isOwnMessage) {
            // Sui PROPRI messaggi la reaction è inutile: il tap mostra/chiude CHI ha
            // visto il messaggio (👁) invece della stellina. Disponibile solo se TDLib
            // lo consente (can_get_viewers: gruppi piccoli/recenti); altrimenti niente.
            // can_get_viewers è inaffidabile nella cache (spesso assente anche quando
            // disponibile) → interroghiamo sempre; TDLib risponde con la lista (vuota
            // dove non disponibile, senza errori bloccanti).
            selectReactionBubble.visible = false;
            // I "visti" (👁) esistono SOLO nei gruppi: in chat private/canali
            // getMessageViewers darebbe l'errore "Can't get viewers of incoming
            // messages" (#12). Quindi interroghiamo solo in basic/supergruppi.
            if (messageListItem.messageViewers) {
                messageListItem.messageViewers = null;   // secondo tap richiude
            } else if ((page.isBasicGroup || page.isSuperGroup)
                       && !!messageListItem.messageId && messageListItem.messageId.toString() !== "0") {
                tdLibWrapper.getMessageViewers(messageListItem.chatId, messageListItem.messageId);
                elementSelected(index);
            }
        } else if (messageListItem.messageReactions) {
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
                    visible: hasTranslatableText
                    onClicked: messageListItem.translateMessage()
                    text: qsTr("Translate message")
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
                    onClicked: requestDelete(false)
                    text: qsTr("Delete message")
                }
                MenuItem {
                    visible: canDeleteMessage && isPartOfAlbum
                    onClicked: requestDelete(true)
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
                MenuItem {
                    visible: myMessage && myMessage["@type"] !== "sponsoredMessage"
                    onClicked: showMessageInfo()
                    text: qsTr("Message info")
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
        onMessageTextTranslated: {
            if (chatId === page.chatInformation.id && messageId === myMessage.id) {
                messageListItem.translating = false
                messageListItem.translatedText = translatedText
            }
        }
        onMessagePropertiesReceived: {
            if (!messageListItem.deletePending) {
                return;
            }
            if (chatId !== page.chatInformation.id || messageId !== myMessage.id) {
                return;
            }
            messageListItem.deletePending = false;
            var album = messageListItem.deletePendingAlbum;
            var forAll = !!properties.can_be_deleted_for_all_users;
            var forSelf = !!properties.can_be_deleted_only_for_self;
            if (forAll && forSelf) {
                // Entrambe possibili → chiedi "per tutti" / "solo per me".
                var cnt = album
                    ? (chatModel.getMessageIdsForAlbum(myMessage.media_album_id) || [ myMessage.id ]).length
                    : 1;
                var dlg = pageStack.push(Qt.resolvedUrl("../components/DeleteMessagesChoiceDialog.qml"), { "count": cnt });
                dlg.accepted.connect(function() { messageListItem.performDelete(album, dlg.revoke); });
            } else {
                // Una sola opzione: per tutti se consentito, altrimenti solo per me.
                messageListItem.performDelete(album, forAll);
            }
        }
        onErrorReceived: {
            // extra == "translateMessage:<chatId>:<messageId>" della richiesta: se
            // la traduzione fallisce (FLOOD_WAIT, lingua non supportata) sblocca lo stato.
            if (extra === "translateMessage:" + page.chatInformation.id + ":" + myMessage.id) {
                messageListItem.translating = false
            }
            // Fallback cancellazione: se getMessageProperties fallisce, cancella
            // comunque (solo per me, sempre consentito) per non lasciare il tap a vuoto.
            if (messageListItem.deletePending &&
                    extra === "messageProperties:" + page.chatInformation.id + ":" + myMessage.id) {
                messageListItem.deletePending = false;
                messageListItem.performDelete(messageListItem.deletePendingAlbum, false);
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
        onMessageAddedReactionsReceived: {
            if (messageListItem.messageId === messageId) {
                messageListItem.messageAddedReactions = reactions;
            }
        }
        onMessageViewersReceived: {
            if (messageListItem.messageId === messageId) {
                messageListItem.messageViewers = viewers;
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

    // 2.0 abbellimento (#4): la lista "chi ha reagito" (emoji + nome) compare SOPRA
    // il bubble del messaggio (non più sotto le reaction); il messaggio scende per
    // fare spazio. Visibile finché il menu del messaggio è aperto (messageAddedReactions).
    Column {
        id: addedReactionsAbove
        width: parent.width - ( 2 * Theme.horizontalPageMargin )
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.paddingSmall
        spacing: Theme.paddingSmall
        visible: messageListItem.messageAddedReactions ? messageListItem.messageAddedReactions.length > 0 : false

        Repeater {
            model: messageListItem.messageAddedReactions

            Row {
                spacing: Theme.paddingMedium

                Image {
                    source: Emoji.getEmojiPath(messageListItem.addedReactionEmoji(modelData.type))
                    width: status === Image.Ready ? Theme.fontSizeMedium : 0
                    height: Theme.fontSizeMedium
                    anchors.verticalCenter: parent.verticalCenter
                }

                Label {
                    text: messageListItem.addedReactionSenderName(modelData.sender_id)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.secondaryHighlightColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // Chi ha VISTO il messaggio: in alto a DESTRA del bubble (occhio + nomi). Compare al
    // tap quando TDLib lo consente (can_get_viewers: propri messaggi, gruppi piccoli/recenti).
    Column {
        id: messageViewersRow
        anchors.right: parent.right
        anchors.rightMargin: Theme.horizontalPageMargin
        y: Theme.paddingSmall
        spacing: Theme.paddingSmall
        visible: messageListItem.messageViewers ? messageListItem.messageViewers.length > 0 : false

        // Prime 5 persone che hanno visto il messaggio (👁 sulla prima riga).
        Repeater {
            model: messageListItem.messageViewers ? Math.min(5, messageListItem.messageViewers.length) : 0

            Row {
                anchors.right: parent.right
                spacing: Theme.paddingSmall

                Image {
                    source: index === 0 ? Emoji.getEmojiPath("👁") : ""
                    width: (index === 0 && status === Image.Ready) ? Theme.fontSizeSmall : 0
                    height: Theme.fontSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Label {
                    text: Functions.getUserName(tdLibWrapper.getUserInformation(messageListItem.messageViewers[index].user_id))
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.secondaryHighlightColor
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, messageListItem.width * 0.55)
                    truncationMode: TruncationMode.Fade
                }
            }
        }

        // "+x": apre l'elenco COMPLETO dei visualizzatori in una pagina dedicata.
        Label {
            anchors.right: parent.right
            visible: messageListItem.messageViewers && messageListItem.messageViewers.length > 5
            text: "+" + (messageListItem.messageViewers ? (messageListItem.messageViewers.length - 5) : 0)
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
            color: Theme.highlightColor

            MouseArea {
                anchors.fill: parent
                onClicked: pageStack.push(Qt.resolvedUrl("../pages/MessageViewersPage.qml"),
                                          { chatId: messageListItem.chatId, messageId: messageListItem.messageId })
            }
        }
    }

    Row {
        id: messageTextRow
        spacing: Theme.paddingSmall
        width: precalculatedValues.entryWidth
        // 2.0 abbellimento (#6): nei gruppi/commenti canali l'avatar dei propri
        // messaggi va a destra del bubble, coerente col lato dei propri messaggi.
        layoutDirection: messageListItem.useOutgoingLayout ? Qt.RightToLeft : Qt.LeftToRight
        anchors.horizontalCenter: Functions.isWidescreen(appWindow) ? undefined : parent.horizontalCenter
        anchors.left: Functions.isWidescreen(appWindow) ? parent.left : undefined
        // Scende sotto la lista "chi ha reagito" quando è visibile (#4).
        y: messageListItem.topInfoVisible
           ? (Theme.paddingSmall + messageListItem.topInfoHeight + Theme.paddingSmall)
           : Theme.paddingSmall
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
                    // Foto singola: allinea il fumetto al lato giusto (dx i propri, sx gli altrui);
                    // altrimenti comportamento classico (sinistra + leftMargin per i propri).
                    left: (messageListItem.useOutgoingLayout && messageListItem.isSingleMedia) ? undefined : parent.left
                    right: (messageListItem.useOutgoingLayout && messageListItem.isSingleMedia) ? parent.right : undefined
                    leftMargin: (messageListItem.useOutgoingLayout && !messageListItem.isSingleMedia) ? precalculatedValues.pageMarginDouble : 0
                    verticalCenter: parent.verticalCenter
                }
                // Cornice MINIMA per le foto singole: il fumetto avvolge l'immagine.
                height: messageListItem.isSingleMedia
                        ? messageTextColumn.height + 2 * Theme.paddingSmall
                        : messageTextColumn.height + precalculatedValues.paddingMediumDouble
                width: (messageListItem.isSingleMedia && extraContentLoader.item)
                       ? Math.round(extraContentLoader.item.preferredWidth + 2 * Theme.paddingSmall)
                       : precalculatedValues.backgroundWidth
                property bool isUnread: messageIndex > chatModel.getLastReadMessageIndex() && myMessage['@type'] !== "sponsoredMessage"
                // Effetto "vetro leggero" (glassmorphism): fumetto molto più trasparente
                // (alpha bassa sul colore, opacity=1) + bordo sottile luminoso. Niente blur
                // (sarebbe 1 passata per messaggio nella lista → pesante su CPU/batteria).
                property color glassBase: Theme.colorScheme === Theme.LightOnDark ? (isUnread ? Theme.secondaryHighlightColor : Theme.secondaryColor) : (isUnread ? Theme.backgroundGlowColor : Theme.overlayBackgroundColor)
                // Tema Silica: fumetto più solido, senza bordo neon colorato.
                color: appSettings.useNeonTheme ? Theme.rgba(glassBase, isUnread ? 0.22 : 0.08)
                                                : Theme.rgba(glassBase, isUnread ? 0.32 : 0.18)
                radius: parent.width / 50
                opacity: 1
                border.width: appSettings.useNeonTheme ? 2 : 0
                // Bordo "vetro" colorato (solo Neon): ROSSO per i propri messaggi, ARANCIONE per gli altrui.
                border.color: Theme.rgba(messageListItem.isOwnMessage ? "#ff5252" : "#ff8a3d", 0.45)
                visible: appSettings.showStickersAsImages || (myMessage.content['@type'] !== "messageSticker" && myMessage.content['@type'] !== "messageAnimatedEmoji")
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            Column {
                id: messageTextColumn

                spacing: Theme.paddingSmall

                // Foto singola: la colonna (e quindi il fumetto) larga quanto l'immagine.
                width: (messageListItem.isSingleMedia && extraContentLoader.item)
                       ? extraContentLoader.item.preferredWidth
                       : precalculatedValues.textColumnWidth
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
                    // Nascondi il chip "in risposta a" se il reply punta al root del thread
                    // (= il post del canale clonato nel discussion group): in modalità
                    // commenti il reply implicito è ovvio e mostrarlo confonde.
                    active: typeof myMessage.reply_to_message_id !== "undefined"
                            && myMessage.reply_to_message_id !== 0
                            && !(page.messageThreadId > 1
                                 && Number(myMessage.reply_to_message_id) === Number(page.messageThreadId))
                    width: parent.width
                    // Altezza = altezza REALE del contenuto (InReplyToRow: nome + anteprima).
                    // Stimarla con un moltiplicatore del font la rendeva troppo corta e
                    // tagliava drasticamente la riga citata; precalc solo come fallback
                    // per il frame in cui l'item non è ancora caricato.
                    height: active ? (item ? item.height : precalculatedValues.messageInReplyToHeight) : 0
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

                // Chip "in risposta a una storia": il reply-a-storia non popola
                // reply_to_message_id (è in reply_to come messageReplyToStory),
                // quindi l'InReplyToRow sopra non scatta. Mostriamo un'etichetta
                // dedicata così si capisce che il messaggio risponde a una storia.
                Loader {
                    id: storyReplyChipLoader
                    active: typeof myMessage.reply_to !== "undefined" && myMessage.reply_to
                            && myMessage.reply_to["@type"] === "messageReplyToStory"
                    width: parent.width
                    height: active ? Theme.iconSizeSmall + Theme.paddingSmall : 0
                    sourceComponent: Component {
                        Item {
                            width: storyReplyChipLoader.width
                            height: storyReplyChipRow.height
                            Row {
                                id: storyReplyChipRow
                                spacing: Theme.paddingSmall
                                Image {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Theme.iconSizeSmall
                                    height: Theme.iconSizeSmall
                                    sourceSize.width: Theme.iconSizeSmall
                                    sourceSize.height: Theme.iconSizeSmall
                                    source: "image://theme/icon-s-message-reply?" + Theme.highlightColor
                                }
                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("In reply to a story")
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    color: Theme.highlightColor
                                }
                            }
                            MouseArea {
                                anchors.fill: storyReplyChipRow
                                onClicked: {
                                    // Apre la storia di riferimento (può essere scaduta:
                                    // il viewer ha un timeout di fallback con toast).
                                    pageStack.push(Qt.resolvedUrl("../pages/StoriesViewerPage.qml"), {
                                        chatId: myMessage.reply_to.story_poster_chat_id,
                                        storyInfos: [ { "story_id": myMessage.reply_to.story_id } ]
                                    });
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

                // Contenuto media (foto/video/...) — SOPRA l'eventuale didascalia (#5).
                Loader {
                    id: extraContentLoader
                    width: (messageListItem.isSingleMedia && item)
                           ? item.preferredWidth
                           : parent.width * getContentWidthMultiplier()
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

                // PROTOTIPO selezione nativa Sailfish: in modalità selezione il testo
                // del messaggio selezionato viene mostrato con una Silica TextArea
                // read-only, che fornisce le maniglie start/end + lente + popup copia
                // nativi. È montata on-demand (solo sul messaggio selezionato) per non
                // pagare il costo su tutti i delegate. NB: TextArea è PlainText → niente
                // emoji-immagini né link cliccabili in selezione (limite noto del prototipo).
                TextArea {
                    id: messageText
                    width: parent.width
                    text: messageListItem.canSelectMessageText
                          ? Functions.getMessageText(myMessage, true, page.myUserId, true)
                          : ""
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                    readOnly: true
                    labelVisible: false
                    label: ""
                    placeholderText: ""
                    backgroundStyle: TextEditor.NoBackground
                    textTopPadding: 0
                    textLeftPadding: 0
                    textRightPadding: 0
                    horizontalAlignment: messageListItem.textAlign
                    visible: canSelectMessageText && (text !== "")
                    // La selezione nativa di Silica su una TextArea read-only parte solo
                    // se l'editor ha già activeFocus (focusOnClick è false in read-only).
                    // Diamogli il focus appena diventa selezionabile, così il primo
                    // long-press su una parola avvia subito la selezione.
                    onVisibleChanged: {
                        if (visible) {
                            forceActiveFocus();
                        }
                    }
                }

                Text {
                    id: messageTextDisplay
                    width: parent.width
                    text: (messageListItem.revealedSpoilersVersion, Emoji.emojify(Functions.getMessageText(myMessage, false, page.myUserId, false, messageListItem.revealedSpoilers), Theme.fontSizeMedium))
                    font.pixelSize: Theme.fontSizeSmall
                    color: messageListItem.textColor
                    // Link/username adattivi al tema (#8): ROSSO sui temi scuri, BLU
                    // sui temi chiari (URL e menzioni hanno già il colore inline via
                    // Functions.messageLinkColor; questo copre mailto/tel/botCommand).
                    linkColor: Theme.colorScheme === Theme.DarkOnLight ? "#2481cc" : "#ff6e40"
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    textFormat: Text.RichText
                    onLinkActivated: {
                        if (messageListItem.handleSpoilerLink(link)) {
                            return;
                        }
                        if (messageListItem.handleCopyLink(link)) {
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

                    // Mostra sempre il tempo relativo ("5 minuti fa"): il tap che
                    // alternava relativo/assoluto è stato rimosso (#1 v2.4). Le info
                    // complete (data assoluta + metadati) sono in "Info messaggio"
                    // nel menù long-press → MessageInfoPage.
                    property bool useElapsed: true

                    id: messageDateText
                    font.pixelSize: Theme.fontSizeTiny
                    color: messageListItem.useOutgoingLayout ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    horizontalAlignment: messageListItem.textAlign
                    text: getMessageStatusText(myMessage, messageIndex, chatView.lastReadSentIndex, messageDateText.useElapsed)
                }

                Loader {
                    id: interactionLoader
                    width: parent.width
                    asynchronous: true
                    active: ( chatPage.isChannel && messageViewCount > 0 ) || reactions.length > 0
                    // Più alto per contenere l'emoji reaction raddoppiata (#2).
                    height: ( ( chatPage.isChannel && messageViewCount > 0 ) || reactions.length > 0 ) ? ( Math.max(Theme.fontSizeExtraSmall, Math.round(Theme.fontSizeTiny * 1.6)) + Theme.paddingSmall ) : 0
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

    BackgroundItem {
        id: commentsButton

        readonly property var replyInfo: (myMessage && myMessage.interaction_info) ? myMessage.interaction_info.reply_info : null
        readonly property int replyCount: replyInfo ? (replyInfo.reply_count || 0) : 0

        anchors {
            top: reactionsColumn.visible ? reactionsColumn.bottom : (translationItem.visible ? translationItem.bottom : (transcriptionItem.visible ? transcriptionItem.bottom : messageTextRow.bottom))
            topMargin: Theme.paddingSmall
            horizontalCenter: parent.horizontalCenter
        }
        width: parent.width - ( 2 * Theme.horizontalPageMargin )
        // Mostra il bottone "N comment(s)" solo se siamo in un canale broadcast
        // E il post è davvero commentabile (TDLib popola reply_info SOLO sui
        // canali con discussion group linkato). Attenzione: TDLib serializza il
        // campo assente come `undefined`, non `null`, e in JS `undefined !== null`
        // è true: serve un truthy-check, non un null-check.
        height: (chatPage.isChannel && !!replyInfo) ? Theme.itemSizeExtraSmall : 0
        visible: !!(chatPage.isChannel && replyInfo)

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.paddingSmall

            Image {
                source: "image://theme/icon-s-chat?" + (commentsButton.highlighted ? Theme.highlightColor : Theme.primaryColor)
                width: Theme.iconSizeSmall
                height: Theme.iconSizeSmall
                anchors.verticalCenter: parent.verticalCenter
            }

            Label {
                text: qsTr("%n comment(s)", "", commentsButton.replyCount) + " ↑"
                color: commentsButton.highlighted ? Theme.highlightColor : Theme.primaryColor
                font.pixelSize: Theme.fontSizeSmall
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        onClicked: {
            tdLibWrapper.getMessageThread(messageListItem.chatId, messageListItem.messageId);
        }
    }

    Connections {
        target: tdLibWrapper
        onMessageThreadInfoReceived: {
            if (chatId !== messageListItem.chatId || messageId !== messageListItem.messageId) {
                return;
            }
            var discussionChatId = threadInfo.chat_id;
            var messageThreadId = threadInfo.message_thread_id;
            if (!discussionChatId || !messageThreadId) {
                return;
            }
            var discussionChat = tdLibWrapper.getChat(discussionChatId.toString());
            if (!discussionChat || !discussionChat.id) {
                return;
            }
            pageStack.push(Qt.resolvedUrl("../pages/ChatPage.qml"), {
                chatInformation: discussionChat,
                messageThreadId: messageThreadId
            });
        }
    }

    // Sezione testo tradotto: fratello di reactionsColumn, con visibilità propria
    // (NON figlio di reactionsColumn, altrimenti sparirebbe sui messaggi senza reazioni).
    Column {
        id: translationItem
        width: parent.width - ( 2 * Theme.horizontalPageMargin )
        anchors.top: messageTextRow.bottom
        anchors.topMargin: Theme.paddingSmall
        anchors.horizontalCenter: parent.horizontalCenter
        visible: messageListItem.translatedText !== "" || messageListItem.translating
        spacing: Theme.paddingSmall

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.secondaryHighlightColor
            opacity: 0.5
        }

        BusyIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            running: messageListItem.translating
            visible: messageListItem.translating
            size: BusyIndicatorSize.ExtraSmall
        }

        Label {
            visible: messageListItem.translatedText !== ""
            width: parent.width
            // translateMessageText restituisce la formattazione come tag HTML:
            // StyledText li rende (grassetto/corsivo...) invece di mostrarli letterali.
            textFormat: Text.StyledText
            text: "🌐 " + messageListItem.translatedText
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.secondaryHighlightColor
            wrapMode: Text.Wrap
        }
    }

    // Trascrizione vocale (Premium), stile come la traduzione: testo arancione FUORI
    // dal fumetto, sotto il messaggio, con icona cassa audio invece del mappamondo.
    Column {
        id: transcriptionItem
        width: parent.width - ( 2 * Theme.horizontalPageMargin )
        anchors.top: messageTextRow.bottom
        anchors.topMargin: Theme.paddingSmall
        anchors.horizontalCenter: parent.horizontalCenter
        visible: messageListItem.transcribedText !== "" || messageListItem.transcribing
        spacing: Theme.paddingSmall

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.secondaryHighlightColor
            opacity: 0.5
        }

        BusyIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            running: messageListItem.transcribing
            visible: messageListItem.transcribing
            size: BusyIndicatorSize.ExtraSmall
        }

        Label {
            visible: messageListItem.transcribedText !== ""
            width: parent.width
            text: "🔊 " + messageListItem.transcribedText
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.secondaryHighlightColor
            wrapMode: Text.Wrap
        }
    }

    Column {
        id: reactionsColumn
        width: parent.width - ( 2 * Theme.horizontalPageMargin )
        anchors.top: translationItem.visible ? translationItem.bottom : (transcriptionItem.visible ? transcriptionItem.bottom : messageTextRow.bottom)
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
