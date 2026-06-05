/*
    Copyright (C) 2026 RooTelegram contributors

    This file is part of RooTelegram.

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/

// Separatore in stile NEON BIANCO che SFUMA ALLE ESTREMITÀ: riusa le Separator
// di Silica (con horizontalAlignment AlignHCenter sfumano ai bordi, come quella
// originale) sovrapposte a opacità calante per dare un leggero "bloom" neon.
// Niente QtGraphicalEffects/Glow → leggero anche per-delegate nelle liste.

import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: neonSeparator
    width: parent ? parent.width : 0
    height: Math.round(Theme.paddingSmall / 2)

    readonly property bool neon: appSettings.useNeonTheme

    // Alone (bloom): due linee bianche tenui sopra/sotto — solo in tema Neon.
    Separator {
        visible: neonSeparator.neon
        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: -1 }
        width: parent.width
        color: Qt.rgba(1, 1, 1, 0.18)
        horizontalAlignment: Qt.AlignHCenter
    }
    Separator {
        visible: neonSeparator.neon
        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: 1 }
        width: parent.width
        color: Qt.rgba(1, 1, 1, 0.18)
        horizontalAlignment: Qt.AlignHCenter
    }
    // Linea centrale: bianca neon nitida, oppure Separator Silica standard.
    Separator {
        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
        width: parent.width
        color: neonSeparator.neon ? Qt.rgba(1, 1, 1, 0.9) : Theme.primaryColor
        horizontalAlignment: Qt.AlignHCenter
    }
}
