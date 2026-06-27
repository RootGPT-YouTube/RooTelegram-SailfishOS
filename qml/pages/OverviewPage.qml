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
import QtGraphicalEffects 1.0
import Nemo.Notifications 1.0
import WerkWolf.RooTelegram 1.0
import "../components"
import "../js/twemoji.js" as Emoji
import "../js/functions.js" as Functions
import "../js/debug.js" as Debug

Page {
    id: overviewPage
    allowedOrientations: Orientation.All

    property bool initializationCompleted: false;
    property bool loading: true;
    // Tema Neon (cyberpunk) vs Silica base. In Silica niente glow/corsivo/sfondo neon.
    readonly property bool neon: appSettings.useNeonTheme
    property bool logoutLoading: false;
    property int connectionState: TelegramAPI.WaitingForNetwork
    property int ownUserId;
    property int activeFolderId: 0;
    property bool chatListCreated: false;

    // link handler:
    property string urlToOpen;
    property var chatToOpen: null; //null or [chatId, messageId]
    // deep-link "apri Storie" da notifica storia (coda per il cold-start)
    property bool openStoriesRequested: false;

    onStatusChanged: {
        if (status === PageStatus.Active && initializationCompleted && !chatListCreated && !logoutLoading) {
            updateContent();
        }
    }

    Connections {
        target: dBusAdaptor
        onPleaseOpenMessage: {
            Debug.log("[OverviewPage] Opening chat from external requested: ", chatId, messageId);
            // Deep-link al messaggio specifico (es. tap notifica reaction su un proprio
            // messaggio): apriamo la chat E mostriamo quel messaggio (overlay via
            // messageIdToShow). Se non c'è messageId, ripieghiamo sull'apertura chat.
            if (messageId && messageId.length > 0 && messageId !== "0") {
                openChatWithMessageId(chatId, messageId);
            } else {
                openChat(chatId);
            }
        }
        onPleaseOpenUrl: {
            Debug.log("[OverviewPage] Opening URL requested: ", url);
            openUrl(url);
        }
        onPleaseOpenStories: {
            Debug.log("[OverviewPage] Opening Stories from external requested");
            openStories();
        }
    }

    Timer {
        id: chatListCreatedTimer
        interval: 100
        running: false
        repeat: false
        onTriggered: {
            overviewPage.chatListCreated = true;
            // Deep-link messo in coda mentre la lista non era ancora pronta (tap
            // notifica ad app chiusa / da daemon): ora apriamo chat/messaggio/URL.
            if (overviewPage.openStoriesRequested) {
                overviewPage.openStories();
            } else if (overviewPage.chatToOpen && overviewPage.chatToOpen.length === 2) {
                if (typeof overviewPage.chatToOpen[1] === "object") {
                    overviewPage.openChatWithMessage(overviewPage.chatToOpen[0], overviewPage.chatToOpen[1]);
                } else {
                    overviewPage.openChatWithMessageId(overviewPage.chatToOpen[0], overviewPage.chatToOpen[1]);
                }
            } else if (overviewPage.urlToOpen && overviewPage.urlToOpen.length > 1) {
                overviewPage.openUrl(overviewPage.urlToOpen);
            } else {
                // Apertura normale (niente deep-link): mostra il popup "Novità"
                // una-tantum dopo un aggiornamento di versione.
                overviewPage.maybeShowWhatsNew();
            }
            chatListView.scrollToTop();
            updateSecondaryContentTimer.start();
            var remainingInteractionHints = appSettings.remainingInteractionHints;
            Debug.log("Remaining interaction hints: " + remainingInteractionHints);
            if (remainingInteractionHints > 0) {
                interactionHintTimer.start();
                titleInteractionHint.opacity = 1.0;
                appSettings.remainingInteractionHints = remainingInteractionHints - 1;
            }
        }
    }

    Timer {
        id: openInitializationPageTimer
        interval: 0
        onTriggered: {
            pageStack.push(Qt.resolvedUrl("../pages/InitializationPage.qml"));
        }
    }
    Timer {
        id: updateSecondaryContentTimer
        interval: 600
        onTriggered: {
            chatListModel.calculateUnreadState();
            tdLibWrapper.getRecentStickers();
            tdLibWrapper.getInstalledStickerSets();
            // Carica a parte le custom emoji così sono già nella cache
            // quando l'utente apre il picker o riceve un messaggio con
            // emoji premium (evita la sezione vuota / parziale).
            tdLibWrapper.getInstalledCustomEmojiSets();
            tdLibWrapper.getContacts();
            tdLibWrapper.getUserPrivacySettingRules(TelegramAPI.SettingAllowChatInvites);
            tdLibWrapper.getUserPrivacySettingRules(TelegramAPI.SettingAllowFindingByPhoneNumber);
            tdLibWrapper.getUserPrivacySettingRules(TelegramAPI.SettingAllowCalls);
            tdLibWrapper.getUserPrivacySettingRules(TelegramAPI.SettingShowLinkInForwardedMessages);
            tdLibWrapper.getUserPrivacySettingRules(TelegramAPI.SettingShowPhoneNumber);
            tdLibWrapper.getUserPrivacySettingRules(TelegramAPI.SettingShowProfilePhoto);
            tdLibWrapper.getUserPrivacySettingRules(TelegramAPI.SettingShowStatus);
            tdLibWrapper.getUserPrivacySettingRules(TelegramAPI.SettingAllowPrivateVoiceAndVideoNoteMessages);
        }
    }

    TextFilterModel {
        id: chatListProxyModel
        sourceModel: (chatSearchField.opacity > 0) ? chatListModel : null
        filterRoleName: "filter"
        filterText: chatSearchField.text
    }

    // Vero quando la lente è attiva e c'è del testo: in quel caso la home
    // diventa una ricerca globale Telegram (sezione "Le mie chat" = match
    // locali; sezione "Risultati globali" = utenti/gruppi/canali pubblici).
    property bool searching: chatSearchField.opacity > 0 && chatSearchField.text.length > 0

    // Risultati della ricerca GLOBALE (server-side): chat non necessariamente
    // presenti tra le proprie. Popolato dalle risposte searchChatsOnServer /
    // searchPublicChats. dynamicRoles per poter conservare la mappa photo.
    ListModel {
        id: searchResultsModel
        dynamicRoles: true
    }
    // id già aggiunti (dedup) — chiave string del chatId
    property var searchSeenIds: ({})

    function resetSearchResults() {
        searchResultsModel.clear();
        searchSeenIds = ({});
    }

    function addSearchResultChat(chatId) {
        if (chatId === undefined || chatId === null) {
            return;
        }
        var idStr = chatId.toString();
        if (searchSeenIds[idStr]) {
            return;
        }
        searchSeenIds[idStr] = true;
        var chat = tdLibWrapper.getChat(idStr);
        if (!chat || !chat.id) {
            return;
        }
        // Se la chat è già in una tua lista (ha "positions"), compare già nella
        // sezione locale "Le mie chat": non duplicarla tra i risultati globali.
        // NB: non basta getById, perché TDLib conosce (updateNewChat) anche le
        // chat pubbliche trovate, pur non essendo tra le tue.
        if (chat.positions && chat.positions.length > 0) {
            return;
        }
        var chatType = chat.type ? (chat.type["@type"] || "") : "";
        var subtitle = "";
        if (chatType === "chatTypePrivate" || chatType === "chatTypeSecret") {
            subtitle = qsTr("User");
        } else if (chatType === "chatTypeBasicGroup") {
            subtitle = qsTr("Group");
        } else if (chatType === "chatTypeSupergroup") {
            var superGroup = tdLibWrapper.getSuperGroup(chat.type.supergroup_id);
            subtitle = (superGroup && superGroup.is_channel === true) ? qsTr("Channel") : qsTr("Group");
        }
        searchResultsModel.append({
            "resultChatId": chat.id,
            "resultTitle": chat.title || "",
            "resultSubtitle": subtitle,
            "resultPhoto": (chat.photo ? chat.photo.small : null)
        });
    }

    Timer {
        id: serverSearchTimer
        interval: 400
        repeat: false
        onTriggered: {
            var query = chatSearchField.text;
            overviewPage.resetSearchResults();
            if (query && query.length > 0) {
                tdLibWrapper.searchChatsOnServer(query, 50);
                tdLibWrapper.searchContacts(query, 100);
                // Ricerca pubblica (username/titolo) già da 2 caratteri, come
                // il client ufficiale, per trovare utenti/gruppi/canali non
                // ancora tra i propri.
                if (query.length >= 2) {
                    tdLibWrapper.searchPublicChats(query);
                }
            }
        }
    }

    Connections {
        target: tdLibWrapper
        onUsersReceived: {
            if (extra === "searchContacts" && userIds) {
                for (var i = 0; i < userIds.length; i += 1) {
                    var userId = userIds[i];
                    if (userId !== undefined && userId !== null) {
                        tdLibWrapper.createPrivateChat(userId.toString(), "searchContacts");
                    }
                }
            }
        }
    }

    // Apertura da notifica/esterno (#3): marca SUBITO la chat come letta fino
    // all'ultimo messaggio (force_read=true), come fa "Segna tutti come letti".
    // Senza questo, il read affidato alla ListView con force:false poteva non
    // arrivare in fondo (deep-link a un messaggio non ultimo) → badge unread che
    // restava in home dopo aver aperto la chat dalla notifica.
    function markChatReadOnExternalOpen(chatInfo) {
        if (chatInfo && chatInfo.id) {
            // Badge home via SUBITO (serve solo l'id): handleChatOpened non azzera piu'
            // il badge all'apertura per canali/gruppi (letto-da-scroll). FUORI dal guard
            // last_message, che su chat aperte da notifica (getChat) spesso manca →
            // altrimenti il clear non gira affatto e il badge resta.
            chatListModel.markChatReadOptimistically(chatInfo.id);
            // Read FORZATO sul server: richiede last_message.
            if (chatInfo.last_message && chatInfo.last_message.id) {
                tdLibWrapper.viewMessage(chatInfo.id, chatInfo.last_message.id, true);
            }
        }
    }

    function openChat(chatId) {
        if(chatListCreated && chatId) {
            Debug.log("[OverviewPage] Opening Chat: ", chatId);
            // Fallback su tdLibWrapper.getChat() se la chat non è nella cartella
            // attiva (getById ritorna mappa vuota): senza id/type ChatPage si rompe
            var chatInfo = chatListModel.getById(chatId);
            if (!chatInfo || !chatInfo.id) {
                Debug.log("[OverviewPage] Chat not in active folder, falling back to TDLib cache");
                chatInfo = tdLibWrapper.getChat(chatId.toString());
            }
            if (!chatInfo || !chatInfo.id) {
                Debug.log("[OverviewPage] Chat unavailable, aborting open: ", chatId);
                return;
            }
            markChatReadOnExternalOpen(chatInfo);
            pageStack.pop(overviewPage, PageStackAction.Immediate);
            pageStack.push(Qt.resolvedUrl("../pages/ChatPage.qml"), { "chatInformation" : chatInfo }, PageStackAction.Immediate);
            chatToOpen = null;
        }
    }

    function openStories() {
        // Se la lista chat non è ancora pronta (notifica ad app chiusa / da daemon)
        // mettiamo in coda: ci ripensa il chatListCreatedTimer.
        if (!chatListCreated) {
            openStoriesRequested = true;
            return;
        }
        Debug.log("[OverviewPage] Opening Stories page from external request");
        pageStack.pop(overviewPage, PageStackAction.Immediate);
        pageStack.push(Qt.resolvedUrl("../pages/StoriesPage.qml"), {}, PageStackAction.Immediate);
        openStoriesRequested = false;
    }

    function openChatWithMessageId(chatId, messageId) {
        if(chatId && messageId) {
            chatToOpen = [chatId, messageId];
        }
        if(chatListCreated && chatToOpen && chatToOpen.length === 2) {
            Debug.log("[OverviewPage] Opening Chat: ", chatToOpen[0], "message ID: " + chatToOpen[1]);
            var chatInfo = tdLibWrapper.getChat(chatToOpen[0]);
            markChatReadOnExternalOpen(chatInfo);
            pageStack.pop(overviewPage, PageStackAction.Immediate);
            pageStack.push(Qt.resolvedUrl("../pages/ChatPage.qml"), { "chatInformation" : chatInfo, "messageIdToShow" : chatToOpen[1] }, PageStackAction.Immediate);
            chatToOpen = null;
        }
    }

    function openChatWithMessage(chatId, message) {
        if(chatId && message) {
            chatToOpen = [chatId, message];
        }
        if(chatListCreated && chatToOpen && chatToOpen.length === 2) {
            Debug.log("[OverviewPage] Opening Chat (with provided message): ", chatToOpen[0]);
            var chatInfo = tdLibWrapper.getChat(chatToOpen[0]);
            markChatReadOnExternalOpen(chatInfo);
            pageStack.pop(overviewPage, PageStackAction.Immediate);
            pageStack.push(Qt.resolvedUrl("../pages/ChatPage.qml"), { "chatInformation" : chatInfo, "messageToShow" : chatToOpen[1] }, PageStackAction.Immediate);
            chatToOpen = null;
        }
    }

    // Popup "Novità": mostrato una sola volta dopo ogni aggiornamento di versione.
    // Confronta la versione corrente (appVersion) con l'ultima per cui è già stato
    // mostrato (appSettings.lastSeenVersion). whatsNewChecked evita ri-tentativi
    // nella stessa sessione (es. ritorno alla overview da una chat).
    property bool whatsNewChecked: false
    function maybeShowWhatsNew() {
        if (whatsNewChecked) {
            return;
        }
        whatsNewChecked = true;
        if (appSettings.lastSeenVersion === appVersion) {
            return;
        }
        appSettings.lastSeenVersion = appVersion;
        pageStack.push(Qt.resolvedUrl("../pages/WhatsNewDialog.qml"));
    }

    function openUrl(url) {
        if(url && url.length > 0) {
            urlToOpen = url;
        }
        if(chatListCreated && urlToOpen && urlToOpen.length > 1) {
            Debug.log("[OverviewPage] Opening URL: ", urlToOpen);
            Functions.handleLink(urlToOpen);
            urlToOpen = "";
        }
    }

    function setPageStatus() {
        switch (overviewPage.connectionState) {
        case TelegramAPI.WaitingForNetwork:
            pageHeader.connectionTitle = qsTr("Waiting for network...");
            break;
        case TelegramAPI.Connecting:
            pageHeader.connectionTitle = qsTr("Connecting to network...");
            break;
        case TelegramAPI.ConnectingToProxy:
            pageHeader.connectionTitle = qsTr("Connecting to proxy...");
            break;
        case TelegramAPI.ConnectionReady:
            // Stato "pronto": il titolo testuale resta vuoto, mostra il brand neon (brandLabel)
            pageHeader.connectionTitle = "";
            break;
        case TelegramAPI.Updating:
            pageHeader.connectionTitle = qsTr("Updating content...");
            break;
        }
    }

    // Colore SEMANTICO del puntino di connessione (Silica): VERDE = connesso,
    // AMBRA = ricerca/instabile, ROSSO = nessuna connessione. Tinte mid-tone
    // leggibili su qualunque ambiance (chiara o scura).
    function connectionDotColor() {
        switch (overviewPage.connectionState) {
        case TelegramAPI.ConnectionReady:   return "#4caf50"; // verde
        case TelegramAPI.WaitingForNetwork: return "#e53935"; // rosso
        default:                            return "#ffb300"; // ambra
        }
    }

    // Stati "in corso/instabile" (l'ambra lampeggia): connessione in corso, al proxy
    // o aggiornamento contenuti.
    function connectionIsConnecting() {
        var s = overviewPage.connectionState;
        return s === TelegramAPI.Connecting
            || s === TelegramAPI.ConnectingToProxy
            || s === TelegramAPI.Updating;
    }

    // Descrizione testuale dello stato (riusa le stesse stringhe già tradotte di
    // setPageStatus). Vuota a connessione pronta (il verde non ha didascalia).
    function connectionDescription() {
        switch (overviewPage.connectionState) {
        case TelegramAPI.WaitingForNetwork: return qsTr("Waiting for network...");
        case TelegramAPI.Connecting:        return qsTr("Connecting to network...");
        case TelegramAPI.ConnectingToProxy: return qsTr("Connecting to proxy...");
        case TelegramAPI.Updating:          return qsTr("Updating content...");
        default:                            return "";
        }
    }

    function updateContent() {
        tdLibWrapper.getChats();
    }

    function initializePage() {
        overviewPage.handleAuthorizationState(true);
        overviewPage.connectionState = tdLibWrapper.getConnectionState();
        overviewPage.setPageStatus();
    }

    function handleAuthorizationState(isOnInitialization) {
        switch (tdLibWrapper.authorizationState) {
        case TelegramAPI.WaitPhoneNumber:
        case TelegramAPI.WaitCode:
        case TelegramAPI.WaitPassword:
        case TelegramAPI.WaitRegistration:
        case TelegramAPI.AuthorizationStateClosed:
            overviewPage.loading = false;
            overviewPage.logoutLoading = false;
            if(isOnInitialization) { // pageStack isn't ready on Component.onCompleted
                openInitializationPageTimer.start()
            } else {
                pageStack.push(Qt.resolvedUrl("../pages/InitializationPage.qml"));
            }
            break;
        case TelegramAPI.AuthorizationReady:
            loadingBusyIndicator.text = qsTr("Loading chat list...");
            overviewPage.loading = false;
            overviewPage.initializationCompleted = true;
            overviewPage.updateContent();
            if (appSettings.disableVideoPreload) {
                Functions.applyVideoPreloadOverride();
            }
            break;
        case TelegramAPI.AuthorizationStateLoggingOut:
            if (logoutLoading) {
                Debug.log("Resources cleared already");
                return;
            }
            Debug.log("Logging out")
            overviewPage.initializationCompleted = false;
            overviewPage.loading = false;
            chatListCreatedTimer.stop();
            updateSecondaryContentTimer.stop();
            loadingBusyIndicator.text = qsTr("Logging out")
            overviewPage.logoutLoading = true;
            chatListModel.reset();
            break;
        default:
            // Nothing ;)
        }
    }

    function resetFocus() {
        if (chatSearchField.text === "") {
            chatSearchField.opacity = 0.0;
            pageHeader.opacity = 1.0;
        }
        chatSearchField.focus = false;
        overviewPage.focus = true;
    }

    function markAllChatsAsRead() {
        tdLibWrapper.sendRequest({
            "@type": "readChatList",
            "chat_list": {
                "@type": "chatListMain"
            },
            "@extra": "readChatList:main"
        });
        tdLibWrapper.sendRequest({
            "@type": "readChatList",
            "chat_list": {
                "@type": "chatListArchive"
            },
            "@extra": "readChatList:archive"
        });
        for (var i = 0; i < chatFoldersModel.count; i++) {
            var folderId = chatFoldersModel.getId(i);
            if (folderId <= 0) {
                continue;
            }
            tdLibWrapper.sendRequest({
                "@type": "readChatList",
                "chat_list": {
                    "@type": "chatListFolder",
                    "chat_folder_id": folderId
                },
                "@extra": "readChatList:folder:" + folderId
            });
        }
        tdLibWrapper.getChats();
        chatListModel.calculateUnreadState();
        appNotification.show(qsTr("All chats marked as read."));
    }

    Connections {
        target: tdLibWrapper
        onAuthorizationStateChanged: {
            handleAuthorizationState(false);
        }
        onConnectionStateChanged: {
            overviewPage.connectionState = connectionState;
            setPageStatus();
        }
        onOwnUserIdFound: {
            overviewPage.ownUserId = ownUserId;
        }
        onChatLastMessageUpdated: {
            if (!overviewPage.chatListCreated) {
                chatListCreatedTimer.restart();
            } else {
                chatListModel.calculateUnreadState();
            }
        }
        onChatOrderUpdated: {
            if (!overviewPage.chatListCreated) {
                chatListCreatedTimer.restart();
            } else {
                chatListModel.calculateUnreadState();
            }
        }
        onChatsReceived: {
            // Le risposte di ricerca globale portano il loro @extra: vanno nei
            // risultati, NON nella paginazione della chat-list.
            var chatsExtra = (chats && chats["@extra"] !== undefined && chats["@extra"] !== null) ? chats["@extra"].toString() : "";
            if (chatsExtra === "searchChatsOnServer" || chatsExtra === "searchPublicChats") {
                var foundIds = (chats && chats.chat_ids) ? chats.chat_ids : [];
                for (var i = 0; i < foundIds.length; i += 1) {
                    overviewPage.addSearchResultChat(foundIds[i]);
                }
                return;
            }
            if(chats && chats.chat_ids && chats.chat_ids.length === 0) {
                chatListCreatedTimer.restart();
            } else {
                // TDLib ha ancora chat da caricare - ne chiediamo altre
                tdLibWrapper.getChats();
            }
        }
        onChatReceived: {
            if (!chat || !chat.id) {
                return;
            }
            var chatExtra = (chat["@extra"] !== undefined && chat["@extra"] !== null) ? chat["@extra"].toString() : ""
            var openAndSendStartToBot = chatExtra.indexOf("openAndSendStartToBot:") === 0
            if(chatExtra === "openDirectly" || openAndSendStartToBot && chat.type["@type"] === "chatTypePrivate") {
                pageStack.pop(overviewPage, PageStackAction.Immediate)
                // if we get a new chat (no messages?), we can not use the provided data
                var chatinfo = tdLibWrapper.getChat(chat.id);
                var options = { "chatInformation" : chatinfo }
                if(openAndSendStartToBot) {
                    options.doSendBotStartMessage = true;
                    options.sendBotStartMessageParameter = chatExtra.substring(22);
                }
                pageStack.push(Qt.resolvedUrl("../pages/ChatPage.qml"), options);
            }
        }
        onErrorReceived: {
            Functions.handleErrorMessage(code, message);
        }
        onCopyToDownloadsSuccessful: {
            appNotification.show(qsTr("Download of %1 successful.").arg(fileName), filePath);
        }

        onCopyToDownloadsError: {
            appNotification.show(qsTr("Download failed."));
        }
        onMessageLinkInfoReceived: {
            if (extra === "openDirectly") {
                if (messageLinkInfo.chat_id === 0) {
                    appNotification.show(qsTr("Unable to open link."));
                } else {
                    openChatWithMessage(messageLinkInfo.chat_id, messageLinkInfo.message);
                }
            }
        }
    }

    Component.onCompleted: {
        initializePage();
    }

    // Sfondo a circuiti elettrici blu (#19), tenue, dietro la lista.
    CircuitBackground {}

    SilicaFlickable {
        id: overviewContainer
        contentHeight: parent.height
        contentWidth: parent.width
        anchors.fill: parent
        visible: !overviewPage.loading

        PullDownMenu {
            // Solo il TESTO al neon bianco (come il nuovo menù): lo sfondo/comportamento
            // del PullDownMenu resta quello standard Silica. I MenuItem non espongono il
            // colore del testo, quindi svuotiamo `text` e mettiamo una Label figlia neon.
            MenuItem {
                visible: Debug.enabled
                onClicked: pageStack.push(Qt.resolvedUrl("../pages/DebugPage.qml"))
                Label {
                    anchors.centerIn: parent
                    text: qsTr("Debug")
                    font.italic: overviewPage.neon
                    color: overviewPage.neon ? (parent.highlighted ? "#fff3e6" : "#ffffff") : (parent.highlighted ? Theme.highlightColor : Theme.primaryColor)
                    layer.enabled: overviewPage.neon
                    layer.effect: Glow { color: "#ffffff"; radius: 6; samples: 13; spread: 0.2; transparentBorder: true }
                }
            }
            MenuItem {
                onClicked: pageStack.push(Qt.resolvedUrl("../pages/SettingsPage.qml"))
                Label {
                    anchors.centerIn: parent
                    text: qsTr("Settings")
                    font.italic: overviewPage.neon
                    color: overviewPage.neon ? (parent.highlighted ? "#fff3e6" : "#ffffff") : (parent.highlighted ? Theme.highlightColor : Theme.primaryColor)
                    layer.enabled: overviewPage.neon
                    layer.effect: Glow { color: "#ffffff"; radius: 6; samples: 13; spread: 0.2; transparentBorder: true }
                }
            }
            NeonSeparator {
                width: parent.width
            }
            MenuItem {
                onClicked: pageStack.push(Qt.resolvedUrl("../pages/StoriesPage.qml"))
                Label {
                    id: storiesMenuLabel
                    anchors.centerIn: parent
                    text: qsTr("Stories")
                    font.italic: overviewPage.neon
                    color: overviewPage.neon ? (parent.highlighted ? "#fff3e6" : "#ffffff") : (parent.highlighted ? Theme.highlightColor : Theme.primaryColor)
                    layer.enabled: overviewPage.neon
                    layer.effect: Glow { color: "#ffffff"; radius: 6; samples: 13; spread: 0.2; transparentBorder: true }
                }
                // Pallino verde: presente quando ci sono storie non viste
                Rectangle {
                    visible: storiesModel.mainUnreadCount > 0
                    width: Theme.paddingMedium
                    height: width
                    radius: width / 2
                    color: "#4caf50"
                    anchors.left: storiesMenuLabel.right
                    anchors.leftMargin: Theme.paddingSmall
                    anchors.verticalCenter: storiesMenuLabel.verticalCenter
                    layer.enabled: overviewPage.neon
                    layer.effect: Glow { color: "#4caf50"; radius: 8; samples: 17; spread: 0.3; transparentBorder: true }
                }
            }
            NeonSeparator {
                width: parent.width
            }
            MenuItem {
                onClicked: pageStack.push(Qt.resolvedUrl("../pages/CreateSupergroupPage.qml"), { "isChannel": false })
                Label {
                    anchors.centerIn: parent
                    text: qsTr("New Group")
                    font.italic: overviewPage.neon
                    color: overviewPage.neon ? (parent.highlighted ? "#fff3e6" : "#ffffff") : (parent.highlighted ? Theme.highlightColor : Theme.primaryColor)
                    layer.enabled: overviewPage.neon
                    layer.effect: Glow { color: "#ffffff"; radius: 6; samples: 13; spread: 0.2; transparentBorder: true }
                }
            }
            MenuItem {
                onClicked: pageStack.push(Qt.resolvedUrl("../pages/CreateSupergroupPage.qml"), { "isChannel": true })
                Label {
                    anchors.centerIn: parent
                    text: qsTr("New Channel")
                    font.italic: overviewPage.neon
                    color: overviewPage.neon ? (parent.highlighted ? "#fff3e6" : "#ffffff") : (parent.highlighted ? Theme.highlightColor : Theme.primaryColor)
                    layer.enabled: overviewPage.neon
                    layer.effect: Glow { color: "#ffffff"; radius: 6; samples: 13; spread: 0.2; transparentBorder: true }
                }
            }
            MenuItem {
                onClicked: pageStack.push(Qt.resolvedUrl("../pages/NewChatPage.qml"))
                Label {
                    anchors.centerIn: parent
                    text: qsTr("New Chat")
                    font.italic: overviewPage.neon
                    color: overviewPage.neon ? (parent.highlighted ? "#fff3e6" : "#ffffff") : (parent.highlighted ? Theme.highlightColor : Theme.primaryColor)
                    layer.enabled: overviewPage.neon
                    layer.effect: Glow { color: "#ffffff"; radius: 6; samples: 13; spread: 0.2; transparentBorder: true }
                }
            }
        }

        PageHeader {
            id: pageHeader
            title: ""
            leftMargin: Theme.itemSizeMedium
            visible: opacity > 0
            // Non lasciare che l'altezza fissa di default schiacci il titolo neon: cresce col label
            height: Math.max(implicitHeight, brandNeon.visible ? brandNeon.implicitHeight + 2 * Theme.paddingLarge : 0)
            Behavior on opacity { FadeAnimation {} }

            // Testo degli stati di connessione ("Connecting…"): il title nativo del
            // PageHeader sarebbe allineato a destra; qui lo mostriamo CENTRATO e su
            // UNA sola riga, coerente col brand. Assegnato da setPageStatus().
            property string connectionTitle: ""
            Label {
                id: connectionLabel
                anchors.centerIn: parent
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: pageHeader.connectionTitle
                visible: !brandNeon.visible && text !== ""
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.NoWrap
                maximumLineCount: 1
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.highlightColor
            }

            // Icona connessione internet — SOLO Silica — all'estrema sinistra della
            // riga del brand, a sinistra del puntino di stato: antenna che irradia =
            // connessione a internet. Asset custom monocromatico (images/icon-m-rt-
            // connection.png) tinto col colore del tema via ColorOverlay.
            Image {
                id: connectionIcon
                visible: !overviewPage.neon
                source: Qt.resolvedUrl("../../images/icon-m-rt-connection.png")
                sourceSize.width: Theme.iconSizeSmall * 2
                sourceSize.height: Theme.iconSizeSmall * 2
                width: Theme.iconSizeSmall
                height: width
                fillMode: Image.PreserveAspectFit
                smooth: true
                anchors {
                    left: parent.left
                    leftMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                layer.enabled: true
                layer.effect: ColorOverlay { color: Theme.primaryColor }
            }

            // Puntino di stato connessione — SOLO Silica — subito a destra dell'icona,
            // sulla stessa riga del brand. VERDE = connesso; AMBRA (lampeggiante) =
            // ricerca/instabile; ROSSO = nessuna connessione. La binding chiama
            // connectionDotColor() che legge connectionState → si riaggiorna al cambio.
            // Nel Neon non compare.
            Rectangle {
                id: connectionDot
                visible: !overviewPage.neon
                width: Theme.paddingMedium * 1.3
                height: width
                radius: width / 2
                anchors {
                    left: connectionIcon.right
                    leftMargin: Theme.paddingSmall
                    verticalCenter: parent.verticalCenter
                }
                color: overviewPage.connectionDotColor()
            }

            // Alone pulsante "sfocato" sopra il puntino quando in ricerca/instabile
            // (stato ambra): un Glow ambra che respira (raggio + opacità). L'Item è più
            // grande del puntino così il glow ha margine trasparente e non viene tagliato.
            // Il puntino sottostante resta solido → il pallino non sparisce, pulsa solo
            // l'alone. Solo Silica e solo nello stato ambra.
            Item {
                id: connectionDotPulse
                visible: !overviewPage.neon && overviewPage.connectionIsConnecting()
                width: connectionDot.width * 2.8
                height: width
                anchors.centerIn: connectionDot
                property real pulseRadius: 6
                Rectangle {
                    anchors.centerIn: parent
                    width: connectionDot.width
                    height: width
                    radius: width / 2
                    color: "#ffb300"
                }
                layer.enabled: true
                layer.effect: Glow {
                    color: "#ffb300"
                    radius: connectionDotPulse.pulseRadius
                    samples: 25
                    spread: 0.2
                    transparentBorder: true
                }
                SequentialAnimation on pulseRadius {
                    running: connectionDotPulse.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 20; duration: 750; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 6;  duration: 750; easing.type: Easing.InOutSine }
                }
                SequentialAnimation on opacity {
                    running: connectionDotPulse.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 750; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0;  duration: 750; easing.type: Easing.InOutSine }
                }
            }

            // Descrizione dello stato — SOLO Silica — a destra del puntino, per TUTTI gli
            // stati tranne "connesso" (verde, senza didascalia). Colore del TEMA
            // (Theme.highlightColor) per adattarsi all'ambiance SFOS. Si tronca con fade
            // se non c'è spazio fino al brand.
            Label {
                id: connectionDescLabel
                visible: !overviewPage.neon && overviewPage.connectionState !== TelegramAPI.ConnectionReady
                text: overviewPage.connectionDescription()
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.highlightColor
                truncationMode: TruncationMode.Fade
                anchors {
                    left: connectionDot.right
                    leftMargin: Theme.paddingMedium
                    right: brandNeon.left
                    rightMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                }
            }

            // Brand "R∞Telegram" in vero stile tubo al neon (nucleo chiaro brillante + alone
            // magenta che diffonde), mostrato solo a connessione pronta; negli altri stati il
            // titolo testuale del PageHeader mostra "Connecting…", ecc.
            Item {
                id: brandNeon
                // Neon: brand solo a connessione pronta (gli altri stati mostrano il
                // testo "Connecting…"). Silica: brand SEMPRE visibile — lo stato di
                // connessione è dato dal puntino verde/celeste a sinistra, quindi il
                // testo "Connecting…" non serve (connectionLabel si nasconde da solo
                // perché brandNeon.visible diventa true).
                visible: overviewPage.neon ? (overviewPage.connectionState === TelegramAPI.ConnectionReady) : true
                implicitWidth: neonCore.implicitWidth
                implicitHeight: neonCore.implicitHeight
                width: implicitWidth
                height: implicitHeight

                // Task 6 — "neon malfunzionante": glowOn (0..1) pilota l'opacità dei
                // tre layer (backglow/halo/core). Tra una raffica di sfarfallio e
                // l'altra resta 1.0 (nessuna animazione attiva = nessun repaint).
                property real glowOn: 1.0
                // Anima SOLO in tema Neon, a brand visibile, con la home in primo
                // piano e l'app attiva: niente animazioni off-screen (CPU sprecata).
                readonly property bool flickerActive: overviewPage.neon && brandNeon.visible
                                                      && overviewPage.status === PageStatus.Active
                                                      && Qt.application.active

                anchors {
                    // Neon: centrato. Silica: allineato a destra dell'header.
                    horizontalCenter: overviewPage.neon ? parent.horizontalCenter : undefined
                    right: overviewPage.neon ? undefined : parent.right
                    rightMargin: overviewPage.neon ? 0 : Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }

                // Luce proiettata sullo SFONDO dietro la parola (come il muro illuminato dal neon)
                RadialGradient {
                    id: neonBackglow
                    visible: overviewPage.neon
                    opacity: brandNeon.glowOn
                    anchors.centerIn: parent
                    width: neonCore.implicitWidth * 1.5
                    height: neonCore.implicitHeight * 2.6
                    horizontalRadius: width / 2
                    verticalRadius: height / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1, 0.34, 0.0, 0.45) }
                        GradientStop { position: 0.55; color: Qt.rgba(1, 0.34, 0.0, 0.12) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // Alone largo e morbido: è il colore "del tubo" che diffonde nell'aria
                Label {
                    id: neonHalo
                    visible: overviewPage.neon
                    opacity: brandNeon.glowOn
                    anchors.centerIn: parent
                    text: "R∞Telegram"
                    font.pixelSize: Theme.fontSizeHuge
                    font.italic: overviewPage.neon
                    color: "#e65000"
                    layer.enabled: overviewPage.neon
                    layer.effect: Glow {
                        color: "#e65000"
                        radius: 32
                        samples: 49
                        spread: 0.30
                        transparentBorder: true
                    }
                }

                // Nucleo: la scritta quasi bianca/luminosa con un glow stretto rosa acceso
                Label {
                    id: neonCore
                    // In Neon segue lo sfarfallio; in Silica sempre pieno (sobrio).
                    opacity: overviewPage.neon ? brandNeon.glowOn : 1.0
                    anchors.centerIn: parent
                    // Silica: "R∞Telegram" (col simbolo dell'infinito come il Neon) in
                    // grassetto+corsivo, allineato a destra, di misura Large (un gradino
                    // di font più piccolo di prima, su richiesta). Neon: "R∞Telegram"
                    // stilizzato invariato. Il colore in Silica segue il tema SFOS.
                    text: "R∞Telegram"
                    font.pixelSize: overviewPage.neon
                                    ? Theme.fontSizeHuge
                                    : Theme.fontSizeLarge
                    font.italic: true
                    font.bold: !overviewPage.neon
                    color: overviewPage.neon ? "#fff3e6" : Theme.highlightColor
                    layer.enabled: overviewPage.neon
                    layer.effect: Glow {
                        color: "#ff9a3d"
                        radius: 8
                        samples: 17
                        spread: 0.55
                        transparentBorder: true
                    }
                }

                // Una "raffica" di sfarfallio: spegnimenti rapidi e riaccensioni
                // irregolari, come un tubo al neon con lo starter difettoso.
                SequentialAnimation {
                    id: flickerBurst
                    NumberAnimation { target: brandNeon; property: "glowOn"; to: 0.10; duration: 45 }
                    NumberAnimation { target: brandNeon; property: "glowOn"; to: 0.92; duration: 50 }
                    NumberAnimation { target: brandNeon; property: "glowOn"; to: 0.22; duration: 40 }
                    PauseAnimation { duration: 70 }
                    NumberAnimation { target: brandNeon; property: "glowOn"; to: 1.0; duration: 60 }
                    NumberAnimation { target: brandNeon; property: "glowOn"; to: 0.45; duration: 35 }
                    NumberAnimation { target: brandNeon; property: "glowOn"; to: 1.0; duration: 110 }
                }

                // Innesca le raffiche a intervalli casuali (1.8–6 s) finché la home
                // è in primo piano. Off-screen: ferma tutto e lascia il brand acceso.
                Timer {
                    id: flickerTimer
                    running: brandNeon.flickerActive
                    repeat: true
                    interval: 2500
                    onTriggered: {
                        if (!flickerBurst.running) {
                            flickerBurst.restart();
                        }
                        interval = 1800 + Math.round(Math.random() * 4200);
                    }
                    onRunningChanged: {
                        if (!running) {
                            flickerBurst.stop();
                            brandNeon.glowOn = 1.0;
                        }
                    }
                }
            }

            // Lente rimossa dalla home: il comando "Search..." è ora nel menu del titolo.
            MouseArea {
                anchors.fill: parent
                onClicked: titleMenuPanel.opened = !titleMenuPanel.opened
            }
        }

        MouseArea {
            id: titleMenuDismiss
            anchors.fill: parent
            visible: titleMenuPanel.opened
            z: 50
            onClicked: titleMenuPanel.opened = false
        }

        Rectangle {
            id: titleMenuPanel
            property bool opened: false
            anchors.top: pageHeader.bottom
            // Neon: pannello a tutta larghezza (card vetro). Silica: box ALLINEATO A
            // DESTRA come il brand, largo quanto basta alle voci. Sfondo (vedi `color`
            // sotto): Neon = arancio bruciato translucido (come il menu Neon); Silica
            // (task 2) = OPACO e adattivo al tema (Theme.overlayBackgroundColor forzato
            // a alpha 1), niente arancio né trasparenza — su ambiance chiaro l'arancio
            // translucido risultava illeggibile.
            anchors.right: parent.right
            anchors.rightMargin: Theme.horizontalPageMargin
            anchors.left: overviewPage.neon ? parent.left : undefined
            anchors.leftMargin: Theme.horizontalPageMargin
            width: overviewPage.neon
                   ? undefined
                   : Math.min(parent.width - 2 * Theme.horizontalPageMargin, Theme.itemSizeHuge * 2.4)
            radius: overviewPage.neon ? Theme.paddingLarge : 0
            color: overviewPage.neon ? Theme.rgba("#803500", 0.82)
                                     : Theme.rgba(Theme.overlayBackgroundColor, 1.0)
            border.width: overviewPage.neon ? 4 : 0
            border.color: "#ff2d2d"
            z: 100
            clip: true
            height: opened ? titleMenuColumn.height + 2 * Theme.paddingMedium : 0
            visible: height > 0
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

            Column {
                id: titleMenuColumn
                anchors.top: parent.top
                anchors.topMargin: Theme.paddingMedium
                anchors.left: parent.left
                anchors.right: parent.right

                Repeater {
                    model: [
                        { "text": qsTr("Search..."), "action": "search" },
                        { "text": qsTr("Search in messages"), "action": "searchMessages" },
                        { "text": qsTr("Mark all as read"), "action": "markRead" },
                        { "text": qsTr("Edit folders"), "action": "editFolders" },
                        { "text": qsTr("Reorder Pinned Chats"), "action": "reorderPinned" },
                        { "text": qsTr("Scheduled messages"), "action": "scheduled" }
                    ]
                    delegate: BackgroundItem {
                        width: parent.width
                        height: Theme.itemSizeSmall
                        onClicked: {
                            titleMenuPanel.opened = false;
                            switch (modelData.action) {
                            case "search":
                                chatSearchField.focus = true;
                                chatSearchField.opacity = 1.0;
                                pageHeader.opacity = 0.0;
                                break;
                            case "searchMessages":
                                pageStack.push(Qt.resolvedUrl("../pages/MessageSearchPage.qml"));
                                break;
                            case "markRead":
                                overviewPage.markAllChatsAsRead();
                                break;
                            case "editFolders":
                                pageStack.push(Qt.resolvedUrl("../pages/ChatFoldersPage.qml"));
                                break;
                            case "reorderPinned":
                                pageStack.push(Qt.resolvedUrl("../pages/ReorderPinnedChatsPage.qml"));
                                break;
                            case "scheduled":
                                pageStack.push(Qt.resolvedUrl("../pages/AllScheduledMessagesPage.qml"));
                                break;
                            }
                        }
                        Label {
                            // Neon: testo centrato. Silica: allineato a sinistra con
                            // padding, come le voci dei ContextMenu nativi.
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: overviewPage.neon ? 0 : Theme.horizontalPageMargin
                            anchors.rightMargin: overviewPage.neon ? 0 : Theme.horizontalPageMargin
                            horizontalAlignment: overviewPage.neon ? Text.AlignHCenter : Text.AlignLeft
                            text: modelData.text
                            font.italic: overviewPage.neon
                            // Scritte bianche al neon su sfondo arancione.
                            color: overviewPage.neon ? (parent.highlighted ? "#fff3e6" : "#ffffff") : (parent.highlighted ? Theme.highlightColor : Theme.primaryColor)
                            layer.enabled: overviewPage.neon
                            layer.effect: Glow {
                                color: "#ffffff"
                                radius: 6
                                samples: 13
                                spread: 0.2
                                transparentBorder: true
                            }
                        }
                    }
                }
            }
        }

        SearchField {
            id: chatSearchField
            visible: opacity > 0
            opacity: 0
            Behavior on opacity { FadeAnimation {} }
            width: parent.width
            height: pageHeader.height
            placeholderText: qsTr("Search chat...")
            // Niente lente: resta solo il placeholder "Cerca la chat...".
            leftItem: null
            canHide: text === ""

            onTextChanged: serverSearchTimer.restart()

            onHideClicked: {
                resetFocus();
            }

            EnterKey.iconSource: "image://theme/icon-m-enter-close"
            EnterKey.onClicked: {
                resetFocus();
            }
        }

        // ── Riga cartelle — approccio identico a Yottagram ──────────
        // SilicaListView direttamente nel SilicaFlickable padre,
        // BackgroundItem come delegate, text: folderName accesso diretto al role
        Timer {
            id: folderSwitchTimer
            interval: 400
            repeat: false
            property int targetFolderId: 0
            onTriggered: { chatListModel.setActiveFolder(targetFolderId) }
        }

        SilicaListView {
            id: chatFolderList
            width: parent.width
            height: chatFoldersModel.count > 0 ? Theme.itemSizeExtraLarge : 0
            model: chatFoldersModel
            orientation: Qt.Horizontal
            layoutDirection: Qt.LeftToRight
            anchors.top: pageHeader.bottom
            visible: chatFoldersModel.count > 0
            clip: true

            HorizontalScrollDecorator {}

            // "Tutte" — header fisso
            header: ListItem {
                id: allHeader
                width: Theme.itemSizeLarge
                contentHeight: Theme.itemSizeExtraLarge
                highlighted: activeFolderId === 0
                // Long-press su "Tutte" rimosso: le stesse voci sono nel menu del titolo.
                openMenuOnPressAndHold: false
                menu: ContextMenu {
                    MenuItem {
                        text: qsTr("Mark all as read")
                        onClicked: {
                            overviewPage.markAllChatsAsRead();
                        }
                    }
                    MenuItem {
                        text: qsTr("Edit folders")
                        onClicked: {
                            pageStack.push(Qt.resolvedUrl("../pages/ChatFoldersPage.qml"));
                        }
                    }
                    MenuItem {
                        text: qsTr("Reorder Pinned Chats")
                        onClicked: {
                            pageStack.push(Qt.resolvedUrl("../pages/ReorderPinnedChatsPage.qml"));
                        }
                    }
                    MenuItem {
                        text: qsTr("Scheduled messages")
                        onClicked: {
                            pageStack.push(Qt.resolvedUrl("../pages/AllScheduledMessagesPage.qml"));
                        }
                    }
                }

                // alone neon dietro l'icona (icona nitida sopra)
                Glow {
                    visible: overviewPage.neon
                    anchors.fill: allIcon
                    source: allIcon
                    color: "#ffffff"
                    radius: 8
                    samples: 17
                    spread: 0.25
                    transparentBorder: true
                    opacity: allIcon.opacity
                    z: -1
                }
                Image {
                    id: allIcon
                    source: overviewPage.neon ? "image://theme/icon-m-chat?#ffffff" : "image://theme/icon-m-chat"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Theme.paddingMedium
                    width: Theme.iconSizeMedium
                    height: Theme.iconSizeMedium
                    fillMode: Image.PreserveAspectFit
                    opacity: activeFolderId === 0 ? 1.0 : 0.6
                }

                Glow {
                    visible: overviewPage.neon
                    anchors.fill: allLabel
                    source: allLabel
                    color: "#ffffff"
                    radius: 6
                    samples: 13
                    spread: 0.2
                    transparentBorder: true
                    opacity: allLabel.opacity
                    z: -1
                }
                Label {
                    id: allLabel
                    text: qsTr("All")
                    font.pixelSize: Theme.fontSizeExtraSmall
                    font.italic: overviewPage.neon
                    anchors.top: allIcon.bottom
                    anchors.topMargin: Theme.paddingSmall
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Theme.itemSizeMedium
                    horizontalAlignment: Text.AlignHCenter
                    color: overviewPage.neon ? "#ffffff" : (activeFolderId === 0 ? Theme.highlightColor : Theme.primaryColor)
                    opacity: activeFolderId === 0 ? 1.0 : 0.6
                }

                onClicked: {
                    folderSwitchTimer.stop()
                    activeFolderId = 0
                    chatListModel.setActiveFolder(0)
                    tdLibWrapper.switchChatList(0)
                    tdLibWrapper.getChats()
                }
            }

            // Delegate cartelle — ESATTAMENTE come Yottagram
            delegate: BackgroundItem {
                width: Theme.itemSizeLarge
                height: Theme.itemSizeExtraLarge
                clip: true
                highlighted: activeFolderId === folderId

                // alone neon dietro l'icona (icona nitida sopra)
                Glow {
                    visible: overviewPage.neon
                    anchors.fill: folderIcon
                    source: folderIcon
                    color: "#ffffff"
                    radius: 8
                    samples: 17
                    spread: 0.3
                    transparentBorder: true
                    opacity: folderIcon.opacity
                    z: -1
                }
                Image {
                    id: folderIcon
                    source: overviewPage.neon ? "image://theme/icon-m-folder?#ffffff" : "image://theme/icon-m-folder"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Theme.paddingMedium
                    width: Theme.iconSizeMedium
                    height: Theme.iconSizeMedium
                    fillMode: Image.PreserveAspectFit
                    opacity: activeFolderId === folderId ? 1.0 : 0.6
                }

                Glow {
                    visible: overviewPage.neon
                    anchors.fill: folderLabel
                    source: folderLabel
                    color: "#ffffff"
                    radius: 6
                    samples: 13
                    spread: 0.25
                    transparentBorder: true
                    opacity: folderLabel.opacity
                    z: -1
                }
                Label {
                    id: folderLabel
                    text: folderName
                    font.pixelSize: Theme.fontSizeExtraSmall
                    font.italic: overviewPage.neon
                    anchors.top: folderIcon.bottom
                    anchors.topMargin: Theme.paddingSmall
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Theme.itemSizeMedium
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    lineHeight: 0.8
                    color: overviewPage.neon ? "#ffffff" : (activeFolderId === folderId ? Theme.highlightColor : Theme.primaryColor)
                    opacity: activeFolderId === folderId ? 1.0 : 0.6
                }

                onClicked: {
                    var fid = folderId
                    if (activeFolderId === fid) {
                        folderSwitchTimer.stop()
                        activeFolderId = 0
                        chatListModel.setActiveFolder(0)
                        tdLibWrapper.switchChatList(0)
                        tdLibWrapper.getChats()
                    } else {
                        activeFolderId = fid
                        tdLibWrapper.switchChatList(2, fid)
                        folderSwitchTimer.targetFolderId = fid
                        folderSwitchTimer.restart()
                    }
                }
            }
        }
        SilicaListView {
            id: chatListView
            anchors {
                top: chatFoldersModel.count > 0 ? chatFolderList.bottom : pageHeader.bottom
                bottom: parent.bottom
                left: parent.left
                right: parent.right
            }
            clip: true
            opacity: (overviewPage.chatListCreated && !overviewPage.logoutLoading) ? 1 : 0
            Behavior on opacity { FadeAnimation {} }
            model: chatListProxyModel.sourceModel ? chatListProxyModel : chatListModel

            // Sezione "Le mie chat": intestazione sopra i match locali (solo
            // durante la ricerca e se ci sono risultati locali).
            header: Component {
                Item {
                    width: chatListView.width
                    height: (overviewPage.searching && chatListView.count > 0) ? myChatsHeader.height : 0
                    visible: height > 0
                    SectionHeader {
                        id: myChatsHeader
                        text: qsTr("My chats")
                    }
                }
            }

            // Sezione "Risultati globali": utenti/gruppi/canali pubblici trovati
            // su Telegram (anche non tra le proprie chat). Sta nel footer così
            // scorre insieme alla lista, sotto i match locali.
            footer: Component {
                Column {
                    width: chatListView.width

                    SectionHeader {
                        text: qsTr("Global results")
                        visible: overviewPage.searching && searchResultsModel.count > 0
                        height: visible ? implicitHeight : 0
                    }

                    Repeater {
                        model: overviewPage.searching ? searchResultsModel : null
                        delegate: SearchResultItem {
                            width: chatListView.width
                            resultChatId: model.resultChatId
                            resultTitle: model.resultTitle
                            resultSubtitle: model.resultSubtitle
                            resultPhoto: model.resultPhoto
                            onClicked: overviewPage.openChat(resultChatId)
                        }
                    }

                    Label {
                        visible: overviewPage.searching && searchResultsModel.count === 0 && chatSearchField.text.length >= 2
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        topPadding: Theme.paddingLarge
                        bottomPadding: Theme.paddingLarge
                        wrapMode: Text.Wrap
                        text: qsTr("No public users, groups or channels found.")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            delegate: ChatListViewItem {
                ownUserId: overviewPage.ownUserId
                activeFolderId: overviewPage.activeFolderId
                // Tema Neon: menù long-press a comparsa (NeonMenuOverlay), invariato.
                // Tema Silica: null → fallback al ContextMenu Silica nativo (2.3 #11b).
                neonMenu: overviewPage.neon ? chatNeonMenu : null
                isVerified: is_verified
                onClicked: {
                    // Se è un supergruppo forum, mostra prima la lista dei topic
                    var chatType = display["type"] || {};
                    if (chatType["@type"] === "chatTypeSupergroup" && !chatType.is_channel) {
                        var groupInfo = tdLibWrapper.getSuperGroup(chatType.supergroup_id);
                        if (groupInfo && groupInfo.is_forum === true) {
                            pageStack.push(Qt.resolvedUrl("../pages/ForumTopicsPage.qml"), {
                                chatInformation: display
                            });
                            return;
                        }
                    }
                    pageStack.push(Qt.resolvedUrl("../pages/ChatPage.qml"), {
                        chatInformation : display,
                        chatPicture: photo_small
                    })
                }
            }

            ViewPlaceholder {
                // Durante la ricerca i risultati (locali + globali) e l'eventuale
                // messaggio "nessun risultato" sono gestiti da header/footer.
                enabled: chatListView.count === 0 && !overviewPage.searching
                text: chatListModel.count === 0 ? qsTr("You don't have any chats yet.") : qsTr("No matching chats found.")
                hintText: qsTr("You can search public chats or create a new chat via the pull-down menu.")
            }

            VerticalScrollDecorator {}
        }

        Column {
            width: parent.width
            spacing: Theme.paddingMedium
            anchors.verticalCenter: chatListView.verticalCenter

            opacity: overviewPage.chatListCreated && !overviewPage.logoutLoading ? 0 : 1
            Behavior on opacity { FadeAnimation {} }
            visible: !overviewPage.chatListCreated || overviewPage.logoutLoading

            BusyLabel {
                    id: loadingBusyIndicator
                    running: true
            }
        }
    }

    Timer {
        id: interactionHintTimer
        running: false
        interval: 4000
        onTriggered: {
            titleInteractionHint.opacity = 0.0;
        }
    }

    InteractionHintLabel {
        id: titleInteractionHint
        text: qsTr("Tap on the title bar to filter your chats")
        visible: opacity > 0
        invert: true
        anchors.fill: parent
        Behavior on opacity { FadeAnimation {} }
        opacity: 0
    }

    // Menù neon a comparsa per il long-press sulle chat (sostituisce il ContextMenu Silica).
    NeonMenuOverlay {
        id: chatNeonMenu
    }

}
