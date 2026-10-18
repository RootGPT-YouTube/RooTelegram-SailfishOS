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
import QtMultimedia 5.6
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

    // Brano o vocale nel player unico: la cover diventa quella di un lettore
    // (titolo, artista, copertina e comandi), come in RooTheater.
    readonly property var player: appWindow.sharedAudio
    readonly property bool audioMode: player.ownerKey !== "" && player.playbackState !== Audio.StoppedState
    readonly property bool audioPlaying: audioMode && player.playbackState === Audio.PlayingState
    readonly property var audioContent: (audioMode && player.message && player.message.content)
                                        ? player.message.content.audio : null

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
        visible: !coverPage.audioMode
        width: (parent.height - Theme.paddingLarge) / 2
        height: width
        sourceDimension: width
        anchors {
            centerIn: undefined
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: Theme.paddingLarge
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.paddingLarge
        spacing: Theme.paddingMedium
        visible: coverPage.authenticated && !coverPage.audioMode
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

    Column {
        id: audioHeader
        visible: coverPage.audioMode
        anchors {
            top: parent.top
            topMargin: Theme.paddingLarge
            left: parent.left
            right: parent.right
            leftMargin: Theme.paddingMedium
            rightMargin: Theme.paddingMedium
        }
        spacing: Theme.paddingSmall
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: coverPage.audioContent
                  ? (coverPage.audioContent.title || coverPage.audioContent.file_name || "")
                  : (coverPage.audioMode ? coverPage.player.title : "")
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.highlightColor
            wrapMode: Text.Wrap
            maximumLineCount: 2
            truncationMode: TruncationMode.Fade
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: text !== ""
            text: coverPage.audioContent ? (coverPage.audioContent.performer || "") : ""
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
            maximumLineCount: 1
            truncationMode: TruncationMode.Fade
        }
    }

    // Copertina dell'album se il brano ne ha una, altrimenti il logo.
    Item {
        visible: coverPage.audioMode
        clip: true
        anchors {
            top: audioHeader.bottom
            topMargin: Theme.paddingMedium
            left: parent.left
            right: parent.right
            bottom: audioProgress.top
        }
        Image {
            readonly property bool hasArt: coverPage.player.coverArt !== ""
            anchors.centerIn: parent
            width: hasArt ? parent.width : Math.min(parent.width, parent.height) * 0.8
            height: hasArt ? parent.height : width
            source: hasArt ? coverPage.player.coverArt : "../../images/background-" + ( Theme.colorScheme ? "black" : "white" ) + ".svg"
            sourceSize.width: width
            sourceSize.height: height
            fillMode: hasArt ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            opacity: hasArt ? 1.0 : 0.15
            asynchronous: true
            smooth: true
        }
    }

    Rectangle {
        id: audioProgress
        visible: coverPage.audioMode
        anchors {
            left: parent.left
            bottom: parent.bottom
        }
        height: Math.max(2, Theme.paddingSmall / 2)
        width: (coverPage.audioMode && coverPage.player.duration > 0)
               ? parent.width * Math.min(1, coverPage.player.position / coverPage.player.duration) : 0
        color: Theme.highlightColor
    }

    // Play/pausa + successivo (stessa chat, stesso tipo: brani o vocali).
    CoverActionList {
        enabled: coverPage.audioMode
        CoverAction {
            iconSource: coverPage.audioPlaying ? "image://theme/icon-cover-pause" : "image://theme/icon-cover-play"
            onTriggered: coverPage.audioPlaying ? coverPage.player.pause() : coverPage.player.play()
        }
        CoverAction {
            iconSource: "image://theme/icon-cover-next-song"
            onTriggered: appWindow.audioPlaylist.step(1, false)
        }
    }

}
