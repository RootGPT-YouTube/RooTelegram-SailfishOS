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

AccordionItem {
    text: qsTr("Appearance")
    clip: heightBehavior.enabled || heightAnimation.running

    // One-shot behavior
    Behavior on height {
        id: heightBehavior
        enabled: false
        SequentialAnimation {
            id: heightAnimation
            SmoothedAnimation { duration: 200 }
            ScriptAction { script: heightBehavior.enabled = false }
        }
    }

    Component {
        ResponsiveGrid {
            bottomPadding: Theme.paddingMedium

            // Selettore tema RooTelegram: Silica (base, leggero) o Neon (cyberpunk).
            // Alla scelta di un tema diverso da quello attivo chiediamo conferma in un
            // popup ("Applica ora? Sì/No"); applichiamo solo dopo conferma.
            ComboBox {
                id: themeCombo
                width: parent.columnWidth
                label: qsTr("Choose RooTelegram's theme")
                currentIndex: appSettings.useNeonTheme ? 1 : 0
                description: appSettings.useNeonTheme
                    ? qsTr("Cyberpunk look (requires a dark and orange theme for the perfect experience)")
                    : qsTr("Silica base theme (lighter, also good on light themes)")

                // Tema richiesto dalla tendina, in attesa di conferma.
                property bool pendingWantNeon: false

                // Riallinea la tendina al tema realmente attivo (dopo apply o annullo).
                function syncSelection() {
                    themeCombo.currentIndex = appSettings.useNeonTheme ? 1 : 0;
                }

                // index 0 = Silica, index 1 = Neon. Conferma prima di applicare.
                function requestTheme(wantNeon) {
                    if (wantNeon === appSettings.useNeonTheme) {
                        return; // nessun cambiamento
                    }
                    themeCombo.pendingWantNeon = wantNeon;
                    // Push differito (Timer, non Qt.callLater: assente in Qt 5.6 di SFOS):
                    // la ContextMenu si sta chiudendo, spingere la Dialog nello stesso giro
                    // d'eventi la farebbe "mangiare".
                    openThemeDialogTimer.restart();
                }

                Timer {
                    id: openThemeDialogTimer
                    interval: 1
                    repeat: false
                    onTriggered: {
                        var wantNeon = themeCombo.pendingWantNeon;
                        var dialog = pageStack.push(Qt.resolvedUrl("../../pages/ThemeConfirmDialog.qml"),
                                                    { "wantNeon": wantNeon });
                        dialog.accepted.connect(function() {
                            appSettings.useNeonTheme = wantNeon;
                            themeCombo.syncSelection();
                        });
                        dialog.rejected.connect(function() {
                            themeCombo.syncSelection();
                        });
                    }
                }

                menu: ContextMenu {
                    MenuItem {
                        text: qsTr("Silica (base theme)")
                        onClicked: themeCombo.requestTheme(false)
                    }
                    MenuItem {
                        text: qsTr("Neon (cyberpunk)")
                        onClicked: themeCombo.requestTheme(true)
                    }
                }

                Connections {
                    target: appSettings
                    onUseNeonThemeChanged: themeCombo.syncSelection()
                }
            }

            TextSwitch {
                width: parent.columnWidth
                checked: appSettings.showStickersAsEmojis
                text: qsTr("Show stickers as emojis")
                description: qsTr("Only display emojis instead of the actual stickers")
                automaticCheck: false
                onClicked: {
                    heightBehavior.enabled = true
                    appSettings.showStickersAsEmojis = !checked
                }
            }

            TextSwitch {
                width: parent.columnWidth
                checked: appSettings.showStickersAsImages
                text: qsTr("Show stickers as images")
                description: qsTr("Show background for stickers and align them centrally like images")
                automaticCheck: false
                onClicked: {
                    appSettings.showStickersAsImages = !checked
                }
                visible: !appSettings.showStickersAsEmojis
                opacity: visible ? 1 : 0
                Behavior on opacity { FadeAnimation  { } }
            }

            Item {
                // Placeholder to move the next switch to the second column
                visible: parent.columns === 2
                width: 1
                height: 1
            }

            TextSwitch {
                width: parent.columnWidth
                checked: appSettings.animateStickers
                text: qsTr("Animate stickers")
                automaticCheck: false
                onClicked: {
                    appSettings.animateStickers = !checked
                }
                visible: !appSettings.showStickersAsEmojis
                opacity: visible ? 1 : 0
                Behavior on opacity { FadeAnimation  { } }
            }
        }
    }
}
