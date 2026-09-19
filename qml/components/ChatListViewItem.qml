import QtQuick 2.6
import Sailfish.Silica 1.0
import WerkWolf.RooTelegram 1.0
import "."

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

    // ⛔ Le due voci di lettura qui sotto lavorano a livello di CHAT. Nel 2026-09-16
    // erano state tolte da gruppi e forum (decisione dell'utente: «non servono a molto
    // quelle voci, meglio eliminarle dai gruppi e dai forum»); dal 2026-09-18 la sola
    // "segna tutto come letto" e' tornata nei gruppi e nei supergruppi NON forum, dove
    // fa quello che promette. Sui FORUM era anche proprio SBAGLIATA:
    // i contatori di non letto stanno PER TOPIC e il badge e' la somma dei topic
    // (ForumTopicsPage.qml:582), quindi una viewMessages chat-level su UN solo messaggio
    // non fa nulla — misurato sul POCO il 2026-09-15 con le sonde [VIEWMSG]/[TDERR]:
    // TDLib accetta la richiesta senza errori e i topic restano non letti (55 e 131,
    // invariati dopo il gesto).
    // ⭐ La voce "segna come non letto" (l'altra) resta invece solo dove ha senso:
    // chat con un singolo utente, chat segrete e canali.
    // ⭐ 2026-09-18: la voce di lettura TORNA nei gruppi e nei supergruppi non-forum
    // (richiesta dell'utente dopo aver dovuto scorrere due mesi di arretrati a mano).
    // Li' la viewMessages chat-level FUNZIONA: il contatore di non letto e' uno solo,
    // quello della chat. Resta esclusa la sola famiglia dove non funzionerebbe, i
    // FORUM, che contano per topic (vedi la nota qui sopra): li' la stessa cosa si fa
    // con la pressione prolungata sul singolo topic, in ForumTopicsPage.
    function chatIsForum() {
        var chatType = display["type"] || {};
        if (chatType["@type"] !== "chatTypeSupergroup" || chatType.is_channel) {
            return false;
        }
        var groupInfo = tdLibWrapper.getSuperGroup(chatType.supergroup_id);
        return !!(groupInfo && groupInfo.is_forum === true);
    }

    // Vero se la chat ha un ultimo messaggio a cui ancorare la lettura: senza di
    // quello viewMessages non avrebbe su cosa lavorare.
    function chatCanBeMarkedRead() {
        return !chatIsForum() && !!(display.last_message && display.last_message.id);
    }

    function chatIsGroup() {
        var chatType = display["type"] || {};
        var typeName = chatType["@type"];
        if (typeName === "chatTypeBasicGroup") {
            return true;
        }
        if (typeName === "chatTypeSupergroup") {
            return !chatType.is_channel;   // supergruppi e forum si', canali no
        }
        return false;
    }

    // Azioni del menù long-press (per il NeonMenuOverlay): array di {text, visible, callback}.
    function buildChatMenuActions() {
        var anyUnread = unread_count > 0 || unread_reaction_count > 0 || unread_mention_count > 0;
        var actions = [];
        actions.push({ text: qsTr("Mark all messages as read"), visible: anyUnread && chatCanBeMarkedRead(), callback: function() {
            tdLibWrapper.viewMessage(chat_id, display.last_message.id, true);
            tdLibWrapper.readAllChatMentions(chat_id);
            tdLibWrapper.readAllChatReactions(chat_id);
            tdLibWrapper.toggleChatIsMarkedAsUnread(chat_id, false);
        }});
        actions.push({ text: is_marked_as_unread ? qsTr("Mark chat as read") : qsTr("Mark chat as unread"), visible: !anyUnread && !chatIsGroup(), callback: function() {
            tdLibWrapper.toggleChatIsMarkedAsUnread(chat_id, !is_marked_as_unread);
        }});
        actions.push({ text: is_pinned ? qsTr("Unpin chat") : qsTr("Pin chat"), callback: function() {
            tdLibWrapper.toggleChatIsPinned(chat_id, !is_pinned);
        }});
        actions.push({ text: qsTr("Archive chat"), callback: function() {
            tdLibWrapper.setChatArchived(chat_id, true);
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
        actions.push({ text: qsTr("Delete Chat"), visible: model.display.type['@type'] === "chatTypePrivate", destructive: true, callback: function() {
            var chatIdToDelete = chat_id;
            var revoke = !!model.display.can_be_deleted_for_all_users;
            Remorse.itemAction(listItem, qsTr("Deleting chat"), function() {
                tdLibWrapper.sendRequest({ "@type": "deleteChatHistory", "chat_id": chatIdToDelete, "remove_from_chat_list": true, "revoke": revoke });
            });
        }});
        return actions;
    }

    // chat title
    // Dimensione titolo: nel tema Silica i nomi (in grassetto) sono ridotti di una
    // misura (fontSizeSmall) su richiesta (#5/#6 v2.4); il neon resta fontSizeMedium.
    // L'hint emoji segue la stessa misura per non disallineare le emoji nel titolo.
    readonly property real chatTitleFontSize: appSettings.useNeonTheme ? Theme.fontSizeMedium : Theme.fontSizeSmall
    // Barbara: menu long-press con la card del tema (vedi NeonMenuOverlay).
    readonly property bool barbara: BarbaraTheme.active
    primaryText.text: title ? Emoji.emojify(title, chatTitleFontSize) : qsTr("Unknown")
    primaryText.font.pixelSize: chatTitleFontSize
    // Nome chat: corsivo nel tema Neon (abbellimento 2.0); grassetto nel tema
    // Silica nativo (2.3 #11a). Pinnate in rosso (#8).
    primaryText.font.italic: appSettings.useNeonTheme
    primaryText.font.bold: !appSettings.useNeonTheme
    // Barbara: titolo della riga in inchiostro del tema (l'accento e' riservato
    // agli stati attivi e agli autori, non ai titoli di lista); le chat fissate
    // si riconoscono dall'etichetta PIN, non dal rosso di Silica.
    primaryText.color: listItem.barbara
                       ? BarbaraTheme.ink
                       : (is_pinned
                          ? "#ff5252"
                          : ((appSettings.highlightUnreadConversations && (unread_count > 0)) ? Theme.highlightColor : Theme.primaryColor))
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
                    visible: (unread_count > 0 || unread_reaction_count > 0 || unread_mention_count > 0) && chatCanBeMarkedRead()
                    onClicked: {
                        tdLibWrapper.viewMessage(chat_id, display.last_message.id, true);
                        tdLibWrapper.readAllChatMentions(chat_id);
                        tdLibWrapper.readAllChatReactions(chat_id);
                        tdLibWrapper.toggleChatIsMarkedAsUnread(chat_id, false);
                    }
                    text: qsTr("Mark all messages as read")
                }

                MenuItem {
                    visible: unread_count === 0 && unread_reaction_count === 0 && unread_mention_count === 0 && !chatIsGroup()
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

                MenuItem {
                    onClicked: {
                        tdLibWrapper.setChatArchived(chat_id, true);
                    }
                    text: qsTr("Archive chat")
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
