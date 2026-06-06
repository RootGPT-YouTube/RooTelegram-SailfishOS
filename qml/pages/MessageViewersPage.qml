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
import "../js/functions.js" as Functions

Page {
    id: viewersPage
    allowedOrientations: Orientation.All

    // chatId/messageId del messaggio di cui mostrare TUTTI i visualizzatori.
    property var chatId: 0
    property var messageId: 0

    ListModel { id: viewersModel }

    Connections {
        target: tdLibWrapper
        onMessageViewersReceived: {
            if (messageId === viewersPage.messageId) {
                viewersModel.clear();
                for (var i = 0; i < viewers.length; i++) {
                    var info = tdLibWrapper.getUserInformation(viewers[i].user_id);
                    viewersModel.append({
                        viewerName: Functions.getUserName(info),
                        viewDate: viewers[i].view_date
                    });
                }
            }
        }
    }

    Component.onCompleted: tdLibWrapper.getMessageViewers(chatId, messageId)

    SilicaListView {
        anchors.fill: parent
        model: viewersModel

        header: PageHeader {
            title: qsTr("Seen by") + " " + viewersModel.count
        }

        delegate: ListItem {
            contentHeight: Theme.itemSizeSmall

            Label {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                text: viewerName
                color: Theme.primaryColor
                truncationMode: TruncationMode.Fade
            }
        }

        ViewPlaceholder {
            enabled: viewersModel.count === 0
            text: qsTr("No views")
        }

        VerticalScrollDecorator {}
    }
}
