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
import "../js/functions.js" as Functions
import "../js/twemoji.js" as Emoji

// Il seguito di un articolo dai primi pulsanti in poi, nell'ordine in cui e' scritto:
// pulsanti, testo, altri pulsanti... (`segments` e' Functions.getRichMessageFlow().rest).
// ReplyMarkupButtons legge myMessage da qui.
Column {
    id: richMessageFlow

    property var myMessage
    property var segments: []
    // la foto che il messaggio disegna gia' sopra il testo
    property var skipBlock: null
    // con la selezione del testo l'articolo intero sta nel campo selezionabile
    property bool textVisible: true
    property color textColor: Theme.primaryColor
    property int textPixelSize: Theme.fontSizeSmall
    property int textAlign: Text.AlignLeft

    signal linkActivated(string link)

    width: parent.width
    spacing: Theme.paddingSmall

    Repeater {
        model: richMessageFlow.segments

        delegate: Column {
            readonly property var segment: modelData
            width: richMessageFlow.width
            spacing: Theme.paddingSmall

            Repeater {
                model: segment.rows
                delegate: ReplyMarkupButtons {
                    width: richMessageFlow.width
                    rows: [modelData.buttons]
                    align: modelData.align
                }
            }

            Text {
                width: parent.width
                visible: richMessageFlow.textVisible && text !== ""
                text: segment.blocks.length > 0
                      ? Emoji.emojify(Functions.pageBlocksToText(segment.blocks, false, richMessageFlow.skipBlock), Theme.fontSizeMedium)
                      : ""
                font.pixelSize: richMessageFlow.textPixelSize
                color: richMessageFlow.textColor
                linkColor: Functions.messageLinkColor()
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                textFormat: Text.RichText
                horizontalAlignment: richMessageFlow.textAlign
                onLinkActivated: richMessageFlow.linkActivated(link)
            }
        }
    }
}
