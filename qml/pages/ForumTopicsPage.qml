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
import QtGraphicalEffects 1.0
import WerkWolf.RooTelegram 1.0
import "../components"
import "../js/functions.js" as Functions
import "../js/twemoji.js" as Emoji

Page {
    id: forumTopicsPage
    allowedOrientations: Orientation.All

    property var chatInformation
    property bool loading: false
    property bool loaded: false
    // Tema Neon (cyberpunk) vs Silica base. In Silica niente glow/corsivo neon.
    readonly property bool neon: appSettings.useNeonTheme
    // Thread ID dell'ultimo topic visitato (per il reload ritardato)
    property int lastViewedThreadId: 0
    // Se true, al prossimo refresh topics proviamo a sincronizzare anche il badge chat in home.
    property bool syncHomeUnreadOnNextLoad: false

    property string topicEditorMode: ""
    property var topicEditorThreadId: 0
    property bool topicEditorBusy: false
    property string topicEditorNewName: ""
    // Traccia l'ultimo topic rinominato per evitare il flicker
    property int lastRenamedTopicId: 0
    property double lastRenamedTime: 0
    property bool actionBusy: false
    // Nome del campo id nelle richieste sui topic. TDLib 1.8.62 (quello che
    // impacchettiamo su tutte e 3 le arch) vuole "forum_topic_id"; il vecchio
    // "message_thread_id" resta come compatibilita' per versioni piu' datate.
    // Vengono inviati ENTRAMBI (vedi assignTopicIdentifier): TDLib ignora le
    // chiavi che non conosce, quindi mandarli insieme non costa nulla.
    property string topicRequestIdField: "forum_topic_id"

    // Topic che hanno restituito "Invalid forum topic identifier specified".
    // Marcandoli evitiamo burst ripetuti di getForumTopic ogni volta che TDLib
    // ci pusha updateForumTopic per quegli ID. Reset alla riapertura della pagina.
    // NOTA: fino alla 2.9 qui ci finivano TUTTI i topic al primo caricamento,
    // perche' mandavamo solo "message_thread_id" e TDLib rispondeva 400 per
    // ognuno: non erano affatto "stali", era la nostra richiesta a essere
    // malformata. Era la causa dei contatori che non si azzeravano.
    property var failedTopicIds: ({})

    function getChatId() {
        return (chatInformation && chatInformation.id !== undefined) ? Number(chatInformation.id) : 0
    }

    function getSupergroupId() {
        if (chatInformation && chatInformation.type && chatInformation.type["@type"] === "chatTypeSupergroup") {
            return Number(chatInformation.type.supergroup_id || 0)
        }
        var chatId = getChatId()
        if (!chatId) {
            return 0
        }
        var chat = tdLibWrapper.getChat(chatId.toString())
        if (chat && chat.type && chat.type["@type"] === "chatTypeSupergroup") {
            return Number(chat.type.supergroup_id || 0)
        }
        return 0
    }

    function getSupergroupInfo() {
        var supergroupId = getSupergroupId()
        if (!supergroupId) {
            return {}
        }
        return tdLibWrapper.getSuperGroup(supergroupId.toString()) || {}
    }

    function getSupergroupStatus() {
        var supergroup = getSupergroupInfo()
        return supergroup.status || {}
    }
    function getStatusFlag(statusData, flagName) {
        var status = statusData || getSupergroupStatus()
        if (!status || !flagName) {
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
    function requestForumTopicDetails(topicId) {
        var chatId = getChatId()
        var numericTopicId = Number(topicId)
        if (!chatId || !numericTopicId || numericTopicId <= 0) {
            return
        }
        // Skip dei topic noti come stali (vedi failedTopicIds): TDLib pusha
        // updateForumTopic anche per topic eliminati lato server e altrimenti
        // re-faremmo il round-trip per ricevere lo stesso errore 400.
        if (failedTopicIds[String(numericTopicId)]) {
            return
        }
        var requestObject = {
            "@type": "getForumTopic",
            "chat_id": chatId,
            "@extra": "getForumTopic:" + chatId + ":" + numericTopicId
        }
        if (!assignTopicIdentifier(requestObject, numericTopicId)) {
            return
        }
        tdLibWrapper.sendRequest(requestObject)
    }

    function canCreateTopicsPermission() {
        if (chatInformation && chatInformation.permissions && chatInformation.permissions.can_create_topics === true) {
            return true
        }
        var chatId = getChatId()
        if (!chatId) {
            return false
        }
        var cachedChat = tdLibWrapper.getChat(chatId.toString()) || {}
        var cachedPermissions = cachedChat.permissions || {}
        return cachedPermissions.can_create_topics === true
    }

    function canManageTopics() {
        var status = getSupergroupStatus()
        return status["@type"] === "chatMemberStatusCreator"
            || status["@type"] === "chatMemberStatusAdministrator"
            || getStatusFlag(status, "can_manage_topics")
    }

    function canDisableTopics() {
        var status = getSupergroupStatus()
        return status["@type"] === "chatMemberStatusCreator"
    }

    function parseForumRequest(requestString) {
        if (!requestString || requestString.indexOf("forumTopics:") !== 0) {
            return []
        }
        var parts = requestString.split(":")
        if (parts.length < 3) {
            return []
        }
        if (parts[2].toString() !== getChatId().toString()) {
            return []
        }
        return parts
    }
    function assignTopicIdentifier(target, topicId) {
        var idValue = Number(topicId)
        if (!idValue || idValue <= 0) {
            return false
        }
        // Entrambe le chiavi: TDLib ignora quella che non conosce. Lo stesso
        // fa gia' il C++ (TDLibWrapper::getForumTopic e getForumTopics).
        target[topicRequestIdField] = idValue
        target["forum_topic_id"] = idValue
        target["message_thread_id"] = idValue
        return true
    }
    function switchTopicRequestIdField(errorMessage) {
        var messageText = (errorMessage || "").toLowerCase()
        var mentionsForumId = messageText.indexOf("forum_topic_id") !== -1
        var mentionsThreadId = messageText.indexOf("message_thread_id") !== -1
        if (mentionsForumId && topicRequestIdField !== "forum_topic_id") {
            topicRequestIdField = "forum_topic_id"
            return true
        }
        if (mentionsThreadId && topicRequestIdField !== "message_thread_id") {
            topicRequestIdField = "message_thread_id"
            return true
        }
        return false
    }

    function numberFromCandidates(candidates, fallbackValue) {
        for (var i = 0; i < candidates.length; i++) {
            var value = candidates[i]
            if (value === undefined || value === null || value === "") {
                continue
            }
            var numericValue = Number(value)
            if (!isNaN(numericValue)) {
                return numericValue
            }
        }
        return fallbackValue
    }

    function topicCounter(topic, info, fieldNames) {
        var candidates = []
        for (var i = 0; i < fieldNames.length; i++) {
            var fieldName = fieldNames[i]
            candidates.push(topic ? topic[fieldName] : undefined)
            candidates.push(info ? info[fieldName] : undefined)
        }
        return numberFromCandidates(candidates, 0)
    }

    function messageThreadIdFromTopic(topic, info) {
        return numberFromCandidates([
            info ? info.message_thread_id : undefined,
            topic ? topic.message_thread_id : undefined,
            topic && topic.last_message ? topic.last_message.message_thread_id : undefined,
            info ? info.thread_id : undefined,
            topic ? topic.thread_id : undefined,
            info ? info.forum_topic_id : undefined,
            topic ? topic.forum_topic_id : undefined,
            topic ? topic.id : undefined
        ], 0)
    }
    function forumTopicIdFromTopic(topic, info) {
        return numberFromCandidates([
            info ? info.forum_topic_id : undefined,
            topic ? topic.forum_topic_id : undefined,
            topic ? topic.id : undefined,
            info ? info.message_thread_id : undefined,
            topic ? topic.message_thread_id : undefined,
            topic && topic.last_message ? topic.last_message.message_thread_id : undefined
        ], 0)
    }

    function applyTopicDetails(topic) {
        var info = topic && topic.info ? topic.info : {}
        var threadId = messageThreadIdFromTopic(topic, info)
        var forumTopicId = forumTopicIdFromTopic(topic, info)
        if (!threadId && !forumTopicId) {
            return
        }
        var unreadCount = topicCounter(topic, info, ["unread_count", "unreadCount", "unread_message_count", "unread_messages_count"])
        var unreadMentionCount = topicCounter(topic, info, ["unread_mention_count", "unread_mentions_count", "unreadMentionCount", "unreadMentionsCount"])
        var unreadReactionCount = topicCounter(topic, info, ["unread_reaction_count", "unread_reactions_count", "unreadReactionCount", "unreadReactionsCount"])
        var lastReadInboxMessageId = topicCounter(topic, info, ["last_read_inbox_message_id", "read_inbox_max_id", "lastReadInboxMessageId"])
        var lastReadOutboxMessageId = topicCounter(topic, info, ["last_read_outbox_message_id", "read_outbox_max_id", "lastReadOutboxMessageId"])
        var lastMsg = topic && topic.last_message ? topic.last_message : {}
        var lastSender = lastMsg && lastMsg.sender_id ? lastMsg.sender_id : {}
        var lastContent = lastMsg && lastMsg.content ? lastMsg.content : {}
        for (var i = 0; i < topicsModel.count; i++) {
            var modelTopic = topicsModel.get(i)
            var sameThread = threadId > 0 && modelTopic.threadId === threadId
            var sameForumTopic = forumTopicId > 0 && modelTopic.forumTopicId === forumTopicId
            if (!sameThread && !sameForumTopic) {
                continue
            }
            if (threadId > 0) topicsModel.setProperty(i, "threadId", threadId)
            if (forumTopicId > 0) topicsModel.setProperty(i, "forumTopicId", forumTopicId)
            if (info.name) topicsModel.setProperty(i, "topicName", info.name)
            if (info.is_closed !== undefined) topicsModel.setProperty(i, "topicIsClosed", info.is_closed)
            if (info.is_pinned !== undefined) topicsModel.setProperty(i, "isPinned", info.is_pinned)
            topicsModel.setProperty(i, "unreadCount", unreadCount)
            topicsModel.setProperty(i, "unreadMentionCount", unreadMentionCount)
            topicsModel.setProperty(i, "unreadReactionCount", unreadReactionCount)
            topicsModel.setProperty(i, "lastReadInboxMessageId", lastReadInboxMessageId)
            topicsModel.setProperty(i, "lastReadOutboxMessageId", lastReadOutboxMessageId)
            if (lastMsg.id !== undefined) topicsModel.setProperty(i, "anchorMsgId", lastMsg.id || 0)
            if (lastSender.user_id !== undefined) topicsModel.setProperty(i, "lastSenderId", lastSender.user_id || 0)
            if (lastMsg.date !== undefined) topicsModel.setProperty(i, "lastMessageDate", lastMsg.date || 0)
            if (lastContent.text && lastContent.text.text !== undefined) topicsModel.setProperty(i, "lastMessageText", lastContent.text.text || "")
            break
        }
    }

    function loadTopics() {
        var chatId = getChatId()
        if (!chatId) return
        if (loading) return   // debounce: evita ricarichi multipli simultanei
        loaded = true
        loading = true
        tdLibWrapper.getForumTopics(chatId)
    }

    function refreshTopics() {
        loading = false
        loadTopics()
    }

    function openCreateTopicEditor() {
        if (!canManageTopics() && !canCreateTopicsPermission()) {
            appNotification.show(qsTr("You don't have permission to create topics."))
            return
        }
        topicEditorMode = "create"
        topicEditorThreadId = 0
        topicEditorBusy = false
        topicNameField.text = ""
        topicListView.scrollToTop()
        topicNameField.forceActiveFocus()
    }

    function openRenameTopicEditor(threadId, currentName) {
        if (!canManageTopics()) {
            appNotification.show(qsTr("Only administrators can manage topics."))
            return
        }
        if (!threadId || threadId <= 0) {
            return
        }
        topicEditorMode = "rename"
        topicEditorThreadId = Number(threadId)
        topicEditorBusy = false
        topicNameField.text = currentName || ""
        topicListView.scrollToTop()
        topicNameField.forceActiveFocus()
        topicNameField.cursorPosition = topicNameField.text.length
    }

    function closeTopicEditor() {
        topicEditorMode = ""
        topicEditorThreadId = 0
        topicEditorBusy = false
        topicNameField.text = ""
    }

    function submitTopicEditor() {
        if (!canManageTopics() || topicEditorBusy) {
            if (topicEditorMode !== "create" || !canCreateTopicsPermission()) {
                console.log("[ForumTopics] submitTopicEditor blocked: canManageTopics=" + canManageTopics()
                    + " busy=" + topicEditorBusy + " mode=" + topicEditorMode)
                return
            }
        }
        if (topicEditorMode !== "create" && !canManageTopics()) {
            console.log("[ForumTopics] submitTopicEditor blocked (non-create): canManageTopics=" + canManageTopics())
            return
        }
        var chatId = getChatId()
        if (!chatId) {
            console.log("[ForumTopics] submitTopicEditor: chatId=0, abort")
            return
        }
        var topicName = topicNameField.text ? topicNameField.text.trim() : ""
        if (topicName.length < 1 || topicName.length > 128) {
            appNotification.show(qsTr("Topic name must be between 1 and 128 characters."))
            return
        }
        console.log("[ForumTopics] submitTopicEditor mode=" + topicEditorMode
            + " chatId=" + chatId + " threadId=" + topicEditorThreadId + " name=" + topicName)
        topicEditorBusy = true
        topicEditorNewName = topicName  // salvato qui — l'editor verrà chiuso dopo l'ok
        if (topicEditorMode === "create") {
            createTimeoutTimer.restart()
            tdLibWrapper.sendRequest({
                "@type": "createForumTopic",
                "chat_id": chatId,
                "name": topicName,
                // TDLib 1.8.x richiede un oggetto forumTopicIcon, non icon_custom_emoji_id flat
                "icon": {
                    "@type": "forumTopicIcon",
                    "color": 7322096,
                    "custom_emoji_id": "0"
                },
                "@extra": "forumTopics:create:" + chatId
            })
            return
        }
        if (topicEditorMode === "rename" && topicEditorThreadId > 0) {
            var renameRequest = {
                "@type": "editForumTopic",
                "chat_id": chatId,
                "forum_topic_id": topicEditorThreadId,
                "name": topicName,
                "edit_icon_custom_emoji": false,
                "icon_custom_emoji_id": "0",
                "@extra": "forumTopics:rename:" + chatId + ":" + topicEditorThreadId
            }
            tdLibWrapper.sendRequest(renameRequest)
            return
        }
        topicEditorBusy = false
    }

    function deleteTopic(threadId) {
        if (!canManageTopics() || actionBusy) {
            console.log("[ForumTopics] deleteTopic blocked: canManage=" + canManageTopics() + " busy=" + actionBusy)
            return
        }
        var chatId = getChatId()
        var topicId = Number(threadId)
        if (!chatId || !topicId || topicId <= 0) {
            console.log("[ForumTopics] deleteTopic: invalid chatId=" + chatId + " topicId=" + topicId)
            return
        }
        console.log("[ForumTopics] deleteTopic chatId=" + chatId + " topicId=" + topicId)
        actionBusy = true
        tdLibWrapper.sendRequest({
            "@type": "deleteForumTopic",
            "chat_id": chatId,
            "forum_topic_id": topicId,
            "@extra": "forumTopics:delete:" + chatId + ":" + topicId
        })
    }

    function toggleTopicClosed(threadId, shouldBeClosed) {
        if (!canManageTopics() || actionBusy) {
            return
        }
        var chatId = getChatId()
        var topicId = Number(threadId)
        if (!chatId || !topicId || topicId <= 0) {
            return
        }
        actionBusy = true
        tdLibWrapper.sendRequest({
            "@type": "toggleForumTopicIsClosed",
            "chat_id": chatId,
            "forum_topic_id": topicId,
            "is_closed": !!shouldBeClosed,
            "@extra": "forumTopics:toggleClosed:" + chatId + ":" + topicId + ":" + (shouldBeClosed ? "1" : "0")
        })
    }

    function disableTopics() {
        if (!canDisableTopics() || actionBusy) {
            return
        }
        var supergroupId = getSupergroupId()
        var chatId = getChatId()
        if (!supergroupId || !chatId) {
            return
        }
        actionBusy = true
        tdLibWrapper.sendRequest({
            "@type": "toggleSupergroupIsForum",
            "supergroup_id": supergroupId,
            "is_forum": false,
            "@extra": "forumTopics:disable:" + chatId
        })
    }

    // Reload ritardato di 800ms — dà tempo a TDLib di aggiornare
    // lo stato interno dopo viewMessages con message_thread_id
    Timer {
        id: postCreateRefreshTimer
        interval: 2000
        repeat: false
        onTriggered: refreshTopics()
    }

    // Fallback: se dopo 5s l'editor è ancora in "Saving..." per create,
    // assume che TDLib abbia creato il topic e forza chiusura + refresh
    Timer {
        id: createTimeoutTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (topicEditorMode === "create" && topicEditorBusy) {
                topicEditorBusy = false
                closeTopicEditor()
                appNotification.show(qsTr("Topic created."))
                refreshTopics()
            }
        }
    }

    Timer {
        id: delayedReloadTimer
        interval: 800
        repeat: false
        onTriggered: {
            loading = false  // sblocca il debounce
            loadTopics()
        }
    }

    onStatusChanged: {
        if (status === PageStatus.Active) {
            if (lastViewedThreadId > 0) {
                // Ritorno da un topic: aspetta che TDLib elabori il viewMessages
                syncHomeUnreadOnNextLoad = true
                lastViewedThreadId = 0
                delayedReloadTimer.restart()
            } else if (!loaded) {
                loadTopics()
            }
        } else if (status === PageStatus.Inactive || status === PageStatus.Deactivating) {
            // Evita che chiamate future a viewMessage fuori dal topic ereditino message_thread_id stale.
            tdLibWrapper.setCurrentMessageThreadId(0)
        }
    }

    PullDownMenu {
        MenuItem {
            onClicked: { refreshTopics() }
            Label {
                anchors.centerIn: parent; text: qsTr("Refresh"); font.italic: forumTopicsPage.neon
                color: forumTopicsPage.neon ? (parent.highlighted ? "#fff3e6" : "#ffffff") : (parent.highlighted ? Theme.highlightColor : Theme.primaryColor)
                layer.enabled: forumTopicsPage.neon
                layer.effect: Glow { color: "#ffffff"; radius: 6; samples: 13; spread: 0.2; transparentBorder: true }
            }
        }
        MenuItem {
            visible: canManageTopics() || canCreateTopicsPermission()
            onClicked: { openCreateTopicEditor() }
            Label {
                anchors.centerIn: parent; text: qsTr("Create Topic"); font.italic: forumTopicsPage.neon
                color: forumTopicsPage.neon ? (parent.highlighted ? "#fff3e6" : "#ffffff") : (parent.highlighted ? Theme.highlightColor : Theme.primaryColor)
                layer.enabled: forumTopicsPage.neon
                layer.effect: Glow { color: "#ffffff"; radius: 6; samples: 13; spread: 0.2; transparentBorder: true }
            }
        }
        MenuItem {
            visible: canDisableTopics()
            onClicked: { disableTopics() }
            Label {
                anchors.centerIn: parent; text: qsTr("Disable Topics"); font.italic: forumTopicsPage.neon
                color: forumTopicsPage.neon ? (parent.highlighted ? "#fff3e6" : "#ffffff") : (parent.highlighted ? Theme.highlightColor : Theme.primaryColor)
                layer.enabled: forumTopicsPage.neon
                layer.effect: Glow { color: "#ffffff"; radius: 6; samples: 13; spread: 0.2; transparentBorder: true }
            }
        }
    }

    Connections {
        target: tdLibWrapper
        onForumTopicsReceived: {
            if (!forumTopicsPage.chatInformation) return
            if (chatId !== forumTopicsPage.chatInformation.id) return
            loading = false
            if (!topics) return
            topicsModel.clear()  // Svuota solo quando i nuovi dati sono pronti
            var totalUnread = 0
            var totalUnreadMentions = 0
            for (var i = 0; i < topics.length; i++) {
                var t = topics[i]
                var info = t.info || {}
                var icon = info.icon || {}
                var lastMsg = t.last_message || {}
                var lastSender = lastMsg.sender_id || {}
                var lastContent = lastMsg.content || {}
                var unreadCount = topicCounter(t, info, ["unread_count", "unreadCount", "unread_message_count", "unread_messages_count"])
                var unreadMentionCount = topicCounter(t, info, ["unread_mention_count", "unread_mentions_count", "unreadMentionCount", "unreadMentionsCount"])
                var unreadReactionCount = topicCounter(t, info, ["unread_reaction_count", "unread_reactions_count", "unreadReactionCount", "unreadReactionsCount"])
                var lastReadInboxMessageId = topicCounter(t, info, ["last_read_inbox_message_id", "read_inbox_max_id", "lastReadInboxMessageId"])
                var lastReadOutboxMessageId = topicCounter(t, info, ["last_read_outbox_message_id", "read_outbox_max_id", "lastReadOutboxMessageId"])
                var threadId = messageThreadIdFromTopic(t, info)
                var forumTopicId = forumTopicIdFromTopic(t, info)
                totalUnread += unreadCount
                totalUnreadMentions += unreadMentionCount
                topicsModel.append({
                    threadId:         threadId,
                    forumTopicId:     forumTopicId,
                    anchorMsgId:      lastMsg.id || 0,
                    topicName:        info.name || ("Topic " + (i + 1)),
                    topicIsClosed:    info.is_closed || false,
                    unreadCount:      unreadCount,
                    unreadMentionCount: unreadMentionCount,
                    unreadReactionCount: unreadReactionCount,
                    isPinned:         info.is_pinned || false,
                    iconColor:        icon.color || 0,
                    iconEmoji:        icon.custom_emoji_id || "",
                    lastReadInboxMessageId: lastReadInboxMessageId,
                    lastReadOutboxMessageId: lastReadOutboxMessageId,
                    lastSenderId:     lastSender.user_id || 0,
                    lastMessageText:  lastContent.text ? lastContent.text.text || "" : "",
                    lastMessageDate:  lastMsg.date || 0
                })
                var lookupTopicId = forumTopicId > 0 ? forumTopicId : threadId
                if (lookupTopicId > 0) {
                    requestForumTopicDetails(lookupTopicId)
                }
            }

            // d1: il badge home del forum riflette la SOMMA degli unread dei topic
            // (il chat-level updateChatReadInbox di TDLib per i forum e' inaffidabile).
            chatListModel.setForumUnreadCount(forumTopicsPage.chatInformation.id, totalUnread, totalUnreadMentions)

            // Se tutti i topic risultano letti, forza una sincronizzazione del badge in home.
            // In alcuni casi TDLib aggiorna subito i topic ma ritarda/non invia updateChatReadInbox.
            if (forumTopicsPage.syncHomeUnreadOnNextLoad) {
                forumTopicsPage.syncHomeUnreadOnNextLoad = false
                if (totalUnread === 0 && totalUnreadMentions === 0) {
                    tdLibWrapper.setCurrentMessageThreadId(0)
                    var chatLastMessage = forumTopicsPage.chatInformation.last_message || {}
                    var chatLastMessageId = Number(chatLastMessage.id || 0)
                    if (chatLastMessageId > 0) {
                        tdLibWrapper.viewMessage(forumTopicsPage.chatInformation.id, chatLastMessageId, true)
                    }
                    tdLibWrapper.readAllChatMentions(forumTopicsPage.chatInformation.id)
                    tdLibWrapper.readAllChatReactions(forumTopicsPage.chatInformation.id)
                    tdLibWrapper.toggleChatIsMarkedAsUnread(forumTopicsPage.chatInformation.id, false)
                }
            }
        }

        onForumTopicReceived: {
            if (!forumTopicsPage.chatInformation) return
            if (chatId !== forumTopicsPage.chatInformation.id) return
            if (!topic) return
            applyTopicDetails(topic)
        }

        onForumTopicUpdated: {
            // updateForumTopic — inviato da TDLib dopo viewMessages con message_thread_id
            // Aggiorniamo i metadati di lettura e poi ricarichiamo da TDLib
            // per avere unread_count autorevole.
            if (!forumTopicsPage.chatInformation) return
            if (chatId !== forumTopicsPage.chatInformation.id) return
            var lookupTopicId = 0
            for (var i = 0; i < topicsModel.count; i++) {
                var t = topicsModel.get(i)
                if (t.threadId === threadId || t.forumTopicId === threadId) {
                    topicsModel.setProperty(i, "lastReadInboxMessageId", lastReadInboxMessageId)
                    topicsModel.setProperty(i, "lastReadOutboxMessageId", lastReadOutboxMessageId)
                    topicsModel.setProperty(i, "unreadMentionCount", unreadMentionCount)
                    lookupTopicId = Number(t.forumTopicId || t.threadId || 0)
                    var anchorMessageId = Number(t.anchorMsgId || 0)
                    if (anchorMessageId > 0 && Number(lastReadInboxMessageId || 0) >= anchorMessageId) {
                        topicsModel.setProperty(i, "unreadCount", 0)
                    }
                    break
                }
            }
            if (lookupTopicId > 0) {
                requestForumTopicDetails(lookupTopicId)
            }
            // d1: aggiorna LIVE il badge home del forum dopo aver letto un topic
            // (somma unread correnti dei topic nel modello).
            var liveUnread = 0
            var liveMentions = 0
            for (var k = 0; k < topicsModel.count; k++) {
                var tk = topicsModel.get(k)
                liveUnread += Number(tk.unreadCount || 0)
                liveMentions += Number(tk.unreadMentionCount || 0)
            }
            chatListModel.setForumUnreadCount(forumTopicsPage.chatInformation.id, liveUnread, liveMentions)
        }

        onForumTopicInfoUpdated: {
            // Aggiorna campi quando TDLib notifica un aggiornamento del topic
            // NOTA: updateForumTopicInfo porta forumTopicInfo che ha message_thread_id,
            // NON forum_topic_id. Aggiorna solo i campi effettivamente presenti.
            if (!forumTopicsPage.chatInformation) return
            if (chatId !== forumTopicsPage.chatInformation.id) return
            var threadId = topicInfo.message_thread_id || topicInfo.forum_topic_id || 0
            var forumTopicId = topicInfo.forum_topic_id || topicInfo.message_thread_id || 0
            var unreadCount = numberFromCandidates([
                topicInfo.unread_count,
                topicInfo.unreadCount,
                topicInfo.unread_message_count,
                topicInfo.unread_messages_count
            ], null)
            var unreadMentionCount = numberFromCandidates([
                topicInfo.unread_mention_count,
                topicInfo.unread_mentions_count,
                topicInfo.unreadMentionCount,
                topicInfo.unreadMentionsCount
            ], null)
            var unreadReactionCount = numberFromCandidates([
                topicInfo.unread_reaction_count,
                topicInfo.unread_reactions_count,
                topicInfo.unreadReactionCount,
                topicInfo.unreadReactionsCount
            ], null)
            for (var i = 0; i < topicsModel.count; i++) {
                var modelTopic = topicsModel.get(i)
                var sameThread = threadId > 0 && modelTopic.threadId === threadId
                var sameForumTopic = forumTopicId > 0 && modelTopic.forumTopicId === forumTopicId
                if (sameThread || sameForumTopic) {
                    if (threadId > 0) topicsModel.setProperty(i, "threadId", threadId)
                    if (forumTopicId > 0) topicsModel.setProperty(i, "forumTopicId", forumTopicId)
                    // Aggiorna nome solo se non è stato rinominato di recente
                    // (evita il flicker: TDLib manda prima il nome vecchio, poi quello nuovo)
                    var lastRename = (lastRenamedTopicId === threadId || lastRenamedTopicId === forumTopicId) ? lastRenamedTime : 0
                    if (topicInfo.name && (Date.now() - lastRename) > 2000) {
                        topicsModel.setProperty(i, "topicName", topicInfo.name)
                    }
                    if (topicInfo.is_closed !== undefined) topicsModel.setProperty(i, "topicIsClosed", topicInfo.is_closed)
                    if (topicInfo.is_pinned !== undefined) topicsModel.setProperty(i, "isPinned", topicInfo.is_pinned)
                    if (unreadCount !== null) topicsModel.setProperty(i, "unreadCount", unreadCount)
                    if (unreadMentionCount !== null) topicsModel.setProperty(i, "unreadMentionCount", unreadMentionCount)
                    if (unreadReactionCount !== null) topicsModel.setProperty(i, "unreadReactionCount", unreadReactionCount)
                    break
                }
            }
            // Se il topic non è nel modello è nuovo — aggiungilo subito con i dati disponibili
            if (i >= topicsModel.count && threadId > 0) {
                topicsModel.append({
                    threadId:            threadId,
                    forumTopicId:        forumTopicId > 0 ? forumTopicId : threadId,
                    topicName:           topicInfo.name || "",
                    topicIsClosed:       topicInfo.is_closed || false,
                    isPinned:            topicInfo.is_pinned || false,
                    unreadCount:         0,
                    unreadMentionCount:  0,
                    unreadReactionCount: 0,
                    anchorMsgId:         0,
                    lastMessageText:     "",
                    lastSenderId:        0,
                    lastSenderName:      ""
                })
                // Se l'editor era aperto in modalità create, chiudilo
                // (fallback per quando processForumTopicInfoCreated C++ non è compilato)
                if (topicEditorMode === "create") {
                    topicEditorBusy = false
                    closeTopicEditor()
                    appNotification.show(qsTr("Topic created."))
                }
                // Ricarica dopo 2s per avere i dati completi
                postCreateRefreshTimer.restart()
            }
        }

        onOkReceived: {
            var parts = parseForumRequest(request)
            if (parts.length === 0) {
                return
            }
            var action = parts[1]
            topicEditorBusy = false
            actionBusy = false
            if (action === "create") {
                closeTopicEditor()
                appNotification.show(qsTr("Topic created."))
                // Piccolo delay: TDLib potrebbe non aver ancora aggiornato
                // il suo cache interno quando risponde con forumTopicInfo
                postCreateRefreshTimer.restart()
                return
            }
            if (action === "rename") {
                // Aggiornamento ottimistico — niente flicker
                var renameThreadId = Number(parts[3])
                var newName = topicEditorNewName
                for (var ri = 0; ri < topicsModel.count; ri++) {
                    if (topicsModel.get(ri).threadId === renameThreadId) {
                        topicsModel.setProperty(ri, "topicName", newName)
                        break
                    }
                }
                // Ignora updateForumTopicInfo con nome vecchio per 2 secondi
                lastRenamedTopicId = renameThreadId
                lastRenamedTime = Date.now()
                closeTopicEditor()
                appNotification.show(qsTr("Topic renamed."))
                return
            }
            if (action === "delete") {
                // Rimozione ottimistica dal modello
                var delThreadId = Number(parts[3])
                for (var di = 0; di < topicsModel.count; di++) {
                    if (topicsModel.get(di).threadId === delThreadId) {
                        topicsModel.remove(di)
                        break
                    }
                }
                appNotification.show(qsTr("Topic deleted."))
                return
            }
            if (action === "toggleClosed") {
                // Aggiornamento ottimistico stato chiuso
                var toggleThreadId = Number(parts[3])
                var isClosed = parts.length > 4 && parts[4] === "1"
                for (var ti = 0; ti < topicsModel.count; ti++) {
                    if (topicsModel.get(ti).threadId === toggleThreadId) {
                        topicsModel.setProperty(ti, "topicIsClosed", isClosed)
                        break
                    }
                }
                appNotification.show(isClosed ? qsTr("Topic closed.") : qsTr("Topic reopened."))
                return
            }
            if (action === "disable") {
                appNotification.show(qsTr("Topics disabled."))
                if (pageStack.depth > 1) {
                    pageStack.pop()
                }
                return
            }
        }

        onErrorReceived: {
            // Log SEMPRE per vedere cosa TDLib risponde
            console.log("[ForumTopics] onErrorReceived code=" + code + " message=" + message + " extra=" + extra)
            if (extra && extra.indexOf("getForumTopic:") === 0) {
                var getTopicParts = extra.split(":")
                if (getTopicParts.length >= 3 && getTopicParts[1].toString() === getChatId().toString()) {
                    // Switch field name (forum_topic_id vs message_thread_id) + retry
                    // una sola volta; se il messaggio NON nomina nessuno dei due
                    // (es. "Invalid forum topic identifier specified") il topic è
                    // davvero stale: lo blacklistiamo per non rifare la chiamata.
                    if (switchTopicRequestIdField(message)) {
                        requestForumTopicDetails(getTopicParts[2])
                        return
                    }
                    var failKey = String(Number(getTopicParts[2]))
                    var failedNext = failedTopicIds
                    failedNext[failKey] = true
                    failedTopicIds = failedNext
                    return
                }
            }
            var parts = parseForumRequest(extra)
            if (parts.length === 0) {
                return
            }
            topicEditorBusy = false
            actionBusy = false
            var action = parts[1]
            if ((action === "rename" || action === "delete" || action === "toggleClosed") && switchTopicRequestIdField(message)) {
                if (action === "rename" && topicEditorMode === "rename" && topicEditorThreadId > 0) {
                    submitTopicEditor()
                    return
                }
                if (action === "delete" && parts.length > 3) {
                    deleteTopic(parts[3])
                    return
                }
                if (action === "toggleClosed" && parts.length > 4) {
                    toggleTopicClosed(parts[3], parts[4] === "1")
                    return
                }
            }
            Functions.handleErrorMessage(code, message)
        }
    }

    ListModel { id: topicsModel }

    // ── Sfondo: avatar del gruppo a TUTTA LARGHEZZA e molto TRASPARENTE, con
    //    dissolvenza verso il basso, così non disturba la lettura dei topic. ──
    TDLibFile {
        id: groupAvatarFile
        tdlib: tdLibWrapper
        autoLoad: true
        fileInformation: (forumTopicsPage.chatInformation && forumTopicsPage.chatInformation.photo)
                         ? forumTopicsPage.chatInformation.photo.small : null
    }
    Image {
        id: backgroundAvatar
        z: -1
        anchors.centerIn: parent
        width: parent.width
        height: width
        visible: groupAvatarFile.isDownloadingCompleted
        source: groupAvatarFile.isDownloadingCompleted ? groupAvatarFile.path : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: 0.15
        layer.enabled: true
        layer.effect: OpacityMask { maskSource: backgroundAvatarMask }
    }
    Rectangle {
        id: backgroundAvatarMask
        width: backgroundAvatar.width
        height: backgroundAvatar.height
        visible: false
        // Dissolvenza simmetrica (alto+basso) così l'avatar centrato sfuma su entrambi i lati.
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.30; color: "white" }
            GradientStop { position: 0.70; color: "white" }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // ── Editor topic (FUORI dal ListView header per accessibilità ID) ──────
    Column {
        id: topicEditorColumn
        visible: topicEditorMode !== ""
        width: parent.width
        anchors.top: parent.top
        anchors.topMargin: Theme.itemSizeLarge  // spazio per il PageHeader
        spacing: Theme.paddingSmall
        z: 10

        TextField {
            id: topicNameField
            width: parent.width
            label: topicEditorMode === "create" ? qsTr("Topic name") : qsTr("New topic name")
            placeholderText: qsTr("Enter topic name")
            EnterKey.enabled: text.trim().length > 0 && !topicEditorBusy
            EnterKey.iconSource: "image://theme/icon-m-enter-accept"
            EnterKey.onClicked: { submitTopicEditor() }
        }

        Row {
            width: parent.width - (2 * Theme.horizontalPageMargin)
            x: Theme.horizontalPageMargin
            spacing: Theme.paddingSmall

            NeonButton {
                width: (parent.width - Theme.paddingSmall) / 2
                text: qsTr("Cancel")
                enabled: !topicEditorBusy
                onClicked: { closeTopicEditor() }
            }

            NeonButton {
                width: (parent.width - Theme.paddingSmall) / 2
                enabled: topicNameField.text.trim().length > 0 && !topicEditorBusy
                text: topicEditorBusy
                      ? qsTr("Saving…")
                      : (topicEditorMode === "create" ? qsTr("Create") : qsTr("Rename"))
                onClicked: { submitTopicEditor() }
            }
        }
    }

    SilicaListView {
        id: topicListView
        anchors.fill: parent
        model: topicsModel

        header: Column {
            width: topicListView.width
            spacing: Theme.paddingSmall

            PageHeader {
                id: topicsHeader
                // Titolo gruppo in stile NEON (come header chat / brand home): alone
                // arancione + nucleo chiaro. title vuoto: rendiamo noi titolo+sottotitolo.
                title: ""
                height: Theme.itemSizeLarge

                Label {
                    id: topicsTitleHalo
                    visible: forumTopicsPage.neon
                    anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; bottom: parent.verticalCenter }
                    width: Math.min(implicitWidth, topicsHeader.width - 2 * Theme.horizontalPageMargin)
                    horizontalAlignment: Text.AlignRight
                    text: topicsTitleCore.text
                    textFormat: Text.StyledText
                    font.pixelSize: Theme.fontSizeLarge
                    font.family: Theme.fontFamilyHeading
                    font.italic: forumTopicsPage.neon
                    truncationMode: TruncationMode.Elide
                    maximumLineCount: 1
                    color: "#e65000"
                    layer.enabled: forumTopicsPage.neon
                    layer.effect: Glow {
                        color: "#e65000"
                        radius: 18
                        samples: 37
                        spread: 0.30
                        transparentBorder: true
                    }
                }
                Label {
                    id: topicsTitleCore
                    anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; bottom: parent.verticalCenter }
                    width: Math.min(implicitWidth, topicsHeader.width - 2 * Theme.horizontalPageMargin)
                    horizontalAlignment: Text.AlignRight
                    text: forumTopicsPage.chatInformation ? Emoji.emojify(forumTopicsPage.chatInformation.title, font.pixelSize) : ""
                    textFormat: Text.StyledText
                    font.pixelSize: Theme.fontSizeLarge
                    font.family: forumTopicsPage.neon ? Theme.fontFamilyHeading : Theme.fontFamily
                    font.italic: forumTopicsPage.neon
                    truncationMode: TruncationMode.Elide
                    maximumLineCount: 1
                    color: forumTopicsPage.neon ? "#fff3e6" : Theme.highlightColor
                    layer.enabled: forumTopicsPage.neon
                    layer.effect: Glow {
                        color: "#ff9a3d"
                        radius: 6
                        samples: 13
                        spread: 0.55
                        transparentBorder: true
                    }
                }
                Label {
                    id: topicsDescLabel
                    anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; top: parent.verticalCenter; topMargin: Theme.paddingSmall / 2 }
                    text: qsTr("Topics")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.secondaryColor
                    horizontalAlignment: Text.AlignRight
                }
            }
            // Pulsante "Crea topic" come FINESTRA A NEON (stesso linguaggio delle
            // schede Impostazioni): cartello di vetro + scritta neon bianca centrata.
            BackgroundItem {
                id: createTopicButton
                width: parent.width
                height: Theme.itemSizeMedium
                visible: topicEditorMode === "" && (canManageTopics() || canCreateTopicsPermission())
                onClicked: { openCreateTopicEditor() }

                Rectangle {
                    id: createTopicCard
                    anchors.fill: parent
                    anchors.leftMargin: Theme.horizontalPageMargin
                    anchors.rightMargin: Theme.horizontalPageMargin
                    anchors.topMargin: Theme.paddingSmall / 2
                    anchors.bottomMargin: Theme.paddingSmall / 2
                    // Tema Silica: nessuna card di vetro (piatta, niente bordo neon).
                    radius: forumTopicsPage.neon ? Theme.paddingLarge : 0
                    color: forumTopicsPage.neon ? Theme.rgba("#ffffff", createTopicButton.highlighted ? 0.14 : 0.06)
                                                : (createTopicButton.highlighted ? Theme.rgba(Theme.highlightColor, 0.1) : "transparent")
                    border.width: forumTopicsPage.neon ? 2 : 0
                    border.color: Theme.rgba("#ff8a3d", createTopicButton.highlighted ? 0.80 : 0.45)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }
                Label {
                    id: createTopicHalo
                    visible: forumTopicsPage.neon
                    anchors.centerIn: createTopicCard
                    text: qsTr("Create Topic")
                    font.family: Theme.fontFamilyHeading
                    font.italic: forumTopicsPage.neon
                    color: "#ffffff"
                    layer.enabled: forumTopicsPage.neon
                    layer.effect: Glow {
                        color: "#ffffff"
                        radius: 12
                        samples: 25
                        spread: 0.20
                        transparentBorder: true
                    }
                }
                Label {
                    anchors.centerIn: createTopicCard
                    text: qsTr("Create Topic")
                    font.family: forumTopicsPage.neon ? Theme.fontFamilyHeading : Theme.fontFamily
                    font.italic: forumTopicsPage.neon
                    color: forumTopicsPage.neon ? "#ffffff" : Theme.highlightColor
                }
            }
            // Spazio placeholder quando l'editor è visibile
            Item {
                width: parent.width
                height: topicEditorMode !== ""
                        ? (topicEditorColumn.height + Theme.paddingMedium)
                        : 0
                visible: topicEditorMode !== ""
            }
        }

        ViewPlaceholder {
            enabled: loading && topicsModel.count === 0
            text: qsTr("Loading topics...")
        }

        ViewPlaceholder {
            enabled: !loading && topicsModel.count === 0
            text: qsTr("No topics found")
            hintText: qsTr("This group has no topics yet.")
        }

        delegate: ListItem {
            id: topicDelegate
            width: ListView.view.width
            contentHeight: Theme.itemSizeExtraLarge
            property var topicThreadId: Number(threadId)
            property var topicForumId: Number(forumTopicId)

            openMenuOnPressAndHold: false
            onPressAndHold: {
                if (forumTopicsPage.canManageTopics()) {
                    topicsNeonMenu.open(buildTopicActions());
                }
            }
            function buildTopicActions() {
                var topicId = topicDelegate.topicForumId > 0 ? topicDelegate.topicForumId : topicDelegate.topicThreadId;
                return [
                    { text: qsTr("Rename topic"), visible: forumTopicsPage.canManageTopics(), callback: function() {
                        forumTopicsPage.openRenameTopicEditor(topicId, topicName);
                    }},
                    { text: topicIsClosed ? qsTr("Reopen topic") : qsTr("Close topic"), visible: forumTopicsPage.canManageTopics() && (topicDelegate.topicForumId > 0 || topicDelegate.topicThreadId > 0), callback: function() {
                        forumTopicsPage.toggleTopicClosed(topicId, !topicIsClosed);
                    }},
                    { text: qsTr("Delete topic"), visible: forumTopicsPage.canManageTopics() && (topicDelegate.topicForumId > 1 || topicDelegate.topicThreadId > 1), callback: function() {
                        Remorse.itemAction(topicDelegate, qsTr("Deleting topic"), function() { forumTopicsPage.deleteTopic(topicId); });
                    }}
                ];
            }

            onClicked: {
                var tid = Number(threadId)
                if (!tid || tid <= 0) return
                var lastMsgId = Number(anchorMsgId) || 0
                forumTopicsPage.lastViewedThreadId = tid
                tdLibWrapper.setCurrentMessageThreadId(tid)
                // NB: qui c'era un viewMessage(..., force=true) sull'ULTIMO messaggio del
                // topic ("allineato a Yottagram"). Marcare come letto l'ultimo messaggio
                // segna letto TUTTO il topic, quindi bastava entrarci per perdere il segno
                // di dove si era arrivati, anche senza leggere niente. Ora la lettura la
                // registra il marcatore progressivo dello scroll (viewMessageTimer in
                // ChatPage, force=false), che segna solo fin dove si e' davvero arrivati.
                pageStack.push(Qt.resolvedUrl("ChatPage.qml"), {
                    chatInformation: forumTopicsPage.chatInformation,
                    messageThreadId: tid,
                    topicLastMessageId: lastMsgId,
                    // Dove eravamo rimasti in QUESTO topic: e' l'ancora con cui la
                    // ChatPage si posiziona, cosi' il topic non si apre in fondo.
                    topicLastReadInboxMessageId: Number(lastReadInboxMessageId || 0),
                    currentTopicInfo: { name: topicName, is_closed: topicIsClosed }
                })
            }

            // Finestra a NEON tonda del topic: interno translucido + CORNICE colorata
            // (colore TDLib, diverso per topic) + alone tenue; dentro la PRIMA LETTERA
            // del titolo invece dell'onnipresente "#".
            Rectangle {
                id: topicIcon
                anchors.left: parent.left
                anchors.leftMargin: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.itemSizeMedium * 0.8
                height: width
                // Tema Silica: icona quadrata (come gli avatar); Neon: tonda.
                radius: forumTopicsPage.neon ? width / 2 : 0
                // Colore TDLib: int ARGB -> estraiamo RGB
                property color topicColor: iconColor ? Qt.rgba(
                    ((iconColor >> 16) & 0xFF) / 255.0,
                    ((iconColor >> 8)  & 0xFF) / 255.0,
                    ( iconColor        & 0xFF) / 255.0,
                    1.0) : Theme.secondaryHighlightColor
                color: Theme.rgba(topicColor, 0.18)
                border.width: 2
                border.color: topicColor

                // Alone neon (cheap, niente Glow per-delegate): anello esterno tenue. Solo Neon.
                Rectangle {
                    visible: forumTopicsPage.neon
                    anchors.centerIn: parent
                    width: parent.width + Theme.paddingSmall
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.rgba(topicIcon.topicColor, 0.30)
                }

                Label {
                    anchors.centerIn: parent
                    text: (topicName && topicName.length > 0) ? topicName.charAt(0).toUpperCase() : "#"
                    font.pixelSize: Theme.fontSizeLarge
                    font.bold: true
                    font.family: Theme.fontFamilyHeading
                    color: "white"
                }
            }

            // Badge messaggi non letti
            Rectangle {
                id: badge
                anchors.right: parent.right
                anchors.rightMargin: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                visible: unreadCount > 0 || unreadMentionCount > 0
                width: visible ? (badgeLbl.width + Theme.paddingSmall * 2) : 0
                height: Theme.fontSizeSmall + Theme.paddingSmall
                radius: height / 2
                color: Theme.highlightColor

                Label {
                    id: badgeLbl
                    anchors.centerIn: parent
                    text: {
                        var badgeCount = unreadCount > 0 ? unreadCount : unreadMentionCount
                        return badgeCount > 999 ? "999+" : ("" + badgeCount)
                    }
                    font.pixelSize: Theme.fontSizeTiny
                    font.bold: true
                    color: "white"
                }
            }

            // Nome topic + preview
            Column {
                anchors.left: topicIcon.right
                anchors.leftMargin: Theme.paddingMedium
                anchors.right: badge.left
                anchors.rightMargin: Theme.paddingSmall
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.paddingSmall / 2

                Label {
                    id: topicNameLabel
                    width: parent.width
                    text: topicIsClosed ? (topicName + " · " + qsTr("Closed")) : topicName
                    font.pixelSize: Theme.fontSizeMedium
                    font.italic: forumTopicsPage.neon
                    color: forumTopicsPage.neon ? "#ffffff" : Theme.primaryColor
                    truncationMode: TruncationMode.Fade
                    maximumLineCount: 1
                    layer.enabled: forumTopicsPage.neon
                    layer.effect: Glow { color: "#ffffff"; radius: 6; samples: 13; spread: 0.2; transparentBorder: true }
                }

                Label {
                    width: parent.width
                    visible: lastMessageText !== ""
                    text: {
                        if (lastSenderId === tdLibWrapper.myUserId) {
                            return qsTr("You") + ": " + lastMessageText
                        } else if (lastSenderId > 0) {
                            var userInfo = tdLibWrapper.getUserInformation(lastSenderId)
                            var name = userInfo ? (userInfo.first_name || "") : ""
                            return name !== "" ? (name + ": " + lastMessageText) : lastMessageText
                        }
                        return lastMessageText
                    }
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    truncationMode: TruncationMode.Fade
                    maximumLineCount: 1
                }
            }
        }

        VerticalScrollDecorator {}
    }

    NeonMenuOverlay {
        id: topicsNeonMenu
    }
}