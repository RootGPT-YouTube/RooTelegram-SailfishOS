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
import "../components"
import "../js/twemoji.js" as Emoji
import "../js/functions.js" as Functions

Page {
    id: reorderPinnedChatsPage
    allowedOrientations: Orientation.All

    function loadPinnedChats() {
        pinnedModel.clear();
        if (!chatListModel || chatListModel.count === undefined || !chatListModel.get) {
            return;
        }
        for (var i = 0; i < chatListModel.count; i++) {
            var row = chatListModel.get(i);
            if (!row || !row.is_pinned) {
                continue;
            }
            var chatId = parseInt(row.chat_id);
            if (isNaN(chatId) || chatId === 0) {
                continue;
            }
            pinnedModel.append({
                "chatId": chatId,
                "chatTitle": row.title || "",
                "photoSmall": row.photo_small || ({})
            });
        }
    }

    function sendReorderRequest() {
        var chatIds = [];
        for (var i = 0; i < pinnedModel.count; i++) {
            chatIds.push(pinnedModel.get(i).chatId);
        }
        tdLibWrapper.sendRequest({
            "@type": "setPinnedChats",
            "chat_list": { "@type": "chatListMain" },
            "chat_ids": chatIds,
            "@extra": "setPinnedChats:main"
        });
    }

    function movePinned(fromIndex, toIndex) {
        if (fromIndex < 0 || toIndex < 0 || fromIndex >= pinnedModel.count || toIndex >= pinnedModel.count || fromIndex === toIndex) {
            return;
        }
        pinnedModel.move(fromIndex, toIndex, 1);
        sendReorderRequest();
    }

    Connections {
        target: tdLibWrapper
        onErrorReceived: {
            if (extra === "setPinnedChats:main") {
                appNotification.show(qsTr("Unable to update pinned chat order."));
                loadPinnedChats();
            }
        }
    }

    ListModel {
        id: pinnedModel
    }

    SilicaListView {
        id: pinnedListView
        anchors.fill: parent
        clip: true
        model: pinnedModel

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: {
                    loadPinnedChats();
                }
            }
        }

        header: PageHeader {
            title: qsTr("Reorder Pinned Chats")
        }

        ViewPlaceholder {
            enabled: pinnedListView.count === 0
            text: qsTr("No pinned chats.")
            hintText: qsTr("Pin a chat from home to reorder it here.")
        }

        delegate: ListItem {
            id: pinnedRow
            width: ListView.view.width
            contentHeight: Theme.itemSizeLarge

            ProfileThumbnail {
                id: pictureThumbnail
                photoData: photoSmall || ({})
                replacementStringHint: chatTitle
                width: Theme.itemSizeMedium
                height: Theme.itemSizeMedium
                radius: width / 2
                anchors {
                    left: parent.left
                    leftMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
            }

            IconButton {
                id: moveDownButton
                icon.source: "image://theme/icon-m-down"
                anchors {
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                enabled: index < pinnedModel.count - 1
                onClicked: {
                    reorderPinnedChatsPage.movePinned(index, index + 1);
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
                enabled: index > 0
                onClicked: {
                    reorderPinnedChatsPage.movePinned(index, index - 1);
                }
            }

            Label {
                anchors {
                    left: pictureThumbnail.right
                    leftMargin: Theme.paddingMedium
                    right: moveUpButton.left
                    rightMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                }
                text: chatTitle ? Emoji.emojify(chatTitle, Theme.fontSizeMedium) : qsTr("Unknown")
                textFormat: Text.StyledText
                truncationMode: TruncationMode.Fade
            }
        }

        VerticalScrollDecorator {}
    }

    Component.onCompleted: {
        loadPinnedChats();
    }
}
