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
import WerkWolf.RooTelegram 1.0
import "../components"

import "../js/twemoji.js" as Emoji
import "../js/functions.js" as Functions

Dialog {
    id: chatSelectionPage
    allowedOrientations: Orientation.All
    canAccept: false
    acceptDestinationAction: PageStackAction.Replace
    acceptDestinationReplaceTarget: pageStack.find( function(page){
        // This crazy workaround is presented to you by a bug introduced with SFOS 4.0.1
        // See https://forum.sailfishos.org/t/4-0-1-45-pagestack-find-not-working-properly-anymore-in-a-dialog/4723 for details.
        chatSelectionPage.currentDepth = chatSelectionPage.currentDepth - 1;
        return(chatSelectionPage.currentDepth === 0);
    } )
    property int myUserId: tdLibWrapper.getUserInformation().id
    property alias headerTitle: pageHeader.title
    property alias headerDescription: pageHeader.description

    property var currentDepth: pageStack.depth

    /*
        payload dependent on chatSelectionPage.state
         - forwardMessages: {fromChatId, messageIds, neededPermissions}
         - shareResources: {resources, neededPermissions}
    */
    property var payload: ({})

    onAccepted: {
        switch(chatSelectionPage.state) {
        case "forwardMessages":
            acceptDestinationInstance.forwardMessages(payload.fromChatId, payload.messageIds)
            break;
        case "fillTextArea": // ReplyMarkupButtons: inlineKeyboardButtonTypeSwitchInline
            acceptDestinationInstance.setMessageText(payload.text)
            break;
        // future uses of chat selection can be processed here
        }
    }

    PageHeader {
        id: pageHeader
        title: qsTr("Select Chat")
        width: parent.width
    }

    SearchField {
        id: chatSearchField
        anchors.top: pageHeader.bottom
        width: parent.width
        placeholderText: qsTr("Search in contacts...")
        EnterKey.iconSource: "image://theme/icon-m-enter-close"
        EnterKey.onClicked: focus = false
    }

    ChatPermissionFilterModel {
        id: chatPermissionFilterModel
        tdlib: tdLibWrapper
        sourceModel: chatListModel
        requirePermissions: chatSelectionPage.payload.neededPermissions
    }

    TextFilterModel {
        id: chatTextFilterModel
        sourceModel: chatPermissionFilterModel
        filterRoleName: "filter"
        filterText: chatSearchField.text
        Component.onCompleted: {
            // Forza il re-lookup del ruolo "filter" dopo che il proxy a monte
            // ha ricevuto il suo sourceModel — altrimenti updateFilterRole()
            // viene chiamato troppo presto e cade su DisplayRole (vuoto).
            filterRoleName = "";
            filterRoleName = "filter";
        }
    }

    SilicaListView {
        id: chatListView

        anchors {
            top: chatSearchField.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }

        clip: true

        model: chatTextFilterModel

        delegate: ChatListViewItem {
            ownUserId: chatSelectionPage.myUserId
            onClicked: {
                var chat = tdLibWrapper.getChat(display.id);
                switch(chatSelectionPage.state) {
                case "forwardMessages":
                case "fillTextArea":
                    chatSelectionPage.acceptDestinationProperties = { "chatInformation" :  chat};
                    chatSelectionPage.acceptDestination = Qt.resolvedUrl("../pages/ChatPage.qml");
                    break;
                case "shareResources":
                    chatSelectionPage.acceptDestinationProperties = {
                        "chatInformation" : chat,
                        "pendingSharedResources" : payload.resources
                    };
                    chatSelectionPage.acceptDestination = Qt.resolvedUrl("../pages/ChatPage.qml");
                    break;
                }
                chatSelectionPage.canAccept = true;
                chatSelectionPage.accept();
            }
        }

        ViewPlaceholder {
            enabled: chatListView.count === 0
            text: qsTr("You don't have any chats yet.")
        }

        VerticalScrollDecorator {}
    }
}
