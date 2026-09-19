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
import "../../js/functions.js" as Functions
import "../../js/twemoji.js" as Emoji

// TDLib 1.8.67: messageRichMessage, disegnato nell'ordine dei client ufficiali.
// Qui: i blocchi che precedono la prima foto (di solito il titolo, piu' grande)
// e la foto, presentata come un messagePhoto (stesso download, stesse dimensioni,
// pagina a tutto schermo al tocco). Il seguito del post lo scrive la chat nel
// testo del messaggio (Functions.getMessageText), che resta selezionabile.
// ChatPage carica questo componente solo se il post ha almeno una foto.
MessageContentBase {
    id: richMessageContent

    readonly property var sourceMessage: messageListItem ? messageListItem.myMessage : overlayFlickable.overlayMessage
    readonly property var richLayout: Functions.getRichMessageLayout(sourceMessage ? sourceMessage.content : null)

    height: richColumn.height
    onClicked: richPhoto.clicked()

    Column {
        id: richColumn
        width: parent.width
        spacing: Theme.paddingMedium

        Text {
            width: parent.width
            text: richMessageContent.richLayout.head.length > 0
                  ? Emoji.emojify(Functions.pageBlocksToText(richMessageContent.richLayout.head, false), Theme.fontSizeMedium)
                  : ""
            visible: text !== ""
            font.pixelSize: Theme.fontSizeSmall
            color: messageListItem ? messageListItem.textColor : Theme.primaryColor
            linkColor: Functions.messageLinkColor()
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            textFormat: Text.RichText
            horizontalAlignment: messageListItem ? messageListItem.textAlign : Text.AlignLeft
            onLinkActivated: {
                var chatCommand = Functions.handleLink(link);
                if (chatCommand) {
                    tdLibWrapper.sendTextMessage(richMessageContent.sourceMessage.chat_id, chatCommand);
                }
            }
        }

        MessagePhoto {
            id: richPhoto
            messageListItem: richMessageContent.messageListItem
            overlayFlickable: richMessageContent.overlayFlickable
            rawMessage: Functions.richMessageAsPhotoMessage(richMessageContent.sourceMessage)
            width: Math.min(parent.width, preferredWidth)
            visible: !!richMessageContent.richLayout.photoBlock
        }
    }
}
