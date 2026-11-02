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

// Sceglie l'utente di un pulsante di un articolo fra le chat private.
Page {
    id: userPickerPage
    allowedOrientations: Orientation.All

    signal userPicked(var userId, string name)

    PageHeader {
        id: pageHeader
        title: qsTr("Choose a user")
    }

    SearchField {
        id: searchField
        anchors.top: pageHeader.bottom
        width: parent.width
        placeholderText: qsTr("Search")
        EnterKey.iconSource: "image://theme/icon-m-enter-close"
        EnterKey.onClicked: focus = false
    }

    TextFilterModel {
        id: textFilterModel
        sourceModel: chatListModel
        filterRoleName: "filter"
        filterText: searchField.text
        Component.onCompleted: {
            // come in ChatSelectionPage: il ruolo si ricerca quando il modello a monte c'e'
            filterRoleName = "";
            filterRoleName = "filter";
        }
    }

    SilicaListView {
        anchors {
            top: searchField.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        clip: true
        model: textFilterModel

        delegate: Item {
            id: pickerDelegate
            readonly property var chat: tdLibWrapper.getChat(display.id)
            readonly property bool isPrivate: !!chat.type && chat.type["@type"] === "chatTypePrivate"
            width: parent ? parent.width : 0
            visible: isPrivate
            height: isPrivate ? pickerItem.height : 0

            ChatListViewItem {
                id: pickerItem
                width: parent.width
                ownUserId: tdLibWrapper.getUserInformation().id
                onClicked: userPickerPage.userPicked(pickerDelegate.chat.type.user_id, pickerDelegate.chat.title)
            }
        }

        VerticalScrollDecorator {}
    }
}
