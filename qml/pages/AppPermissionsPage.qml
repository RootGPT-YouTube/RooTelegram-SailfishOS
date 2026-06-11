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

// Gate soft dei permessi: SailfishOS (Sailjail) concede tutti i permessi
// dichiarati nel .desktop in un colpo solo all'avvio. Questa pagina NON revoca
// il permesso di sistema (solo le Impostazioni di SailfishOS possono farlo): è
// un controllo applicativo che RooTelegram rispetta PRIMA di usare la risorsa.
// Ogni voce è disattivabile singolarmente. Default: tutto concesso.

import QtQuick 2.6
import Sailfish.Silica 1.0
import WerkWolf.RooTelegram 1.0
import "../components"

Page {
    id: appPermissionsPage
    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height

        VerticalScrollDecorator {}

        Column {
            id: contentColumn
            width: parent.width
            bottomPadding: Theme.paddingLarge

            PageHeader {
                title: qsTr("App permissions")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                text: qsTr("Turn off the resources you don't want RooTelegram to use. This only blocks the app internally — to fully revoke a system permission use the SailfishOS Settings.")
            }

            // --- SEZIONE 1: sensori e dati personali (sicuri da disattivare) ---
            SectionHeader {
                text: qsTr("Sensors and personal data")
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("Safe to turn off: only the related feature stops working, the rest of the app keeps running normally.")
            }

            PermissionSwitch {
                perm: "location"
                text: qsTr("Location")
                description: qsTr("Attaching your location and inline bots that request it.")
            }
            PermissionSwitch {
                perm: "camera"
                text: qsTr("Camera")
                description: qsTr("Video during calls.")
            }
            PermissionSwitch {
                perm: "microphone"
                text: qsTr("Microphone")
                description: qsTr("Voice messages and audio during calls.")
            }
            PermissionSwitch {
                perm: "contacts"
                text: qsTr("Contacts")
                description: qsTr("Synchronizing your address book with Telegram.")
            }

            // --- SEZIONE 2: accesso a foto/video/file (disattiva con cautela) ---
            SectionHeader {
                text: qsTr("Photos, videos and files")
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("Turn off with caution: these are needed to attach and send media. With one off you won't be able to pick that kind of file to send.")
            }

            PermissionSwitch {
                perm: "pictures"
                text: qsTr("Images")
                description: qsTr("Picking photos to send or to set as profile/story.")
            }
            PermissionSwitch {
                perm: "videos"
                text: qsTr("Videos")
                description: qsTr("Picking videos to send or to post as a story.")
            }
            PermissionSwitch {
                perm: "documents"
                text: qsTr("Documents and files")
                description: qsTr("Picking arbitrary files to send as documents.")
            }

            // --- SEZIONE 3: permessi di sistema (informativa, non gateabili) ---
            SectionHeader {
                text: qsTr("System permissions")
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("Internet access and other low-level permissions are required for the app to work at all and are managed by SailfishOS. To revoke them, open the system Settings → Apps → RooTelegram.")
            }
        }
    }
}
