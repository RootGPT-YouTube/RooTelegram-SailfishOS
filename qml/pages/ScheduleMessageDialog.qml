import QtQuick 2.6
import Sailfish.Silica 1.0

Dialog {
    id: dialog

    property string chatIdString: "0"

    property date selectedDateTime: {
        var d = new Date();
        d.setTime(d.getTime() + 60 * 60 * 1000);
        d.setSeconds(0);
        d.setMilliseconds(0);
        return d;
    }

    property var scheduledMessages: []

    canAccept: selectedDateTime.getTime() > (new Date()).getTime() + 30 * 1000

    function refreshScheduled() {
        var cid = Number(chatIdString);
        if (cid) {
            tdLibWrapper.getChatScheduledMessages(cid);
        }
    }

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

    function scheduledDate(msg) {
        if (!msg || !msg.scheduling_state) return null;
        var sd = msg.scheduling_state.send_date;
        if (!sd) return null;
        return new Date(sd * 1000);
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

    Connections {
        target: tdLibWrapper
        onMessagesReceivedWithExtra: {
            if (extra === ("getChatScheduledMessages:" + dialog.chatIdString)) {
                var arr = [];
                for (var i = 0; i < messages.length; i++) {
                    var m = messages[i];
                    arr.push({
                        messageId: m.id ? m.id.toString() : "",
                        text: dialog.previewText(m),
                        when: dialog.scheduledDate(m)
                    });
                }
                dialog.scheduledMessages = arr;
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 600
        repeat: false
        onTriggered: refreshScheduled()
    }

    Component.onCompleted: refreshScheduled()

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        VerticalScrollDecorator {}

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            DialogHeader {
                acceptText: qsTr("Schedule")
                cancelText: qsTr("Cancel")
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeLarge
                color: dialog.canAccept ? Theme.highlightColor : Theme.secondaryColor
                text: Qt.formatDateTime(dialog.selectedDateTime, "dddd d MMMM yyyy  hh:mm")
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: dialog.canAccept
                      ? qsTr("Message will be sent at the selected time.")
                      : qsTr("Pick a time in the future.")
            }

            ValueButton {
                label: qsTr("Date")
                value: Qt.formatDate(dialog.selectedDateTime, Qt.DefaultLocaleShortDate)
                onClicked: {
                    var picker = pageStack.push("Sailfish.Silica.DatePickerDialog", { date: dialog.selectedDateTime });
                    picker.accepted.connect(function() {
                        var d = new Date(dialog.selectedDateTime);
                        d.setFullYear(picker.year, picker.month - 1, picker.day);
                        dialog.selectedDateTime = d;
                    });
                }
            }

            ValueButton {
                label: qsTr("Time")
                value: Qt.formatTime(dialog.selectedDateTime, "hh:mm")
                onClicked: {
                    var picker = pageStack.push("Sailfish.Silica.TimePickerDialog", {
                        hour: dialog.selectedDateTime.getHours(),
                        minute: dialog.selectedDateTime.getMinutes(),
                        hourMode: DateTime.TwentyFourHours
                    });
                    picker.accepted.connect(function() {
                        var d = new Date(dialog.selectedDateTime);
                        d.setHours(picker.hour, picker.minute, 0, 0);
                        dialog.selectedDateTime = d;
                    });
                }
            }

            SectionHeader {
                text: qsTr("Already scheduled in this chat")
                visible: dialog.scheduledMessages.length > 0
            }

            Label {
                visible: dialog.scheduledMessages.length === 0
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("No other scheduled messages in this chat.")
            }

            Repeater {
                model: dialog.scheduledMessages

                ListItem {
                    id: scheduledItem
                    width: contentColumn.width
                    contentHeight: Theme.itemSizeMedium

                    function rescheduleMe() {
                        dialog.pickDateTime(modelData.when, function(newDate) {
                            var ts = Math.floor(newDate.getTime() / 1000);
                            tdLibWrapper.editMessageSchedulingState(Number(dialog.chatIdString), Number(modelData.messageId), ts);
                            refreshTimer.restart();
                        });
                    }

                    function deleteMe() {
                        remorseAction(qsTr("Deleting scheduled message"), function() {
                            var ids = [];
                            ids.push(modelData.messageId);
                            tdLibWrapper.deleteMessages(dialog.chatIdString, ids);
                            refreshTimer.restart();
                        });
                    }

                    menu: ContextMenu {
                        MenuItem {
                            text: qsTr("Reschedule")
                            onClicked: scheduledItem.rescheduleMe()
                        }
                        MenuItem {
                            text: qsTr("Delete")
                            onClicked: scheduledItem.deleteMe()
                        }
                    }

                    Column {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.paddingSmall

                        Label {
                            text: modelData.text
                            color: scheduledItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                            width: parent.width
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        Label {
                            text: modelData.when ? Qt.formatDateTime(modelData.when, "ddd d MMM hh:mm") : ""
                            color: scheduledItem.highlighted ? Theme.highlightColor : Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }
                }
            }
        }
    }
}
