import QtQuick 2.6
import Sailfish.Silica 1.0
import WerkWolf.RooTelegram 1.0

import "../js/twemoji.js" as Emoji
import "../js/functions.js" as Functions

PhotoTextsListItem {
    id: listItem
    // Anteprima home: nome+messaggio in flusso unico su 2 righe, orario in basso a dx
    useCompactPreview: true
    pictureThumbnail {
        photoData: photo_small || ({})
        highlighted: listItem.highlighted && !listItem.menuOpen
    }
    property int ownUserId
    // Cartella attualmente visualizzata (0 = "Tutte"): se !=0 mostriamo la voce
    // "Rimuovi dalla cartella" nel menu long-press.
    property int activeFolderId: 0
    // Menù neon a comparsa (NeonMenuOverlay) della pagina: se impostato, il long-press
    // apre quello (stile arancio/rosso) invece del ContextMenu Silica.
    property var neonMenu: null
    property bool showDraft: !!draft_message_text && draft_message_date > last_message_date
    property string previewText: showDraft ? draft_message_text : last_message_text

    function folderNameById(fid) {
        if (!chatFoldersModel) return "";
        for (var i = 0; i < chatFoldersModel.count; i++) {
            if (chatFoldersModel.getId(i) === fid) return chatFoldersModel.getName(i);
        }
        return "";
    }

    // Azioni del menù long-press (per il NeonMenuOverlay): array di {text, visible, callback}.
    function buildChatMenuActions() {
        var anyUnread = unread_count > 0 || unread_reaction_count > 0 || unread_mention_count > 0;
        var actions = [];
        actions.push({ text: qsTr("Mark all messages as read"), visible: anyUnread, callback: function() {
            tdLibWrapper.viewMessage(chat_id, display.last_message.id, true);
            tdLibWrapper.readAllChatMentions(chat_id);
            tdLibWrapper.readAllChatReactions(chat_id);
            tdLibWrapper.toggleChatIsMarkedAsUnread(chat_id, false);
        }});
        actions.push({ text: is_marked_as_unread ? qsTr("Mark chat as read") : qsTr("Mark chat as unread"), visible: !anyUnread, callback: function() {
            tdLibWrapper.toggleChatIsMarkedAsUnread(chat_id, !is_marked_as_unread);
        }});
        actions.push({ text: is_pinned ? qsTr("Unpin chat") : qsTr("Pin chat"), callback: function() {
            tdLibWrapper.toggleChatIsPinned(chat_id, !is_pinned);
        }});
        actions.push({ text: display.notification_settings.mute_for > 0 ? qsTr("Unmute chat") : qsTr("Mute chat"), visible: chat_id != listItem.ownUserId, callback: function() {
            var ns = display.notification_settings;
            ns.mute_for = ns.mute_for > 0 ? 0 : 6666666;
            ns.use_default_mute_for = false;
            tdLibWrapper.setChatNotificationSettings(chat_id, ns);
        }});
        actions.push({ text: qsTr("Add to folder..."), visible: !!(chatFoldersModel && chatFoldersModel.count > 0), callback: function() {
            pageStack.push(Qt.resolvedUrl("../pages/AddToFolderPage.qml"), { "chatId": chat_id });
        }});
        actions.push({ text: qsTr("Remove from folder: %1").arg(listItem.folderNameById(listItem.activeFolderId)), visible: listItem.activeFolderId !== 0, callback: function() {
            var fn = listItem.folderNameById(listItem.activeFolderId);
            tdLibWrapper.removeChatFromFolder(chat_id, listItem.activeFolderId);
            appNotification.show(qsTr("Removed from folder: %1").arg(fn));
        }});
        actions.push({ text: model.display.type['@type'] === "chatTypePrivate" ? qsTr("User Info") : qsTr("Group Info"), callback: function() {
            if (pageStack.depth > 2) {
                pageStack.pop(pageStack.find(function(page){ return(page._depth === 0) }), PageStackAction.Immediate);
            }
            pageStack.push(Qt.resolvedUrl("../pages/ChatInformationPage.qml"), { "chatInformation" : display });
        }});
        actions.push({ text: qsTr("Delete Chat"), visible: model.display.type['@type'] === "chatTypePrivate", callback: function() {
            var chatIdToDelete = chat_id;
            var revoke = !!model.display.can_be_deleted_for_all_users;
            Remorse.itemAction(listItem, qsTr("Deleting chat"), function() {
                tdLibWrapper.sendRequest({ "@type": "deleteChatHistory", "chat_id": chatIdToDelete, "remove_from_chat_list": true, "revoke": revoke });
            });
        }});
        return actions;
    }

    // chat title
    primaryText.text: title ? Emoji.emojify(title, Theme.fontSizeMedium) : qsTr("Unknown")
    // 2.0 abbellimento: tutti i nomi chat in corsivo (#9); pinnate in rosso (#8)
    primaryText.font.italic: true
    primaryText.color: is_pinned
                       ? "#ff5252"
                       : ((appSettings.highlightUnreadConversations && (unread_count > 0)) ? Theme.highlightColor : Theme.primaryColor)
    // last user
    prologSecondaryText.text: showDraft ? "<i>"+qsTr("Draft")+"</i>" : (is_channel ? "" : ( last_message_sender_id ? ( last_message_sender_id !== ownUserId ? Emoji.emojify(Functions.getUserName(tdLibWrapper.getUserInformation(last_message_sender_id)), Theme.fontSizeExtraSmall) : qsTr("You") ) : "" ))
    // last message
    secondaryText.text: previewText ? Emoji.emojify(Functions.enhanceHtmlEntities(previewText), Theme.fontSizeExtraSmall) : "<i>" + qsTr("No message in this chat.") + "</i>"
    // message date
    tertiaryText.text: showDraft ? Functions.getDateTimeElapsed(draft_message_date) : ( last_message_date ? ( last_message_date.length === 0 ? "" : Functions.getDateTimeElapsed(last_message_date) + Emoji.emojify(last_message_status, tertiaryText.font.pixelSize) ) : "" )
    unreadCount: unread_count
    unreadReactionCount: unread_reaction_count
    unreadMentionCount: unread_mention_count
    isSecret: ( chat_type === TelegramAPI.ChatTypeSecret )
    isMarkedAsUnread: is_marked_as_unread
    isPinned: is_pinned
    isMuted: display.notification_settings.mute_for > 0

    openMenuOnPressAndHold: true//chat_id != overviewPage.ownUserId

    onPressAndHold: {
        if (neonMenu) {
            neonMenu.open(buildChatMenuActions());
        } else {
            contextMenuLoader.active = true;
        }
    }

    Loader {
        id: contextMenuLoader
        active: false
        asynchronous: true
        onStatusChanged: {
            if(status === Loader.Ready) {
                listItem.menu = item;
                listItem.openMenu();
            }
        }
        sourceComponent: Component {
            ContextMenu {
                MenuItem {
                    visible: unread_count > 0 || unread_reaction_count > 0 || unread_mention_count > 0
                    onClicked: {
                        tdLibWrapper.viewMessage(chat_id, display.last_message.id, true);
                        tdLibWrapper.readAllChatMentions(chat_id);
                        tdLibWrapper.readAllChatReactions(chat_id);
                        tdLibWrapper.toggleChatIsMarkedAsUnread(chat_id, false);
                    }
                    text: qsTr("Mark all messages as read")
                }

                MenuItem {
                    visible: unread_count === 0 && unread_reaction_count === 0 && unread_mention_count === 0
                    onClicked: {
                        tdLibWrapper.toggleChatIsMarkedAsUnread(chat_id, !is_marked_as_unread);
                    }
                    text: is_marked_as_unread ? qsTr("Mark chat as read") : qsTr("Mark chat as unread")
                }

                MenuItem {
                    onClicked: {
                        tdLibWrapper.toggleChatIsPinned(chat_id, !is_pinned);
                    }
                    text: is_pinned ? qsTr("Unpin chat") : qsTr("Pin chat")
                }

                // Voce singola: apre una pagina con l'elenco delle cartelle (evita un
                // menu lunghissimo quando le cartelle sono molte).
                MenuItem {
                    visible: chatFoldersModel && chatFoldersModel.count > 0
                    text: qsTr("Add to folder...")
                    onClicked: {
                        pageStack.push(Qt.resolvedUrl("../pages/AddToFolderPage.qml"), { "chatId": chat_id });
                    }
                }

                // Visibile solo dentro una cartella: rimuove la chat dalla cartella attiva.
                MenuItem {
                    visible: listItem.activeFolderId !== 0
                    text: qsTr("Remove from folder: %1").arg(listItem.folderNameById(listItem.activeFolderId))
                    onClicked: {
                        var fn = listItem.folderNameById(listItem.activeFolderId);
                        tdLibWrapper.removeChatFromFolder(chat_id, listItem.activeFolderId);
                        appNotification.show(qsTr("Removed from folder: %1").arg(fn));
                    }
                }

                MenuItem {
                    visible: chat_id != listItem.ownUserId
                    onClicked: {
                        var newNotificationSettings = display.notification_settings;
                        if (newNotificationSettings.mute_for > 0) {
                            newNotificationSettings.mute_for = 0;
                        } else {
                            newNotificationSettings.mute_for = 6666666;
                        }
                        newNotificationSettings.use_default_mute_for = false;
                        tdLibWrapper.setChatNotificationSettings(chat_id, newNotificationSettings);
                    }
                    text: display.notification_settings.mute_for > 0 ? qsTr("Unmute chat") : qsTr("Mute chat")
                }

                MenuItem {
                    onClicked: {
                        if(pageStack.depth > 2) {
                            pageStack.pop(pageStack.find( function(page){ return(page._depth === 0)} ), PageStackAction.Immediate);
                        }

                        pageStack.push(Qt.resolvedUrl("../pages/ChatInformationPage.qml"), { "chatInformation" : display});
                    }
                    text: model.display.type['@type'] === "chatTypePrivate" ? qsTr("User Info") : qsTr("Group Info")
                }

                MenuItem {
                    visible: model.display.type['@type'] === "chatTypePrivate"
                    text: qsTr("Delete Chat")
                    onClicked: {
                        var chatIdToDelete = chat_id;
                        var revoke = !!model.display.can_be_deleted_for_all_users;
                        Remorse.itemAction(listItem, qsTr("Deleting chat"), function() {
                            tdLibWrapper.sendRequest({
                                "@type": "deleteChatHistory",
                                "chat_id": chatIdToDelete,
                                "remove_from_chat_list": true,
                                "revoke": revoke
                            });
                        });
                    }
                }
            }
        }
    }

}
