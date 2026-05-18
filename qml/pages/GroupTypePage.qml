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
import "../js/twemoji.js" as Emoji
import "../js/functions.js" as Functions

Page {
    id: groupTypePage
    allowedOrientations: Orientation.All

    property var chatId: 0
    property string chatTitle: ""
    property string supergroupId: ""
    property string currentUsername: ""
    property bool isChannel: false
    property bool joinByRequest: false
    property bool hasProtectedContent: false

    property bool isPublic: currentUsername !== ""
    property bool saveInProgress: false
    property string pendingRequestExtra: ""
    property string usernameErrorText: ""
    property string pendingJoinByRequestExtra: ""
    property string pendingProtectedContentExtra: ""

    function normalizedUsername() {
        var username = usernameField.text.trim();
        if (username.indexOf("@") === 0) {
            username = username.substring(1);
        }
        return username;
    }

    function validateUsername(username) {
        if (!isPublic) {
            return "";
        }
        if (username.length < 5 || username.length > 32) {
            return qsTr("Username must be 5-32 characters.");
        }
        if (!/^[A-Za-z0-9_]+$/.test(username)) {
            return qsTr("Username can only use letters, numbers and underscores.");
        }
        return "";
    }

    function toggleJoinByRequest() {
        if (pendingJoinByRequestExtra !== "" || supergroupId === "") {
            return;
        }
        var desired = !joinByRequest;
        pendingJoinByRequestExtra = "toggleSupergroupJoinByRequest:" + supergroupId + ":" + (new Date().getTime());
        tdLibWrapper.sendRequest({
            "@type": "toggleSupergroupJoinByRequest",
            "supergroup_id": supergroupId,
            "join_by_request": desired,
            "@extra": pendingJoinByRequestExtra
        });
        joinByRequest = desired;
    }

    function toggleProtectedContent() {
        if (pendingProtectedContentExtra !== "" || !chatId) {
            return;
        }
        var desired = !hasProtectedContent;
        pendingProtectedContentExtra = "toggleChatHasProtectedContent:" + chatId + ":" + (new Date().getTime());
        tdLibWrapper.sendRequest({
            "@type": "toggleChatHasProtectedContent",
            "chat_id": chatId,
            "has_protected_content": desired,
            "@extra": pendingProtectedContentExtra
        });
        hasProtectedContent = desired;
    }

    function saveGroupType() {
        if (saveInProgress || supergroupId === "") {
            return;
        }
        var username = isPublic ? normalizedUsername() : "";
        var validationError = validateUsername(username);
        usernameErrorText = validationError;
        if (validationError !== "") {
            return;
        }
        pendingRequestExtra = "setSupergroupUsername:" + supergroupId + ":" + (new Date().getTime());
        saveInProgress = true;
        tdLibWrapper.sendRequest({
            "@type": "setSupergroupUsername",
            "supergroup_id": supergroupId,
            "username": username,
            "@extra": pendingRequestExtra
        });
    }

    PullDownMenu {
        MenuItem {
            text: saveInProgress ? qsTr("Saving…") : qsTr("Save")
            enabled: !saveInProgress
            onClicked: {
                saveGroupType();
            }
        }
    }

    Component.onCompleted: {
        if (chatId) {
            tdLibWrapper.sendRequest({
                "@type": "getChat",
                "chat_id": chatId
            });
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: isChannel ? qsTr("Channel Type") : qsTr("Group Type")
                description: chatTitle ? Emoji.emojify(chatTitle, font.pixelSize) : ""
            }

            TextSwitch {
                width: parent.width
                checked: isPublic
                text: isChannel ? qsTr("Public Channel") : qsTr("Public Group")
                description: qsTr("Public chats can be found via username.")
                automaticCheck: false
                onClicked: {
                    if (saveInProgress) {
                        return;
                    }
                    isPublic = !checked;
                    usernameErrorText = "";
                }
            }

            Label {
                visible: !isPublic
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                text: qsTr("Private chats can only be joined through invite links.")
            }

            TextField {
                id: usernameField
                visible: isPublic
                width: parent.width
                label: qsTr("Username")
                placeholderText: qsTr("Set public username")
                text: currentUsername
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhPreferLowercase
                enabled: !saveInProgress
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.enabled: !saveInProgress
                EnterKey.onClicked: {
                    saveGroupType();
                }
                onTextChanged: {
                    usernameErrorText = "";
                    if (text.indexOf("@") === 0) {
                        text = text.substring(1);
                    }
                }
            }

            Label {
                visible: isPublic
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: usernameErrorText !== "" ? Theme.errorColor : Theme.secondaryColor
                text: usernameErrorText !== ""
                        ? usernameErrorText
                        : qsTr("Use 5-32 letters, numbers or underscores.")
            }

            TextSwitch {
                width: parent.width
                visible: isPublic
                checked: joinByRequest
                text: qsTr("Approve new members")
                description: qsTr("New members must be approved by an administrator.")
                automaticCheck: false
                enabled: pendingJoinByRequestExtra === ""
                onClicked: toggleJoinByRequest()
            }

            TextSwitch {
                width: parent.width
                visible: isPublic
                checked: hasProtectedContent
                text: qsTr("Forbid content saving")
                description: qsTr("Prevents forwarding, copying and saving of chat contents.")
                automaticCheck: false
                enabled: pendingProtectedContentExtra === ""
                onClicked: toggleProtectedContent()
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - 2 * Theme.horizontalPageMargin, Theme.itemSizeHuge * 2)
                text: saveInProgress ? qsTr("Saving…") : qsTr("Save")
                enabled: !saveInProgress
                onClicked: {
                    saveGroupType();
                }
            }
        }
    }

    Connections {
        target: tdLibWrapper

        onChatReceived: {
            if (chat && chat.id && chatId && chat.id.toString() === chatId.toString()) {
                hasProtectedContent = !!chat.has_protected_content;
            }
        }

        onOkReceived: {
            if (request === pendingJoinByRequestExtra) {
                pendingJoinByRequestExtra = "";
                return;
            }
            if (request === pendingProtectedContentExtra) {
                pendingProtectedContentExtra = "";
                // The C++ wrapper has no handler for updateChatHasProtectedContent,
                // so cached chat state stays stale. Force a refresh: getChat triggers
                // chatReceived → the parent ChatInformationPage updates chatInformation,
                // and re-entering this page will reflect the true state.
                tdLibWrapper.sendRequest({
                    "@type": "getChat",
                    "chat_id": chatId
                });
                return;
            }
            if (request !== pendingRequestExtra) {
                return;
            }
            saveInProgress = false;
            pendingRequestExtra = "";
            currentUsername = isPublic ? normalizedUsername() : "";
            tdLibWrapper.sendRequest({
                "@type": "getSupergroup",
                "supergroup_id": supergroupId
            });
            tdLibWrapper.getGroupFullInfo(supergroupId, true);
            appNotification.show(qsTr("Options saved"));
        }

        onErrorReceived: {
            if (extra === pendingJoinByRequestExtra) {
                pendingJoinByRequestExtra = "";
                joinByRequest = !joinByRequest;
                Functions.handleErrorMessage(code, message);
                return;
            }
            if (extra === pendingProtectedContentExtra) {
                pendingProtectedContentExtra = "";
                hasProtectedContent = !hasProtectedContent;
                Functions.handleErrorMessage(code, message);
                return;
            }
            if (extra !== pendingRequestExtra) {
                return;
            }
            saveInProgress = false;
            pendingRequestExtra = "";
            Functions.handleErrorMessage(code, message);
        }
    }
}
