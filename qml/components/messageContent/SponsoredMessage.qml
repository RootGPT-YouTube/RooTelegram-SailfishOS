/*
    Copyright (C) 2021 Sebastian J. Wolf and other contributors

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
import "../"
import "../../js/functions.js" as Functions

Column {
    id: sponsoredMessageColumn

    property var sponsoredMessageData;

    Connections {
        target: tdLibWrapper
        onMessageLinkInfoReceived: {
            if (sponsoredMessageData.link.url === url) {
                messageOverlayLoader.overlayMessage = messageLinkInfo.message;
                messageOverlayLoader.active = true;
            }
        }
    }

    Component.onCompleted: {
        if (sponsoredMessageData) {
            if (typeof sponsoredMessageData.link === "undefined") {
                sponsoredMessageButton.text = qsTr("Go to Channel");
                sponsoredMessageButton.advertisesChannel = true;
            } else if (sponsoredMessageData.link['@type'] === "internalLinkTypeMessage") {
                sponsoredMessageButton.text = qsTr("Go to Message");
                sponsoredMessageButton.advertisesMessage = true;
            } else {
                sponsoredMessageButton.text = qsTr("Start Bot");
                sponsoredMessageButton.advertisesBot = true;
            }
        }
    }

    Button {
        id: sponsoredMessageButton
        property bool advertisesChannel: false;
        property bool advertisesMessage: false;
        property bool advertisesBot: false;
        anchors {
            horizontalCenter: parent.horizontalCenter
        }
        onClicked: {
            if (advertisesChannel) {
                tdLibWrapper.createSupergroupChat(tdLibWrapper.getChat(sponsoredMessageData.sponsor_chat_id).type.supergroup_id, "openDirectly");
            }
            if (advertisesMessage) {
                tdLibWrapper.getMessageLinkInfo(sponsoredMessageData.link.url);
            }
            if (advertisesBot) {
                tdLibWrapper.createPrivateChat(tdLibWrapper.getUserInformationByName(sponsoredMessageData.link.bot_username).id, "openAndSendStartToBot:" + sponsoredMessageData.link.start_parameter);
            }
        }
    }

}
