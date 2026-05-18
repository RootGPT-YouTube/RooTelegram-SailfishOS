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
    loadingText:  (isPrivateChat || isSecretChat) ? qsTr("Loading common chats…", "chats you have in common with a user") : qsTr("Loading group members…")
    loading: ( chatInformationPage.isSuperGroup || chatInformationPage.isPrivateChat || chatInformationPage.isSecretChat) && !chatInformationPage.isChannel
    loadingVisible: loading && membersView.count === 0

    property var chatPartnerCommonGroupsIds: ([]);
    property var processingByUserId: ({})
    property var pendingStatusByUserId: ({})
    readonly property var ownGroupStatus: chatInformationPage.groupInformation && chatInformationPage.groupInformation.status ? chatInformationPage.groupInformation.status : ({})
    readonly property bool canRestrictMembers: ownGroupStatus["@type"] === "chatMemberStatusCreator" || getStatusFlag(ownGroupStatus, "can_restrict_members")
    readonly property bool canPromoteMembers: ownGroupStatus["@type"] === "chatMemberStatusCreator" || getStatusFlag(ownGroupStatus, "can_promote_members")
    readonly property bool isCreator: ownGroupStatus["@type"] === "chatMemberStatusCreator"

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

    function getMemberUserId(memberData) {
        if (!memberData || !memberData.member_id) {
            return 0
        }
        return Number(memberData.member_id.user_id || 0)
    }

    function setProcessing(userId, processing) {
        var key = userId.toString()
        var state = {}
        for (var entry in processingByUserId) {
            state[entry] = processingByUserId[entry]
        }
        if (processing) {
            state[key] = true
        } else {
            delete state[key]
        }
        processingByUserId = state
    }

    function isProcessing(userId) {
        return !!processingByUserId[userId.toString()]
    }

    function findMemberIndexByUserId(userId) {
        for (var i = 0; i < pageContent.membersList.count; i++) {
            var member = pageContent.membersList.get(i)
            if (member && member.member_id && Number(member.member_id.user_id || 0) === Number(userId)) {
                return i
            }
        }
        return -1
    }

    function getMemberEntryByUserId(userId) {
        var index = findMemberIndexByUserId(userId)
        return index > -1 ? pageContent.membersList.get(index) : null
    }

    function canManageTarget(memberData) {
        if (!chatInformationPage.isSuperGroup || chatInformationPage.isChannel) {
            return false
        }
        var targetUserId = getMemberUserId(memberData)
        if (!targetUserId || targetUserId === chatInformationPage.myUserId) {
            return false
        }
        var targetStatus = memberData && memberData.status ? memberData.status : {}
        var targetStatusType = targetStatus["@type"] || ""
        if (targetStatusType === "chatMemberStatusCreator") {
            return false
        }
        if (targetStatusType === "chatMemberStatusAdministrator" && !getStatusFlag(targetStatus, "can_be_edited") && ownGroupStatus["@type"] !== "chatMemberStatusCreator") {
            return false
        }
        return true
    }

    function canPromoteTarget(memberData) {
        if (!canPromoteMembers || !canManageTarget(memberData)) {
            return false
        }
        var targetStatusType = memberData && memberData.status ? (memberData.status["@type"] || "") : ""
        return targetStatusType !== "chatMemberStatusCreator"
                && targetStatusType !== "chatMemberStatusAdministrator"
                && targetStatusType !== "chatMemberStatusBanned"
    }

    function canRemoveTarget(memberData) {
        if (!canRestrictMembers || !canManageTarget(memberData)) {
            return false
        }
        var targetStatusType = memberData && memberData.status ? (memberData.status["@type"] || "") : ""
        return targetStatusType !== "chatMemberStatusBanned" && targetStatusType !== "chatMemberStatusLeft"
    }

    function canDemoteTarget(memberData) {
        // Solo il Creator può rimuovere lo status di Admin
        if (!isCreator) {
            return false
        }
        if (!chatInformationPage.isSuperGroup || chatInformationPage.isChannel) {
            return false
        }
        var targetUserId = getMemberUserId(memberData)
        if (!targetUserId || targetUserId === chatInformationPage.myUserId) {
            return false
        }
        var targetStatusType = memberData && memberData.status ? (memberData.status["@type"] || "") : ""
        return targetStatusType === "chatMemberStatusAdministrator"
    }

    function buildAdministratorRights() {
        return {
            "@type": "chatAdministratorRights",
            "can_manage_chat": true,
            "can_change_info": false,
            "can_post_messages": false,
            "can_edit_messages": false,
            "can_delete_messages": false,
            "can_invite_users": true,
            "can_restrict_members": false,
            "can_pin_messages": true,
            "can_manage_topics": true,
            "can_promote_members": false,
            "can_manage_video_chats": true,
            "can_post_stories": false,
            "can_edit_stories": false,
            "can_delete_stories": false,
            "is_anonymous": false
        }
    }

    function buildAdministratorStatus() {
        var rights = buildAdministratorRights()
        return {
            "@type": "chatMemberStatusAdministrator",
            "custom_title": "",
            "can_be_edited": true,
            "rights": rights,
            "can_manage_chat": rights.can_manage_chat,
            "can_change_info": rights.can_change_info,
            "can_post_messages": rights.can_post_messages,
            "can_edit_messages": rights.can_edit_messages,
            "can_delete_messages": rights.can_delete_messages,
            "can_invite_users": rights.can_invite_users,
            "can_restrict_members": rights.can_restrict_members,
            "can_pin_messages": rights.can_pin_messages,
            "can_manage_topics": rights.can_manage_topics,
            "can_promote_members": rights.can_promote_members,
            "can_manage_video_chats": rights.can_manage_video_chats,
            "is_anonymous": rights.is_anonymous
        }
    }

    function refreshGroupInformation() {
        if (!chatInformationPage.isSuperGroup || !chatInformationPage.chatPartnerGroupId) {
            return
        }
        tdLibWrapper.sendRequest({
            "@type": "getSupergroup",
            "supergroup_id": chatInformationPage.chatPartnerGroupId
        })
        tdLibWrapper.getGroupFullInfo(chatInformationPage.chatPartnerGroupId, true)
    }

    function promoteMemberToAdmin(userId) {
        var memberEntry = getMemberEntryByUserId(userId)
        if (!canPromoteTarget(memberEntry) || isProcessing(userId)) {
            return
        }
        var userInfo = memberEntry && memberEntry.user ? memberEntry.user : tdLibWrapper.getUserInformation(userId)
        var displayName = Functions.getUserName(userInfo || {})
        var dialog = pageStack.push(Qt.resolvedUrl("../../pages/PromoteAdminDialog.qml"), {
            "userName": displayName,
            "isChannelChat": chatInformationPage.isChannel,
            "initialRights": buildAdministratorRights(),
            "initialCustomTitle": ""
        })
        dialog.accepted.connect(function() {
            if (!dialog.resultStatus) {
                return
            }
            setProcessing(userId, true)
            var nextPending = ({})
            for (var key in pendingStatusByUserId) {
                nextPending[key] = pendingStatusByUserId[key]
            }
            nextPending[userId.toString()] = dialog.resultStatus
            pendingStatusByUserId = nextPending
            tdLibWrapper.sendRequest({
                "@type": "setChatMemberStatus",
                "chat_id": chatInformationPage.chatInformation.id,
                "member_id": {
                    "@type": "messageSenderUser",
                    "user_id": userId
                },
                "status": dialog.resultStatus,
                "@extra": "chatMemberAction:promote:" + chatInformationPage.chatInformation.id + ":" + userId
            })
        })
    }

    function demoteAdminToMember(userId) {
        var memberEntry = getMemberEntryByUserId(userId)
        if (!canDemoteTarget(memberEntry) || isProcessing(userId)) {
            return
        }
        setProcessing(userId, true)
        tdLibWrapper.sendRequest({
            "@type": "setChatMemberStatus",
            "chat_id": chatInformationPage.chatInformation.id,
            "member_id": {
                "@type": "messageSenderUser",
                "user_id": userId
            },
            "status": {
                "@type": "chatMemberStatusMember"
            },
            "@extra": "chatMemberAction:demote:" + chatInformationPage.chatInformation.id + ":" + userId
        })
    }

    function removeMemberFromGroup(userId) {
        var memberEntry = getMemberEntryByUserId(userId)
        if (!canRemoveTarget(memberEntry) || isProcessing(userId)) {
            return
        }
        setProcessing(userId, true)
        tdLibWrapper.sendRequest({
            "@type": "setChatMemberStatus",
            "chat_id": chatInformationPage.chatInformation.id,
            "member_id": {
                "@type": "messageSenderUser",
                "user_id": userId
            },
            "status": {
                "@type": "chatMemberStatusBanned",
                "banned_until_date": 0
            },
            "@extra": "chatMemberAction:remove:" + chatInformationPage.chatInformation.id + ":" + userId
        })
    }

    SilicaListView {
        id: membersView
        model: (chatInformationPage.isPrivateChat || chatInformationPage.isSecretChat) ? (chatPartnerCommonGroupsIds.length > 0 ? delegateModel : null) : pageContent.membersList
        clip: true
        height: tabBase.height
        width: tabBase.width
        opacity: tabBase.loading ? (count > 0 ? 0.5 : 0.0) : 1.0
        Behavior on opacity { FadeAnimation {} }
        function handleScrollIntoView(force){
            if(!tabBase.loading && !dragging && !quickScrollAnimating ) {
                if(!atYBeginning) {
                    pageContent.scrollDown()
                } else {
                    pageContent.scrollUp(force);
                }
            }
        }
        onDraggingChanged: {
            handleScrollIntoView()
        }
        onAtYBeginningChanged: {
            handleScrollIntoView()
        }
        onAtYEndChanged: {
            if(tabBase.active && !tabBase.loading && chatInformationPage.isSuperGroup && !chatInformationPage.isChannel && (chatInformationPage.groupInformation.member_count > membersView.count) && membersView.atYEnd) {
                tabBase.loading = true;
                fetchMoreMembersTimer.start()
            }
        }
        onQuickScrollAnimatingChanged: {
            handleScrollIntoView(true)
        }
        ViewPlaceholder {
            y: Theme.paddingLarge
            enabled: membersView.count === 0
            text: (chatInformationPage.isPrivateChat || chatInformationPage.isSecretChat) ? qsTr("You don't have any groups in common with this user.") : ( chatInformationPage.isChannel ? qsTr("Channel members are anonymous.") : qsTr("This group is empty.") )
        }
        delegate: PhotoTextsListItem {
            id: memberDelegate
            pictureThumbnail {
                photoData: user.profile_photo ? user.profile_photo.small : null
            }
            width: parent.width
            property int memberUserId: Number(member_id && member_id.user_id ? member_id.user_id : 0)
            property var memberEntry: ({ "member_id": member_id, "status": status })
            property bool actionInProgress: tabBase.isProcessing(memberUserId)
            property bool canPromoteCurrent: tabBase.canPromoteTarget(memberEntry)
            property bool canRemoveCurrent: tabBase.canRemoveTarget(memberEntry)
            property bool canDemoteCurrent: tabBase.canDemoteTarget(memberEntry)
            openMenuOnPressAndHold: chatInformationPage.isSuperGroup && !chatInformationPage.isChannel && (canPromoteCurrent || canRemoveCurrent || canDemoteCurrent)
            menu: ContextMenu {
                MenuItem {
                    visible: memberDelegate.canPromoteCurrent
                    text: memberDelegate.actionInProgress ? qsTr("Processing…") : qsTr("Promote to Admin")
                    enabled: !memberDelegate.actionInProgress
                    onClicked: {
                        tabBase.promoteMemberToAdmin(memberDelegate.memberUserId)
                    }
                }
                MenuItem {
                    visible: memberDelegate.canDemoteCurrent
                    text: memberDelegate.actionInProgress ? qsTr("Processing…") : qsTr("Remove Admin")
                    enabled: !memberDelegate.actionInProgress
                    onClicked: {
                        Remorse.itemAction(memberDelegate, qsTr("Removing Admin"), function() {
                            tabBase.demoteAdminToMember(memberDelegate.memberUserId)
                        })
                    }
                }
                MenuItem {
                    visible: memberDelegate.canRemoveCurrent
                    text: memberDelegate.actionInProgress ? qsTr("Processing…") : qsTr("Remove from group")
                    enabled: !memberDelegate.actionInProgress
                    onClicked: {
                        Remorse.itemAction(memberDelegate, qsTr("Removing user"), function() {
                            tabBase.removeMemberFromGroup(memberDelegate.memberUserId)
                        })
                    }
                }
            }

            // chat title
            primaryText.text: Emoji.emojify(Functions.getUserName(user), primaryText.font.pixelSize)
            // last user
            prologSecondaryText.text: "@"+(user.username ? user.username : member_id.user_id) + (member_id.user_id === chatInformationPage.myUserId ? " " + qsTr("You") : "")
            secondaryText {
                horizontalAlignment: Text.AlignRight
                property string statusText: Functions.getChatMemberStatusText(model.status ? model.status["@type"] : "")
                property string customText: (model.status && model.status.custom_title) ? Emoji.emojify(model.status.custom_title, secondaryText.font.pixelSize) : ""
                text: (statusText !== "" && customText !== "") ? statusText + ", " + customText : statusText + customText
            }
            tertiaryText {
                maximumLineCount: 1
                text: user.type["@type"] === "userTypeBot" ? (Emoji.emojify("🤖 "+bot_info.description, tertiaryText.font.pixelSize)) : Functions.getChatPartnerStatusText(user.status["@type"], user.status.was_online);
            }

            onClicked: {
                tdLibWrapper.createPrivateChat(member_id.user_id, "openDirectly");
            }
        }
        footer: Component {
            Item {
                property bool active: tabBase.active && chatInformationPage.isSuperGroup && (chatInformationPage.groupInformation.member_count > membersView.count)
                width: tabBase.width
                height: active ? Theme.itemSizeLarge : Theme.paddingMedium

                BusyIndicator {
                    id: loadMoreIndicator
                    anchors.centerIn: parent
                    size: BusyIndicatorSize.Small
                    running: tabBase.loading
                }
            }
        }

        VerticalScrollDecorator {}
    }


    DelegateModel {
        id: delegateModel
        model: chatListModel
        groups: [
            DelegateModelGroup {
                name: "filterGroup"; includeByDefault: false
            }
        ]
        filterOnGroup: "filterGroup"
        function hasMatch(searchInArray) {
            for (var i = 0; i < searchInArray.length; i++) {
                if(searchInArray[i].toLowerCase().indexOf(chatInformationPage.searchString) > -1) {
                    return true;
                }
            }
            return false;
        }

        function applyFilter(){
            var numberOfEntries = chatListModel.rowCount();
            var hasFilterString = !!chatInformationPage.searchString && chatInformationPage.searchString !== ""
            for (var i = 0; i < numberOfEntries; i++){
                var metadata = chatListModel.get(i);
                if(tabBase.chatPartnerCommonGroupsIds.indexOf(metadata.chat_id) > -1) {
                    items.addGroups(i, 1, "filterGroup");
                } else {
                    items.removeGroups(i, 1, "filterGroup");
                }

            }
        }

        delegate: ChatListViewItem {
            ownUserId: chatInformationPage.myUserId

            unreadCount: unread_count
            onClicked: {
                pageStack.pop(pageStack.find( function(page){ return(page._depth === 0)} ), PageStackAction.Immediate);
                pageStack.push(Qt.resolvedUrl("../../pages/ChatPage.qml"), { "chatInformation" : display });
            }
        }
    }

    Timer {
        id: fetchMoreMembersTimer
        interval: 600
        property int fetchLimit: 50
        onTriggered: {
            if(chatInformationPage.isSuperGroup && (!chatInformationPage.isChannel || chatInformationPage.canGetMembers) && (chatInformationPage.groupInformation.member_count > membersView.count)) {
                tabBase.loading = true
                tdLibWrapper.getSupergroupMembers(chatInformationPage.chatPartnerGroupId, fetchLimit, pageContent.membersList.count);
                fetchLimit = 200
                interval = 400
            }
        }
    }

    Connections {
        target: tdLibWrapper

        onChatMembersReceived: {
            if (chatInformationPage.isSuperGroup && chatInformationPage.chatPartnerGroupId === extra) {
                if(members && members.length > 0 && chatInformationPage.groupInformation.member_count > membersView.count) {
                    for(var memberIndex in members) {
                        var memberData = members[memberIndex];
                        var userInfo = tdLibWrapper.getUserInformation(memberData.member_id.user_id) || {user:{}, bot_info:{}};
                        if (!userInfo.username && userInfo.usernames && userInfo.usernames.active_usernames) {
                            userInfo.username = userInfo.usernames.active_usernames[0]
                        }
                        memberData.user = userInfo;
                        memberData.bot_info = memberData.bot_info || {};
                        pageContent.membersList.append(memberData);
                    }
                    chatInformationPage.groupInformation.member_count = totalMembers
                    updateGroupStatusText();
//                    if(pageContent.membersList.count < totalMembers) {
//                        fetchMoreMembersTimer.start()
//                    }
                }
                // if we set it directly, the views start scrolling
                loadedTimer.start();
            }
        }
        onChatsReceived: {// common chats with user
            if((isPrivateChat || isSecretChat) && chats["@extra"] === chatInformationPage.chatPartnerGroupId) {
                tabBase.chatPartnerCommonGroupsIds = chats.chat_ids;
                delegateModel.applyFilter();
                // if we set it directly, the views start scrolling
                loadedTimer.start();
            }
        }
        onOkReceived: {
            if (!request || request.indexOf("chatMemberAction:") !== 0) {
                return
            }
            var parts = request.split(":")
            if (parts.length !== 4 || parts[2].toString() !== chatInformationPage.chatInformation.id.toString()) {
                return
            }
            var action = parts[1]
            var userId = Number(parts[3] || 0)
            if (!userId) {
                return
            }
            setProcessing(userId, false)
            var memberIndex = findMemberIndexByUserId(userId)
            if (action === "remove") {
                if (memberIndex > -1) {
                    pageContent.membersList.remove(memberIndex)
                }
                var currentMemberCount = Number(chatInformationPage.groupInformation.member_count || 0)
                if (!isNaN(currentMemberCount) && currentMemberCount > 0) {
                    chatInformationPage.groupInformation.member_count = currentMemberCount - 1
                    updateGroupStatusText()
                }
                appNotification.show(qsTr("Member removed from group."))
                refreshGroupInformation()
                return
            }
            if (action === "promote") {
                var pendingKey = userId.toString()
                var appliedStatus = pendingStatusByUserId[pendingKey] || buildAdministratorStatus()
                if (memberIndex > -1) {
                    pageContent.membersList.setProperty(memberIndex, "status", appliedStatus)
                }
                if (pendingStatusByUserId[pendingKey]) {
                    var nextPending = ({})
                    for (var key in pendingStatusByUserId) {
                        if (key !== pendingKey) {
                            nextPending[key] = pendingStatusByUserId[key]
                        }
                    }
                    pendingStatusByUserId = nextPending
                }
                appNotification.show(qsTr("Member promoted to Admin."))
                refreshGroupInformation()
                return
            }
            if (action === "demote") {
                if (memberIndex > -1) {
                    pageContent.membersList.setProperty(memberIndex, "status", { "@type": "chatMemberStatusMember" })
                }
                appNotification.show(qsTr("Admin demoted to member."))
                refreshGroupInformation()
            }
        }
        onErrorReceived: {
            if (!extra || extra.indexOf("chatMemberAction:") !== 0) {
                return
            }
            var parts = extra.split(":")
            if (parts.length === 4 && parts[2].toString() === chatInformationPage.chatInformation.id.toString()) {
                setProcessing(parts[3], false)
            }
            Functions.handleErrorMessage(code, message)
        }
    }
    Connections {
        target: chatListModel
        onRowsInserted: {
            if (chatInformationPage.isPrivateChat || chatInformationPage.isSecretChat) {
                delegateModel.applyFilter();
            }
        }
        onModelReset: {
            if (chatInformationPage.isPrivateChat || chatInformationPage.isSecretChat) {
                delegateModel.applyFilter();
            }
        }
    }
    Timer {
        id: loadedTimer
        interval: 50
        onTriggered: {
            tabBase.loading = false
        }
    }

    Component.onCompleted: {
        if(chatInformationPage.isPrivateChat || chatInformationPage.isSecretChat) {
            tdLibWrapper.getGroupsInCommon(chatInformationPage.chatPartnerGroupId, 200, 0); // we only use the first 200
        } else if(chatInformationPage.isSuperGroup) {
            fetchMoreMembersTimer.start();
        }
    }

}
