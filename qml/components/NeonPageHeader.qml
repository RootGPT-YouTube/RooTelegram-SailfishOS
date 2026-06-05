/*
    Copyright (C) 2026 RooTelegram contributors

    This file is part of RooTelegram.

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/

// Header di pagina in stile NEON ARANCIONE (brand RooTelegram): alone arancione
// + nucleo chiaro, corsivo, font heading. Stesso linguaggio del titolo home,
// dell'header chat e della lista topic. Espone `text` (titolo) e `description`
// (sottotitolo opzionale). Drop-in al posto di un PageHeader.
//
// Con il tema SILICA (appSettings.useNeonTheme == false) il titolo torna allo
// stile header Silica nativo: niente alone/glow, colore highlight, non corsivo
// (resta allineato a destra, come gli header Silica).

import QtQuick 2.6
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0

PageHeader {
    id: neonHeader
    property string text: ""
    property string description: ""
    readonly property bool neon: appSettings.useNeonTheme

    title: ""
    height: Theme.itemSizeLarge

    // Alone arancione: solo in tema Neon.
    Label {
        id: neonHalo
        visible: neonHeader.neon
        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; bottom: parent.verticalCenter }
        width: Math.min(implicitWidth, neonHeader.width - 2 * Theme.horizontalPageMargin)
        horizontalAlignment: Text.AlignRight
        text: neonCore.text
        textFormat: Text.StyledText
        font.pixelSize: Theme.fontSizeLarge
        font.family: Theme.fontFamilyHeading
        font.italic: true
        truncationMode: TruncationMode.Elide
        maximumLineCount: 1
        color: "#e65000"
        layer.enabled: true
        layer.effect: Glow {
            color: "#e65000"
            radius: 18
            samples: 37
            spread: 0.30
            transparentBorder: true
        }
    }
    // Nucleo: visibile in entrambi i temi, ma stile condizionale.
    Label {
        id: neonCore
        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; bottom: parent.verticalCenter }
        width: Math.min(implicitWidth, neonHeader.width - 2 * Theme.horizontalPageMargin)
        horizontalAlignment: Text.AlignRight
        text: neonHeader.text
        textFormat: Text.StyledText
        font.pixelSize: Theme.fontSizeLarge
        font.family: neonHeader.neon ? Theme.fontFamilyHeading : Theme.fontFamily
        font.italic: neonHeader.neon
        truncationMode: TruncationMode.Elide
        maximumLineCount: 1
        color: neonHeader.neon ? "#fff3e6" : Theme.highlightColor
        layer.enabled: neonHeader.neon
        layer.effect: Glow {
            color: "#ff9a3d"
            radius: 6
            samples: 13
            spread: 0.55
            transparentBorder: true
        }
    }
    Label {
        id: neonDesc
        visible: neonHeader.description !== ""
        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; top: parent.verticalCenter; topMargin: Theme.paddingSmall / 2 }
        horizontalAlignment: Text.AlignRight
        text: neonHeader.description
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.secondaryColor
    }
}
