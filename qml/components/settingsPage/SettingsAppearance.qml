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
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0
import WerkWolf.RooTelegram 1.0
import ".."

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

            // Selettore tema RooTelegram: Silica (base, leggero), Neon (cyberpunk)
            // o Barbara (vetro ciano, palette propria chiara/scura).
            // Alla scelta di un tema diverso da quello attivo chiediamo conferma in un
            // popup ("Applica ora? Sì/No"); applichiamo solo dopo conferma.
            // ── Selettore tema: TRE PILLOLE (SILICA/NEON/BARBARA), l'attiva
            // evidenziata. UNICO componente per tutti e tre i temi (niente più
            // ComboBox): ciascuna pillola cambia colori/font/bordo secondo il
            // tema ATTIVO, con lo stesso linguaggio visivo già usato altrove
            // nell'app (AccordionItem, NeonButton, NeonMenuOverlay).
            // ⭐ Motivo tecnico oltre all'estetica: la ComboBox nativa usata in
            // precedenza per Silica/Neon si "rompeva" (menu a tendina instabile);
            // le pillole sono un semplice MouseArea, niente popup nativo.
            Column {
                id: themeSelector
                width: parent.columnWidth
                spacing: Theme.paddingSmall

                readonly property bool neon: appSettings.useNeonTheme
                readonly property bool barbara: BarbaraTheme.active

                readonly property string description: barbara
                    ? qsTr("Cold glass and cyan, readable with both light and dark ambiences")
                    : (neon
                       ? qsTr("Cyberpunk look (requires a dark and orange theme for the perfect experience)")
                       : qsTr("Silica base theme (lighter, also good on light themes)"))

                // Tema richiesto dalle pillole, in attesa di conferma nel dialog.
                property int pendingTheme: AppSettings.ThemeSilica

                // Le pillole seguono l'ordine dell'enum: 0 Silica, 1 Neon, 2 Barbara.
                function requestTheme(wantTheme) {
                    if (wantTheme === appSettings.appTheme) {
                        return; // nessun cambiamento
                    }
                    themeSelector.pendingTheme = wantTheme;
                    // Push differito (Timer, non Qt.callLater: assente in Qt 5.6 di SFOS):
                    // il tocco sulla pillola sta ancora propagandosi, spingere la Dialog
                    // nello stesso giro d'eventi la farebbe "mangiare".
                    openThemeDialogTimer.restart();
                }

                Timer {
                    id: openThemeDialogTimer
                    interval: 1
                    repeat: false
                    onTriggered: {
                        var wantTheme = themeSelector.pendingTheme;
                        var dialog = pageStack.push(Qt.resolvedUrl("../../pages/ThemeConfirmDialog.qml"),
                                                    { "wantTheme": wantTheme });
                        dialog.accepted.connect(function() {
                            appSettings.appTheme = wantTheme;
                        });
                    }
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: qsTr("Choose RooTelegram's theme")
                    font.pixelSize: Theme.fontSizeSmall
                    color: themeSelector.barbara ? BarbaraTheme.inkSecondary
                         : (themeSelector.neon ? "#ffffff" : Theme.secondaryHighlightColor)
                    wrapMode: Text.Wrap
                }

                Row {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    spacing: Theme.paddingSmall

                    Repeater {
                        model: 3
                        delegate: Item {
                            id: themePill
                            width: Math.floor((parent.width - 2 * Theme.paddingSmall) / 3)
                            height: Math.round(Theme.fontSizeSmall * 1.2) + 2 * Theme.paddingSmall
                            readonly property bool isCurrent: appSettings.appTheme === index

                            Rectangle {
                                anchors.fill: parent
                                radius: themeSelector.neon ? Theme.paddingLarge
                                      : (themeSelector.barbara ? BarbaraTheme.radiusBubble : 0)
                                color: themeSelector.barbara
                                       ? (themePill.isCurrent ? BarbaraTheme.accent
                                          : (pillArea.pressed ? BarbaraTheme.accentWash : "transparent"))
                                     : themeSelector.neon
                                       ? Theme.rgba("#ffffff", themePill.isCurrent ? 0.16 : (pillArea.pressed ? 0.12 : 0.06))
                                       : (themePill.isCurrent ? Theme.rgba(Theme.highlightColor, 0.15)
                                          : (pillArea.pressed ? Theme.rgba(Theme.highlightColor, 0.08) : "transparent"))
                                border.width: themeSelector.barbara ? (themePill.isCurrent ? 0 : BarbaraTheme.borderWidth)
                                            : themeSelector.neon ? 2
                                            : 1
                                border.color: themeSelector.barbara ? BarbaraTheme.glassBorder
                                            : themeSelector.neon ? Theme.rgba("#ff8a3d", themePill.isCurrent ? 0.85 : 0.45)
                                            : Theme.rgba(Theme.primaryColor, 0.2)
                                Behavior on color {
                                    ColorAnimation { duration: themeSelector.barbara ? BarbaraTheme.pressDuration : 150 }
                                }
                            }
                            Label {
                                anchors.fill: parent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: index === 0 ? "SILICA" : (index === 1 ? "NEON" : "BARBARA")
                                font.family: themeSelector.barbara ? BarbaraTheme.fontFamilyMono
                                           : (themeSelector.neon ? Theme.fontFamilyHeading : Theme.fontFamily)
                                font.italic: themeSelector.neon
                                font.pixelSize: themeSelector.barbara ? BarbaraTheme.fontSizeMetaSmall : Theme.fontSizeExtraSmall
                                font.bold: themePill.isCurrent && !themeSelector.neon
                                color: themeSelector.barbara ? (themePill.isCurrent ? BarbaraTheme.onAccent : BarbaraTheme.inkSecondary)
                                     : themeSelector.neon ? (themePill.isCurrent ? "#fff3e6" : "#ffffff")
                                     : (themePill.isCurrent ? Theme.highlightColor : Theme.primaryColor)
                                truncationMode: TruncationMode.Fade
                                maximumLineCount: 1
                                // Alone neon: solo sulla pillola del tema attivo, come un'insegna accesa.
                                layer.enabled: themeSelector.neon && themePill.isCurrent
                                layer.effect: Glow {
                                    color: "#ff9a3d"
                                    radius: 8
                                    samples: 17
                                    spread: 0.35
                                    transparentBorder: true
                                }
                            }
                            MouseArea {
                                id: pillArea
                                anchors.fill: parent
                                onClicked: themeSelector.requestTheme(index)
                            }
                        }
                    }
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: themeSelector.description
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: themeSelector.barbara ? BarbaraTheme.inkSecondary
                         : (themeSelector.neon ? Theme.rgba("#ffffff", 0.7) : Theme.secondaryColor)
                    wrapMode: Text.Wrap
                }
            }

            // Interruttore proprio di Barbara: l'alone sui titoli ha effetto solo con
            // ambience scura, e si puo' spegnere del tutto (utile su device lenti).
            TextSwitch {
                width: parent.columnWidth
                visible: BarbaraTheme.active
                checked: appSettings.barbaraGlowTitles
                text: qsTr("Glow on titles")
                description: qsTr("Barbara theme only, and only with a dark ambience")
                automaticCheck: false
                onClicked: {
                    heightBehavior.enabled = true
                    appSettings.barbaraGlowTitles = !checked
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
