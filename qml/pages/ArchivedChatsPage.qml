/*
    Copyright (C) 2026 RooTelegram contributors

    This file is part of RooTelegram.

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
import "../components"
import "../js/twemoji.js" as Emoji
import "../js/functions.js" as Functions

// Lista delle CHAT ARCHIVIATE (#4 v2.4). Aperta da Impostazioni → Memoria → Chat
// archiviate. Tap = apre la chat; long-press = disarchivia. Dati da archivedChatsModel.
Page {
    id: archivedPage
    allowedOrientations: Orientation.All

    property bool firstLoadDone: false

    Component.onCompleted: {
        archivedChatsModel.reload();
        // Diamo un attimo al caricamento prima di mostrare il placeholder "vuoto".
        firstLoadTimer.start();
    }

    Timer {
        id: firstLoadTimer
        interval: 1500
        onTriggered: archivedPage.firstLoadDone = true
    }

    function previewText(chat) {
        var m = chat && chat.last_message ? chat.last_message : null;
        if (!m || !m.content) return "";
        var c = m.content;
        var t = c["@type"];
        // Media con didascalia: mostra la didascalia se presente.
        if (c.caption && c.caption.text && c.caption.text.length > 0) {
            return c.caption.text;
        }
        switch (t) {
        case "messageText":          return c.text ? c.text.text : "";
        case "messagePhoto":         return qsTr("Photo");
        case "messageVideo":         return qsTr("Video");
        case "messageAnimation":     return qsTr("GIF");
        case "messageVoiceNote":     return qsTr("Voice message");
        case "messageVideoNote":     return qsTr("Video message");
        case "messageAudio":         return qsTr("Audio");
        case "messageDocument":      return qsTr("Document");
        case "messageSticker":       return (c.sticker && c.sticker.emoji ? c.sticker.emoji + " " : "") + qsTr("Sticker");
        case "messageAnimatedEmoji": return qsTr("Sticker");
        case "messageLocation":      return qsTr("Location");
        case "messageVenue":         return qsTr("Location");
        case "messageContact":       return qsTr("Contact");
        case "messagePoll":          return qsTr("Poll");
        case "messageCall":          return qsTr("Call");
        default:                     return "";
        }
    }

    SilicaListView {
        id: archivedList
        anchors.fill: parent
        model: archivedChatsModel
        clip: true

        // NeonPageHeader: titolo in stile neon col tema Neon, header Silica nativo altrimenti.
        header: NeonPageHeader {
            text: qsTr("Archived chats")
            description: archivedChatsModel.count > 0
                         ? qsTr("%n chat(s)", "", archivedChatsModel.count) : ""
        }

        delegate: ListItem {
            id: chatItem
            width: archivedList.width
            contentHeight: Theme.itemSizeLarge

            property var chat: display
            property string chatTitle: (chat && chat.title && chat.title.length > 0)
                                       ? chat.title : qsTr("Unknown")
            property int unread: (chat && chat.unread_count) ? chat.unread_count : 0

            property bool neon: appSettings.useNeonTheme

            // Tema Silica: ContextMenu nativo. Tema Neon: menù a comparsa neon (come
            // il long-press delle chat in home) → #1 v2.4.
            menu: neon ? null : silicaMenuComponent
            onPressAndHold: {
                if (neon) {
                    archiveNeonMenu.open([
                        { text: qsTr("Unarchive"), visible: true, callback: function() {
                            tdLibWrapper.setChatArchived(model.chat_id, false);
                        }}
                    ]);
                }
            }

            Component {
                id: silicaMenuComponent
                ContextMenu {
                    MenuItem {
                        text: qsTr("Unarchive")
                        onClicked: tdLibWrapper.setChatArchived(model.chat_id, false)
                    }
                }
            }

            onClicked: {
                if (chat && chat.id) {
                    pageStack.push(Qt.resolvedUrl("ChatPage.qml"), { "chatInformation": chat });
                }
            }

            Row {
                anchors {
                    left: parent.left; right: parent.right
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.paddingMedium

                ProfileThumbnail {
                    id: avatar
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.itemSizeMedium
                    height: Theme.itemSizeMedium
                    photoData: (chatItem.chat && chatItem.chat.photo) ? chatItem.chat.photo.small : ({})
                    replacementStringHint: chatItem.chatTitle
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - avatar.width - parent.spacing
                           - (unreadBadge.visible ? unreadBadge.width + parent.spacing : 0)
                    spacing: Theme.paddingSmall / 2

                    Label {
                        width: parent.width
                        textFormat: Text.StyledText
                        truncationMode: TruncationMode.Fade
                        color: chatItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                        text: Emoji.emojify(chatItem.chatTitle, font.pixelSize)
                    }
                    Label {
                        width: parent.width
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                        truncationMode: TruncationMode.Fade
                        textFormat: Text.StyledText
                        text: Emoji.emojify(archivedPage.previewText(chatItem.chat), font.pixelSize)
                    }
                }

                Rectangle {
                    id: unreadBadge
                    anchors.verticalCenter: parent.verticalCenter
                    visible: chatItem.unread > 0
                    width: Math.max(Theme.fontSizeSmall * 1.6, unreadLabel.width + Theme.paddingSmall)
                    height: Theme.fontSizeSmall * 1.6
                    radius: height / 2
                    color: Theme.highlightColor
                    Label {
                        id: unreadLabel
                        anchors.centerIn: parent
                        text: chatItem.unread > 99 ? "99+" : chatItem.unread
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.colorScheme === Theme.LightOnDark ? "#000000" : "#ffffff"
                    }
                }
            }
        }

        VerticalScrollDecorator {}

        ViewPlaceholder {
            enabled: archivedChatsModel.count === 0 && archivedPage.firstLoadDone
            text: qsTr("No archived chats")
            hintText: qsTr("Long-press a chat in the main list and choose Archive.")
        }

        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: archivedChatsModel.count === 0 && !archivedPage.firstLoadDone
            visible: running
        }
    }

    // Menù neon a comparsa per il long-press (usato col tema Neon).
    NeonMenuOverlay {
        id: archiveNeonMenu
    }
}
