/*
    Copyright (C) 2026 RooTelegram contributors

    This file is part of RooTelegram.

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/

// Sfondo a tema "circuiti elettrici" blu scintillanti (#19): SVG di circuiti reso
// molto trasparente (non disturba la lettura) con un leggero GLOW blu (QtSvg non
// supporta i filtri SVG, quindi il bagliore lo aggiungiamo qui). Va messo come
// primo figlio della pagina con z negativo, così sta dietro la lista/contenuti.

import QtQuick 2.6
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0

// Tema Silica: lo sfondo non viene istanziato affatto (il Loader resta inattivo),
// così non si paga né l'SVG né il FastBlur → è parte del guadagno prestazioni.
Loader {
    id: circuitBackground
    z: -1
    anchors.fill: parent
    active: appSettings.useNeonTheme
    asynchronous: true
    sourceComponent: Image {
        source: Qt.resolvedUrl("../../images/bg_circuits.svg")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        opacity: 0.12
        // Render dell'SVG alla risoluzione di schermo (nitido).
        sourceSize.width: width > 0 ? width : Screen.width
        sourceSize.height: height > 0 ? height : Screen.height
        // Forte sfocatura: i circuiti diventano una "foschia" blu diffusa, molto meno
        // invadente (il blu sfocato fa anche da alone scintillante). One-time su
        // immagine statica → nessun costo per-frame.
        layer.enabled: true
        layer.effect: FastBlur {
            radius: 48
            transparentBorder: true
        }
    }
}
