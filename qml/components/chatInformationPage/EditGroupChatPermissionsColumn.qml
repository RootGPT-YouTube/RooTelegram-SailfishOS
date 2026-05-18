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
import "../../js/functions.js" as Functions

Column {
    id: chatPermissionsColumn
    property var groupStatus: chatInformationPage.groupInformation && chatInformationPage.groupInformation.status ? chatInformationPage.groupInformation.status : ({})
    property bool canRestrictMembers: getStatusFlag(groupStatus, "can_restrict_members") || groupStatus["@type"] === "chatMemberStatusCreator"
    property bool canChangeInfo: getStatusFlag(groupStatus, "can_change_info") || groupStatus["@type"] === "chatMemberStatusCreator"
    property var chatPermissions: chatInformationPage.chatInformation && chatInformationPage.chatInformation.permissions ? chatInformationPage.chatInformation.permissions : ({})
    property bool permissionUpdateInProgress: false
    property var pendingPermissionValues: ({})
    property var requestedPermissions: ({})
    property bool hasRequestedPermissions: false

    readonly property bool hasMemberPermissionSwitches: hasPermission("can_send_basic_messages", ["can_send_messages"])
                                                   || hasPermission("can_send_media_messages", ["can_send_audios", "can_send_documents", "can_send_photos", "can_send_videos", "can_send_video_notes", "can_send_voice_notes"])
                                                   || hasPermission("can_send_polls", [])
                                                   || hasPermission("can_send_other_messages", [])
                                                   || hasPermission("can_add_link_previews", ["can_add_web_page_previews"])
                                                   || hasPermission("can_change_info", [])
                                                   || hasPermission("can_invite_users", [])
                                                   || hasPermission("can_pin_messages", [])
                                                   || hasPermission("can_create_topics", [])

    function clonePermissions(sourcePermissions) {
        var result = {}
        for (var key in sourcePermissions) {
            result[key] = sourcePermissions[key]
        }
        return result
    }
    function getEffectivePermissions() {
        return hasRequestedPermissions ? requestedPermissions : chatPermissionsColumn.chatPermissions
    }
    function getStatusFlag(statusData, flagName) {
        var status = statusData || {}
        if (!flagName) {
            return false
        }
        if (typeof status[flagName] === "boolean") {
            return status[flagName]
        }
        var rights = status.rights || {}
        if (typeof rights[flagName] === "boolean") {
            return rights[flagName]
        }
        var permissions = status.permissions || {}
        if (typeof permissions[flagName] === "boolean") {
            return permissions[flagName]
        }
        return false
    }

    function getExistingPermissionKeys(primaryKey, aliasKeys, permissionsSource) {
        var keys = []
        var allKeys = [primaryKey]
        var aliases = aliasKeys || []
        for (var i = 0; i < aliases.length; i += 1) {
            allKeys.push(aliases[i])
        }
        var permissions = permissionsSource || getEffectivePermissions()
        for (var j = 0; j < allKeys.length; j += 1) {
            var key = allKeys[j]
            if (key && (key in permissions)) {
                keys.push(key)
            }
        }
        return keys
    }

    function areKeysEnabled(keys, permissionsSource) {
        var permissions = permissionsSource || getEffectivePermissions()
        for (var i = 0; i < keys.length; i += 1) {
            if (permissions[keys[i]] === true) {
                return true
            }
        }
        return false
    }

    function hasPermission(primaryKey, aliasKeys) {
        return getExistingPermissionKeys(primaryKey, aliasKeys).length > 0
    }

    function isPermissionEnabled(primaryKey, aliasKeys) {
        var keys = getExistingPermissionKeys(primaryKey, aliasKeys)
        return keys.length > 0 && areKeysEnabled(keys)
    }

    function normalizePermissions(permissions) {
        var basicMessageKey = ("can_send_basic_messages" in permissions) ? "can_send_basic_messages" : ("can_send_messages" in permissions ? "can_send_messages" : "")
        var linkPreviewKey = ("can_add_link_previews" in permissions) ? "can_add_link_previews" : ("can_add_web_page_previews" in permissions ? "can_add_web_page_previews" : "")

        var modernMediaKeys = []
        var candidateMediaKeys = ["can_send_audios", "can_send_documents", "can_send_photos", "can_send_videos", "can_send_video_notes", "can_send_voice_notes"]
        for (var i = 0; i < candidateMediaKeys.length; i += 1) {
            if (candidateMediaKeys[i] in permissions) {
                modernMediaKeys.push(candidateMediaKeys[i])
            }
        }

        var dependentKeys = []
        for (var j = 0; j < modernMediaKeys.length; j += 1) {
            dependentKeys.push(modernMediaKeys[j])
        }
        if ("can_send_media_messages" in permissions) {
            dependentKeys.push("can_send_media_messages")
        }
        if ("can_send_polls" in permissions) {
            dependentKeys.push("can_send_polls")
        }
        if ("can_send_other_messages" in permissions) {
            dependentKeys.push("can_send_other_messages")
        }
        if (linkPreviewKey !== "") {
            dependentKeys.push(linkPreviewKey)
        }

        if (basicMessageKey !== "" && permissions[basicMessageKey] === false) {
            for (var k = 0; k < dependentKeys.length; k += 1) {
                permissions[dependentKeys[k]] = false
            }
        }

        if ("can_send_media_messages" in permissions && modernMediaKeys.length > 0) {
            permissions.can_send_media_messages = areKeysEnabled(modernMediaKeys, permissions)
        }

        if (basicMessageKey !== "" && areKeysEnabled(dependentKeys, permissions)) {
            permissions[basicMessageKey] = true
        }
    }
    function clearPendingPermissionState() {
        pendingPermissionValues = ({})
    }
    function verifyPendingPermissionState(currentPermissions) {
        var pendingKeys = Object.keys(pendingPermissionValues)
        if (pendingKeys.length === 0) {
            return
        }
        var checkedCount = 0
        var accepted = true
        for (var i = 0; i < pendingKeys.length; i += 1) {
            var permissionKey = pendingKeys[i]
            if (typeof currentPermissions[permissionKey] !== "boolean") {
                continue
            }
            checkedCount += 1
            if (currentPermissions[permissionKey] !== pendingPermissionValues[permissionKey]) {
                accepted = false
                break
            }
        }
        if (checkedCount === 0) {
            return
        }
        appNotification.show(accepted ? qsTr("Group permissions updated.") : qsTr("Some permission changes were rejected by Telegram."))
        clearPendingPermissionState()
    }

    function setChatPermissions(textSwitchItem) {
        if (chatInformationPage.isChannel) {
            return
        }
        var permissionName = textSwitchItem.permissionName
        var permissionAliases = textSwitchItem.permissionAliases || []
        var newPermissions = clonePermissions(getEffectivePermissions())
        var targetKeys = getExistingPermissionKeys(permissionName, permissionAliases, newPermissions)
        if (targetKeys.length === 0) {
            return
        }
        var newValue = !areKeysEnabled(targetKeys, newPermissions)
        for (var i = 0; i < targetKeys.length; i += 1) {
            newPermissions[targetKeys[i]] = newValue
        }
        normalizePermissions(newPermissions)
        var nextPendingValues = clonePermissions(pendingPermissionValues)
        for (var j = 0; j < targetKeys.length; j += 1) {
            nextPendingValues[targetKeys[j]] = newValue
        }
        pendingPermissionValues = nextPendingValues
        requestedPermissions = clonePermissions(newPermissions)
        hasRequestedPermissions = true
        permissionUpdateInProgress = true
        tdLibWrapper.sendRequest({
            "@type": "setChatPermissions",
            "chat_id": chatInformationPage.chatInformation.id,
            "permissions": newPermissions,
            "@extra": "setChatPermissions:" + chatInformationPage.chatInformation.id
        })
    }

    Column {
        visible: !chatInformationPage.isChannel && chatPermissionsColumn.canRestrictMembers && chatPermissionsColumn.hasMemberPermissionSwitches
        width: parent.width

        SectionHeader {
            text: qsTr("Group Member Permissions", "what can normal group members do")
        }

        TextSwitch {
            visible: chatPermissionsColumn.hasPermission(permissionName, permissionAliases)
            automaticCheck: false
            property string permissionName: "can_send_basic_messages"
            property var permissionAliases: ["can_send_messages"]
            text: qsTr("Send Messages", "member permission")
            checked: chatPermissionsColumn.isPermissionEnabled(permissionName, permissionAliases)
            onCheckedChanged: { busy = false }
            onClicked: {
                chatPermissionsColumn.setChatPermissions(this)
            }
        }

        TextSwitch {
            visible: chatPermissionsColumn.hasPermission(permissionName, permissionAliases)
            automaticCheck: false
            property string permissionName: "can_send_media_messages"
            property var permissionAliases: ["can_send_audios", "can_send_documents", "can_send_photos", "can_send_videos", "can_send_video_notes", "can_send_voice_notes"]
            text: qsTr("Send Media Messages", "member permission")
            checked: chatPermissionsColumn.isPermissionEnabled(permissionName, permissionAliases)
            onCheckedChanged: { busy = false }
            onClicked: {
                chatPermissionsColumn.setChatPermissions(this)
            }
        }

        TextSwitch {
            visible: chatPermissionsColumn.hasPermission(permissionName, permissionAliases)
            automaticCheck: false
            property string permissionName: "can_send_polls"
            property var permissionAliases: []
            text: qsTr("Send Polls", "member permission")
            checked: chatPermissionsColumn.isPermissionEnabled(permissionName, permissionAliases)
            onCheckedChanged: { busy = false }
            onClicked: {
                chatPermissionsColumn.setChatPermissions(this)
            }
        }

        TextSwitch {
            visible: chatPermissionsColumn.hasPermission(permissionName, permissionAliases)
            automaticCheck: false
            property string permissionName: "can_send_other_messages"
            property var permissionAliases: []
            text: qsTr("Send Other Messages", "member permission")
            checked: chatPermissionsColumn.isPermissionEnabled(permissionName, permissionAliases)
            onCheckedChanged: { busy = false }
            onClicked: {
                chatPermissionsColumn.setChatPermissions(this)
            }
        }

        TextSwitch {
            visible: chatPermissionsColumn.hasPermission(permissionName, permissionAliases)
            automaticCheck: false
            property string permissionName: "can_add_link_previews"
            property var permissionAliases: ["can_add_web_page_previews"]
            text: qsTr("Add Web Page Previews", "member permission")
            checked: chatPermissionsColumn.isPermissionEnabled(permissionName, permissionAliases)
            onCheckedChanged: { busy = false }
            onClicked: {
                chatPermissionsColumn.setChatPermissions(this)
            }
        }

        TextSwitch {
            visible: chatPermissionsColumn.hasPermission(permissionName, permissionAliases)
            automaticCheck: false
            property string permissionName: "can_change_info"
            property var permissionAliases: []
            text: qsTr("Change Chat Info", "member permission")
            checked: chatPermissionsColumn.isPermissionEnabled(permissionName, permissionAliases)
            onCheckedChanged: { busy = false }
            onClicked: {
                chatPermissionsColumn.setChatPermissions(this)
            }
        }

        TextSwitch {
            visible: chatPermissionsColumn.hasPermission(permissionName, permissionAliases)
            automaticCheck: false
            property string permissionName: "can_invite_users"
            property var permissionAliases: []
            text: qsTr("Invite Users", "member permission")
            checked: chatPermissionsColumn.isPermissionEnabled(permissionName, permissionAliases)
            onCheckedChanged: { busy = false }
            onClicked: {
                chatPermissionsColumn.setChatPermissions(this)
            }
        }

        TextSwitch {
            visible: chatPermissionsColumn.hasPermission(permissionName, permissionAliases)
            automaticCheck: false
            property string permissionName: "can_pin_messages"
            property var permissionAliases: []
            text: qsTr("Pin Messages", "member permission")
            checked: chatPermissionsColumn.isPermissionEnabled(permissionName, permissionAliases)
            onCheckedChanged: { busy = false }
            onClicked: {
                chatPermissionsColumn.setChatPermissions(this)
            }
        }

        TextSwitch {
            visible: chatPermissionsColumn.hasPermission(permissionName, permissionAliases)
            automaticCheck: false
            property string permissionName: "can_create_topics"
            property var permissionAliases: []
            text: qsTr("Create Topics", "member permission")
            checked: chatPermissionsColumn.isPermissionEnabled(permissionName, permissionAliases)
            onCheckedChanged: { busy = false }
            onClicked: {
                chatPermissionsColumn.setChatPermissions(this)
            }
        }
    }

    SectionHeader {
        visible: historyAvailableSwitch.visible
        text: qsTr("New Members", "what can new group members do")
    }

    TextSwitch {
        id: historyAvailableSwitch
        visible: chatInformationPage.isSuperGroup && chatPermissionsColumn.canChangeInfo
        automaticCheck: false
        text: qsTr("New members can see older messages", "member permission")
        onCheckedChanged: { busy = false }
        checked: !!(chatInformationPage.groupFullInformation && chatInformationPage.groupFullInformation.is_all_history_available)
        onClicked: {
            if (chatInformationPage.groupInformation && chatInformationPage.groupInformation.is_forum && checked) {
                appNotification.show(qsTr("Message history can't be hidden while topics are enabled."))
                return
            }
            tdLibWrapper.sendRequest({
                "@type": "toggleSupergroupIsAllHistoryAvailable",
                "supergroup_id": chatInformationPage.chatPartnerGroupId,
                "is_all_history_available": !checked,
                "@extra": "toggleSupergroupIsAllHistoryAvailable:" + chatInformationPage.chatInformation.id + ":" + (!checked ? "1" : "0")
            })
        }
    }

    Connections {
        target: tdLibWrapper

        onChatPermissionsUpdated: {
            if (chatId.toString() === chatInformationPage.chatInformation.id.toString()) {
                permissionUpdateInProgress = false
                hasRequestedPermissions = false
                requestedPermissions = ({})
                verifyPendingPermissionState(permissions || ({}))
            }
        }

        onChatReceived: {
            if (!chat || chat.id.toString() !== chatInformationPage.chatInformation.id.toString()) {
                return
            }
            hasRequestedPermissions = false
            requestedPermissions = ({})
            verifyPendingPermissionState(chat.permissions || ({}))
        }

        onOkReceived: {
            if (request && request.indexOf("setChatPermissions:" + chatInformationPage.chatInformation.id) === 0) {
                tdLibWrapper.sendRequest({
                    "@type": "getChat",
                    "chat_id": chatInformationPage.chatInformation.id
                })
            }
        }

        onErrorReceived: {
            if (extra && extra.indexOf("setChatPermissions:" + chatInformationPage.chatInformation.id) === 0) {
                permissionUpdateInProgress = false
                hasRequestedPermissions = false
                requestedPermissions = ({})
                clearPendingPermissionState()
                Functions.handleErrorMessage(code, message)
            }
        }
    }
}