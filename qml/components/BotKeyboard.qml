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
import "../js/twemoji.js" as Emoji

// Tastiera personalizzata di un bot (replyMarkupShowKeyboard). A differenza dei
// pulsanti inline non appartiene a un messaggio ma alla CHAT: sta fissa sopra la
// barra di scrittura finche' il bot non la cambia o la toglie
// (updateChatReplyMarkup), come nei client ufficiali. Prima era disegnata dentro
// ogni messaggio e scorreva via a ogni messaggio nuovo (segnalazione di un tester,
// 19/09/2026).
Column {
    id: botKeyboard

    // il messaggio che porta la tastiera (chat.reply_markup_message_id)
    property var markupMessage: null
    readonly property var markup: (markupMessage && markupMessage.reply_markup
                                   && markupMessage.reply_markup["@type"] === "replyMarkupShowKeyboard")
                                  ? markupMessage.reply_markup : null

    // pulsante di testo premuto: la chat manda il testo
    signal textButtonClicked(string text)

    spacing: Theme.paddingSmall

    Repeater {
        model: botKeyboard.markup ? botKeyboard.markup.rows : []
        delegate: Row {
            width: botKeyboard.width
            height: Theme.itemSizeSmall
            spacing: Theme.paddingSmall

            Repeater {
                id: rowRepeater
                model: modelData
                delegate: MouseArea {
                    // Per ora solo i pulsanti di testo; gli altri (telefono, posizione,
                    // sondaggio, web app...) si vedono ma sono spenti.
                    enabled: modelData.type["@type"] === "keyboardButtonTypeText"
                    width: (botKeyboard.width + Theme.paddingSmall) / rowRepeater.count - Theme.paddingSmall
                    height: Theme.itemSizeSmall
                    onClicked: botKeyboard.textButtonClicked(modelData.text)

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.paddingSmall
                        color: parent.pressed ? Theme.rgba(Theme.highlightBackgroundColor, Theme.highlightBackgroundOpacity)
                                              : Theme.rgba(Theme.primaryColor, Theme.opacityFaint)
                        opacity: parent.enabled ? 1.0 : Theme.opacityLow

                        Label {
                            anchors.centerIn: parent
                            width: Math.min(parent.width - Theme.paddingSmall * 2, contentWidth)
                            truncationMode: TruncationMode.Fade
                            text: Emoji.emojify(modelData.text, Theme.fontSizeSmall)
                            color: parent.parent.pressed ? Theme.highlightColor : Theme.primaryColor
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }
            }
        }
    }
}
