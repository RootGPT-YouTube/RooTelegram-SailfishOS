/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), which is
    licensed under the GNU General Public License v3.0. The original
    license is available at:
    https://github.com/Wunderfitz/harbour-fernschreiber/blob/master/LICENSE
*/
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/functions.js" as Functions
import "../js/twemoji.js" as Emoji

Page {
    id: addChatMembersPage
    allowedOrientations: Orientation.All

    property var chatId: 0
    property string chatTitle: ""
    property string groupType: ""       // "basic" or "super"
    property string targetGroupId: ""

    property bool contactsLoaded: false
    property bool membersLoaded: false
    property bool isLoading: true
    property var rawContacts: []        // JS array of plain contact objects
    property var existingMemberIds: ({})
    property var addedByUserId: ({})
    property var processingByUserId: ({})

    readonly property string contactsExtra: "addChatMembersPage:contacts:" + chatId
    readonly property string membersExtra: "addChatMembersPage:members:" + chatId

    function resetFocus() {
        contactsSearchField.focus = false;
        addChatMembersPage.focus = true;
    }

    function getMemberKey(userId) {
        return userId !== undefined && userId !== null ? userId.toString() : "";
    }

    function isExistingMember(userId) {
        return !!existingMemberIds[getMemberKey(userId)];
    }

    function isAdded(userId) {
        return !!addedByUserId[getMemberKey(userId)];
    }

    function isProcessing(userId) {
        return !!processingByUserId[getMemberKey(userId)];
    }

    function isMember(userId) {
        return isExistingMember(userId) || isAdded(userId);
    }

    function setMapValue(propName, userId, value) {
        var key = getMemberKey(userId);
        if (!key) {
            return;
        }
        var current = addChatMembersPage[propName] || ({});
        var state = {};
        for (var entry in current) {
            state[entry] = current[entry];
        }
        if (value) {
            state[key] = true;
        } else {
            delete state[key];
        }
        addChatMembersPage[propName] = state;
    }

    function setProcessing(userId, processing) {
        setMapValue("processingByUserId", userId, processing);
    }

    function setAddedFlag(userId, added) {
        setMapValue("addedByUserId", userId, added);
    }

    function setExistingMember(userId, isMember) {
        setMapValue("existingMemberIds", userId, isMember);
    }

    function lowerTitle(entry) {
        return ((entry.title || "") + "").toLowerCase();
    }

    function rebuildSortedModel() {
        sortedContactsModel.clear();
        if (!rawContacts || rawContacts.length === 0) {
            isLoading = !(contactsLoaded && membersLoaded);
            return;
        }
        var members = [];
        var others = [];
        for (var i = 0; i < rawContacts.length; i++) {
            var entry = rawContacts[i];
            if (isMember(entry.user_id)) {
                members.push(entry);
            } else {
                others.push(entry);
            }
        }
        var byTitle = function(a, b) {
            var ta = lowerTitle(a);
            var tb = lowerTitle(b);
            return ta < tb ? -1 : (ta > tb ? 1 : 0);
        };
        members.sort(byTitle);
        others.sort(byTitle);
        for (var m = 0; m < members.length; m++) {
            sortedContactsModel.append(members[m]);
        }
        for (var o = 0; o < others.length; o++) {
            sortedContactsModel.append(others[o]);
        }
        isLoading = !(contactsLoaded && membersLoaded);
    }

    function buildRawContactsFromIds(userIds) {
        var arr = [];
        for (var i = 0; i < userIds.length; i++) {
            var idStr = userIds[i].toString();
            var u = tdLibWrapper.getUserInformation(idStr);
            if (!u || !u.id) {
                continue;
            }
            var usernames = u.usernames || {};
            var displayName = ((u.first_name || "") + " " + (u.last_name || "")).replace(/^\s+|\s+$/g, "");
            if (displayName === "") {
                displayName = usernames.editable_username || (usernames.active_usernames && usernames.active_usernames[0]) || u.username || ("#" + u.id);
            }
            arr.push({
                user_id: u.id,
                title: displayName,
                username: usernames.editable_username || (usernames.active_usernames && usernames.active_usernames.length > 0 ? usernames.active_usernames[0] : "") || u.username || "",
                photo_small: u.profile_photo ? u.profile_photo.small : null,
                user_status: u.status ? (u.status["@type"] || "") : "",
                user_last_online: u.status && u.status.was_online !== undefined ? u.status.was_online : 0
            });
        }
        rawContacts = arr;
        contactsLoaded = true;
        rebuildSortedModel();
    }

    function loadContacts() {
        tdLibWrapper.sendRequest({
            "@type": "getContacts",
            "@extra": contactsExtra
        });
    }

    function captureBasicMembersFromInfo(groupFullInfo) {
        if (!groupFullInfo || !groupFullInfo.members) {
            membersLoaded = true;
            rebuildSortedModel();
            return;
        }
        var map = {};
        for (var i = 0; i < groupFullInfo.members.length; i++) {
            var member = groupFullInfo.members[i];
            var mid = member && member.member_id;
            if (mid && mid.user_id) {
                map[getMemberKey(mid.user_id)] = true;
            }
        }
        existingMemberIds = map;
        membersLoaded = true;
        rebuildSortedModel();
    }

    function captureSuperMembers(members) {
        var map = {};
        for (var key in existingMemberIds) {
            map[key] = existingMemberIds[key];
        }
        if (members) {
            for (var i = 0; i < members.length; i++) {
                var mid = members[i] && members[i].member_id;
                if (mid && mid.user_id) {
                    map[getMemberKey(mid.user_id)] = true;
                }
            }
        }
        existingMemberIds = map;
        membersLoaded = true;
        rebuildSortedModel();
    }

    function resolveGroupAndLoadMembers() {
        var chat = tdLibWrapper.getChat(chatId.toString());
        if (!chat || !chat.type) {
            membersLoaded = true;
            rebuildSortedModel();
            return;
        }
        var t = chat.type["@type"];
        if (t === "chatTypeBasicGroup") {
            groupType = "basic";
            targetGroupId = chat.type.basic_group_id.toString();
            var basic = tdLibWrapper.getBasicGroup(targetGroupId);
            if (basic && basic.members && basic.members.length > 0) {
                captureBasicMembersFromInfo(basic);
            }
            tdLibWrapper.getGroupFullInfo(targetGroupId, false);
        } else if (t === "chatTypeSupergroup") {
            groupType = "super";
            targetGroupId = chat.type.supergroup_id.toString();
            tdLibWrapper.getSupergroupMembers(targetGroupId, 200, 0, "supergroupMembersFilterRecent", membersExtra);
        } else {
            membersLoaded = true;
            rebuildSortedModel();
        }
    }

    function inviteMember(userId) {
        if (!chatId || !userId || isProcessing(userId) || isMember(userId)) {
            return;
        }
        setProcessing(userId, true);
        tdLibWrapper.sendRequest({
            "@type": "setChatMemberStatus",
            "chat_id": chatId,
            "member_id": {
                "@type": "messageSenderUser",
                "user_id": userId
            },
            "status": {
                "@type": "chatMemberStatusMember"
            },
            "@extra": "addChatMember:" + chatId + ":" + userId
        });
    }

    ListModel {
        id: sortedContactsModel
    }

    PullDownMenu {
        MenuItem {
            text: qsTr("Refresh")
            onClicked: {
                contactsLoaded = false;
                membersLoaded = false;
                isLoading = true;
                loadContacts();
                resolveGroupAndLoadMembers();
            }
        }
    }

    PageHeader {
        id: addMembersPageHeader
        title: qsTr("Add Members")
        description: chatTitle ? Emoji.emojify(chatTitle, font.pixelSize) : ""
    }

    SearchField {
        id: contactsSearchField
        anchors.top: addMembersPageHeader.bottom
        width: parent.width
        placeholderText: qsTr("Search a contact...")
        active: !addChatMembersPage.isLoading
        visible: !addChatMembersPage.isLoading
        opacity: visible ? 1 : 0
        Behavior on opacity { FadeAnimation {} }
        EnterKey.iconSource: "image://theme/icon-m-enter-close"
        EnterKey.onClicked: {
            resetFocus();
        }
    }

    SilicaListView {
        id: contactsListView
        anchors {
            top: contactsSearchField.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        clip: true
        visible: !addChatMembersPage.isLoading
        opacity: visible ? 1 : 0
        Behavior on opacity { FadeAnimation {} }
        model: sortedContactsModel

        ViewPlaceholder {
            y: Theme.paddingLarge
            enabled: contactsListView.count === 0
            text: (contactsSearchField.text.length > 0)
                  ? qsTr("No contacts found.")
                  : qsTr("You don't have any contacts.")
        }

        delegate: ListItem {
            id: contactRow
            width: ListView.view.width
            contentHeight: Theme.itemSizeLarge

            property int targetUserId: Number(user_id)
            property bool requestInProgress: !!addChatMembersPage.processingByUserId[targetUserId.toString()]
            property bool alreadyMember: !!addChatMembersPage.existingMemberIds[targetUserId.toString()]
                                          || !!addChatMembersPage.addedByUserId[targetUserId.toString()]
            property bool filterMatches: {
                var query = contactsSearchField.text.toLowerCase();
                if (query.length === 0) {
                    return true;
                }
                var hay = ((title || "") + " " + (username || "")).toLowerCase();
                return hay.indexOf(query) > -1;
            }

            visible: filterMatches
            height: filterMatches ? Theme.itemSizeLarge : 0
            enabled: !requestInProgress && !alreadyMember

            Icon {
                id: memberCheck
                source: alreadyMember ? "image://theme/icon-s-accept?#28a745" : ""
                width: Theme.iconSizeSmall
                height: Theme.iconSizeSmall
                visible: alreadyMember
                anchors {
                    left: parent.left
                    leftMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                }
            }

            ProfileThumbnail {
                id: avatar
                photoData: typeof photo_small !== "undefined" && photo_small ? photo_small : ({})
                replacementStringHint: title
                width: Theme.itemSizeMedium
                height: Theme.itemSizeMedium
                radius: width / 2
                anchors {
                    left: parent.left
                    leftMargin: Theme.paddingMedium + Theme.iconSizeSmall + Theme.paddingSmall
                    verticalCenter: parent.verticalCenter
                }
            }

            Column {
                anchors {
                    left: avatar.right
                    leftMargin: Theme.paddingMedium
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.paddingSmall / 2

                Label {
                    width: parent.width
                    text: title ? Emoji.emojify(title, font.pixelSize, "../js/emoji/") : "?"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.primaryColor
                    truncationMode: TruncationMode.Fade
                    textFormat: Text.StyledText
                }

                Label {
                    width: parent.width
                    text: "@" + (username !== "" ? username : user_id)
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.highlightColor
                    truncationMode: TruncationMode.Fade
                }

                Label {
                    width: parent.width
                    text: contactRow.requestInProgress
                          ? qsTr("Adding…")
                          : (contactRow.alreadyMember
                             ? qsTr("Added")
                             : Functions.getChatPartnerStatusText(user_status, user_last_online))
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: contactRow.alreadyMember ? "#28a745" : Theme.secondaryColor
                    truncationMode: TruncationMode.Fade
                }
            }

            onClicked: {
                if (!contactRow.alreadyMember && !contactRow.requestInProgress) {
                    addChatMembersPage.inviteMember(targetUserId);
                }
            }
        }

        VerticalScrollDecorator {}
    }

    Column {
        opacity: visible ? 1 : 0
        Behavior on opacity { FadeAnimation {} }
        visible: addChatMembersPage.isLoading
        width: parent.width
        height: loadingLabel.height + loadingBusyIndicator.height + Theme.paddingMedium
        spacing: Theme.paddingMedium
        anchors.verticalCenter: parent.verticalCenter

        InfoLabel {
            id: loadingLabel
            text: qsTr("Loading contacts...")
        }

        BusyIndicator {
            id: loadingBusyIndicator
            anchors.horizontalCenter: parent.horizontalCenter
            running: addChatMembersPage.isLoading
            size: BusyIndicatorSize.Large
        }
    }

    Connections {
        target: tdLibWrapper

        onUsersReceived: {
            if (extra === contactsExtra) {
                buildRawContactsFromIds(userIds);
            }
        }

        onBasicGroupFullInfoReceived: {
            if (groupType === "basic" && targetGroupId === groupId) {
                captureBasicMembersFromInfo(groupFullInfo);
            }
        }

        onBasicGroupFullInfoUpdated: {
            if (groupType === "basic" && targetGroupId === groupId) {
                captureBasicMembersFromInfo(groupFullInfo);
            }
        }

        onChatMembersReceived: {
            if (extra === membersExtra) {
                captureSuperMembers(members);
            }
        }

        onOkReceived: {
            if (!request || request.indexOf("addChatMember:") !== 0) {
                return;
            }
            var parts = request.split(":");
            if (parts.length !== 3 || parts[1].toString() !== chatId.toString()) {
                return;
            }
            var invitedUserId = parts[2];
            setProcessing(invitedUserId, false);
            setAddedFlag(invitedUserId, true);
            rebuildSortedModel();
            appNotification.show(qsTr("Member added."));
        }

        onErrorReceived: {
            if (!extra) {
                return;
            }
            if (extra.indexOf("addChatMember:") === 0) {
                var parts = extra.split(":");
                if (parts.length === 3 && parts[1].toString() === chatId.toString()) {
                    setProcessing(parts[2], false);
                }
                Functions.handleErrorMessage(code, message);
                return;
            }
            if (extra === membersExtra) {
                membersLoaded = true;
                rebuildSortedModel();
                return;
            }
            if (extra === contactsExtra) {
                contactsLoaded = true;
                rebuildSortedModel();
                return;
            }
        }
    }

    Component.onCompleted: {
        loadContacts();
        resolveGroupAndLoadMembers();
    }
}
