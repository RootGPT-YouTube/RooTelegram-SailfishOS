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
import "../components"
import "../components/chatInformationPage"
import "../js/twemoji.js" as Emoji
import "../js/functions.js" as Functions
import "../js/debug.js" as Debug

Page {
    id: chatInformationPage

    allowedOrientations: Orientation.All
    property string searchString

    property int chatOnlineMemberCount: 0;
    property int myUserId: tdLibWrapper.getUserInformation().id;

    property bool isPrivateChat: false
    property bool isSecretChat: false
    property bool isBasicGroup: false
    property bool isSuperGroup: false
    property bool isChannel: false
    readonly property bool canGetMembers: ("can_get_members" in groupFullInformation) && groupFullInformation.can_get_members

    property string chatPartnerGroupId

    property bool userIsMember: ((isPrivateChat || isSecretChat ) && chatInformation["@type"]) || // should be optimized
                                (isBasicGroup || isSuperGroup) && (
                                    (groupInformation.status["@type"] === "chatMemberStatusMember")
                                    || (groupInformation.status["@type"] === "chatMemberStatusAdministrator")
                                    || (groupInformation.status["@type"] === "chatMemberStatusRestricted" && groupInformation.status.is_member)
                                    || (groupInformation.status["@type"] === "chatMemberStatusCreator" && groupInformation.status.is_member)
                                    )

    property var chatInformation:({});
    property var privateChatUserInformation:({});
    property var chatPartnerFullInformation:({});
    property var chatPartnerProfilePhotos:([]);
    property var groupInformation: ({});
    property var groupFullInformation: ({});
    property bool sharedMediaRequestInFlight: false
    property string sharedMediaPendingTabKey: ""
    property var pendingStatisticsChatId: 0

//    property alias membersList: membersList

    onStatusChanged: {
        switch(status) {
        case PageStatus.Activating:
            Debug.log("activating Loader")
            mainContentLoader.active = true
            break;
        case PageStatus.Active:
            break;
        }
    }

    Loader {
        id: mainContentLoader
        active: false
        asynchronous: true
        anchors.fill: parent
        source: Qt.resolvedUrl("../components/chatInformationPage/ChatInformationPageContent.qml");
    }

}
