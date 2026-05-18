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
    id: supergroupMembersPage
    allowedOrientations: Orientation.All

    property var chatId: 0
    property string chatTitle: ""
    property string supergroupId: ""
    property string mode: "administrators" // administrators | banned

    property bool loading: false
    property bool loadingMore: false
    property int totalCount: 0
    property int pageLimit: 200
    property string requestExtra: ""
    property var processingByUserId: ({})

    function isBannedMode() {
        return mode === "banned"
    }

    function getPageTitle() {
        return isBannedMode() ? qsTr("Removed Users") : qsTr("Administrators")
    }

    function getFilterType() {
        return isBannedMode() ? "supergroupMembersFilterBanned" : "supergroupMembersFilterAdministrators"
    }

    function getRequestExtra() {
        if (requestExtra === "") {
            requestExtra = "supergroupMembers:" + chatId + ":" + mode
        }
        return requestExtra
    }

    function resolveSupergroupId() {
        if (supergroupId !== "") {
            return supergroupId
        }
        if (!chatId) {
            return ""
        }
        var chat = tdLibWrapper.getChat(chatId.toString())
        if (chat && chat.type && chat.type["@type"] === "chatTypeSupergroup") {
            supergroupId = chat.type.supergroup_id.toString()
        }
        return supergroupId
    }

    function getUserIdentity(userData, userId) {
        if (!userData) {
            return "ID: " + userId
        }
        if (userData.username) {
            return "@" + userData.username
        }
        if (userData.usernames && userData.usernames.editable_username) {
            return "@" + userData.usernames.editable_username
        }
        if (userData.usernames && userData.usernames.active_usernames && userData.usernames.active_usernames.length > 0) {
            return "@" + userData.usernames.active_usernames[0]
        }
        return "ID: " + userId
    }

    function getUserInformation(userId) {
        if (!userId || userId <= 0) {
            return {}
        }
        var user = tdLibWrapper.getUserInformation(userId.toString())
        return (user && user.id) ? user : {}
    }

    function setProcessing(userId, processing) {
        var state = {}
        for (var key in processingByUserId) {
            state[key] = processingByUserId[key]
        }
        if (processing) {
            state[userId] = true
        } else {
            delete state[userId]
        }
        processingByUserId = state
    }

    function isProcessing(userId) {
        return !!processingByUserId[userId]
    }

    function findMemberIndex(userId) {
        for (var i = 0; i < membersModel.count; i += 1) {
            if (membersModel.get(i).user_id.toString() === userId.toString()) {
                return i
            }
        }
        return -1
    }

    function removeMember(userId) {
        var index = findMemberIndex(userId)
        if (index > -1) {
            membersModel.remove(index)
        }
    }

    function getStatusText(statusData) {
        var status = statusData || {}
        var statusType = status["@type"] || ""
        if (isBannedMode()) {
            var bannedUntilDate = Number(status.banned_until_date || 0)
            if (bannedUntilDate > 0) {
                return qsTr("Banned until %1").arg(Functions.getDateTimeTimepoint(bannedUntilDate))
            }
            return qsTr("Banned")
        }
        var statusText = Functions.getChatMemberStatusText(statusType)
        var customTitle = status.custom_title ? Emoji.emojify(status.custom_title, Theme.fontSizeExtraSmall) : ""
        if (statusText !== "" && customTitle !== "") {
            return statusText + ", " + customTitle
        }
        return statusText !== "" ? statusText : customTitle
    }

    function appendOrUpdateMember(memberData) {
        var memberId = memberData.member_id || {}
        if (memberId["@type"] !== "messageSenderUser" || !memberId.user_id) {
            return
        }
        var userId = Number(memberId.user_id)
        var entry = {
            user_id: userId,
            user: getUserInformation(userId),
            status: memberData.status || {},
            joined_chat_date: Number(memberData.joined_chat_date || 0)
        }
        var existingIndex = findMemberIndex(userId)
        if (existingIndex > -1) {
            membersModel.set(existingIndex, entry)
        } else {
            membersModel.append(entry)
        }
    }

    function loadMembers(loadMore) {
        var resolvedSupergroupId = resolveSupergroupId()
        if (resolvedSupergroupId === "") {
            appNotification.show(qsTr("Unable to load members for this chat."))
            return
        }
        if (loading) {
            return
        }
        if (!loadMore) {
            membersModel.clear()
        }
        loading = true
        loadingMore = loadMore
        tdLibWrapper.getSupergroupMembers(
                    resolvedSupergroupId,
                    pageLimit,
                    loadMore ? membersModel.count : 0,
                    getFilterType(),
                    getRequestExtra())
    }

    function refreshMembers() {
        loadMembers(false)
    }

    function triggerUnban(userId) {
        if (!isBannedMode() || !chatId || !userId || isProcessing(userId)) {
            return
        }
        setProcessing(userId, true)
        tdLibWrapper.unbanChatMember(chatId, userId)
    }

    PullDownMenu {
        MenuItem {
            text: qsTr("Refresh")
            onClicked: {
                refreshMembers()
            }
        }
    }

    SilicaListView {
        id: membersView
        anchors.fill: parent
        model: membersModel
        clip: true
        onAtYEndChanged: {
            if (atYEnd && !loading && membersModel.count > 0 && membersModel.count < totalCount) {
                loadMembers(true)
            }
        }

        header: Column {
            width: parent.width
            spacing: Theme.paddingSmall

            PageHeader {
                title: getPageTitle()
                description: chatTitle ? Emoji.emojify(chatTitle, font.pixelSize) : ""
            }
        }

        ViewPlaceholder {
            enabled: !loading && membersView.count === 0
            text: isBannedMode()
                  ? qsTr("There are no removed users.")
                  : qsTr("No administrators found.")
        }

        delegate: PhotoTextsListItem {
            id: memberDelegate
            width: parent.width
            property var userData: user || ({})
            property bool inProgress: supergroupMembersPage.isProcessing(user_id)

            pictureThumbnail {
                photoData: userData.profile_photo ? userData.profile_photo.small : null
            }
            primaryText.text: Emoji.emojify(Functions.getUserName(userData) !== "" ? Functions.getUserName(userData) : ("#" + user_id), primaryText.font.pixelSize)
            prologSecondaryText.text: getUserIdentity(userData, user_id)
            secondaryText.text: getStatusText(status)
            tertiaryText.text: joined_chat_date > 0 ? qsTr("Joined %1").arg(Functions.getDateTimeTimepoint(joined_chat_date)) : ""

            openMenuOnPressAndHold: isBannedMode()
            menu: ContextMenu {
                MenuItem {
                    text: memberDelegate.inProgress ? qsTr("Unbanning…") : qsTr("Unban")
                    enabled: !memberDelegate.inProgress
                    onClicked: {
                        supergroupMembersPage.triggerUnban(user_id)
                    }
                }
            }

            onClicked: {
                if (user_id > 0) {
                    tdLibWrapper.createPrivateChat(user_id, "openDirectly")
                }
            }
        }

        footer: Item {
            width: parent.width
            height: (loading && membersModel.count > 0) || (membersModel.count > 0 && membersModel.count < totalCount) ? Theme.itemSizeLarge : Theme.paddingSmall

            BusyIndicator {
                anchors.centerIn: parent
                running: loading && membersModel.count > 0
                size: BusyIndicatorSize.Small
            }

            Button {
                anchors.centerIn: parent
                text: qsTr("Load more")
                visible: !loading && membersModel.count > 0 && membersModel.count < totalCount
                onClicked: {
                    loadMembers(true)
                }
            }
        }

        VerticalScrollDecorator {}
    }

    ListModel {
        id: membersModel
    }

    Connections {
        target: tdLibWrapper

        onChatMembersReceived: {
            if (extra !== getRequestExtra()) {
                return
            }
            totalCount = totalMembers
            for (var i = 0; i < members.length; i += 1) {
                appendOrUpdateMember(members[i])
            }
            loading = false
            loadingMore = false
        }

        onUserUpdated: {
            for (var i = 0; i < membersModel.count; i += 1) {
                if (membersModel.get(i).user_id.toString() === userId.toString()) {
                    membersModel.setProperty(i, "user", userInformation)
                }
            }
        }

        onOkReceived: {
            if (!request.startsWith("unbanChatMember:")) {
                return
            }
            var parts = request.split(":")
            if (parts.length !== 3 || parts[1].toString() !== chatId.toString()) {
                return
            }
            var unbannedUserId = parts[2]
            setProcessing(unbannedUserId, false)
            removeMember(unbannedUserId)
            totalCount = Math.max(0, totalCount - 1)
            appNotification.show(qsTr("User has been unbanned."))
        }

        onErrorReceived: {
            if (extra && extra.startsWith("unbanChatMember:")) {
                var parts = extra.split(":")
                if (parts.length === 3 && parts[1].toString() === chatId.toString()) {
                    setProcessing(parts[2], false)
                }
            }
            if (loading && extra && extra.toString() === getRequestExtra()) {
                loading = false
                loadingMore = false
            }
            Functions.handleErrorMessage(code, message)
        }
    }

    Component.onCompleted: {
        refreshMembers()
    }
}
