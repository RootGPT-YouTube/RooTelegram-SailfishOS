/*
    Copyright (C) 2020 Sebastian J. Wolf and other contributors

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
import "../js/functions.js" as Functions

CoverBackground {

    id: coverPage

    property int unreadMessages: 0
    property int unreadChats: 0
    property int privateUnreadMessages: 0
    property int privateUnreadChats: 0
    readonly property bool hideGroupChannelUnread: appSettings.coverHideGroupChannelUnread
    readonly property int displayedUnreadMessages: hideGroupChannelUnread ? privateUnreadMessages : unreadMessages
    readonly property int displayedUnreadChats: hideGroupChannelUnread ? privateUnreadChats : unreadChats
    readonly property bool authenticated: tdLibWrapper.authorizationState === TelegramAPI.AuthorizationReady
    property int connectionState: TelegramAPI.WaitingForNetwork

    function refreshPrivateUnreadCounts() {
        var counts = chatListModel.getPrivateUnreadCounts();
        privateUnreadMessages = counts.unread_messages || 0;
        privateUnreadChats = counts.unread_chats || 0;
        setUnreadInfoText();
    }

    function setUnreadInfoText() {

        unreadMessagesText.text = qsTr("unread messages", "", coverPage.displayedUnreadMessages);
        unreadChatsText.text = qsTr("chats", "", coverPage.displayedUnreadChats)

        switch (coverPage.connectionState) {
        case TelegramAPI.WaitingForNetwork:
            connectionStateText.text = qsTr("Waiting for network...");
            break;
        case TelegramAPI.Connecting:
            connectionStateText.text = qsTr("Connecting to network...");
            break;
        case TelegramAPI.ConnectingToProxy:
            connectionStateText.text = qsTr("Connecting to proxy...");
            break;
        case TelegramAPI.ConnectionReady:
            connectionStateText.text = qsTr("Connected");
            break;
        case TelegramAPI.Updating:
            connectionStateText.text = qsTr("Updating content...");
            break;
        }
    }

    Component.onCompleted: {
        coverPage.connectionState = tdLibWrapper.getConnectionState();
        coverPage.unreadMessages = tdLibWrapper.getUnreadMessageInformation().unread_count || 0;
        coverPage.unreadChats = tdLibWrapper.getUnreadChatInformation().unread_count || 0;
        refreshPrivateUnreadCounts();
    }

    Connections {
        target: tdLibWrapper
        onUnreadMessageCountUpdated: {
            coverPage.unreadMessages = messageCountInformation.unread_count;
            setUnreadInfoText();
        }
        onUnreadChatCountUpdated: {
            coverPage.unreadChats = chatCountInformation.unread_count;
            setUnreadInfoText();
        }
        onAuthorizationStateChanged: {
            setUnreadInfoText();
        }
        onConnectionStateChanged: {
            coverPage.connectionState = connectionState;
            setUnreadInfoText();
        }
    }

    Connections {
        target: chatListModel
        onUnreadStateChanged: {
            coverPage.unreadMessages = unreadMessagesCount;
            coverPage.unreadChats = unreadChatsCount;
            setUnreadInfoText();
        }
        onPrivateUnreadStateChanged: refreshPrivateUnreadCounts()
    }

    Connections {
        target: appSettings
        onCoverHideGroupChannelUnreadChanged: setUnreadInfoText()
    }

    BackgroundImage {
        id: backgroundImage
        width: parent.height - Theme.paddingLarge
        height: width
        sourceDimension: width
        anchors {
            verticalCenter: parent.verticalCenter
            centerIn: undefined
            bottom: parent.bottom
            bottomMargin: Theme.paddingMedium
            right: parent.right
            rightMargin: Theme.paddingMedium
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.paddingLarge
        spacing: Theme.paddingMedium
        visible: coverPage.authenticated
        Row {
            width: parent.width
            spacing: Theme.paddingMedium
            Text {
                id: unreadMessagesCountText
                font.pixelSize: Theme.fontSizeHuge
                color: Theme.primaryColor
                text: Functions.getShortenedCount(coverPage.displayedUnreadMessages)
            }
            Label {
                id: unreadMessagesText
                font.pixelSize: Theme.fontSizeExtraSmall
                width: parent.width - unreadMessagesCountText.width - Theme.paddingMedium
                wrapMode: Text.Wrap
                anchors.verticalCenter: unreadMessagesCountText.verticalCenter
                maximumLineCount: 2
                truncationMode: TruncationMode.Fade
            }
        }

        Row {
            width: parent.width
            spacing: Theme.paddingMedium
            visible: coverPage.authenticated && coverPage.displayedUnreadMessages > 1
            Text {
                id: inText
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.primaryColor
                text: qsTr("in")
                anchors.verticalCenter: unreadChatsCountText.verticalCenter
            }
            Text {
                id: unreadChatsCountText
                font.pixelSize: Theme.fontSizeHuge
                color: Theme.primaryColor
                text: Functions.getShortenedCount(coverPage.displayedUnreadChats)
            }
            Text {
                id: unreadChatsText
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.primaryColor
                width: parent.width - unreadChatsCountText.width - inText.width - ( 2 * Theme.paddingMedium )
                wrapMode: Text.Wrap
                anchors.verticalCenter: unreadChatsCountText.verticalCenter
            }
        }

        Text {
            id: connectionStateText
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.highlightColor
            visible: coverPage.authenticated
            width: parent.width
            maximumLineCount: 3
            wrapMode: Text.Wrap
        }
    }

}
