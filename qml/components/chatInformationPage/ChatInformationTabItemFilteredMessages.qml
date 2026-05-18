/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), which is
    licensed under the GNU General Public License v3.0. The original
    license is available at:
    https://github.com/Wunderfitz/harbour-fernschreiber/blob/master/LICENSE
*/
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../"
import "../../js/functions.js" as Functions

ChatInformationTabItemBase {
    id: filteredTab
    property var filterTypes: []
    property string tabKey: ""
    property string emptyPlaceholderText: ""
    property bool mediaGridMode: false
    property bool requestInFlight: false
    property bool noMoreResults: false
    property int nextFilterIndex: 0
    property string currentRequestFilter: ""
    property string currentRequestExtra: ""
    property var fromMessageByFilter: ({})
    property var noMoreByFilter: ({})
    property var seenMessageIds: ({})
    loading: requestInFlight && filteredListModel.count === 0
    loadingVisible: loading

    function resolvedFilters() {
        var filters = [];
        if (filterTypes && filterTypes.length !== undefined) {
            for (var i = 0; i < filterTypes.length; i++) {
                var nextType = filterTypes[i];
                if (nextType && nextType.length > 0) {
                    filters.push(nextType);
                }
            }
        }
        if (filters.length === 0) {
            if (tabKey === "media") {
                filters = ["searchMessagesFilterPhotoAndVideo"];
            } else if (tabKey === "audio") {
                filters = ["searchMessagesFilterVoiceAndVideoNote", "searchMessagesFilterAudio"];
            } else if (tabKey === "documents") {
                filters = ["searchMessagesFilterDocument"];
            } else if (tabKey === "links") {
                filters = ["searchMessagesFilterUrl"];
            }
        }
        return filters;
    }

    function resetFilterState() {
        filteredListModel.clear();
        requestInFlight = false;
        noMoreResults = false;
        nextFilterIndex = 0;
        currentRequestFilter = "";
        currentRequestExtra = "";
        fromMessageByFilter = ({});
        noMoreByFilter = ({});
        seenMessageIds = ({});
    }

    function ensureFilterState() {
        var filters = resolvedFilters();
        if (filters.length === 0) {
            return;
        }
        var nextFromByFilter = {};
        var nextNoMoreByFilter = {};
        for (var i = 0; i < filters.length; i++) {
            var filter = filters[i];
            nextFromByFilter[filter] = fromMessageByFilter[filter] || 0;
            nextNoMoreByFilter[filter] = !!noMoreByFilter[filter];
        }
        fromMessageByFilter = nextFromByFilter;
        noMoreByFilter = nextNoMoreByFilter;
    }

    function hasRemainingFilters() {
        var filters = resolvedFilters();
        if (filters.length === 0) {
            return false;
        }
        for (var i = 0; i < filters.length; i++) {
            if (!noMoreByFilter[filters[i]]) {
                return true;
            }
        }
        return false;
    }

    function pickNextFilter() {
        var filters = resolvedFilters();
        if (filters.length === 0) {
            return "";
        }
        var startIndex = nextFilterIndex;
        for (var i = 0; i < filters.length; i++) {
            var idx = (startIndex + i) % filters.length;
            var candidate = filters[idx];
            if (!noMoreByFilter[candidate]) {
                nextFilterIndex = (idx + 1) % filters.length;
                return candidate;
            }
        }
        return "";
    }

    function extractLinkFromText(textValue) {
        var linkMatch = (textValue || "").match(/((https?:\/\/|www\.)\S+|t\.me\/\S+|telegram\.me\/\S+)/i);
        if (linkMatch && linkMatch.length > 0) {
            return linkMatch[0];
        }
        return "";
    }

    function normalizePreviewText(textValue) {
        var normalized = (textValue || "").replace(/\s+/g, " ").trim();
        if (tabKey === "links") {
            var extractedLink = extractLinkFromText(normalized);
            if (extractedLink !== "") {
                return extractedLink;
            }
        }
        return normalized;
    }

    function isImageDocumentContent(messageContent) {
        if (!messageContent || messageContent["@type"] !== "messageDocument" || !messageContent.document) {
            return false;
        }
        var documentInfo = messageContent.document;
        var mimeType = (documentInfo.mime_type || "").toLowerCase();
        if (mimeType.indexOf("image/") === 0) {
            return true;
        }
        var fileName = (documentInfo.file_name || "").toLowerCase();
        return /\.(jpg|jpeg|png|gif|webp|bmp|heic|heif|tif|tiff|svg)$/.test(fileName);
    }

    function shouldIncludeMessage(msg) {
        if (!msg || !msg.content) {
            return false;
        }
        if (tabKey === "documents") {
            var contentType = msg.content["@type"] || "";
            if (contentType !== "messageDocument") {
                return false;
            }
            if (isImageDocumentContent(msg.content)) {
                return false;
            }
        }
        return true;
    }

    function findLinkInFormattedText(formattedText) {
        if (!formattedText || !formattedText.text) {
            return "";
        }
        var plainText = formattedText.text;
        var entities = formattedText.entities || [];
        for (var i = 0; i < entities.length; i++) {
            var entity = entities[i];
            if (!entity || entity["@type"] !== "textEntity" || !entity.type) {
                continue;
            }
            var entityType = entity.type["@type"] || "";
            if (entityType === "textEntityTypeTextUrl" && entity.type.url) {
                return entity.type.url;
            }
            if (entityType === "textEntityTypeUrl") {
                var offset = Number(entity.offset);
                var length = Number(entity.length);
                if (!isNaN(offset) && !isNaN(length) && offset >= 0 && length > 0) {
                    return plainText.substring(offset, offset + length);
                }
            }
        }
        return extractLinkFromText(plainText);
    }

    function extractLinkFromMessage(msg) {
        if (!msg || !msg.content) {
            return "";
        }
        var messageContent = msg.content;
        if (messageContent["@type"] === "messageText") {
            return findLinkInFormattedText(messageContent.text);
        }
        if (messageContent.caption) {
            var captionLink = findLinkInFormattedText(messageContent.caption);
            if (captionLink !== "") {
                return captionLink;
            }
        }
        var fallbackText = "";
        try {
            fallbackText = Functions.getMessageText(msg, true, chatInformationPage.myUserId, true) || "";
        } catch (error) {
            fallbackText = "";
        }
        return extractLinkFromText(fallbackText);
    }

    function openMessageFromFilteredEntry(messageId) {
        if (!messageId || !chatInformationPage.chatInformation || !chatInformationPage.chatInformation.id) {
            return;
        }
        var rootPage = pageStack.find(function(page) { return (page._depth === 0); });
        if (rootPage) {
            pageStack.pop(rootPage, PageStackAction.Immediate);
        }
        var chatData = tdLibWrapper.getChat(chatInformationPage.chatInformation.id) || chatInformationPage.chatInformation;
        pageStack.push(Qt.resolvedUrl("../../pages/ChatPage.qml"), {
            "chatInformation": chatData,
            "messageIdToShow": messageId
        }, PageStackAction.Immediate);
    }

    function openFilteredEntry(messageId, msg, previewText) {
        if (tabKey === "links") {
            var linkToOpen = extractLinkFromMessage(msg);
            if (linkToOpen === "") {
                linkToOpen = extractLinkFromText(previewText || "");
            }
            if (linkToOpen !== "") {
                Functions.handleLink(linkToOpen);
                return;
            }
        }
        openMessageFromFilteredEntry(messageId);
    }

    function appendMessage(msg) {
        if (!shouldIncludeMessage(msg)) {
            return false;
        }
        var messageId = msg.id ? msg.id.toString() : "";
        if (messageId === "" || seenMessageIds[messageId]) {
            return false;
        }
        seenMessageIds[messageId] = true;
        var messageDate = Number(msg.date || 0);
        var messageText = "";
        try {
            messageText = Functions.getMessageText(msg, true, chatInformationPage.myUserId, true) || "";
        } catch (error) {
            messageText = "";
        }
        messageText = normalizePreviewText(messageText);
        var entry = {
            "messageId": messageId,
            "messageDate": messageDate,
            "contentType": (msg.content ? msg.content["@type"] : "") || "",
            "messageText": messageText,
            "rawMessage": msg
        };
        var insertIndex = filteredListModel.count;
        for (var i = 0; i < filteredListModel.count; i++) {
            var existingDate = Number(filteredListModel.get(i).messageDate || 0);
            if (messageDate > existingDate) {
                insertIndex = i;
                break;
            }
        }
        filteredListModel.insert(insertIndex, entry);
        return true;
    }

    function releaseRequestState() {
        requestInFlight = false;
        currentRequestFilter = "";
        currentRequestExtra = "";
    }

    function updateNoMoreFlag() {
        noMoreResults = !hasRemainingFilters();
    }

    function requestMessages() {
        if (tabKey === "" || requestInFlight || noMoreResults) {
            return;
        }
        var chatId = chatInformationPage.chatInformation.id;
        if (!chatId) {
            return;
        }
        ensureFilterState();
        var selectedFilter = pickNextFilter();
        if (selectedFilter === "") {
            updateNoMoreFlag();
            return;
        }
        currentRequestFilter = selectedFilter;
        currentRequestExtra = "sharedMedia:" + tabKey + ":" + Date.now() + ":" + Math.floor(Math.random() * 1000000);
        requestInFlight = true;
        var requestObject = {
            "@type": "searchChatMessages",
            "chat_id": chatId,
            "query": "",
            "from_message_id": fromMessageByFilter[selectedFilter] || 0,
            "offset": 0,
            "limit": 50,
            "filter": { "@type": selectedFilter },
            "@extra": currentRequestExtra
        };
        tdLibWrapper.sendRequest(requestObject);
    }

    function handleFoundMessages(messages, usedFilter) {
        if (usedFilter === "") {
            return;
        }
        if (!messages || messages.length === 0) {
            noMoreByFilter[usedFilter] = true;
            updateNoMoreFlag();
            if (filteredListModel.count === 0 && !noMoreResults) {
                requestMessages();
            }
            return;
        }
        var insertedMessages = 0;
        for (var i = 0; i < messages.length; i++) {
            if (appendMessage(messages[i])) {
                insertedMessages += 1;
            }
        }
        var lastMessage = messages[messages.length - 1];
        if (lastMessage && lastMessage.id) {
            fromMessageByFilter[usedFilter] = lastMessage.id;
        }
        if (messages.length < 50) {
            noMoreByFilter[usedFilter] = true;
        }
        updateNoMoreFlag();
        if (insertedMessages === 0 && !noMoreResults) {
            requestMessages();
        }
    }

    ListModel {
        id: filteredListModel
    }

    Connections {
        target: tdLibWrapper
        onMessagesReceivedWithExtra: {
            if (!filteredTab.requestInFlight || extra !== filteredTab.currentRequestExtra) {
                return;
            }
            var usedFilter = filteredTab.currentRequestFilter;
            var responseMessages = messages || [];
            releaseRequestState();
            handleFoundMessages(responseMessages, usedFilter);
        }
        onErrorReceived: {
            if (!filteredTab.requestInFlight || extra !== filteredTab.currentRequestExtra) {
                return;
            }
            var failedFilter = filteredTab.currentRequestFilter;
            releaseRequestState();
            if (failedFilter !== "") {
                noMoreByFilter[failedFilter] = true;
            }
            updateNoMoreFlag();
            if (filteredListModel.count === 0 && !noMoreResults) {
                requestMessages();
            }
            appNotification.show(message !== "" ? message : qsTr("Unable to load content."));
        }
    }

    SilicaGridView {
        id: mediaGridView
        visible: filteredTab.mediaGridMode
        width: filteredTab.width - (Theme.horizontalPageMargin * 2)
        x: Theme.horizontalPageMargin
        height: filteredTab.height
        clip: true
        property int columnsCount: 4
        cellWidth: Math.max(Theme.itemSizeMedium, Math.floor((width - Theme.paddingSmall * (columnsCount - 1)) / columnsCount))
        cellHeight: cellWidth
        model: filteredListModel

        ViewPlaceholder {
            y: Theme.paddingLarge
            enabled: mediaGridView.count === 0 && !filteredTab.requestInFlight && filteredTab.noMoreResults
            text: filteredTab.emptyPlaceholderText
        }

        delegate: BackgroundItem {
            id: mediaItem
            width: mediaGridView.cellWidth
            height: mediaGridView.cellHeight
            property var messageContent: (rawMessage && rawMessage.content) ? rawMessage.content : ({})
            property string messageContentType: messageContent["@type"] || ""

            onClicked: {
                if (!rawMessage) {
                    return;
                }
                if (messageContentType === "messagePhoto" || messageContentType === "messageVideo") {
                    pageStack.push(Qt.resolvedUrl("../../pages/MediaAlbumPage.qml"), {
                        "messages": [rawMessage],
                        "index": 0
                    });
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.paddingSmall
                color: Theme.rgba(Theme.primaryColor, 0.08)
                border.color: Theme.rgba(Theme.primaryColor, 0.2)
                clip: true

                TDLibPhoto {
                    anchors.fill: parent
                    visible: mediaItem.messageContentType === "messagePhoto"
                    photo: mediaItem.messageContent.photo
                    highlighted: mediaItem.highlighted
                }

                TDLibThumbnail {
                    anchors.fill: parent
                    visible: mediaItem.messageContentType === "messageVideo"
                    thumbnail: mediaItem.messageContent.video ? mediaItem.messageContent.video.thumbnail : null
                    minithumbnail: mediaItem.messageContent.video ? mediaItem.messageContent.video.minithumbnail : null
                    highlighted: mediaItem.highlighted
                }

                Label {
                    anchors.centerIn: parent
                    visible: mediaItem.messageContentType !== "messagePhoto" && mediaItem.messageContentType !== "messageVideo"
                    text: "◻"
                    color: Theme.secondaryColor
                }
            }

            Icon {
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    rightMargin: Theme.paddingSmall
                    bottomMargin: Theme.paddingSmall
                }
                source: "image://theme/icon-s-play"
                highlighted: true
                visible: mediaItem.messageContentType === "messageVideo"
            }

            Label {
                anchors {
                    left: parent.left
                    bottom: parent.bottom
                    leftMargin: Theme.paddingSmall
                    bottomMargin: Theme.paddingSmall
                }
                text: messageDate > 0 ? Functions.getDateTimeElapsed(messageDate) : ""
                font.pixelSize: Theme.fontSizeTiny
                color: Theme.primaryColor
            }
        }

        onAtYEndChanged: {
            if (atYEnd && mediaGridView.count > 0) {
                filteredTab.requestMessages();
            }
        }

        VerticalScrollDecorator {
            flickable: mediaGridView
        }
    }

    SilicaListView {
        id: filteredListView
        visible: !filteredTab.mediaGridMode
        width: filteredTab.width
        height: filteredTab.height
        clip: true
        model: filteredListModel

        ViewPlaceholder {
            y: Theme.paddingLarge
            enabled: filteredListView.count === 0 && !filteredTab.requestInFlight && filteredTab.noMoreResults
            text: filteredTab.emptyPlaceholderText
        }

        delegate: ListItem {
            id: filteredMessageItem
            width: parent.width
            contentHeight: messageColumn.height + (2 * Theme.paddingSmall)
            onClicked: {
                filteredTab.openFilteredEntry(messageId, rawMessage, messageText);
            }

            Column {
                id: messageColumn
                anchors {
                    left: parent.left
                    leftMargin: Theme.horizontalPageMargin
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.paddingTiny

                Label {
                    width: parent.width
                    text: messageText !== "" ? messageText : contentType
                    truncationMode: TruncationMode.Fade
                    maximumLineCount: 1
                    wrapMode: Text.NoWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: filteredMessageItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                }

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignRight
                    text: messageDate > 0 ? Functions.getDateTimeElapsed(messageDate) : ""
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                }
            }
        }

        onAtYEndChanged: {
            if (atYEnd && filteredListView.count > 0) {
                filteredTab.requestMessages();
            }
        }

        VerticalScrollDecorator {
            flickable: filteredListView
        }
    }

    Component.onCompleted: {
        ensureFilterState();
        updateNoMoreFlag();
        requestMessages();
    }

    onFilterTypesChanged: {
        resetFilterState();
        ensureFilterState();
        updateNoMoreFlag();
        requestMessages();
    }

    onTabKeyChanged: {
        if (filteredListModel.count === 0 && !requestInFlight) {
            requestMessages();
        }
    }

    onActiveChanged: {
        if (active && filteredListModel.count === 0 && !requestInFlight) {
            requestMessages();
        }
    }
}