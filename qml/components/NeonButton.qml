/*
    Copyright (C) 2026 RooTelegram contributors

    This file is part of RooTelegram.

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/

// Pulsante in stile "FINESTRA A NEON" (2.0 Cyberpunk): cartello di vetro
// (Rectangle translucido + bordo arancione luminoso) + scritta neon BIANCA
// centrata (alone Glow + nucleo nitido), stesso linguaggio di AccordionItem
// e dei fumetti glassmorphism delle chat.
//
// Drop-in al posto di una Silica `Button`: espone `text`, `enabled`,
// il segnale `clicked()` e si auto-dimensiona (oppure imponi `width`).
// Niente blur (CPU): solo Glow sul testo.

import QtQuick 2.6
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0

MouseArea {
    id: neonButton

    property string text: ""
    property bool down: pressed && containsMouse
    // colore base del bordo/alone: arancione brand, sovrascrivibile (es. azioni distruttive)
    property color accentColor: "#ff8a3d"

    enabled: true

    implicitHeight: Math.max(Theme.itemSizeSmall, labelCore.implicitHeight + 2 * Theme.paddingMedium)
    implicitWidth: Math.min(
                       Screen.width - 2 * Theme.horizontalPageMargin,
                       labelCore.implicitWidth + 4 * Theme.paddingLarge)
    width: implicitWidth
    height: implicitHeight

    opacity: enabled ? 1.0 : 0.4
    Behavior on opacity { FadeAnimation {} }

    Rectangle {
        id: glassCard
        anchors.fill: parent
        radius: Theme.paddingLarge
        color: Theme.rgba("#ffffff", neonButton.down ? 0.14 : 0.06)
        border.width: 2
        border.color: Theme.rgba(neonButton.accentColor, neonButton.down ? 0.80 : 0.45)
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
    }

    // Scritta neon bianca: alone (Glow) + nucleo nitido.
    Label {
        id: labelHalo
        anchors {
            left: glassCard.left
            right: glassCard.right
            verticalCenter: glassCard.verticalCenter
            leftMargin: Theme.paddingMedium
            rightMargin: Theme.paddingMedium
        }
        horizontalAlignment: Text.AlignHCenter
        truncationMode: TruncationMode.Fade
        text: neonButton.text
        font.family: Theme.fontFamilyHeading
        font.italic: true
        color: "#ffffff"
        textFormat: Text.PlainText
        layer.enabled: true
        layer.effect: Glow {
            color: "#ffffff"
            radius: 12
            samples: 25
            spread: 0.20
            transparentBorder: true
        }
    }
    Label {
        id: labelCore
        anchors {
            left: glassCard.left
            right: glassCard.right
            verticalCenter: glassCard.verticalCenter
            leftMargin: Theme.paddingMedium
            rightMargin: Theme.paddingMedium
        }
        horizontalAlignment: Text.AlignHCenter
        truncationMode: TruncationMode.Fade
        text: neonButton.text
        font.family: Theme.fontFamilyHeading
        font.italic: true
        color: "#ffffff"
        textFormat: Text.PlainText
    }
}
