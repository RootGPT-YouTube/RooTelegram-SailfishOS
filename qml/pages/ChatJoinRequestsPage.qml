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
    id: chatJoinRequestsPage
    allowedOrientations: Orientation.All

    property var chatId: 0
    property string chatTitle: ""
    property string inviteLink: ""

    property int totalCount: 0
    property bool loading: false
    property bool loadingMore: false
    property string activeQuery: ""
    property var processingByUserId: ({})

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

    function findRequestIndex(userId) {
        for (var i = 0; i < requestsModel.count; i += 1) {
            if (requestsModel.get(i).user_id.toString() === userId.toString()) {
                return i
            }
        }
        return -1
    }

    function getRequestUser(userId) {
        var user = tdLibWrapper.getUserInformation(userId.toString())
        return (user && user.id) ? user : {}
    }

    function appendRequest(requestData) {
        requestsModel.append({
            user_id: requestData.user_id,
            date: requestData.date,
            bio: requestData.bio || "",
            user: getRequestUser(requestData.user_id)
        })
    }

    function prependRequest(requestData) {
        requestsModel.insert(0, {
            user_id: requestData.user_id,
            date: requestData.date,
            bio: requestData.bio || "",
            user: getRequestUser(requestData.user_id)
        })
    }

    function removeRequest(userId) {
        var index = findRequestIndex(userId)
        if (index > -1) {
            requestsModel.remove(index)
        }
    }

    function loadRequests(loadMore) {
        if (loading || !chatId) {
            return
        }
        loading = true
        loadingMore = loadMore
        var offsetRequest = {}
        if (loadMore && requestsModel.count > 0) {
            var lastRequest = requestsModel.get(requestsModel.count - 1)
            offsetRequest = {
                user_id: lastRequest.user_id,
                date: lastRequest.date,
                bio: lastRequest.bio || ""
            }
        }
        tdLibWrapper.getChatJoinRequests(chatId, inviteLink, activeQuery, offsetRequest, 50)
    }

    function refreshRequests() {
        activeQuery = searchField.text
        loadingMore = false
        requestsModel.clear()
        loadRequests(false)
    }

    function handleProcessJoinRequest(userId, approve) {
        if (isProcessing(userId)) {
            return
        }
        setProcessing(userId, true)
        tdLibWrapper.processChatJoinRequest(chatId, userId, approve)
    }

    Timer {
        id: searchTimer
        interval: 450
        repeat: false
        onTriggered: {
            refreshRequests()
        }
    }

    PullDownMenu {
        MenuItem {
            text: qsTr("Refresh")
            onClicked: {
                refreshRequests()
            }
        }
    }

    SilicaFlickable {
        id: contentFlickable
        anchors.fill: parent
        contentHeight: pageHeader.height + searchField.height + requestsView.height

        PageHeader {
            id: pageHeader
            title: qsTr("Join Requests")
            description: chatTitle ? Emoji.emojify(chatTitle, font.pixelSize) : ""
        }

        SearchField {
            id: searchField
            width: parent.width
            anchors.top: pageHeader.bottom
            placeholderText: qsTr("Search requests")
            onTextChanged: {
                searchTimer.restart()
            }
            EnterKey.iconSource: "image://theme/icon-m-enter-close"
            EnterKey.onClicked: {
                focus = false
            }
        }

        SilicaListView {
            id: requestsView
            anchors {
                top: searchField.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            model: requestsModel
            clip: false
            onAtYEndChanged: {
                if (atYEnd && !loading && requestsModel.count > 0 && requestsModel.count < totalCount) {
                    loadRequests(true)
                }
            }

            ViewPlaceholder {
                enabled: !loading && requestsView.count === 0
                text: qsTr("There are no pending join requests.")
            }

            header: Item {
                width: parent.width
                height: loading && requestsModel.count === 0 ? Theme.itemSizeLarge : Theme.paddingSmall
                BusyIndicator {
                    anchors.centerIn: parent
                    running: loading && requestsModel.count === 0
                    size: BusyIndicatorSize.Medium
                }
            }

            delegate: ListItem {
                id: requestDelegate
                width: parent.width
                readonly property var userData: user || ({})
                readonly property bool requestProcessing: chatJoinRequestsPage.isProcessing(user_id)
                readonly property string displayName: Functions.getUserName(userData)
                readonly property string formattedBio: bio !== "" ? Emoji.emojify(bio, Theme.fontSizeExtraSmall) : qsTr("No bio")
                readonly property string identityText: userData.username ? ("@" + userData.username) : ("ID: " + user_id)
                readonly property string requestedText: qsTr("Requested %1").arg(Functions.getDateTimeTimepoint(date))
                contentHeight: requestContentItem.height + requestActionsRow.height + (3 * Theme.paddingSmall)
                height: contentHeight
                openMenuOnPressAndHold: false
                onClicked: {
                    tdLibWrapper.createPrivateChat(user_id, "openDirectly")
                }

                Item {
                    id: requestContentItem
                    width: parent.width - (2 * Theme.horizontalPageMargin)
                    anchors {
                        top: parent.top
                        topMargin: Theme.paddingSmall
                        horizontalCenter: parent.horizontalCenter
                    }
                    height: Math.max(requestAvatar.height, requestTextColumn.height)

                    ProfileThumbnail {
                        id: requestAvatar
                        width: Theme.itemSizeLarge
                        height: width
                        photoData: requestDelegate.userData.profile_photo ? requestDelegate.userData.profile_photo.small : null
                        replacementStringHint: requestDelegate.displayName !== "" ? requestDelegate.displayName : ("#" + user_id)
                    }

                    Column {
                        id: requestTextColumn
                        width: requestContentItem.width - requestAvatar.width - Theme.paddingSmall
                        anchors {
                            left: requestAvatar.right
                            leftMargin: Theme.paddingSmall
                            top: parent.top
                        }
                        spacing: Theme.paddingSmall / 2

                        Label {
                            width: parent.width
                            text: Emoji.emojify(requestDelegate.displayName !== "" ? requestDelegate.displayName : ("#" + user_id), font.pixelSize)
                            textFormat: Text.StyledText
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.primaryColor
                            maximumLineCount: 1
                            truncationMode: TruncationMode.Fade
                        }
                        Label {
                            width: parent.width
                            text: requestDelegate.identityText
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.highlightColor
                            maximumLineCount: 1
                            truncationMode: TruncationMode.Fade
                        }
                        Label {
                            width: parent.width
                            text: requestDelegate.formattedBio
                            textFormat: Text.StyledText
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.primaryColor
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                            truncationMode: TruncationMode.Fade
                        }
                        Label {
                            width: parent.width
                            text: requestDelegate.requestedText
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.secondaryColor
                            maximumLineCount: 1
                            truncationMode: TruncationMode.Fade
                        }
                    }
                }

                Row {
                    id: requestActionsRow
                    width: parent.width - (2 * Theme.horizontalPageMargin)
                    height: Theme.itemSizeMedium
                    anchors {
                        top: requestContentItem.bottom
                        topMargin: Theme.paddingSmall
                        horizontalCenter: parent.horizontalCenter
                    }
                    spacing: Theme.paddingSmall

                    Button {
                        width: (requestActionsRow.width - requestActionsRow.spacing) / 2
                        height: parent.height
                        text: requestDelegate.requestProcessing ? qsTr("Approving…") : qsTr("Approve")
                        enabled: !requestDelegate.requestProcessing
                        onClicked: {
                            chatJoinRequestsPage.handleProcessJoinRequest(user_id, true)
                        }
                    }
                    Button {
                        width: (requestActionsRow.width - requestActionsRow.spacing) / 2
                        height: parent.height
                        text: requestDelegate.requestProcessing ? qsTr("Rejecting…") : qsTr("Reject")
                        enabled: !requestDelegate.requestProcessing
                        onClicked: {
                            chatJoinRequestsPage.handleProcessJoinRequest(user_id, false)
                        }
                    }
                }
            }

            footer: Item {
                width: parent.width
                height: (loading && requestsModel.count > 0) || (requestsModel.count < totalCount) ? Theme.itemSizeLarge : Theme.paddingSmall

                BusyIndicator {
                    anchors.centerIn: parent
                    running: loading && requestsModel.count > 0
                    size: BusyIndicatorSize.Small
                }

                Button {
                    anchors.centerIn: parent
                    text: qsTr("Load more")
                    visible: !loading && requestsModel.count > 0 && requestsModel.count < totalCount
                    onClicked: {
                        loadRequests(true)
                    }
                }
            }

            VerticalScrollDecorator {}
        }
    }

    ListModel {
        id: requestsModel
    }

    Connections {
        target: tdLibWrapper

        onChatJoinRequestsReceived: {
            if (chatId.toString() !== chatJoinRequestsPage.chatId.toString()) {
                return
            }
            if (!loadingMore) {
                requestsModel.clear()
            }
            chatJoinRequestsPage.totalCount = totalCount
            for (var i = 0; i < requests.length; i += 1) {
                appendRequest(requests[i])
            }
            loading = false
            loadingMore = false
        }

        onNewChatJoinRequest: {
            if (chatId.toString() !== chatJoinRequestsPage.chatId.toString() || activeQuery !== "") {
                return
            }
            if (findRequestIndex(request.user_id) < 0) {
                prependRequest(request)
            }
            chatJoinRequestsPage.totalCount = Math.max(chatJoinRequestsPage.totalCount, requestsModel.count)
        }

        onChatPendingJoinRequestsUpdated: {
            if (chatId.toString() === chatJoinRequestsPage.chatId.toString()) {
                chatJoinRequestsPage.totalCount = pendingJoinRequests.total_count
            }
        }

        onUserUpdated: {
            for (var i = 0; i < requestsModel.count; i += 1) {
                if (requestsModel.get(i).user_id.toString() === userId.toString()) {
                    requestsModel.setProperty(i, "user", userInformation)
                }
            }
        }

        onOkReceived: {
            if (!request || request.indexOf("processChatJoinRequest:") !== 0) {
                return
            }
            var parts = request.split(":")
            if (parts.length !== 3 || parts[1].toString() !== chatJoinRequestsPage.chatId.toString()) {
                return
            }
            var processedUserId = parts[2]
            setProcessing(processedUserId, false)
            removeRequest(processedUserId)
            // Il conteggio viene aggiornato da onChatPendingJoinRequestsUpdated
            // (rilanciato anche per i reject dal wrapper C++).
        }

        onErrorReceived: {
            if (extra.indexOf("processChatJoinRequest:") === 0) {
                var parts = extra.split(":")
                if (parts.length === 3 && parts[1].toString() === chatJoinRequestsPage.chatId.toString()) {
                    setProcessing(parts[2], false)
                }
            }
            if (loading && extra.toString() === chatJoinRequestsPage.chatId.toString()) {
                loading = false
                loadingMore = false
            }
            Functions.handleErrorMessage(code, message)
        }
    }

    Component.onCompleted: {
        refreshRequests()
    }
}
