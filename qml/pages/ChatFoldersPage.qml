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
import WerkWolf.RooTelegram 1.0

Page {
    id: chatFoldersPage
    allowedOrientations: Orientation.All

    property string pendingFolderName: ""
    property int pendingFolderCount: 0
    property bool waitingFolderCreation: false
    property int pendingCreateAttempt: -1
    property string pendingCreateRequestExtra: ""
    property string createStatusText: ""
    property bool createStatusIsError: false
    property var pendingDeleteFolderNames: ({})
    function normalizedFolderTitle(rawText) {
        if (rawText === undefined || rawText === null) {
            return "";
        }
        return ("" + rawText).replace(/^\s+|\s+$/g, "");
    }
    function folderNameFromInfo(folderInfo) {
        if (!folderInfo) {
            return "";
        }
        if (typeof folderInfo.name === "string") {
            return folderInfo.name;
        }
        if (folderInfo.name) {
            if (typeof folderInfo.name.text === "string") {
                return folderInfo.name.text;
            }
            if (folderInfo.name.text && typeof folderInfo.name.text.text === "string") {
                return folderInfo.name.text.text;
            }
        }
        if (typeof folderInfo.title === "string") {
            return folderInfo.title;
        }
        return "";
    }

    function refreshFolderModel(folders) {
        folderEditModel.clear();
        if (folders && folders.length !== undefined) {
            for (var i = 0; i < folders.length; i++) {
                var folderInfo = folders[i] || {};
                var folderId = parseInt(folderInfo.id);
                if (isNaN(folderId) || folderId <= 0) {
                    continue;
                }
                folderEditModel.append({
                    "folderId": folderId,
                    "folderName": folderNameFromInfo(folderInfo)
                });
            }
        } else {
            for (var j = 0; j < chatFoldersModel.count; j++) {
                folderEditModel.append({
                    "folderId": chatFoldersModel.getId(j),
                    "folderName": chatFoldersModel.getName(j)
                });
            }
        }
        if (waitingFolderCreation && folderEditModel.count > pendingFolderCount) {
            waitingFolderCreation = false;
            pendingFolderName = "";
            pendingCreateAttempt = -1;
            pendingCreateRequestExtra = "";
            createFolderResponseTimer.stop();
            createStatusText = qsTr("Folder created.");
            createStatusIsError = false;
            appNotification.show(qsTr("Folder created."));
        }
    }

    function sendReorderRequest() {
        var folderIds = [];
        for (var i = 0; i < folderEditModel.count; i++) {
            folderIds.push(folderEditModel.get(i).folderId);
        }
        tdLibWrapper.sendRequest({
            "@type": "reorderChatFolders",
            "chat_folder_ids": folderIds,
            "main_chat_list_position": 0,
            "@extra": "reorderChatFolders"
        });
    }

    function moveFolder(fromIndex, toIndex) {
        if (fromIndex < 0 || toIndex < 0 || fromIndex >= folderEditModel.count || toIndex >= folderEditModel.count || fromIndex === toIndex) {
            return;
        }
        folderEditModel.move(fromIndex, toIndex, 1);
        sendReorderRequest();
    }

    function setPendingDelete(folderId, folderName) {
        var state = {};
        for (var key in pendingDeleteFolderNames) {
            state[key] = pendingDeleteFolderNames[key];
        }
        if (folderName && folderName.length > 0) {
            state[folderId] = folderName;
        } else {
            delete state[folderId];
        }
        pendingDeleteFolderNames = state;
    }

    function isDeletePending(folderId) {
        return !!pendingDeleteFolderNames[folderId];
    }

    function upsertFolderInModel(folderId, folderName) {
        if (folderId <= 0) {
            return;
        }
        for (var i = 0; i < folderEditModel.count; i++) {
            if (folderEditModel.get(i).folderId === folderId) {
                folderEditModel.setProperty(i, "folderName", folderName);
                return;
            }
        }
        folderEditModel.append({
            "folderId": folderId,
            "folderName": folderName
        });
    }

    function removeFolderFromModel(folderId) {
        for (var i = 0; i < folderEditModel.count; i++) {
            if (folderEditModel.get(i).folderId === folderId) {
                folderEditModel.remove(i);
                return;
            }
        }
    }

    function sendDeleteFolderRequest(folderId) {
        tdLibWrapper.sendRequest({
            "@type": "deleteChatFolder",
            "chat_folder_id": folderId,
            "@extra": "deleteChatFolder:" + folderId
        });
    }

    function firstVisibleChatId() {
        if (!chatListModel || chatListModel.count === undefined || !chatListModel.get) {
            return 0;
        }
        for (var i = 0; i < chatListModel.count; i++) {
            var row = chatListModel.get(i);
            var chatId = parseInt(row.chat_id);
            if (!isNaN(chatId) && chatId !== 0) {
                return chatId;
            }
        }
        return 0;
    }

    function deleteFolderAt(sourceItem, modelIndex) {
        if (modelIndex < 0 || modelIndex >= folderEditModel.count) {
            return;
        }
        var folderEntry = folderEditModel.get(modelIndex);
        var folderId = folderEntry.folderId;
        var folderName = folderEntry.folderName || "";
        if (folderId <= 0 || isDeletePending(folderId)) {
            return;
        }
        Remorse.itemAction(sourceItem, qsTr("Deleting folder"), function() {
            setPendingDelete(folderId, folderName);
            sendDeleteFolderRequest(folderId);
        });
    }

    function sendCreateFolderRequest(folderTitle, attemptIndex) {
        pendingCreateAttempt = attemptIndex;
        pendingCreateRequestExtra = "createChatFolder:" + attemptIndex + ":" + (new Date().getTime());
        createStatusText = attemptIndex === 0
                ? qsTr("Creating folder...")
                : qsTr("Retrying creation...");
        createStatusIsError = false;
        var seedChatId = firstVisibleChatId();
        var useSeedChat = attemptIndex === 0 && seedChatId !== 0;
        var folderObject = {
            "@type": "chatFolder",
            "color_id": -1,
            "is_shareable": false,
            "pinned_chat_ids": [],
            "included_chat_ids": useSeedChat ? [seedChatId] : [],
            "excluded_chat_ids": [],
            "exclude_muted": false,
            "exclude_read": false,
            "exclude_archived": false,
            "include_contacts": !useSeedChat,
            "include_non_contacts": !useSeedChat,
            "include_bots": !useSeedChat,
            "include_groups": !useSeedChat,
            "include_channels": !useSeedChat
        };
        folderObject["name"] = {
            "@type": "chatFolderName",
            "text": {
                "@type": "formattedText",
                "text": folderTitle,
                "entities": []
            },
            "animate_custom_emoji": false
        };
        tdLibWrapper.sendRequest({
            "@type": "createChatFolder",
            "folder": folderObject,
            "@extra": pendingCreateRequestExtra
        });
        createFolderResponseTimer.restart();
    }

    function createFolder(rawTitle, sourceField) {
        var folderTitle = "";
        try {
            folderTitle = normalizedFolderTitle(rawTitle);
        } catch (error) {
            createStatusText = qsTr("Internal error while creating folder.");
            createStatusIsError = true;
            appNotification.show(qsTr("Internal error while creating folder."));
            return false;
        }
        if (folderTitle.length === 0) {
            return false;
        }
        if (folderTitle.length > 12) {
            createStatusText = qsTr("Folder name must be at most 12 characters.");
            createStatusIsError = true;
            appNotification.show(qsTr("Folder name must be at most 12 characters."));
            return false;
        }
        pendingFolderName = folderTitle;
        pendingFolderCount = folderEditModel.count;
        waitingFolderCreation = true;
        pendingCreateAttempt = -1;
        pendingCreateRequestExtra = "";
        createStatusText = "";
        createStatusIsError = false;
        if (sourceField) {
            sourceField.text = "";
            sourceField.focus = false;
        }
        try {
            sendCreateFolderRequest(folderTitle, 0);
            return true;
        } catch (requestError) {
            waitingFolderCreation = false;
            pendingFolderName = "";
            pendingCreateAttempt = -1;
            pendingCreateRequestExtra = "";
            createFolderResponseTimer.stop();
            createStatusText = qsTr("Internal error while creating folder.");
            createStatusIsError = true;
            appNotification.show(qsTr("Internal error while creating folder."));
            return false;
        }
    }

    Connections {
        target: tdLibWrapper
        onChatFoldersReceived: {
            refreshFolderModel(folders);
        }
        onChatFolderInfoReceived: {
            if (!waitingFolderCreation) {
                return;
            }
            var responseExtra = folderInfo["@extra"] || "";
            if (responseExtra.length > 0 && responseExtra !== pendingCreateRequestExtra) {
                return;
            }
            var createdFolderId = parseInt(folderInfo.id);
            if (isNaN(createdFolderId) || createdFolderId <= 0) {
                return;
            }
            upsertFolderInModel(createdFolderId, folderNameFromInfo(folderInfo));
            waitingFolderCreation = false;
            pendingFolderName = "";
            pendingCreateAttempt = -1;
            pendingCreateRequestExtra = "";
            createFolderResponseTimer.stop();
            createStatusText = qsTr("Folder created.");
            createStatusIsError = false;
            appNotification.show(qsTr("Folder created."));
        }
        onOkReceived: {
            if (request.indexOf("deleteChatFolder:") === 0) {
                var deleteParts = request.split(":");
                if (deleteParts.length === 2) {
                    var deletedFolderId = parseInt(deleteParts[1]);
                    setPendingDelete(deletedFolderId, "");
                    removeFolderFromModel(deletedFolderId);
                    appNotification.show(qsTr("Folder deleted."));
                }
                return;
            }
            if (waitingFolderCreation && request === pendingCreateRequestExtra) {
                createFolderResponseTimer.restart();
            }
        }
        onErrorReceived: {
            if (extra.indexOf("deleteChatFolder:") === 0) {
                var folderParts = extra.split(":");
                if (folderParts.length === 2) {
                    var failedDeleteFolderId = parseInt(folderParts[1]);
                    var failedDeleteName = pendingDeleteFolderNames[failedDeleteFolderId] || "";
                    setPendingDelete(failedDeleteFolderId, "");
                    appNotification.show(failedDeleteName.length > 0
                                         ? qsTr("Unable to delete folder %1").arg(failedDeleteName)
                                         : qsTr("Unable to delete folder."));
                }
                return;
            }
            if (extra === "reorderChatFolders") {
                appNotification.show(qsTr("Unable to update folder order."));
                return;
            }
            var isCreateError = waitingFolderCreation
                                && pendingFolderName.length > 0
                                && (extra === pendingCreateRequestExtra
                                    || extra.indexOf("createChatFolder:") === 0
                                    || extra.length === 0);
            if (isCreateError) {
                if (pendingCreateAttempt === 0) {
                    sendCreateFolderRequest(pendingFolderName, 1);
                    return;
                }
                waitingFolderCreation = false;
                var failedFolderName = pendingFolderName;
                pendingFolderName = "";
                pendingCreateAttempt = -1;
                pendingCreateRequestExtra = "";
                createFolderResponseTimer.stop();
                createStatusText = message && message.length > 0
                        ? qsTr("Error creating folder: %1").arg(message)
                        : qsTr("Unable to create folder %1").arg(failedFolderName);
                createStatusIsError = true;
                appNotification.show(message && message.length > 0
                                     ? qsTr("Unable to create folder %1: %2").arg(failedFolderName).arg(message)
                                     : qsTr("Unable to create folder %1").arg(failedFolderName));
                return;
            }
        }
    }

    Component.onCompleted: {
        refreshFolderModel();
    }

    ListModel {
        id: folderEditModel
    }

    Timer {
        id: createFolderResponseTimer
        interval: 2200
        repeat: false
        onTriggered: {
            if (!waitingFolderCreation) {
                return;
            }
            if (pendingCreateAttempt === 0 && pendingFolderName.length > 0) {
                sendCreateFolderRequest(pendingFolderName, 1);
                return;
            }
            var failedFolderName = pendingFolderName;
            waitingFolderCreation = false;
            pendingFolderName = "";
            pendingCreateAttempt = -1;
            pendingCreateRequestExtra = "";
            createStatusText = failedFolderName.length > 0
                    ? qsTr("Unable to create folder %1").arg(failedFolderName)
                    : qsTr("Unable to create folder.");
            createStatusIsError = true;
            appNotification.show(failedFolderName.length > 0
                                 ? qsTr("Unable to create folder %1").arg(failedFolderName)
                                 : qsTr("Unable to create folder."));
        }
    }

    SilicaListView {
        id: foldersListView
        anchors.fill: parent
        clip: true
        model: folderEditModel

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: {
                    refreshFolderModel();
                }
            }
        }

        header: Column {
            width: foldersListView.width

            PageHeader {
                title: qsTr("Edit folders")
            }

            ListItem {
                width: parent.width
                contentHeight: Theme.itemSizeLarge
                enabled: false

                Icon {
                    id: allChatsIcon
                    source: "image://theme/icon-m-chat"
                    anchors {
                        left: parent.left
                        leftMargin: Theme.horizontalPageMargin
                        verticalCenter: parent.verticalCenter
                    }
                }

                Label {
                    anchors {
                        left: allChatsIcon.right
                        leftMargin: Theme.paddingMedium
                        right: parent.right
                        rightMargin: Theme.horizontalPageMargin
                        verticalCenter: parent.verticalCenter
                    }
                    truncationMode: TruncationMode.Fade
                    text: qsTr("All")
                    color: Theme.secondaryHighlightColor
                }
            }

            SectionHeader {
                text: qsTr("Custom folders")
            }
        }

        delegate: ListItem {
            id: folderRow
            width: ListView.view.width
            contentHeight: Theme.itemSizeLarge

            Icon {
                id: folderIcon
                source: "image://theme/icon-m-folder"
                anchors {
                    left: parent.left
                    leftMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
            }

            IconButton {
                id: deleteFolderButton
                icon.source: "image://theme/icon-m-clear"
                anchors {
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                enabled: !chatFoldersPage.isDeletePending(folderId)
                onClicked: {
                    chatFoldersPage.deleteFolderAt(folderRow, index);
                }
            }

            IconButton {
                id: moveDownButton
                icon.source: "image://theme/icon-m-down"
                anchors {
                    right: deleteFolderButton.left
                    rightMargin: Theme.paddingSmall
                    verticalCenter: parent.verticalCenter
                }
                enabled: index < folderEditModel.count - 1 && !chatFoldersPage.isDeletePending(folderId)
                onClicked: {
                    chatFoldersPage.moveFolder(index, index + 1);
                }
            }

            IconButton {
                id: moveUpButton
                icon.source: "image://theme/icon-m-up"
                anchors {
                    right: moveDownButton.left
                    rightMargin: Theme.paddingSmall
                    verticalCenter: parent.verticalCenter
                }
                enabled: index > 0 && !chatFoldersPage.isDeletePending(folderId)
                onClicked: {
                    chatFoldersPage.moveFolder(index, index - 1);
                }
            }

            Label {
                anchors {
                    left: folderIcon.right
                    leftMargin: Theme.paddingMedium
                    right: moveUpButton.left
                    rightMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                }
                text: folderName
                truncationMode: TruncationMode.Fade
            }
        }

        footer: Column {
            width: parent.width
            spacing: Theme.paddingMedium

            SectionHeader {
                text: qsTr("Create new folder")
            }

            TextField {
                id: newFolderNameField
                width: parent.width
                label: qsTr("Folder name")
                placeholderText: qsTr("Enter the folder name")
                EnterKey.enabled: chatFoldersPage.normalizedFolderTitle(text).length > 0
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: {
                    chatFoldersPage.createFolder(text, newFolderNameField);
                }
            }

            Button {
                width: parent.width - (2 * Theme.horizontalPageMargin)
                anchors.horizontalCenter: parent.horizontalCenter
                enabled: chatFoldersPage.normalizedFolderTitle(newFolderNameField.text).length > 0 && !waitingFolderCreation
                text: qsTr("Create folder")
                onClicked: {
                    chatFoldersPage.createFolder(newFolderNameField.text, newFolderNameField);
                }
            }

            Label {
                width: parent.width - (2 * Theme.horizontalPageMargin)
                anchors.horizontalCenter: parent.horizontalCenter
                visible: chatFoldersPage.createStatusText.length > 0
                text: chatFoldersPage.createStatusText
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                color: chatFoldersPage.createStatusIsError ? Theme.errorColor : Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        VerticalScrollDecorator {}
    }
}
