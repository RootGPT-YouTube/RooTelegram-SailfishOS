/*
    Copyright (C) 2021 Sebastian J. Wolf and other contributors

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
import ".."

AccordionItem {
    text: qsTr("Storage")
    Component {
        ResponsiveGrid {
            bottomPadding: Theme.paddingMedium
            TextSwitch {
                width: parent.columnWidth
                checked: appSettings.onlineOnlyMode
                text: qsTr("Enable online-only mode")
                description: qsTr("Disables offline caching. Certain features may be limited or missing in this mode. Changes require a restart of RooTelegram to take effect.")
                automaticCheck: false
                onClicked: {
                    appSettings.onlineOnlyMode = !checked
                }
            }

            TextSwitch {
                width: parent.columnWidth
                checked: appSettings.storageOptimizer
                text: qsTr("Enable storage optimizer")
                automaticCheck: false
                onClicked: {
                    appSettings.storageOptimizer = !checked
                }
            }

            // Scorciatoia alle chat archiviate (#4 v2.4). NeonButton: stile neon col
            // tema Neon, fallback Button Silica nativo altrimenti.
            NeonButton {
                width: parent.columnWidth
                text: qsTr("Archived chats")
                onClicked: pageStack.push(Qt.resolvedUrl("../../pages/ArchivedChatsPage.qml"))
            }

            // Stesso separatore che divide una chat dall'altra nella home (sfuma
            // ai bordi, neon in tema Neon). La linea interna è centrata verticalmente:
            // alziamo l'altezza dell'elemento per dare respiro sopra e sotto, così il
            // divisorio si stacca bene dai due pulsanti.
            NeonSeparator {
                width: parent.columnWidth
                height: Theme.itemSizeExtraSmall
            }

            // "Kill the Daemon!": kill forzato dell'app/daemon (SIGKILL nativo, vedi
            // ProcessLauncher::killApp). SOLO l'etichetta del pulsante resta SEMPRE
            // in inglese (richiesta esplicita): NON va passata da qsTr. La descrizione
            // "di lore" è invece tradotta in tutte le lingue (corsivo, tra virgolette).
            Column {
                width: parent.columnWidth
                spacing: Theme.paddingSmall
                NeonButton {
                    width: parent.width
                    text: "Kill the Daemon!"
                    onClicked: processLauncher.killApp()
                }
                Label {
                    width: parent.width
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeExtraSmall
                    font.italic: true
                    color: Theme.secondaryColor
                    text: qsTr("“Seal the domain of the Daemon and close its cycle in the void of the eternal log!”")
                }
            }
        }
    }
}
