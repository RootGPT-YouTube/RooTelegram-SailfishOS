/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), which is
    licensed under the GNU General Public License v3.0. The original
    license is available at:
    https://github.com/Wunderfitz/harbour-fernschreiber/blob/master/LICENSE

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

// Sfondo del tema Barbara: la SUPERFICIE DEL TEMA (`surface`) più un reticolo
// tenue. È il pezzo che rende Barbara leggibile con qualunque ambience: il vetro
// delle card poggia su questa superficie, non sullo sfondo di sistema.
//
// Va messo come primo figlio della pagina (z negativo), al posto che occupa
// CircuitBackground in Neon. Come quello, è un Loader: con gli altri due temi
// non viene istanziato nulla.
//
// Niente SVG e niente FastBlur (che è il motivo per cui Barbara è più leggera di
// Neon): il reticolo è disegnato una volta sola su Canvas.

import QtQuick 2.6
import Sailfish.Silica 1.0
import "."

Loader {
    id: barbaraBackground
    z: -1
    anchors.fill: parent
    active: BarbaraTheme.active

    sourceComponent: Item {

        Rectangle {
            anchors.fill: parent
            color: BarbaraTheme.surface
        }

        // Reticolo 44px del mockup, riportato in proporzione alla larghezza dello
        // schermo. Una sola passata di disegno: si ridipinge solo al cambio di
        // ambience (chiara <-> scura) o di dimensione.
        Canvas {
            id: grid
            anchors.fill: parent
            opacity: 0.55
            renderStrategy: Canvas.Cooperative

            readonly property real step: Math.max(24, Math.round(Screen.width / 9))
            readonly property color lineColor: BarbaraTheme.grid

            onLineColorChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.clearRect(0, 0, width, height);
                ctx.strokeStyle = lineColor;
                ctx.lineWidth = 1;
                ctx.beginPath();
                var x, y;
                // Mezzo pixel di offset: senza, la linea da 1px finisce a cavallo
                // di due pixel e viene resa sbiadita su due righe.
                for (x = grid.step; x < width; x += grid.step) {
                    ctx.moveTo(Math.round(x) + 0.5, 0);
                    ctx.lineTo(Math.round(x) + 0.5, height);
                }
                for (y = grid.step; y < height; y += grid.step) {
                    ctx.moveTo(0, Math.round(y) + 0.5);
                    ctx.lineTo(width, Math.round(y) + 0.5);
                }
                ctx.stroke();
            }
        }
    }
}
