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
import "../"
import "../../js/twemoji.js" as Emoji
import "../../js/functions.js" as Functions
import "../../js/debug.js" as Debug


SilicaFlickable {
    id: pageContent
    property alias membersList: membersList
    property bool groupPhotoUploadInProgress: false

    function initializePage() {
        membersList.clear();
        var chatType = chatInformation.type["@type"];
        switch(chatType) {
        case "chatTypePrivate":
            chatInformationPage.isPrivateChat = true;
            chatInformationPage.chatPartnerGroupId = chatInformationPage.chatInformation.type.user_id.toString();
            if(!chatInformationPage.privateChatUserInformation.id) {
                chatInformationPage.privateChatUserInformation = tdLibWrapper.getUserInformation(chatInformationPage.chatPartnerGroupId);
            }
            tdLibWrapper.getUserFullInfo(chatInformationPage.chatPartnerGroupId);
            tdLibWrapper.getUserProfilePhotos(chatInformationPage.chatPartnerGroupId, 100, 0);
            break;
        case "chatTypeSecret":
            chatInformationPage.isSecretChat = true;
            chatInformationPage.chatPartnerGroupId = chatInformationPage.chatInformation.type.user_id.toString();
            if(!chatInformationPage.privateChatUserInformation.id) {
                chatInformationPage.privateChatUserInformation = tdLibWrapper.getUserInformation(chatInformationPage.chatPartnerGroupId);
            }
            tdLibWrapper.getUserFullInfo(chatInformationPage.chatPartnerGroupId);
            tdLibWrapper.getUserProfilePhotos(chatInformationPage.chatPartnerGroupId, 100, 0);
            break;
        case "chatTypeBasicGroup":
            chatInformationPage.isBasicGroup = true;
            chatInformationPage.chatPartnerGroupId = chatInformation.type.basic_group_id.toString();
            if(!chatInformationPage.groupInformation.id) {
                chatInformationPage.groupInformation = tdLibWrapper.getBasicGroup(chatInformationPage.chatPartnerGroupId);
            }
            tdLibWrapper.getGroupFullInfo(chatInformationPage.chatPartnerGroupId, false);
            break;
        case "chatTypeSupergroup":
            chatInformationPage.isSuperGroup = true;
            chatInformationPage.chatPartnerGroupId = chatInformation.type.supergroup_id.toString();
            if(!chatInformationPage.groupInformation.id) {
                chatInformationPage.groupInformation = tdLibWrapper.getSuperGroup(chatInformationPage.chatPartnerGroupId);
            }

            tdLibWrapper.getGroupFullInfo(chatInformationPage.chatPartnerGroupId, true);
            chatInformationPage.isChannel = chatInformationPage.groupInformation.is_channel;
            break;
        }
        Debug.log("is set up", chatInformationPage.isPrivateChat, chatInformationPage.isSecretChat, chatInformationPage.isBasicGroup, chatInformationPage.isSuperGroup, chatInformationPage.chatPartnerGroupId)
        if(!(chatInformationPage.isPrivateChat || chatInformationPage.isSecretChat)) {
            updateGroupStatusText();
        }


        tabViewLoader.active = true;
    }
    function scrollUp(force) {
        if(force) {
            // animation does not always work while quick scrolling
            scrollUpTimer.start()
        } else {
            scrollUpAnimation.start()
        }
    }
    function scrollDown(force) {
        if(force) {
            scrollDownTimer.start()
        } else {
            scrollDownAnimation.start()
        }
    }
    function handleBasicGroupFullInfo(groupFullInfo) {
        chatInformationPage.groupFullInformation = groupFullInfo;
        membersList.clear();
        if(groupFullInfo.members && groupFullInfo.members.length > 0) {
            for(var memberIndex in groupFullInfo.members) {
                var memberData = groupFullInfo.members[memberIndex];
                var userInfo = tdLibWrapper.getUserInformation(memberData.member_id.user_id) || {user:{}, bot_info:{}};
                memberData.user = userInfo;
                memberData.bot_info = memberData.bot_info || {};
                membersList.append(memberData);
            }
            chatInformationPage.groupInformation.member_count = groupFullInfo.members.length
            updateGroupStatusText();
        }
    }
    function updateGroupStatusText() {
        if (chatInformationPage.chatOnlineMemberCount > 0) {
            headerItem.description = qsTr("%1, %2", "combination of '[x members], [y online]', which are separate translations")
                .arg(qsTr("%1 members", "", chatInformationPage.groupInformation.member_count)
                    .arg(Functions.getShortenedCount(chatInformationPage.groupInformation.member_count)))
                .arg(qsTr("%1 online", "", chatInformationPage.chatOnlineMemberCount)
                    .arg(Functions.getShortenedCount(chatInformationPage.chatOnlineMemberCount)));
        } else {
            if (isChannel) {
                headerItem.description = qsTr("%1 subscribers", "", chatInformationPage.groupInformation.member_count ).arg(Functions.getShortenedCount(chatInformationPage.groupInformation.member_count));
            } else {
                headerItem.description = qsTr("%1 members", "", chatInformationPage.groupInformation.member_count).arg(Functions.getShortenedCount(chatInformationPage.groupInformation.member_count));
            }
        }
    }
    function getInformationText(informationValue) {
        if (typeof informationValue === "string") {
            return informationValue;
        }
        if (informationValue && typeof informationValue.text === "string") {
            return informationValue.text;
        }
        return "";
    }
    function cloneMap(sourceMap) {
        var result = {};
        if (!sourceMap) {
            return result;
        }
        for (var key in sourceMap) {
            result[key] = sourceMap[key];
        }
        return result;
    }
    function getInviteLink() {
        if (chatInformationPage.isPrivateChat || chatInformationPage.isSecretChat) {
            return "";
        }
        var inviteLink = chatInformationPage.groupFullInformation ? chatInformationPage.groupFullInformation.invite_link : "";
        if (typeof inviteLink === "string") {
            return inviteLink;
        }
        if (inviteLink && typeof inviteLink.invite_link === "string") {
            return inviteLink.invite_link;
        }
        return "";
    }
    function getPublicChatUsername() {
        var groupInformation = chatInformationPage.groupInformation || {};
        if (groupInformation.username) {
            return groupInformation.username;
        }
        var usernames = groupInformation.usernames || {};
        if (usernames.editable_username) {
            return usernames.editable_username;
        }
        if (usernames.active_usernames && usernames.active_usernames.length > 0) {
            return usernames.active_usernames[0];
        }
        return "";
    }
    function getGroupTypeText() {
        return getPublicChatUsername() !== "" ? qsTr("Public") : qsTr("Private");
    }
    function getChatHistoryVisibilityText() {
        return chatInformationPage.groupFullInformation && chatInformationPage.groupFullInformation.is_all_history_available
                ? qsTr("Visible")
                : qsTr("Hidden");
    }
    function getTopicStateText() {
        if (!chatInformationPage.groupInformation || typeof chatInformationPage.groupInformation.is_forum === "undefined") {
            return qsTr("Off");
        }
        return chatInformationPage.groupInformation.is_forum ? qsTr("On") : qsTr("Off");
    }
    function getReactionsSummaryText() {
        var availableReactions = chatInformationPage.chatInformation ? chatInformationPage.chatInformation.available_reactions : null;
        if ((!availableReactions || !availableReactions["@type"]) && chatInformationPage.chatInformation && chatInformationPage.chatInformation.id) {
            var cachedChat = tdLibWrapper.getChat(chatInformationPage.chatInformation.id.toString());
            availableReactions = cachedChat ? cachedChat.available_reactions : availableReactions;
        }
        if (availableReactions && availableReactions["@type"] === "chatAvailableReactionsSome") {
            var reducedCount = availableReactions.reactions ? availableReactions.reactions.length : 0;
            return reducedCount > 0 ? qsTr("%1 selected").arg(reducedCount) : qsTr("None");
        }
        if (availableReactions && availableReactions.length !== undefined && typeof availableReactions !== "string") {
            return availableReactions.length > 0 ? qsTr("%1 selected").arg(availableReactions.length) : qsTr("None");
        }
        return qsTr("All");
    }
    function getPermissionsSummaryText() {
        // Conta solo i 9 gruppi di permessi visibili nella UI,
        // non tutti i campi booleani restituiti da TDLib (che in 1.8.x possono essere 14-15
        // tra nomi vecchi e nuovi come can_send_messages + can_send_basic_messages, ecc.)
        var chatInformation = chatInformationPage.chatInformation || {};
        var permissions = chatInformation.permissions || {};
        var permissionGroups = [
            ["can_send_basic_messages", "can_send_messages"],
            ["can_send_media_messages", "can_send_audios", "can_send_documents",
             "can_send_photos", "can_send_videos", "can_send_video_notes", "can_send_voice_notes"],
            ["can_send_polls"],
            ["can_send_other_messages"],
            ["can_add_link_previews", "can_add_web_page_previews"],
            ["can_change_info"],
            ["can_invite_users"],
            ["can_pin_messages"],
            ["can_create_topics"]
        ];
        var totalPermissions = 0;
        var allowedPermissions = 0;
        for (var g = 0; g < permissionGroups.length; g++) {
            var group = permissionGroups[g];
            var groupPresent = false;
            var groupEnabled = false;
            for (var k = 0; k < group.length; k++) {
                var key = group[k];
                if (typeof permissions[key] === "boolean") {
                    groupPresent = true;
                    if (permissions[key]) groupEnabled = true;
                }
            }
            if (groupPresent) {
                totalPermissions += 1;
                if (groupEnabled) allowedPermissions += 1;
            }
        }
        return totalPermissions > 0 ? (allowedPermissions + "/" + totalPermissions) : "0/0";
    }
    function getAdministratorsCountText() {
        var groupFullInformation = chatInformationPage.groupFullInformation || {};
        var adminCount = Number(groupFullInformation.administrator_count);
        if (!isNaN(adminCount) && adminCount >= 0) {
            return Functions.getShortenedCount(adminCount);
        }
        var statusType = chatInformationPage.groupInformation && chatInformationPage.groupInformation.status
                ? chatInformationPage.groupInformation.status["@type"]
                : "";
        return (statusType === "chatMemberStatusCreator" || statusType === "chatMemberStatusAdministrator") ? "1" : "0";
    }
    function getMembersCountText() {
        var groupInformation = chatInformationPage.groupInformation || {};
        var memberCount = Number(groupInformation.member_count);
        if (isNaN(memberCount) || memberCount < 0) {
            return "0";
        }
        return Functions.getShortenedCount(memberCount);
    }
    function getInviteLinksCountText() {
        return getInviteLink() !== "" ? "1" : "0";
    }
    function getDiscussionStateText() {
        var groupFullInformation = chatInformationPage.groupFullInformation || {};
        var linkedChatId = Number(groupFullInformation.linked_chat_id);
        if (!isNaN(linkedChatId) && linkedChatId !== 0) {
            return qsTr("Added");
        }
        return qsTr("Add");
    }
    function getDirectMessagesText() {
        return qsTr("No");
    }
    function getChannelAppearanceText() {
        var chatInformation = chatInformationPage.chatInformation || {};
        var themeName = chatInformation.theme_name || "";
        return themeName !== "" ? themeName : qsTr("Default");
    }
    function getAutoTranslateMessagesText() {
        if (chatInformationPage.chatInformation && typeof chatInformationPage.chatInformation.auto_translation_enabled === "boolean") {
            return chatInformationPage.chatInformation.auto_translation_enabled ? qsTr("On") : qsTr("Off");
        }
        return qsTr("Off");
    }
    function getRemovedUsersCountText() {
        var groupFullInformation = chatInformationPage.groupFullInformation || {};
        var bannedCount = Number(groupFullInformation.banned_count);
        if (isNaN(bannedCount) || bannedCount < 0) {
            return "0";
        }
        return Functions.getShortenedCount(bannedCount);
    }
    function getStatisticsAvailabilityText() {
        return chatInformationPage.groupFullInformation && chatInformationPage.groupFullInformation.can_get_statistics
                ? qsTr("Available")
                : qsTr("Unavailable");
    }
    function getGroupStatus() {
        if (!chatInformationPage.groupInformation || !chatInformationPage.groupInformation.status) {
            return {};
        }
        return chatInformationPage.groupInformation.status;
    }
    function getStatusFlag(statusData, flagName) {
        var status = statusData || getGroupStatus();
        if (!status || !flagName) {
            return false;
        }
        if (typeof status[flagName] === "boolean") {
            return status[flagName];
        }
        var rights = status.rights || {};
        if (typeof rights[flagName] === "boolean") {
            return rights[flagName];
        }
        var permissions = status.permissions || {};
        if (typeof permissions[flagName] === "boolean") {
            return permissions[flagName];
        }
        return false;
    }
    function canCreateTopics() {
        if (!chatInformationPage.chatInformation || !chatInformationPage.chatInformation.permissions) {
            return false;
        }
        return chatInformationPage.chatInformation.permissions.can_create_topics === true;
    }
    function canChangeGroupInfo() {
        var groupStatus = getGroupStatus();
        return groupStatus["@type"] === "chatMemberStatusCreator" || getStatusFlag(groupStatus, "can_change_info");
    }
    function canManageTopics() {
        var groupStatus = getGroupStatus();
        return groupStatus["@type"] === "chatMemberStatusCreator" || getStatusFlag(groupStatus, "can_manage_topics");
    }
    function canInviteMembers() {
        var groupStatus = getGroupStatus();
        return groupStatus["@type"] === "chatMemberStatusCreator" || getStatusFlag(groupStatus, "can_invite_users");
    }
    function openGroupPhotoPicker() {
        if (!(chatInformationPage.isBasicGroup || chatInformationPage.isSuperGroup)) {
            return;
        }
        if (!canChangeGroupInfo()) {
            appNotification.show(qsTr("Only administrators can change the group picture."));
            return;
        }
        if (groupPhotoUploadInProgress) {
            return;
        }
        var picker = pageStack.push("Sailfish.Pickers.ImagePickerPage", {
            allowedOrientations: chatInformationPage.allowedOrientations
        });
        picker.selectedContentPropertiesChanged.connect(function() {
            if (!picker.selectedContentProperties || !picker.selectedContentProperties.filePath) {
                return;
            }
            groupPhotoUploadInProgress = true;
            appNotification.show(qsTr("Uploading group picture..."));
            tdLibWrapper.setChatPhoto(chatInformationPage.chatInformation.id.toString(), picker.selectedContentProperties.filePath);
        });
    }
    function refreshMembersList() {
        if (chatInformationPage.isBasicGroup) {
            tdLibWrapper.getGroupFullInfo(chatInformationPage.chatPartnerGroupId, false);
            return;
        }
        if (chatInformationPage.isSuperGroup && !chatInformationPage.isChannel) {
            membersList.clear();
            tdLibWrapper.getSupergroupMembers(chatInformationPage.chatPartnerGroupId, 50, 0);
        }
    }
    function refreshSupergroupInformation() {
        if (!chatInformationPage.isSuperGroup || !chatInformationPage.chatPartnerGroupId) {
            return;
        }
        tdLibWrapper.getGroupFullInfo(chatInformationPage.chatPartnerGroupId, true);
        tdLibWrapper.sendRequest({
            "@type": "getSupergroup",
            "supergroup_id": chatInformationPage.chatPartnerGroupId
        });
    }
    function toggleTopics() {
        if (!chatInformationPage.isSuperGroup || chatInformationPage.isChannel) {
            return;
        }
        var groupStatus = getGroupStatus();
        if (groupStatus["@type"] !== "chatMemberStatusCreator") {
            appNotification.show(qsTr("Only the group owner can change topics."));
            return;
        }
        var isForumEnabled = !!(chatInformationPage.groupInformation && chatInformationPage.groupInformation.is_forum);
        tdLibWrapper.sendRequest({
            "@type": "toggleSupergroupIsForum",
            "supergroup_id": chatInformationPage.chatPartnerGroupId,
            "is_forum": !isForumEnabled,
            "@extra": "toggleSupergroupIsForum:" + chatInformationPage.chatInformation.id + ":" + (!isForumEnabled ? "1" : "0")
        });
    }
    function toggleReactionsAvailability() {
        if (!chatInformationPage.isSuperGroup) {
            appNotification.show(qsTr("Reactions can only be changed in supergroups and channels."));
            return;
        }
        if (!canChangeGroupInfo()) {
            appNotification.show(qsTr("Only administrators can change reactions."));
            return;
        }
        var availableReactions = chatInformationPage.chatInformation ? chatInformationPage.chatInformation.available_reactions : null;
        if ((!availableReactions || !availableReactions["@type"]) && chatInformationPage.chatInformation && chatInformationPage.chatInformation.id) {
            var cachedChat = tdLibWrapper.getChat(chatInformationPage.chatInformation.id.toString());
            availableReactions = cachedChat ? cachedChat.available_reactions : availableReactions;
        }
        var isSome = availableReactions && availableReactions["@type"] === "chatAvailableReactionsSome";
        var currentSomeCount = isSome && availableReactions.reactions ? availableReactions.reactions.length : 0;
        var isNone = isSome && currentSomeCount === 0;
        var maxReactionCount = Number(availableReactions && availableReactions.max_reaction_count);
        if (isNaN(maxReactionCount) || maxReactionCount < 1) {
            maxReactionCount = 11;
        }
        tdLibWrapper.sendRequest({
            "@type": "setChatAvailableReactions",
            "chat_id": chatInformationPage.chatInformation.id,
            "available_reactions": isNone
                                   ? {
                                         "@type": "chatAvailableReactionsAll",
                                         "max_reaction_count": maxReactionCount
                                     }
                                   : {
                                         "@type": "chatAvailableReactionsSome",
                                         "reactions": [],
                                         "max_reaction_count": 1
                                     },
            "@extra": "setChatAvailableReactions:" + chatInformationPage.chatInformation.id + ":" + (isNone ? "all" : "none")
        });
    }
    function showComingSoon(optionTitle) {
        appNotification.show(qsTr("%1 is not available yet.").arg(optionTitle));
    }
    function openTabByName(tabName) {
        if (tabViewLoader.status === Loader.Ready && tabViewLoader.item && tabViewLoader.item.openTabByName(tabName)) {
            pageContent.scrollDown();
            return true;
        }
        return false;
    }
    function copyInviteLink() {
        var inviteLink = getInviteLink();
        if (inviteLink === "") {
            appNotification.show(qsTr("No invite link available yet."));
            return;
        }
        Clipboard.text = inviteLink;
        appNotification.show(qsTr("The Invite Link has been copied to the clipboard."));
    }
    function isUserBlocked() {
        var fullInfo = chatInformationPage.chatPartnerFullInformation || {};
        if (fullInfo.block_list && fullInfo.block_list["@type"]) {
            return true;
        }
        if (typeof fullInfo.is_blocked === "boolean") {
            return fullInfo.is_blocked;
        }
        return false;
    }
    function toggleUserBlocked() {
        if (!(chatInformationPage.isPrivateChat || chatInformationPage.isSecretChat)) {
            return;
        }
        var userId = Number(chatInformationPage.chatPartnerGroupId);
        if (!userId) {
            return;
        }
        var nextBlocked = !isUserBlocked();
        tdLibWrapper.sendRequest({
            "@type": "setMessageSenderBlockList",
            "sender_id": {
                "@type": "messageSenderUser",
                "user_id": userId
            },
            "block_list": nextBlocked ? { "@type": "blockListMain" } : null,
            "@extra": "setMessageSenderBlockList:" + userId + ":" + (nextBlocked ? "block" : "unblock")
        });
    }
    function triggerDeleteOrLeaveChat() {
        var chatId = chatInformationPage.chatInformation.id;
        var canDeleteForAll = !!chatInformationPage.chatInformation.can_be_deleted_for_all_users;
        var remorseText = (chatInformationPage.isChannel && canDeleteForAll) ? qsTr("Deleting channel") : qsTr("Leaving chat");
        Remorse.popupAction(chatInformationPage, remorseText, function() {
            if (canDeleteForAll) {
                tdLibWrapper.deleteChat(chatId);
            } else {
                tdLibWrapper.leaveChat(chatId);
            }
            pageStack.pop(pageStack.find( function(page){ return(page._depth === 0)} ));
        });
    }

    Connections {
        target: tdLibWrapper

        onBasicGroupUpdated: {
            if (chatInformationPage.isBasicGroup && chatInformationPage.chatPartnerGroupId === groupId.toString()) {
                chatInformationPage.groupInformation = tdLibWrapper.getBasicGroup(groupId);
                updateGroupStatusText();
            }
        }
        onSuperGroupUpdated: {
            if (chatInformationPage.isSuperGroup && chatInformationPage.chatPartnerGroupId === groupId.toString()) {
                chatInformationPage.groupInformation = tdLibWrapper.getSuperGroup(groupId);
                chatInformationPage.isChannel = chatInformationPage.groupInformation.is_channel;
                updateGroupStatusText();
            }
        }
        onChatOnlineMemberCountUpdated: {
            if ((chatInformationPage.isSuperGroup || chatInformationPage.isBasicGroup) && chatInformationPage.chatInformation.id.toString() === chatId) {
                chatInformationPage.chatOnlineMemberCount = onlineMemberCount;
                updateGroupStatusText();
            }
        }
        onSupergroupFullInfoReceived: {
            Debug.log("onSupergroupFullInfoReceived", chatInformationPage.isSuperGroup, chatInformationPage.chatPartnerGroupId, groupId)
            if(chatInformationPage.isSuperGroup && chatInformationPage.chatPartnerGroupId === groupId) {
                chatInformationPage.groupFullInformation = groupFullInfo;
            }
        }
        onSupergroupFullInfoUpdated: {
            Debug.log("onSupergroupFullInfoUpdated", chatInformationPage.isSuperGroup, chatInformationPage.chatPartnerGroupId, groupId)
            if(chatInformationPage.isSuperGroup && chatInformationPage.chatPartnerGroupId === groupId) {
                chatInformationPage.groupFullInformation = groupFullInfo;
            }
        }
        onBasicGroupFullInfoReceived: {
            if(chatInformationPage.isBasicGroup && chatInformationPage.chatPartnerGroupId === groupId) {
                handleBasicGroupFullInfo(groupFullInfo)
            }
        }

        onBasicGroupFullInfoUpdated: {
            if(chatInformationPage.isBasicGroup && chatInformationPage.chatPartnerGroupId === groupId) {
                handleBasicGroupFullInfo(groupFullInfo)
            }
        }
        onUserFullInfoReceived: {
            if((chatInformationPage.isPrivateChat || chatInformationPage.isSecretChat) && userFullInfo["@extra"] === chatInformationPage.chatPartnerGroupId) {
                chatInformationPage.chatPartnerFullInformation = userFullInfo;
            }
        }
        onUserFullInfoUpdated: {
            if((chatInformationPage.isPrivateChat || chatInformationPage.isSecretChat) && userId === chatInformationPage.chatPartnerGroupId) {
                chatInformationPage.chatPartnerFullInformation = userFullInfo;
            }
        }

        onUserProfilePhotosReceived: {
            if((chatInformationPage.isPrivateChat || chatInformationPage.isSecretChat) && extra === chatInformationPage.chatPartnerGroupId) {
                chatInformationPage.chatPartnerProfilePhotos = photos;
            }
        }
        onChatPermissionsUpdated: {
            if (chatInformationPage.chatInformation.id.toString() === chatId) {
                // set whole object to trigger change
                var newInformation = cloneMap(chatInformation);
                newInformation.permissions = cloneMap(permissions);
                chatInformationPage.chatInformation = newInformation
            }
        }
        onChatPhotoUpdated: {
            if (chatInformationPage.chatInformation.id.toString() === chatId.toString()) {
                var newInformation = cloneMap(chatInformationPage.chatInformation);
                newInformation.photo = cloneMap(photo);
                chatInformationPage.chatInformation = newInformation;
                groupPhotoUploadInProgress = false;
            }
        }
        onChatTitleUpdated: {
            if (chatInformationPage.chatInformation.id.toString() === chatId) {
                // set whole object to trigger change
                var newInformation = cloneMap(chatInformation);
                newInformation.title = title
                chatInformationPage.chatInformation = newInformation
            }
        }
        onChatReceived: {
            if (chat && chat.id && chatInformationPage.chatInformation.id.toString() === chat.id.toString()) {
                chatInformationPage.chatInformation = cloneMap(chat);
            }
        }
        onChatNotificationSettingsUpdated: {
            if (chatInformationPage.chatInformation.id.toString() === chatId) {
                // set whole object to trigger change
                var newInformation = cloneMap(chatInformation);
                newInformation.notification_settings = cloneMap(chatNotificationSettings);
                chatInformationPage.chatInformation = newInformation;
            }
        }
        onChatAvailableReactionsUpdated: {
            if (chatInformationPage.chatInformation.id.toString() === chatId.toString()) {
                var newInformation = cloneMap(chatInformation);
                newInformation.available_reactions = availableReactions;
                chatInformationPage.chatInformation = newInformation;
            }
        }
        onOkReceived: {
            var requestText = request !== undefined && request !== null ? request.toString() : "";
            if (requestText === "") {
                return;
            }
            if (requestText.indexOf("addChatMember:") === 0) {
                var addParts = requestText.split(":");
                if (addParts.length === 3 && addParts[1].toString() === chatInformationPage.chatInformation.id.toString()) {
                    refreshMembersList();
                }
                return;
            }
            if (requestText.indexOf("setChatPhoto:") === 0) {
                var photoParts = requestText.split(":");
                if (photoParts.length === 2 && photoParts[1].toString() === chatInformationPage.chatInformation.id.toString()) {
                    groupPhotoUploadInProgress = false;
                    appNotification.show(qsTr("Group picture updated."));
                    tdLibWrapper.sendRequest({
                        "@type": "getChat",
                        "chat_id": chatInformationPage.chatInformation.id
                    });
                }
                return;
            }
            if (requestText.indexOf("toggleSupergroupIsAllHistoryAvailable:") === 0) {
                var historyParts = requestText.split(":");
                if (historyParts.length === 3 && historyParts[1].toString() === chatInformationPage.chatInformation.id.toString()) {
                    var historyVisible = historyParts[2] === "1";
                    if (chatInformationPage.groupFullInformation) {
                        var updatedGroupFullInformation = cloneMap(chatInformationPage.groupFullInformation);
                        updatedGroupFullInformation.is_all_history_available = historyVisible;
                        chatInformationPage.groupFullInformation = updatedGroupFullInformation;
                    }
                    appNotification.show(historyVisible ? qsTr("Chat history is now visible.") : qsTr("Chat history is now hidden."));
                    refreshSupergroupInformation();
                }
                return;
            }
            if (requestText.indexOf("toggleSupergroupIsForum:") === 0) {
                var forumParts = requestText.split(":");
                if (forumParts.length === 3 && forumParts[1].toString() === chatInformationPage.chatInformation.id.toString()) {
                    var newForumState = forumParts[2] === "1";
                    if (chatInformationPage.groupInformation) {
                        var updatedGroupInformation = cloneMap(chatInformationPage.groupInformation);
                        updatedGroupInformation.is_forum = newForumState;
                        chatInformationPage.groupInformation = updatedGroupInformation;
                    }
                    appNotification.show(newForumState ? qsTr("Topics enabled.") : qsTr("Topics disabled."));
                    refreshSupergroupInformation();
                }
                return;
            }
            if (requestText.indexOf("setMessageSenderBlockList:") === 0) {
                var blockParts = requestText.split(":");
                if (blockParts.length === 3 && blockParts[1].toString() === chatInformationPage.chatPartnerGroupId) {
                    var isBlock = blockParts[2] === "block";
                    var updatedFullInfo = cloneMap(chatInformationPage.chatPartnerFullInformation);
                    if (isBlock) {
                        updatedFullInfo.block_list = { "@type": "blockListMain" };
                        updatedFullInfo.is_blocked = true;
                    } else {
                        delete updatedFullInfo.block_list;
                        updatedFullInfo.is_blocked = false;
                    }
                    chatInformationPage.chatPartnerFullInformation = updatedFullInfo;
                    appNotification.show(isBlock ? qsTr("User has been blocked.") : qsTr("User has been unblocked."));
                }
                return;
            }
            if (requestText.indexOf("setChatAvailableReactions:") === 0) {
                var reactionParts = requestText.split(":");
                if (reactionParts.length === 3 && reactionParts[1].toString() === chatInformationPage.chatInformation.id.toString()) {
                    var setAllReactions = reactionParts[2] === "all";
                    var updatedChatInformation = cloneMap(chatInformationPage.chatInformation);
                    updatedChatInformation.available_reactions = setAllReactions
                            ? {
                                  "@type": "chatAvailableReactionsAll",
                                  "max_reaction_count": 11
                              }
                            : {
                                  "@type": "chatAvailableReactionsSome",
                                  "reactions": [],
                                  "max_reaction_count": 1
                              };
                    chatInformationPage.chatInformation = updatedChatInformation;
                    appNotification.show(setAllReactions ? qsTr("All reactions enabled.") : qsTr("Reactions disabled."));
                }
            }
        }
        onErrorReceived: {
            var extraText = extra !== undefined && extra !== null ? extra.toString() : "";
            if (extraText.indexOf("toggleSupergroupIsAllHistoryAvailable:") === 0) {
                Functions.handleErrorMessage(code, message);
                return;
            }
            if (extraText.indexOf("toggleSupergroupIsForum:") === 0) {
                Functions.handleErrorMessage(code, message);
                return;
            }
            if (extraText.indexOf("setChatAvailableReactions:") === 0) {
                Functions.handleErrorMessage(code, message);
                return;
            }
            if (extraText.indexOf("setMessageSenderBlockList:") === 0) {
                Functions.handleErrorMessage(code, message);
                return;
            }
            if (extraText.indexOf("setChatPhoto:") === 0) {
                groupPhotoUploadInProgress = false;
                Functions.handleErrorMessage(code, message);
                return;
            }
            if (extraText.indexOf("getChatStatisticsUrl:") === 0) {
                chatInformationPage.pendingStatisticsChatId = 0;
                Functions.handleErrorMessage(code, message);
                return;
            }
            if (extraText.indexOf("createCall:") === 0) {
                appNotification.show(message !== "" ? message : qsTr("Unable to start the call."));
            }
        }
        onChatStatisticsUrlReceived: {
            if (chatInformationPage.pendingStatisticsChatId.toString() !== chatId.toString()) {
                return;
            }
            chatInformationPage.pendingStatisticsChatId = 0;
            if (!url) {
                appNotification.show(qsTr("Statistics are unavailable for this chat."));
                return;
            }
            pageStack.push(Qt.resolvedUrl("../../pages/ChannelStatisticsPage.qml"), {
                "statisticsUrl": url,
                "chatTitle": chatInformationPage.chatInformation.title || ""
            });
        }
    }

    Component.onCompleted: {
        initializePage();
    }

    ListModel {
        id: membersList
    }

    PullDownMenu {
        MenuItem {
            visible: (chatInformationPage.isSuperGroup || chatInformationPage.isBasicGroup) && chatInformationPage.groupInformation && chatInformationPage.groupInformation.status["@type"] !== "chatMemberStatusBanned"
            text: chatInformationPage.userIsMember ? qsTr("Leave Chat") : qsTr("Join Chat")
            onClicked: {
                // ensure it's done even if the page is closed:
                if (chatInformationPage.userIsMember) {
                    var chatId = chatInformationPage.chatInformation.id;
                    Remorse.popupAction(chatInformationPage, qsTr("Leaving chat"), function() {
                        tdLibWrapper.leaveChat(chatId);
                        // this does not care about the response (ideally type "ok" without further reference) for now
                        pageStack.pop(pageStack.find( function(page){ return(page._depth === 0)} ));
                    });
                } else {
                    tdLibWrapper.joinChat(chatInformationPage.chatInformation.id);
                }
            }
        }
        MenuItem {
            visible: chatInformationPage.userIsMember
            onClicked: {
                var newNotificationSettings = chatInformationPage.chatInformation.notification_settings;
                if (newNotificationSettings.mute_for > 0) {
                    newNotificationSettings.mute_for = 0;
                } else {
                    newNotificationSettings.mute_for = 6666666;
                }
                newNotificationSettings.use_default_mute_for = false;
                tdLibWrapper.setChatNotificationSettings(chatInformationPage.chatInformation.id, newNotificationSettings);
            }
            text: chatInformation.notification_settings.mute_for > 0 ? qsTr("Unmute Chat") : qsTr("Mute Chat")
        }
        MenuItem {
            visible: chatInformationPage.userIsMember
                     && chatInformationPage.isSuperGroup
                     && chatInformationPage.groupInformation
                     && chatInformationPage.groupInformation.status
                     && (chatInformationPage.groupInformation.status["@type"] === "chatMemberStatusCreator"
                         || getStatusFlag(chatInformationPage.groupInformation.status, "can_invite_users"))
            onClicked: {
                pageStack.push(Qt.resolvedUrl("../../pages/ChatJoinRequestsPage.qml"), {
                    "chatId": chatInformationPage.chatInformation.id,
                    "chatTitle": chatInformationPage.chatInformation.title
                });
            }
            text: qsTr("Join Requests")
        }
        MenuItem {
            visible: chatInformationPage.isPrivateChat
            onClicked: {
                tdLibWrapper.createNewSecretChat(chatInformationPage.chatPartnerGroupId, "openDirectly");
            }
            text: qsTr("New Secret Chat")
        }
        MenuItem {
            visible: (chatInformationPage.isPrivateChat || chatInformationPage.isSecretChat)
                     && chatInformationPage.chatPartnerGroupId !== ""
                     && chatInformationPage.privateChatUserInformation.id !== chatInformationPage.myUserId
            text: isUserBlocked() ? qsTr("Unblock User") : qsTr("Block User")
            onClicked: {
                toggleUserBlocked();
            }
        }
    }
    // header
    PageHeader {
        id: headerItem
        z: 5
        Item {
            id: imageContainer
            property bool hasImage: typeof chatInformationPage.chatInformation.photo !== "undefined"
            property int minDimension: chatInformationPage.isLandscape ? Theme.itemSizeSmall : Theme.itemSizeMedium
            property int maxDimension: Screen.width / 2
            property int minX: Theme.horizontalPageMargin
            property int maxX: (chatInformationPage.width - maxDimension)/2
            property int minY: Theme.paddingMedium
            property int maxY: parent.height
            property double tweenFactor: {
                if(!hasImage) {
                    return 0
                }
                return 1 - Math.max(0, Math.min(1, contentFlickable.contentY / maxDimension))
            }
            property bool thumbnailVisible: imageContainer.tweenFactor > 0.8
            property bool thumbnailActive: imageContainer.tweenFactor === 1.0
            property var thumbnailModel: chatInformationPage.chatPartnerProfilePhotos
            property int thumbnailRadius: imageContainer.minDimension / 2

            function getEased(min,max,factor) {
                return min + (max-min)*factor
            }
            width: getEased(minDimension,maxDimension, tweenFactor)
            height: width
            x: getEased(minX,maxX, tweenFactor)
            y: getEased(minY,maxY, tweenFactor)

            ProfileThumbnail {
                id: chatPictureThumbnail
                photoData: imageContainer.hasImage ? chatInformationPage.chatInformation.photo.small : ""
                replacementStringHint: headerItem.title
                width: parent.width
                height: width
                radius: imageContainer.thumbnailRadius
                opacity: profilePictureLoader.status !== Loader.Ready || profilePictureLoader.item.opacity < 1 ? 1.0 : 0.0
                optimizeImageSize: false
            }

            Loader {
                id: profilePictureLoader
                active: imageContainer.hasImage
                asynchronous: true
                anchors.fill: chatPictureThumbnail
                source: ( chatInformationPage.isPrivateChat || chatInformationPage.isSecretChat)
                        ? "../ProfilePictureList.qml"
                        : "ChatInformationProfilePicture.qml"
            }
        }
        leftMargin: imageContainer.getEased((imageContainer.minDimension + Theme.paddingMedium), 0, imageContainer.tweenFactor) + Theme.horizontalPageMargin
        title: chatInformationPage.chatInformation.title !== "" ? Emoji.emojify(chatInformationPage.chatInformation.title, Theme.fontSizeLarge) : qsTr("Unknown")
        description: ((chatInformationPage.isPrivateChat || chatInformationPage.isSecretChat) && chatInformationPage.privateChatUserInformation.usernames.editable_username)
            ? ("@"+chatInformationPage.privateChatUserInformation.usernames.editable_username) : ""
    }

    SilicaFlickable {
        id: contentFlickable
        contentHeight: groupInfoItem.height + tabViewLoader.height
        clip: true
        interactive: !scrollUpAnimation.running && !scrollDownAnimation.running

        anchors {
            top: headerItem.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        NumberAnimation {
            id: scrollDownAnimation
            target: contentFlickable
            to: groupInfoItem.height
            property: "contentY"
            duration: 500
            easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            id: scrollUpAnimation
            target: contentFlickable
            to: 0
            property: "contentY"
            duration: 500
            easing.type: Easing.InOutCubic
            property Timer scrollUpTimer: Timer {
                id: scrollUpTimer
                interval: 50
                onTriggered: {
                    contentFlickable.scrollToTop()
                }
            }
            property Timer scrollDownTimer: Timer {
                id: scrollDownTimer
                interval: 50
                onTriggered: {
                    contentFlickable.scrollToBottom()
                }
            }
        }

        Column {
            id: groupInfoItem
            bottomPadding: Theme.paddingLarge
            topPadding: Theme.paddingLarge
            anchors {
                top: parent.top
                left: parent.left
                leftMargin: Theme.horizontalPageMargin
                right: parent.right
                rightMargin: Theme.horizontalPageMargin
            }

            Item { //large image placeholder
                width: parent.width
                height: imageContainer.hasImage ? imageContainer.maxDimension : 0
            }

            Label {
                id: copyIdText
                x: Math.max(headerItem.x + imageContainer.x - groupInfoItem.x + (imageContainer.width - width)/2, 0)
                text: chatInformationPage.chatPartnerGroupId
                font.pixelSize: Theme.fontSizeSmall
                color: copyIdMouseArea.pressed ? Theme.secondaryHighlightColor : Theme.highlightColor
                visible: text !== ""

                MouseArea {
                    id: copyIdMouseArea
                    anchors {
                        fill: parent
                        margins: -Theme.paddingLarge
                    }
                    onClicked: {
                        Clipboard.text = copyIdText.text
                        appNotification.show(qsTr("ID has been copied to the clipboard."));
                    }
                }
            }

            InformationEditArea {
                visible: canEdit
                canEdit: !(chatInformationPage.isPrivateChat || chatInformationPage.isSecretChat) && chatInformationPage.groupInformation.status && (getStatusFlag(chatInformationPage.groupInformation.status, "can_change_info")  || chatInformationPage.groupInformation.status["@type"] === "chatMemberStatusCreator")
                headerText: qsTr("Chat Title", "group title header")
                text: chatInformationPage.chatInformation.title

                onSaveButtonClicked: {
                    if(!editItem.errorHighlight) {
                        tdLibWrapper.setChatTitle(chatInformationPage.chatInformation.id, textValue);
                    } else {
                        isEditing = true
                    }
                }

                onTextEdited: {
                    if(textValue.length > 0 && textValue.length < 129) {
                        editItem.errorHighlight = false
                        editItem.label = ""
                        editItem.placeholderText = ""
                    } else {
                        editItem.label = qsTr("Enter 1-128 characters")
                        editItem.placeholderText = editItem.label
                        editItem.errorHighlight = true
                    }
                }
            }
            InformationEditArea {
                canEdit: ((chatInformationPage.isPrivateChat || chatInformationPage.isSecretChat) && chatInformationPage.privateChatUserInformation.id === chatInformationPage.myUserId) || ((chatInformationPage.isBasicGroup || chatInformationPage.isSuperGroup) && chatInformationPage.groupInformation && (getStatusFlag(chatInformationPage.groupInformation.status, "can_change_info") || chatInformationPage.groupInformation.status["@type"] === "chatMemberStatusCreator"))
                emptyPlaceholderText: qsTr("There is no information text available, yet.")
                headerText: qsTr("Info", "group or user infotext header")
                multiLine: true
                text: getInformationText((chatInformationPage.isPrivateChat || chatInformationPage.isSecretChat) ? chatInformationPage.chatPartnerFullInformation.bio : chatInformationPage.groupFullInformation.description)
                onSaveButtonClicked: {
                    if ((chatInformationPage.isPrivateChat || chatInformationPage.isSecretChat)) { // own bio
                        tdLibWrapper.setBio(textValue);
                    } else { // group info
                        tdLibWrapper.setChatDescription(chatInformationPage.chatInformation.id, textValue);
                    }
                }
            }

            InformationTextItem {
                headerText: qsTr("Phone Number", "user phone number header")
                text: ((chatInformationPage.isPrivateChat || chatInformationPage.isSecretChat) && chatInformationPage.privateChatUserInformation.phone_number ? "+"+chatInformationPage.privateChatUserInformation.phone_number : "") || ""
                isLinkedLabel: true
            }

            SectionHeader {
                visible: chatInformationPage.isBasicGroup || chatInformationPage.isSuperGroup
                font.pixelSize: Theme.fontSizeExtraSmall
                text: chatInformationPage.isChannel ? qsTr("Channel Settings") : qsTr("Group Settings")
                x: 0
            }
            Column {
                id: modernOptionsColumn
                width: parent.width
                visible: chatInformationPage.isBasicGroup || chatInformationPage.isSuperGroup
                spacing: 0

                ModernChatOptionItem {
                    width: parent.width
                    visible: chatInformationPage.isBasicGroup || chatInformationPage.isSuperGroup
                    title: chatInformationPage.isChannel ? qsTr("Channel Picture") : qsTr("Group Picture")
                    iconSource: "image://theme/icon-m-image"
                    showDisclosure: true
                    onClicked: {
                        openGroupPhotoPicker();
                    }
                }

                ModernChatOptionItem {
                    width: parent.width
                    visible: chatInformationPage.isSuperGroup
                    title: chatInformationPage.isChannel ? qsTr("Channel Type") : qsTr("Group Type")
                    value: getGroupTypeText()
                    iconSource: "image://theme/icon-m-chat"
                    showDisclosure: true
                    onClicked: {
                        if (!chatInformationPage.isSuperGroup) {
                            appNotification.show(qsTr("Basic groups are private."));
                            return;
                        }
                        if (!canChangeGroupInfo()) {
                            appNotification.show(qsTr("Only administrators can change the group type."));
                            return;
                        }
                        pageStack.push(Qt.resolvedUrl("../../pages/GroupTypePage.qml"), {
                            "chatId": chatInformationPage.chatInformation.id,
                            "chatTitle": chatInformationPage.chatInformation.title || "",
                            "supergroupId": chatInformationPage.chatPartnerGroupId,
                            "currentUsername": getPublicChatUsername(),
                            "isChannel": chatInformationPage.isChannel,
                            "joinByRequest": !!(chatInformationPage.groupInformation && chatInformationPage.groupInformation.join_by_request),
                            "hasProtectedContent": !!(chatInformationPage.chatInformation && chatInformationPage.chatInformation.has_protected_content)
                        });
                    }
                }

                ModernChatOptionItem {
                    width: parent.width
                    visible: chatInformationPage.isSuperGroup && !chatInformationPage.isChannel
                    title: qsTr("Chat History")
                    value: getChatHistoryVisibilityText()
                    iconSource: "image://theme/icon-m-chat"
                    showDisclosure: true
                    onClicked: {
                        var canChangeInfo = chatInformationPage.groupInformation
                                && chatInformationPage.groupInformation.status
                                && (getStatusFlag(chatInformationPage.groupInformation.status, "can_change_info")
                                    || chatInformationPage.groupInformation.status["@type"] === "chatMemberStatusCreator");
                        if (!canChangeInfo) {
                            appNotification.show(qsTr("Only administrators can change chat history visibility."));
                            return;
                        }
                        var isHistoryVisible = !!(chatInformationPage.groupFullInformation && chatInformationPage.groupFullInformation.is_all_history_available);
                        if (chatInformationPage.groupInformation && chatInformationPage.groupInformation.is_forum && isHistoryVisible) {
                            appNotification.show(qsTr("Message history can't be hidden while topics are enabled."));
                            return;
                        }
                        tdLibWrapper.sendRequest({
                            "@type": "toggleSupergroupIsAllHistoryAvailable",
                            "supergroup_id": chatInformationPage.chatPartnerGroupId,
                            "is_all_history_available": !isHistoryVisible,
                            "@extra": "toggleSupergroupIsAllHistoryAvailable:" + chatInformationPage.chatInformation.id + ":" + (!isHistoryVisible ? "1" : "0")
                        });
                    }
                }

                ModernChatOptionItem {
                    width: parent.width
                    visible: chatInformationPage.isSuperGroup && !chatInformationPage.isChannel
                    title: qsTr("Topics")
                    value: getTopicStateText()
                    iconSource: "image://theme/icon-m-folder"
                    showDisclosure: true
                    onClicked: {
                        toggleTopics();
                    }
                }
                ModernChatOptionItem {
                    width: parent.width
                    visible: chatInformationPage.isSuperGroup
                             && !chatInformationPage.isChannel
                             && chatInformationPage.groupInformation
                             && chatInformationPage.groupInformation.is_forum
                    title: qsTr("Manage Topics")
                    iconSource: "image://theme/icon-m-folder"
                    showDisclosure: true
                    onClicked: {
                        if (!canManageTopics()) {
                            if (canCreateTopics()) {
                                pageStack.push(Qt.resolvedUrl("../../pages/ForumTopicsPage.qml"), {
                                    "chatInformation": chatInformationPage.chatInformation
                                });
                                return;
                            }
                            appNotification.show(qsTr("Only administrators can manage topics."));
                            return;
                        }
                        pageStack.push(Qt.resolvedUrl("../../pages/ForumTopicsPage.qml"), {
                            "chatInformation": chatInformationPage.chatInformation
                        });
                    }
                }

                ModernChatOptionItem {
                    width: parent.width
                    visible: chatInformationPage.isChannel
                    title: qsTr("Discussion")
                    value: getDiscussionStateText()
                    iconSource: "image://theme/icon-m-chat"
                    showDisclosure: true
                    onClicked: {
                        var groupStatus = getGroupStatus();
                        var isCreator = groupStatus && groupStatus["@type"] === "chatMemberStatusCreator";
                        if (!isCreator) {
                            appNotification.show(qsTr("Only the channel owner can change the discussion group."));
                            return;
                        }
                        var linkedChatIdNum = Number(chatInformationPage.groupFullInformation
                                                    ? chatInformationPage.groupFullInformation.linked_chat_id
                                                    : 0);
                        if (isNaN(linkedChatIdNum)) {
                            linkedChatIdNum = 0;
                        }
                        pageStack.push(Qt.resolvedUrl("../../pages/SelectDiscussionGroupPage.qml"), {
                            "channelChat": chatInformationPage.chatInformation,
                            "linkedChatId": linkedChatIdNum
                        });
                    }
                }

                ModernChatOptionItem {
                    width: parent.width
                    visible: chatInformationPage.isChannel
                    title: qsTr("Direct Messages")
                    value: getDirectMessagesText()
                    iconSource: "image://theme/icon-m-chat"
                    showDisclosure: true
                    onClicked: {
                        showComingSoon(title);
                    }
                }

                ModernChatOptionItem {
                    width: parent.width
                    visible: chatInformationPage.isChannel
                    title: qsTr("Appearance")
                    value: getChannelAppearanceText()
                    iconSource: "image://theme/icon-m-image"
                    showDisclosure: true
                    onClicked: {
                        var groupStatus = getGroupStatus();
                        var canChange = groupStatus
                                && (groupStatus["@type"] === "chatMemberStatusCreator"
                                    || getStatusFlag(groupStatus, "can_change_info"));
                        if (!canChange) {
                            appNotification.show(qsTr("Only administrators can change the appearance."));
                            return;
                        }
                        pageStack.push(Qt.resolvedUrl("../../pages/ChannelAppearancePage.qml"), {
                            "channelChat": chatInformationPage.chatInformation
                        });
                    }
                }

                ModernChatOptionItem {
                    width: parent.width
                    visible: chatInformationPage.isChannel
                    title: qsTr("Auto-Translate Messages")
                    value: getAutoTranslateMessagesText()
                    iconSource: "image://theme/icon-m-text-input"
                    showDisclosure: true
                    onClicked: {
                        showComingSoon(title);
                    }
                }

                ModernChatOptionItem {
                    width: parent.width
                    visible: chatInformationPage.isSuperGroup
                    title: qsTr("Reactions")
                    value: getReactionsSummaryText()
                    iconSource: "image://theme/icon-m-sticker"
                    showDisclosure: true
                    onClicked: {
                        toggleReactionsAvailability();
                    }
                }

                ModernChatOptionItem {
                    width: parent.width
                    visible: !chatInformationPage.isChannel
                    title: qsTr("Permissions")
                    value: getPermissionsSummaryText()
                    iconSource: "image://theme/icon-m-developer-mode"
                    showDisclosure: true
                    onClicked: {
                        if (!openTabByName("ChatInformationTabItemSettings")) {
                            showComingSoon(title);
                        }
                    }
                }

                ModernChatOptionItem {
                    width: parent.width
                    title: qsTr("Invite Link")
                    value: getInviteLinksCountText()
                    iconSource: "image://theme/icon-m-link"
                    showDisclosure: true
                    onClicked: {
                        copyInviteLink();
                    }
                }
                ModernChatOptionItem {
                    width: parent.width
                    visible: (chatInformationPage.isBasicGroup || chatInformationPage.isSuperGroup) && !chatInformationPage.isChannel && chatInformationPage.userIsMember && canInviteMembers()
                    title: qsTr("Add Members")
                    iconSource: "image://theme/icon-m-add"
                    showDisclosure: true
                    onClicked: {
                        pageStack.push(Qt.resolvedUrl("../../pages/AddChatMembersPage.qml"), {
                            "chatId": chatInformationPage.chatInformation.id,
                            "chatTitle": chatInformationPage.chatInformation.title || ""
                        });
                    }
                }

                ModernChatOptionItem {
                    width: parent.width
                    title: qsTr("Administrators")
                    value: getAdministratorsCountText()
                    iconSource: "image://theme/icon-m-contact"
                    showDisclosure: true
                    onClicked: {
                        if (!chatInformationPage.isSuperGroup) {
                            if (!openTabByName("ChatInformationTabItemMembersGroups")) {
                                showComingSoon(title);
                            }
                            return;
                        }
                        pageStack.push(Qt.resolvedUrl("../../pages/SupergroupMembersPage.qml"), {
                            "chatId": chatInformationPage.chatInformation.id,
                            "chatTitle": chatInformationPage.chatInformation.title || "",
                            "supergroupId": chatInformationPage.chatPartnerGroupId,
                            "mode": "administrators"
                        });
                    }
                }

                ModernChatOptionItem {
                    width: parent.width
                    title: chatInformationPage.isChannel ? qsTr("Subscribers") : qsTr("Members")
                    value: getMembersCountText()
                    iconSource: "image://theme/icon-m-people"
                    showDisclosure: true
                    onClicked: {
                        if (!openTabByName("ChatInformationTabItemMembersGroups")) {
                            showComingSoon(title);
                        }
                    }
                }

                ModernChatOptionItem {
                    width: parent.width
                    visible: chatInformationPage.isSuperGroup
                    title: qsTr("Removed Users")
                    value: getRemovedUsersCountText()
                    iconSource: "image://theme/icon-m-remove"
                    showDisclosure: true
                    onClicked: {
                        pageStack.push(Qt.resolvedUrl("../../pages/SupergroupMembersPage.qml"), {
                            "chatId": chatInformationPage.chatInformation.id,
                            "chatTitle": chatInformationPage.chatInformation.title || "",
                            "supergroupId": chatInformationPage.chatPartnerGroupId,
                            "mode": "banned"
                        });
                    }
                }

                ModernChatOptionItem {
                    width: parent.width
                    visible: chatInformationPage.isChannel
                    title: qsTr("Statistics")
                    value: getStatisticsAvailabilityText()
                    iconSource: "image://theme/icon-m-diagnostic"
                    showDisclosure: true
                    onClicked: {
                        if (!(chatInformationPage.groupFullInformation && chatInformationPage.groupFullInformation.can_get_statistics)) {
                            appNotification.show(qsTr("Statistics are unavailable for this chat."));
                            return;
                        }
                        chatInformationPage.pendingStatisticsChatId = chatInformationPage.chatInformation.id;
                        tdLibWrapper.getChatStatisticsUrl(chatInformationPage.chatInformation.id, true);
                    }
                }

                ModernChatOptionItem {
                    width: parent.width
                    visible: chatInformationPage.isChannel
                    title: qsTr("Recent Actions")
                    iconSource: "image://theme/icon-m-developer-mode"
                    showDisclosure: true
                    onClicked: {
                        pageStack.push(Qt.resolvedUrl("../../pages/ChatRecentActionsPage.qml"), {
                            "chatId": chatInformationPage.chatInformation.id,
                            "chatTitle": chatInformationPage.chatInformation.title || ""
                        });
                    }
                }

                ModernChatOptionItem {
                    width: parent.width
                    visible: chatInformationPage.isChannel
                    title: qsTr("Affiliate Programs")
                    iconSource: "image://theme/icon-m-share"
                    showDisclosure: true
                    onClicked: {
                        showComingSoon(title);
                    }
                }
            }
            ModernChatOptionItem {
                width: parent.width
                visible: chatInformationPage.isBasicGroup
                         && chatInformationPage.groupInformation
                         && chatInformationPage.groupInformation.status
                         && chatInformationPage.groupInformation.status["@type"] === "chatMemberStatusCreator"
                title: qsTr("Convert to supergroup")
                iconSource: "image://theme/icon-m-cloud-upload"
                onClicked: {
                    var chatId = chatInformationPage.chatInformation.id;
                    Remorse.popupAction(chatInformationPage, qsTr("Converting to supergroup"), function() {
                        tdLibWrapper.upgradeBasicGroupChatToSupergroupChat(chatId);
                        appNotification.show(qsTr("Conversion in progress…"));
                        pageStack.pop(pageStack.find( function(page){ return(page._depth === 0)} ));
                    });
                }
            }

            ModernChatOptionItem {
                width: parent.width
                visible: (chatInformationPage.isBasicGroup || chatInformationPage.isSuperGroup) && chatInformationPage.userIsMember
                title: chatInformationPage.isChannel ? qsTr("Delete channel") : qsTr("Delete and leave group")
                iconSource: "image://theme/icon-m-delete"
                destructive: true
                onClicked: {
                    triggerDeleteOrLeaveChat();
                }
            }

            Item {
                width: parent.width
                height: (chatInformationPage.isBasicGroup || chatInformationPage.isSuperGroup) ? Theme.paddingLarge : 0
            }

            Separator {
                width: parent.width
                color: Theme.primaryColor
                horizontalAlignment: Qt.AlignHCenter
                opacity: (tabViewLoader.status === Loader.Ready && tabViewLoader.item.count > 0) ? 1.0 : 0.0

                Behavior on opacity { FadeAnimation {}}
            }
        }

        Loader {
            id: tabViewLoader
            asynchronous: true
            active: false
            anchors {
                left: parent.left
                right: parent.right
                top: groupInfoItem.bottom
            }
            sourceComponent: Component {
                ChatInformationTabView {
                    id: tabView
                    height: tabView.count > 0 ? chatInformationPage.height - headerItem.height : 0
                }
            }
        }
    }
}
