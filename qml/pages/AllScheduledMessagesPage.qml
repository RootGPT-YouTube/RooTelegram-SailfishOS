import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: page

    property var items: []
    property var pendingChats: []
    property bool loading: false

    function previewText(msg) {
        if (!msg || !msg.content) return "—";
        var c = msg.content;
        var t = c['@type'];
        if (t === 'messageText') return (c.text && c.text.text) || "";
        if (t === 'messagePhoto') {
            var cap = c.caption && c.caption.text ? c.caption.text : "";
            return cap ? ("[" + qsTr("Photo") + "] " + cap) : ("[" + qsTr("Photo") + "]");
        }
        if (t === 'messageVideo') {
            var cv = c.caption && c.caption.text ? c.caption.text : "";
            return cv ? ("[" + qsTr("Video") + "] " + cv) : ("[" + qsTr("Video") + "]");
        }
        if (t === 'messageDocument') return "[" + qsTr("Document") + "]";
        if (t === 'messageVoiceNote') return "[" + qsTr("Voice") + "]";
        if (t === 'messageAnimation') return "[" + qsTr("GIF") + "]";
        if (t === 'messageSticker') return "[" + qsTr("Sticker") + "]";
        if (t === 'messageLocation') return "[" + qsTr("Location") + "]";
        return "[" + t + "]";
    }

    function pickDateTime(initial, onDone) {
        var startDate = initial && initial.getTime ? initial : new Date();
        var dp = pageStack.push("Sailfish.Silica.DatePickerDialog", { date: startDate });
        dp.accepted.connect(function() {
            var d = new Date(startDate);
            d.setFullYear(dp.year, dp.month - 1, dp.day);
            var tp = pageStack.push("Sailfish.Silica.TimePickerDialog", {
                hour: d.getHours(),
                minute: d.getMinutes(),
                hourMode: DateTime.TwentyFourHours
            });
            tp.accepted.connect(function() {
                d.setHours(tp.hour, tp.minute, 0, 0);
                onDone(d);
            });
        });
    }

    function refresh() {
        page.items = [];
        page.pendingChats = chatListModel.getAllChatIds();
        page.loading = page.pendingChats.length > 0;
        for (var i = 0; i < page.pendingChats.length; i++) {
            tdLibWrapper.getChatScheduledMessages(Number(page.pendingChats[i]));
        }
    }

    Connections {
        target: tdLibWrapper
        onMessagesReceivedWithExtra: {
            if (!extra || extra.indexOf("getChatScheduledMessages:") !== 0) return;
            var cidStr = extra.substring("getChatScheduledMessages:".length);
            var cid = Number(cidStr);

            // Marca chat come processata
            var idx = page.pendingChats.indexOf(cid);
            if (idx === -1) {
                // numeri JS vs qlonglong: confronto string-based fallback
                for (var k = 0; k < page.pendingChats.length; k++) {
                    if (page.pendingChats[k].toString() === cidStr) {
                        idx = k;
                        break;
                    }
                }
            }
            if (idx !== -1) {
                page.pendingChats.splice(idx, 1);
                if (page.pendingChats.length === 0) page.loading = false;
            }

            if (!messages || messages.length === 0) return;
            var chatTitle = chatListModel.getChatTitle(cid) || qsTr("Unknown chat");
            var added = page.items.slice();
            for (var i = 0; i < messages.length; i++) {
                var m = messages[i];
                if (!m || !m.scheduling_state || !m.scheduling_state.send_date) continue;
                added.push({
                    chatId: cidStr,
                    chatTitle: chatTitle,
                    messageId: m.id ? m.id.toString() : "",
                    preview: page.previewText(m),
                    sendDate: m.scheduling_state.send_date
                });
            }
            // ordina per data crescente
            added.sort(function(a, b) { return a.sendDate - b.sendDate; });
            page.items = added;
        }
    }

    Timer {
        id: refreshTimer
        interval: 700
        repeat: false
        onTriggered: page.refresh()
    }

    Component.onCompleted: refresh()

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: page.items

        header: PageHeader {
            title: qsTr("Scheduled messages")
            description: page.items.length > 0
                ? qsTr("%n scheduled message(s)", "", page.items.length)
                : (page.loading ? qsTr("Loading…") : qsTr("No scheduled messages"))
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: page.refresh()
            }
        }

        ViewPlaceholder {
            enabled: !page.loading && page.items.length === 0
            text: qsTr("No scheduled messages")
            hintText: qsTr("Long-press the send button in a chat to schedule a new message.")
        }

        delegate: ListItem {
            id: item
            width: listView.width
            contentHeight: contentCol.height + 2 * Theme.paddingMedium

            function rescheduleMe() {
                var initial = new Date(modelData.sendDate * 1000);
                page.pickDateTime(initial, function(newDate) {
                    var ts = Math.floor(newDate.getTime() / 1000);
                    tdLibWrapper.editMessageSchedulingState(Number(modelData.chatId), Number(modelData.messageId), ts);
                    refreshTimer.restart();
                });
            }

            function deleteMe() {
                remorseAction(qsTr("Deleting"), function() {
                    var ids = [];
                    ids.push(modelData.messageId);
                    tdLibWrapper.deleteMessages(modelData.chatId, ids);
                    refreshTimer.restart();
                });
            }

            menu: ContextMenu {
                MenuItem {
                    text: qsTr("Reschedule")
                    onClicked: item.rescheduleMe()
                }
                MenuItem {
                    text: qsTr("Delete")
                    onClicked: item.deleteMe()
                }
            }

            Column {
                id: contentCol
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.paddingSmall

                Label {
                    text: modelData.chatTitle
                    color: item.highlighted ? Theme.highlightColor : Theme.highlightColor
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    width: parent.width
                }
                Label {
                    text: modelData.preview
                    color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    width: parent.width
                }
                Label {
                    text: Qt.formatDateTime(new Date(modelData.sendDate * 1000), "dddd d MMMM hh:mm")
                    color: item.highlighted ? Theme.highlightColor : Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
