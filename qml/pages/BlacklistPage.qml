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
import "../js/twemoji.js" as Emoji
import "../js/functions.js" as Functions
import "../js/debug.js" as Debug

Page {
    id: blacklistPage
    allowedOrientations: Orientation.All

    readonly property string requestExtra: "blacklistPage:getBlockedMessageSenders"
    property bool loading: false
    property bool loadingMore: false
    property int totalCount: 0
    property int pageLimit: 100
    property var processingByUserId: ({})

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

    function getUserInformationFor(userId) {
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

    function findUserIndex(userId) {
        for (var i = 0; i < blockedModel.count; i += 1) {
            if (blockedModel.get(i).user_id.toString() === userId.toString()) {
                return i
            }
        }
        return -1
    }

    function removeUser(userId) {
        var index = findUserIndex(userId)
        if (index > -1) {
            blockedModel.remove(index)
        }
    }

    function appendOrUpdateSender(senderData) {
        if (!senderData || senderData["@type"] !== "messageSenderUser" || !senderData.user_id) {
            return
        }
        var userId = Number(senderData.user_id)
        var entry = {
            user_id: userId,
            user: getUserInformationFor(userId)
        }
        var existingIndex = findUserIndex(userId)
        if (existingIndex > -1) {
            blockedModel.set(existingIndex, entry)
        } else {
            blockedModel.append(entry)
        }
    }

    function loadBlocked(loadMore) {
        if (loading) {
            return
        }
        if (!loadMore) {
            blockedModel.clear()
        }
        loading = true
        loadingMore = loadMore
        tdLibWrapper.sendRequest({
            "@type": "getBlockedMessageSenders",
            "block_list": { "@type": "blockListMain" },
            "offset": loadMore ? blockedModel.count : 0,
            "limit": pageLimit,
            "@extra": requestExtra
        })
    }

    function triggerUnblock(userId) {
        if (!userId || isProcessing(userId)) {
            return
        }
        setProcessing(userId, true)
        tdLibWrapper.sendRequest({
            "@type": "setMessageSenderBlockList",
            "sender_id": {
                "@type": "messageSenderUser",
                "user_id": userId
            },
            "block_list": null,
            "@extra": "blacklistPage:unblock:" + userId
        })
    }

    PullDownMenu {
        MenuItem {
            text: qsTr("Refresh")
            onClicked: {
                loadBlocked(false)
            }
        }
    }

    SilicaListView {
        id: blockedView
        anchors.fill: parent
        model: blockedModel
        clip: true
        onAtYEndChanged: {
            if (atYEnd && !loading && blockedModel.count > 0 && blockedModel.count < totalCount) {
                loadBlocked(true)
            }
        }

        header: PageHeader {
            title: qsTr("Blacklist")
            description: totalCount > 0 ? qsTr("%1 blocked", "", totalCount).arg(totalCount) : ""
        }

        ViewPlaceholder {
            enabled: !loading && blockedView.count === 0
            text: qsTr("No blocked users.")
            hintText: qsTr("Block a user from their profile to see them here.")
        }

        delegate: PhotoTextsListItem {
            id: blockedDelegate
            width: parent.width
            property var userData: user || ({})
            property bool inProgress: blacklistPage.isProcessing(user_id)

            pictureThumbnail {
                photoData: userData.profile_photo ? userData.profile_photo.small : null
            }
            primaryText.text: Emoji.emojify(Functions.getUserName(userData) !== "" ? Functions.getUserName(userData) : ("#" + user_id), primaryText.font.pixelSize)
            prologSecondaryText.text: getUserIdentity(userData, user_id)
            secondaryText.text: ""
            tertiaryText.text: inProgress ? qsTr("Unblocking…") : ""

            openMenuOnPressAndHold: true
            menu: ContextMenu {
                MenuItem {
                    text: blockedDelegate.inProgress ? qsTr("Unblocking…") : qsTr("Unblock")
                    enabled: !blockedDelegate.inProgress
                    onClicked: {
                        blacklistPage.triggerUnblock(user_id)
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
            height: (loading && blockedModel.count > 0) || (blockedModel.count > 0 && blockedModel.count < totalCount) ? Theme.itemSizeLarge : Theme.paddingSmall

            BusyIndicator {
                anchors.centerIn: parent
                running: loading && blockedModel.count > 0
                size: BusyIndicatorSize.Small
            }

            Button {
                anchors.centerIn: parent
                text: qsTr("Load more")
                visible: !loading && blockedModel.count > 0 && blockedModel.count < totalCount
                onClicked: {
                    loadBlocked(true)
                }
            }
        }

        VerticalScrollDecorator {}
    }

    BusyLabel {
        text: qsTr("Loading blocked users...")
        running: loading && blockedModel.count === 0
    }

    ListModel {
        id: blockedModel
    }

    Connections {
        target: tdLibWrapper

        onMessageSendersReceived: {
            if (extra !== requestExtra) {
                return
            }
            totalCount = totalUsers
            for (var i = 0; i < senders.length; i += 1) {
                appendOrUpdateSender(senders[i])
            }
            loading = false
            loadingMore = false
        }

        onUserUpdated: {
            for (var i = 0; i < blockedModel.count; i += 1) {
                if (blockedModel.get(i).user_id.toString() === userId.toString()) {
                    blockedModel.setProperty(i, "user", userInformation)
                }
            }
        }

        onOkReceived: {
            var requestText = request !== undefined && request !== null ? request.toString() : ""
            if (requestText.indexOf("blacklistPage:unblock:") !== 0) {
                return
            }
            var parts = requestText.split(":")
            if (parts.length !== 3) {
                return
            }
            var unblockedUserId = parts[2]
            setProcessing(unblockedUserId, false)
            removeUser(unblockedUserId)
            totalCount = Math.max(0, totalCount - 1)
            appNotification.show(qsTr("User has been unblocked."))
        }

        onErrorReceived: {
            var extraText = extra !== undefined && extra !== null ? extra.toString() : ""
            if (extraText.indexOf("blacklistPage:unblock:") === 0) {
                var parts = extraText.split(":")
                if (parts.length === 3) {
                    setProcessing(parts[2], false)
                }
                Functions.handleErrorMessage(code, message)
                return
            }
            if (extraText === requestExtra) {
                loading = false
                loadingMore = false
                Functions.handleErrorMessage(code, message)
            }
        }
    }

    Component.onCompleted: {
        loadBlocked(false)
    }
}
