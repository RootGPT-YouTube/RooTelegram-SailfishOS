/*
    Copyright (C) 2026 RootGPT

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
import QtQuick 2.6
import Sailfish.Silica 1.0

// Pill "1× / 1.25× / 1.5×": un tap cicla appWindow.mediaPlaybackRate, la
// velocità condivisa da vocali e audio (NON video: il decoder hardware droid
// non regge il trick-play, vedi commento in harbour-rootelegram.qml).
MouseArea {
    id: speedButton

    // true = pill scura da overlay video; false = colori tema (bolle chat).
    property bool darkPill: true

    width: speedLabel.width + 2 * Theme.paddingMedium
    height: speedLabel.height + Theme.paddingSmall

    onClicked: appWindow.cycleMediaPlaybackRate()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: speedButton.darkPill ? Theme.rgba("#000000", 0.5)
                                    : Theme.rgba(Theme.primaryColor, speedButton.pressed ? 0.3 : 0.15)
        border.width: 1
        border.color: speedButton.darkPill ? Theme.rgba("#ffffff", 0.25)
                                           : Theme.rgba(Theme.primaryColor, 0.3)
    }

    Label {
        id: speedLabel
        anchors.centerIn: parent
        text: appWindow.mediaPlaybackRate === 1.25 ? "1.25×"
            : appWindow.mediaPlaybackRate === 1.5 ? "1.5×" : "1×"
        color: speedButton.darkPill ? "white"
                                    : (speedButton.pressed ? Theme.highlightColor : Theme.primaryColor)
        font.pixelSize: Theme.fontSizeExtraSmall
        font.bold: appWindow.mediaPlaybackRate !== 1.0
    }
}
