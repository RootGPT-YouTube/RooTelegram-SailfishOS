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
import "../js/whatsnew.js" as WhatsNew

Dialog {
    id: whatsNewDialog
    allowedOrientations: Orientation.All

    // Lingua dell'app = locale di sistema (SailfishApp carica i .qm in base ad
    // essa). Prendiamo il codice a 2 lettere (es. "it" da "it_IT") per scegliere
    // changelog/messaggio dal whatsnew.js, con fallback a "en" gestito nei getter.
    readonly property string uiLang: Qt.locale().name.substring(0, 2)
    readonly property string uiMessage: WhatsNew.messageFor(uiLang)

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        VerticalScrollDecorator {}

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            DialogHeader {
                acceptText: qsTr("Continua")
                cancelText: ""
            }

            Item {
                width: parent.width
                height: Math.max(novaIcon.height, titleColumn.height)

                Image {
                    id: novaIcon
                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.horizontalPageMargin
                    // icon-l-about non esiste nel tema di SFOS 5.1 (c'e' solo la
                    // taglia -m-): qui ci sta meglio l'icona dell'app
                    source: Qt.resolvedUrl("../../images/rootelegram.svg")
                    width: Theme.iconSizeLarge
                    height: Theme.iconSizeLarge
                }

                Column {
                    id: titleColumn
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: novaIcon.right
                    anchors.leftMargin: Theme.paddingLarge
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.horizontalPageMargin

                    Label {
                        width: parent.width
                        text: qsTr("Novità")
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.highlightColor
                        wrapMode: Text.Wrap
                    }
                    Label {
                        width: parent.width
                        text: "RooTelegram " + appVersion
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.secondaryHighlightColor
                        wrapMode: Text.Wrap
                    }
                }
            }

            // Elenco puntato dei cambiamenti di questa versione.
            Repeater {
                model: WhatsNew.changelogFor(whatsNewDialog.uiLang)

                Row {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    spacing: Theme.paddingMedium

                    Label {
                        text: "•"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.highlightColor
                    }
                    Label {
                        width: parent.width - Theme.paddingMedium - Theme.fontSizeMedium
                        text: modelData
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
                    }
                }
            }

            // Messaggio opzionale dello sviluppatore.
            Item {
                width: parent.width
                height: Theme.paddingMedium
                visible: whatsNewDialog.uiMessage !== ""
            }
            Label {
                visible: whatsNewDialog.uiMessage !== ""
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: whatsNewDialog.uiMessage
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                wrapMode: Text.Wrap
            }
        }
    }
}
