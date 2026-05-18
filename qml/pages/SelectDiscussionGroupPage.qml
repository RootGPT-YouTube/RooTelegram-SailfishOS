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
import "../components"
import "../js/twemoji.js" as Emoji
import "../js/functions.js" as Functions

Page {
    id: selectDiscussionGroupPage
    allowedOrientations: Orientation.All

    property var channelChat: ({})
    property var linkedChatId: 0
    property bool isLoading: true

    function refresh() {
        isLoading = true;
        suitableModel.clear();
        tdLibWrapper.getSuitableDiscussionChats();
    }

    function appendChat(chatId) {
        var chat = tdLibWrapper.getChat(String(chatId));
        if (!chat || !chat.id) {
            return;
        }
        suitableModel.append({
            "chatId": String(chat.id),
            "chatTitle": chat.title || "",
            "photo": (typeof chat.photo !== "undefined" && chat.photo !== null) ? chat.photo.small || {} : {}
        });
    }

    function selectChat(chatId) {
        var channelId = Number(channelChat.id);
        var discussionId = Number(chatId);
        if (isNaN(channelId) || isNaN(discussionId)) {
            return;
        }
        tdLibWrapper.setChatDiscussionGroup(channelId, discussionId);
        appNotification.show(qsTr("Discussion group updated"));
        pageStack.pop();
    }

    function unlinkChat() {
        var channelId = Number(channelChat.id);
        if (isNaN(channelId)) {
            return;
        }
        tdLibWrapper.setChatDiscussionGroup(channelId, 0);
        appNotification.show(qsTr("Discussion group removed"));
        pageStack.pop();
    }

    Component.onCompleted: refresh()

    Connections {
        target: tdLibWrapper
        onSuitableDiscussionChatsReceived: {
            suitableModel.clear();
            var alreadyHasLinked = false;
            for (var i = 0; i < chatIds.length; i++) {
                if (Number(chatIds[i]) === selectDiscussionGroupPage.linkedChatId) {
                    alreadyHasLinked = true;
                }
                appendChat(chatIds[i]);
            }
            if (!alreadyHasLinked && selectDiscussionGroupPage.linkedChatId !== 0) {
                appendChat(selectDiscussionGroupPage.linkedChatId);
            }
            selectDiscussionGroupPage.isLoading = false;
        }
        onErrorReceived: {
            if (extra === "getSuitableDiscussionChats") {
                selectDiscussionGroupPage.isLoading = false;
                appNotification.show(qsTr("Error: %1").arg(message));
            }
        }
    }

    ListModel {
        id: suitableModel
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        clip: true

        PullDownMenu {
            MenuItem {
                visible: selectDiscussionGroupPage.linkedChatId !== 0
                text: qsTr("Remove discussion group")
                onClicked: unlinkChat()
            }
            MenuItem {
                text: qsTr("Reload")
                onClicked: selectDiscussionGroupPage.refresh()
            }
        }

        header: Column {
            width: listView.width

            PageHeader {
                title: qsTr("Discussion")
                description: channelChat.title ? Emoji.emojify(channelChat.title, Theme.fontSizeLarge) : ""
            }

            BackgroundItem {
                visible: selectDiscussionGroupPage.linkedChatId !== 0
                width: parent.width
                height: Theme.itemSizeMedium
                onClicked: unlinkChat()

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.horizontalPageMargin
                    anchors.rightMargin: Theme.horizontalPageMargin
                    spacing: Theme.paddingMedium

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.iconSizeMedium
                        height: width
                        source: "image://theme/icon-m-clear"
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Remove discussion group")
                        color: Theme.highlightColor
                    }
                }
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("Choose a group that will host discussion of channel posts.")
            }

            Item { width: 1; height: Theme.paddingMedium }
        }

        model: suitableModel

        delegate: ListItem {
            id: groupItem
            width: ListView.view.width
            contentHeight: Theme.itemSizeMedium

            property bool isLinked: Number(chatId) === selectDiscussionGroupPage.linkedChatId

            onClicked: {
                if (isLinked) {
                    return;
                }
                selectChat(chatId);
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.horizontalPageMargin
                anchors.rightMargin: Theme.horizontalPageMargin
                spacing: Theme.paddingMedium

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.iconSizeSmall
                    height: width

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        visible: groupItem.isLinked
                        color: "#4caf50"
                    }
                    Image {
                        anchors.centerIn: parent
                        width: parent.width * 0.8
                        height: width
                        visible: groupItem.isLinked
                        source: "image://theme/icon-s-accept?white"
                    }
                }

                ProfileThumbnail {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.itemSizeSmall
                    height: width
                    photoData: photo
                    replacementStringHint: chatTitle
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Emoji.emojify(chatTitle, font.pixelSize)
                    color: groupItem.isLinked ? Theme.highlightColor : Theme.primaryColor
                    width: parent.width - Theme.iconSizeSmall - Theme.itemSizeSmall - 2 * Theme.paddingMedium
                    truncationMode: TruncationMode.Fade
                }
            }
        }

        ViewPlaceholder {
            enabled: !selectDiscussionGroupPage.isLoading && suitableModel.count === 0
            text: qsTr("No suitable groups")
            hintText: qsTr("Create a public supergroup or convert an existing one to use as discussion.")
        }

        VerticalScrollDecorator {}
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: selectDiscussionGroupPage.isLoading
        size: BusyIndicatorSize.Large
    }
}
