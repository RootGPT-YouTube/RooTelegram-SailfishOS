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

// Scelta "per tutti" / "solo per me" per la cancellazione di più messaggi (#1).
// Si accetta solo tramite i due pulsanti, che impostano `revoke` ed emettono
// accepted(); il chiamante esegue poi la cancellazione (col Remorse).
Dialog {
    id: dialog
    allowedOrientations: Orientation.All

    property int count: 1
    property bool revoke: false

    // L'accettazione avviene via i due pulsanti (impostano revoke e chiamano
    // accept()). canAccept resta true perché in alcune versioni Silica accept()
    // è ignorato se canAccept è false. Lo swipe-forward accidentale usa il
    // default revoke=false ("solo per me"), comportamento sicuro.
    canAccept: true

    Column {
        width: parent.width
        spacing: Theme.paddingLarge

        DialogHeader {
            acceptText: ""
            cancelText: qsTr("Cancel")
        }

        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            wrapMode: Text.Wrap
            color: Theme.highlightColor
            font.pixelSize: Theme.fontSizeLarge
            text: qsTr("Delete %Ln message(s)?", "", dialog.count)
        }

        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Delete for everyone")
            onClicked: {
                dialog.revoke = true;
                dialog.accept();
            }
        }

        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Delete for me")
            onClicked: {
                dialog.revoke = false;
                dialog.accept();
            }
        }
    }
}
