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
    id: recentActionsPage
    allowedOrientations: Orientation.All

    property var chatId: 0
    property string chatTitle: ""
    property bool loading: false
    property bool loadingMore: false
    property bool canLoadMore: false
    property int pageLimit: 50
    property var nextFromEventId: 0

    function getUserInformation(userId) {
        if (!userId || userId <= 0) {
            return {}
        }
        var user = tdLibWrapper.getUserInformation(userId.toString())
        return (user && user.id) ? user : {}
    }

    function resolveSenderUserId(senderData) {
        var sender = senderData || {}
        if (sender["@type"] === "messageSenderUser" && sender.user_id) {
            return Number(sender.user_id)
        }
        return 0
    }

    function getSenderName(senderData) {
        var sender = senderData || {}
        if (sender["@type"] === "messageSenderUser" && sender.user_id) {
            var user = getUserInformation(Number(sender.user_id))
            var name = Functions.getUserName(user)
            if (name !== "") {
                return name
            }
            if (user.username) {
                return "@" + user.username
            }
            return "#" + sender.user_id
        }
        if (sender["@type"] === "messageSenderChat" && sender.chat_id) {
            var actorChat = tdLibWrapper.getChat(sender.chat_id.toString())
            if (actorChat && actorChat.title) {
                return actorChat.title
            }
            return "#" + sender.chat_id
        }
        return qsTr("Unknown user")
    }

    function getActionText(actionData) {
        var actionType = actionData ? actionData["@type"] : ""
        switch (actionType) {
        case "chatEventMessageEdited":
            return qsTr("edited a message")
        case "chatEventMessageDeleted":
            return qsTr("deleted a message")
        case "chatEventMessagePinned":
            return qsTr("pinned a message")
        case "chatEventMemberJoined":
            return qsTr("joined the chat")
        case "chatEventMemberJoinedByInviteLink":
            return qsTr("joined via invite link")
        case "chatEventMemberLeft":
            return qsTr("left the chat")
        case "chatEventMemberInvited":
            return qsTr("invited a member")
        case "chatEventMemberPromoted":
            return qsTr("updated administrator rights")
        case "chatEventMemberRestricted":
            return qsTr("updated member permissions")
        case "chatEventTitleChanged":
            return qsTr("changed the chat title")
        case "chatEventDescriptionChanged":
            return qsTr("changed the description")
        case "chatEventUsernameChanged":
            return qsTr("changed the public username")
        case "chatEventPhotoChanged":
            return qsTr("changed the photo")
        case "chatEventInvitesToggled":
            return qsTr("changed invite link permissions")
        case "chatEventSignMessagesToggled":
            return qsTr("changed message signing")
        case "chatEventStickerSetChanged":
            return qsTr("changed sticker set")
        case "chatEventLinkedChatChanged":
            return qsTr("changed linked chat")
        case "chatEventSlowModeDelayChanged":
            return qsTr("changed slow mode")
        case "chatEventVideoChatCreated":
            return qsTr("started a video chat")
        case "chatEventVideoChatEnded":
            return qsTr("ended the video chat")
        case "chatEventVideoChatMuteNewParticipantsToggled":
            return qsTr("changed video chat permissions")
        case "chatEventInviteLinkEdited":
            return qsTr("edited an invite link")
        case "chatEventInviteLinkRevoked":
            return qsTr("revoked an invite link")
        case "chatEventInviteLinkDeleted":
            return qsTr("deleted an invite link")
        default:
            return qsTr("performed an action")
        }
    }

    function getEventTargetUserId(actionData) {
        var action = actionData || {}
        if (action.user_id) {
            return Number(action.user_id)
        }
        var memberId = action.member_id || {}
        if (memberId["@type"] === "messageSenderUser" && memberId.user_id) {
            return Number(memberId.user_id)
        }
        return 0
    }

    function getEventTargetName(actionData) {
        var targetUserId = getEventTargetUserId(actionData)
        if (targetUserId <= 0) {
            return ""
        }
        var targetUser = getUserInformation(targetUserId)
        var userName = Functions.getUserName(targetUser)
        if (userName !== "") {
            return userName
        }
        if (targetUser.username) {
            return "@" + targetUser.username
        }
        return "#" + targetUserId
    }

    function getActionDetails(actionData) {
        var action = actionData || {}
        var actionType = action["@type"] || ""
        switch (actionType) {
        case "chatEventTitleChanged":
            return action.new_title ? action.new_title : ""
        case "chatEventDescriptionChanged":
            return action.new_description ? action.new_description : qsTr("Description cleared")
        case "chatEventUsernameChanged":
            return action.new_username ? ("@" + action.new_username) : qsTr("Username removed")
        case "chatEventSlowModeDelayChanged":
            return Number(action.new_slow_mode_delay || 0) > 0
                    ? qsTr("Slow mode: %1s").arg(action.new_slow_mode_delay)
                    : qsTr("Slow mode disabled")
        case "chatEventMemberInvited":
        case "chatEventMemberPromoted":
        case "chatEventMemberRestricted":
            var targetName = getEventTargetName(action)
            return targetName !== "" ? targetName : ""
        case "chatEventLinkedChatChanged":
            if (action.new_linked_chat_id) {
                var linkedChat = tdLibWrapper.getChat(action.new_linked_chat_id.toString())
                return linkedChat && linkedChat.title ? linkedChat.title : ("#" + action.new_linked_chat_id)
            }
            return qsTr("Linked chat removed")
        default:
            return ""
        }
    }

    function findEventIndex(eventId) {
        for (var i = 0; i < eventsModel.count; i += 1) {
            if (eventsModel.get(i).event_id.toString() === eventId.toString()) {
                return i
            }
        }
        return -1
    }

    function appendEvent(eventData) {
        var eventId = eventData.id ? eventData.id.toString() : ""
        if (eventId === "" || eventId === "0" || findEventIndex(eventId) > -1) {
            return
        }
        var memberId = eventData.member_id || {}
        var actorUserId = resolveSenderUserId(memberId)
        var actorUser = getUserInformation(actorUserId)
        var actionData = eventData.action || {}
        var actionText = getActionText(actionData)
        var detailsText = getActionDetails(actionData)
        eventsModel.append({
            event_id: eventId,
            actor_user_id: actorUserId,
            actor_name: getSenderName(memberId),
            actor_user: actorUser,
            action_text: actionText,
            details_text: detailsText,
            date_text: eventData.date ? Functions.getDateTimeTimepoint(eventData.date) : ""
        })
    }

    function loadEvents(loadMore) {
        if (!chatId || loading) {
            return
        }
        if (!loadMore) {
            eventsModel.clear()
            nextFromEventId = 0
            canLoadMore = false
        }
        loading = true
        loadingMore = loadMore
        tdLibWrapper.getChatEventLog(chatId, loadMore ? nextFromEventId : 0, pageLimit)
    }

    function refreshEvents() {
        loadEvents(false)
    }

    PullDownMenu {
        MenuItem {
            text: qsTr("Refresh")
            onClicked: {
                refreshEvents()
            }
        }
    }

    SilicaListView {
        id: eventsView
        anchors.fill: parent
        model: eventsModel
        clip: true
        onAtYEndChanged: {
            if (atYEnd && !loading && canLoadMore && eventsModel.count > 0) {
                loadEvents(true)
            }
        }

        header: Column {
            width: parent.width
            spacing: Theme.paddingSmall

            PageHeader {
                title: qsTr("Recent Actions")
                description: chatTitle ? Emoji.emojify(chatTitle, font.pixelSize) : ""
            }
        }

        ViewPlaceholder {
            enabled: !loading && eventsView.count === 0
            text: qsTr("No recent actions found.")
        }

        delegate: PhotoTextsListItem {
            width: parent.width
            property var actorUserData: actor_user || ({})
            pictureThumbnail {
                photoData: actorUserData.profile_photo ? actorUserData.profile_photo.small : null
            }
            primaryText.text: Emoji.emojify(actor_name, primaryText.font.pixelSize)
            prologSecondaryText.text: ""
            secondaryText.text: Emoji.emojify(Functions.enhanceHtmlEntities(action_text + (details_text !== "" ? (": " + details_text) : "")), secondaryText.font.pixelSize)
            tertiaryText.text: date_text

            onClicked: {
                if (actor_user_id > 0) {
                    tdLibWrapper.createPrivateChat(actor_user_id, "openDirectly")
                }
            }
        }

        footer: Item {
            width: parent.width
            height: (loading && eventsModel.count > 0) || canLoadMore ? Theme.itemSizeLarge : Theme.paddingSmall

            BusyIndicator {
                anchors.centerIn: parent
                running: loading && eventsModel.count > 0
                size: BusyIndicatorSize.Small
            }

            Button {
                anchors.centerIn: parent
                text: qsTr("Load more")
                visible: !loading && canLoadMore && eventsModel.count > 0
                onClicked: {
                    loadEvents(true)
                }
            }
        }

        VerticalScrollDecorator {}
    }

    ListModel {
        id: eventsModel
    }

    Connections {
        target: tdLibWrapper

        onChatEventLogReceived: {
            if (chatId.toString() !== recentActionsPage.chatId.toString()) {
                return
            }
            if (!loadingMore) {
                eventsModel.clear()
            }
            for (var i = 0; i < events.length; i += 1) {
                appendEvent(events[i])
            }
            if (events.length > 0) {
                nextFromEventId = events[events.length - 1].id ? events[events.length - 1].id.toString() : 0
            } else {
                nextFromEventId = "0"
            }
            canLoadMore = events.length >= pageLimit && nextFromEventId.toString() !== "0"
            loading = false
            loadingMore = false
        }

        onUserUpdated: {
            for (var i = 0; i < eventsModel.count; i += 1) {
                if (eventsModel.get(i).actor_user_id.toString() === userId.toString()) {
                    eventsModel.setProperty(i, "actor_user", userInformation)
                    var updatedName = Functions.getUserName(userInformation)
                    if (updatedName !== "") {
                        eventsModel.setProperty(i, "actor_name", updatedName)
                    }
                }
            }
        }

        onErrorReceived: {
            if (loading && extra && extra.toString() === recentActionsPage.chatId.toString()) {
                loading = false
                loadingMore = false
                canLoadMore = false
            }
            Functions.handleErrorMessage(code, message)
        }
    }

    Component.onCompleted: {
        refreshEvents()
    }
}
