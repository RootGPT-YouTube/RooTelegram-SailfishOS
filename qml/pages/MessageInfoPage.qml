/*
    Copyright (C) 2026 RooTelegram contributors

    This file is part of RooTelegram.

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
import WerkWolf.RooTelegram 1.0
import "../js/functions.js" as Functions

// Metadati di un singolo messaggio (#1 v2.4). Apribile da "Info messaggio" nel
// menù long-press; sostituisce il vecchio tap relativo/assoluto sulla data.
Page {
    id: infoPage
    allowedOrientations: Orientation.All

    // Messaggio completo (myMessage) di cui mostrare i metadati + chat di origine.
    property var messageObject: ({})
    property var chatId: 0

    function fullDate(ts) {
        if (!ts || ts <= 0) return "";
        return Functions.getDateTimeTranslated(ts);
    }

    function senderName() {
        var s = messageObject.sender_id;
        if (!s) return "";
        if (s["@type"] === "messageSenderUser") {
            return Functions.getUserName(tdLibWrapper.getUserInformation(s.user_id));
        } else if (s["@type"] === "messageSenderChat") {
            var c = tdLibWrapper.getChat(s.chat_id);
            return (c && c.title) ? c.title : "";
        }
        return "";
    }

    function viaBotName() {
        if (!messageObject.via_bot_user_id) return "";
        var b = tdLibWrapper.getUserInformation(messageObject.via_bot_user_id);
        return Functions.getUserName(b);
    }

    function forwardOrigin() {
        var fi = messageObject.forward_info;
        if (!fi || !fi.origin) return "";
        var o = fi.origin;
        var t = o["@type"];
        if (t === "messageOriginChannel" || t === "messageForwardOriginChannel") {
            var c = tdLibWrapper.getChat(o.chat_id);
            return (c && c.title) ? c.title : "";
        } else if (t === "messageOriginUser" || t === "messageForwardOriginUser") {
            return Functions.getUserName(tdLibWrapper.getUserInformation(o.sender_user_id));
        } else if (t === "messageOriginChat" || t === "messageForwardOriginChat") {
            var cc = tdLibWrapper.getChat(o.sender_chat_id);
            return (cc && cc.title) ? cc.title : "";
        } else if (t === "messageOriginHiddenUser" || t === "messageForwardOriginHiddenUser") {
            return o.sender_name || "";
        }
        return "";
    }

    function forwardDate() {
        var fi = messageObject.forward_info;
        return (fi && fi.date) ? fi.date : 0;
    }

    function scheduledText() {
        var st = messageObject.scheduling_state;
        if (!st) return "";
        if (st["@type"] === "messageSchedulingStateSendAtDate") {
            return Functions.getDateTimeTranslated(st.send_date);
        } else if (st["@type"] === "messageSchedulingStateSendWhenOnline") {
            return qsTr("When the recipient comes online");
        }
        return "";
    }

    // ID Telegram "reale": TDLib codifica l'id messaggio shiftato di 20 bit.
    function realMessageId() {
        if (!messageObject.id) return "";
        return "" + Math.floor(messageObject.id / 1048576);
    }

    function reactionsTotal() {
        var ii = messageObject.interaction_info;
        if (!ii || !ii.reactions) return 0;
        // 1.8.62: interaction_info.reactions = messageReactions { reactions: [...] }.
        var arr = ii.reactions.reactions ? ii.reactions.reactions : ii.reactions;
        if (!arr || !arr.length) return 0;
        var tot = 0;
        for (var i = 0; i < arr.length; i++) {
            tot += (arr[i].total_count ? arr[i].total_count : 0);
        }
        return tot;
    }

    function viewCount() {
        var ii = messageObject.interaction_info;
        return (ii && ii.view_count) ? ii.view_count : 0;
    }

    function forwardCount() {
        var ii = messageObject.interaction_info;
        return (ii && ii.forward_count) ? ii.forward_count : 0;
    }

    function albumId() {
        var a = messageObject.media_album_id;
        return (a && a !== "0" && a !== 0) ? ("" + a) : "";
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        VerticalScrollDecorator {}

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: qsTr("Message info")
            }

            DetailItem {
                label: qsTr("Sent")
                value: infoPage.fullDate(messageObject.date)
                visible: !!value
            }
            DetailItem {
                label: qsTr("Edited")
                value: infoPage.fullDate(messageObject.edit_date)
                visible: !!value
            }
            DetailItem {
                label: qsTr("Scheduled")
                value: infoPage.scheduledText()
                visible: !!value
            }
            DetailItem {
                label: qsTr("Sender")
                value: infoPage.senderName()
                visible: !!value
            }
            DetailItem {
                label: qsTr("Author signature")
                value: messageObject.author_signature ? messageObject.author_signature : ""
                visible: !!value
            }
            DetailItem {
                label: qsTr("Via bot")
                value: infoPage.viaBotName()
                visible: !!value
            }
            DetailItem {
                label: qsTr("Forwarded from")
                value: infoPage.forwardOrigin()
                visible: !!value
            }
            DetailItem {
                label: qsTr("Original date")
                value: infoPage.fullDate(infoPage.forwardDate())
                visible: !!value
            }
            DetailItem {
                label: qsTr("Views")
                value: "" + infoPage.viewCount()
                visible: infoPage.viewCount() > 0
            }
            DetailItem {
                label: qsTr("Forwards")
                value: "" + infoPage.forwardCount()
                visible: infoPage.forwardCount() > 0
            }
            DetailItem {
                label: qsTr("Reactions")
                value: "" + infoPage.reactionsTotal()
                visible: infoPage.reactionsTotal() > 0
            }
            DetailItem {
                label: qsTr("Message ID")
                value: infoPage.realMessageId()
                visible: !!value
            }
            DetailItem {
                label: qsTr("Album ID")
                value: infoPage.albumId()
                visible: !!value
            }
        }
    }
}
