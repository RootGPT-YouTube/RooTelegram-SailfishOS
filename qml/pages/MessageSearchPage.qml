/*
    Forked in 2026 by RootGPT — part of RooTelegram.

    Ricerca GLOBALE per testo nei messaggi di tutte le proprie chat
    (TDLib searchMessages). Voce "Cerca nei messaggi" nel menu del titolo
    della home. Distinta dalla ricerca per-chat (ChatPage "Search in Chat")
    e dalla ricerca chat/utenti/canali (OverviewPage "Search...").
*/
import QtQuick 2.6
import Sailfish.Silica 1.0
import WerkWolf.RooTelegram 1.0
import "../components"
import "../js/twemoji.js" as Emoji
import "../js/functions.js" as Functions
import "../js/debug.js" as Debug

Page {
    id: messageSearchPage
    allowedOrientations: defaultAllowedOrientations

    property var myUserId: tdLibWrapper.getUserInformation().id
    property string currentQuery: ""
    property bool searching: false
    property var seenMessageIds: ({})

    function normalizePreviewText(text) {
        if (!text) {
            return "";
        }
        return text.replace(/\s+/g, " ").trim();
    }

    function resetResults() {
        resultsModel.clear();
        seenMessageIds = ({});
    }

    function doSearch() {
        var query = searchField.text.trim();
        messageSearchPage.currentQuery = query;
        messageSearchPage.resetResults();
        if (query.length > 0) {
            messageSearchPage.searching = true;
            Debug.log("[MessageSearchPage] searchMessages: " + query);
            tdLibWrapper.searchMessages(query, "", 50);
        } else {
            messageSearchPage.searching = false;
        }
    }

    function openResult(chatId, messageId) {
        var chatData = tdLibWrapper.getChat(chatId);
        if (!chatData) {
            return;
        }
        pageStack.push(Qt.resolvedUrl("ChatPage.qml"), {
            "chatInformation": chatData,
            "messageIdToShow": messageId
        });
    }

    Timer {
        id: searchDebounceTimer
        interval: 600
        onTriggered: messageSearchPage.doSearch()
    }

    // dynamicRoles per poter conservare la mappa "photo" (oggetto annidato)
    ListModel {
        id: resultsModel
        dynamicRoles: true
    }

    Connections {
        target: tdLibWrapper
        onMessagesInChatsReceived: {
            messageSearchPage.searching = false;
            for (var i = 0; i < messages.length; i++) {
                var msg = messages[i];
                if (!msg || typeof msg.chat_id === "undefined") {
                    continue;
                }
                var messageId = msg.id ? msg.id.toString() : "";
                if (messageId === "" || messageSearchPage.seenMessageIds[messageId]) {
                    continue;
                }
                messageSearchPage.seenMessageIds[messageId] = true;
                var chat = tdLibWrapper.getChat(msg.chat_id);
                var title = (chat && chat.title) ? chat.title : "";
                var photo = (chat && chat.photo) ? chat.photo : ({});
                var snippet = "";
                try {
                    snippet = Functions.getMessageText(msg, true, messageSearchPage.myUserId, true) || "";
                } catch (error) {
                    snippet = "";
                }
                snippet = messageSearchPage.normalizePreviewText(snippet);
                resultsModel.append({
                    "chatId": msg.chat_id,
                    "messageId": messageId,
                    "title": title,
                    "snippet": snippet,
                    "photo": photo
                });
            }
        }
    }

    PageHeader {
        id: pageHeader
        title: qsTr("Search in messages")
    }

    SearchField {
        id: searchField
        anchors.top: pageHeader.bottom
        width: parent.width
        placeholderText: qsTr("Search in messages")
        EnterKey.iconSource: "image://theme/icon-m-enter-close"
        EnterKey.onClicked: searchField.focus = false
        onTextChanged: searchDebounceTimer.restart()
    }

    SilicaListView {
        id: resultsView
        anchors {
            top: searchField.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        clip: true
        model: resultsModel

        delegate: SearchResultItem {
            width: resultsView.width
            resultChatId: model.chatId
            resultTitle: model.title
            resultSubtitle: model.snippet
            resultPhoto: model.photo
            onClicked: messageSearchPage.openResult(model.chatId, model.messageId)
        }

        ViewPlaceholder {
            enabled: resultsModel.count === 0 && !messageSearchPage.searching
            text: messageSearchPage.currentQuery.length === 0
                  ? qsTr("Type a word to search in all your chats")
                  : qsTr("No messages found")
        }

        VerticalScrollDecorator {}
    }

    BusyIndicator {
        size: BusyIndicatorSize.Large
        anchors.centerIn: parent
        running: messageSearchPage.searching && resultsModel.count === 0
    }

    Component.onCompleted: searchField.forceActiveFocus()
}
