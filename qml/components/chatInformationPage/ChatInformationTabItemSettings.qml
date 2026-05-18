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
import QtQml.Models 2.3

import "../"
import "../../pages"
import "../../js/twemoji.js" as Emoji
import "../../js/functions.js" as Functions

ChatInformationTabItemBase {
    id: tabBase
//    title: qsTr("Settings", "Button: Chat Settings")
//    image: "image://theme/icon-m-developer-mode"
    readonly property var groupStatus: chatInformationPage.groupInformation && chatInformationPage.groupInformation.status ? chatInformationPage.groupInformation.status : ({})
    function statusFlag(flagName) {
        if (!flagName) {
            return false;
        }
        if (typeof groupStatus[flagName] === "boolean") {
            return groupStatus[flagName];
        }
        var rights = groupStatus.rights || {};
        if (typeof rights[flagName] === "boolean") {
            return rights[flagName];
        }
        var permissions = groupStatus.permissions || {};
        if (typeof permissions[flagName] === "boolean") {
            return permissions[flagName];
        }
        return false;
    }
    readonly property bool canRestrictMembers: statusFlag("can_restrict_members") || groupStatus["@type"] === "chatMemberStatusCreator"
    readonly property bool canChangeInfo: statusFlag("can_change_info") || groupStatus["@type"] === "chatMemberStatusCreator"

    SilicaFlickable {
        height: tabBase.height
        width: tabBase.width
        contentHeight: contentColumn.height
        Column {
            id: contentColumn
            width: tabBase.width

            //permissions

            // if chatInformationPage.chatInformation.permissions.can_change_info
            //  - upload/change chat photo/VIDEO (hahaha)
            //  - description change
            //  - toggleSupergroupIsAllHistoryAvailable
            // if ?????? can_promote_members ???? can_restrict_members
            // - setChatMemberStatus
            // if creator (BasicGroup)
            // - upgradeBasicGroupChatToSupergroupChat
            // if creator (supergroup/channel)
            // - canTransferOwnership?
            //   - transferChatOwnership
            Loader {
                active: (chatInformationPage.isBasicGroup || chatInformationPage.isSuperGroup) && (tabBase.canRestrictMembers || tabBase.canChangeInfo)
                asynchronous: true
                source: "./EditGroupChatPermissionsColumn.qml"
                width: parent.width
            }

            Loader {
                active: chatInformationPage.isSuperGroup && tabBase.canRestrictMembers
                asynchronous: true
                source: "./EditSuperGroupSlowModeColumn.qml"
                width: parent.width
            }

        }
    }
}
