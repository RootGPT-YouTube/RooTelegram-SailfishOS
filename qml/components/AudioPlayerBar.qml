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
import QtMultimedia 5.6
import "."

// Barra del player unico (appWindow.sharedAudio): compare in cima a qualunque
// pagina finche' un brano o un vocale e' in riproduzione o in pausa, cosi' si
// puo' sempre mettere in pausa o fermare, anche da una chat diversa o dopo aver
// chiuso e riaperto l'app. Niente testi nuovi: solo icone e tempi.
// Anche precedente/successivo nella stessa chat, come in Telegram.
Rectangle {
    id: bar

    property var player
    property var playlist
    readonly property bool hasPlaylist: active && playlist && playlist.available

    readonly property bool active: player && player.ownerKey !== ""
                                   && player.playbackState !== Audio.StoppedState
    readonly property bool playing: active && player.playbackState === Audio.PlayingState

    // Pillola in alto a SINISTRA, non una striscia: a tutta larghezza copriva
    // l'intestazione della chat e il tocco sul titolo (che apre le info) finiva
    // sulla barra (visto sul POCO). Cosi' resta libera la parte destra.
    anchors {
        top: parent.top
        left: parent.left
        topMargin: Theme.paddingSmall
        leftMargin: Theme.paddingSmall
    }
    width: Math.min(parent.width * (hasPlaylist ? 0.7 : 0.6),
                    Theme.itemSizeSmall * 2 + Theme.paddingSmall * 4 + Theme.itemSizeExtraLarge * 2
                    + (hasPlaylist ? Theme.iconSizeMedium * 2 : 0))
    height: active ? Theme.itemSizeSmall : 0
    visible: height > 0
    clip: true
    radius: Theme.paddingMedium
    Behavior on height { NumberAnimation { duration: 150 } }

    // Opaca: con la trasparenza il titolo della pagina si leggeva attraverso.
    color: BarbaraTheme.active ? BarbaraTheme.panel : Theme.highlightDimmerColor
    border.width: 1
    border.color: BarbaraTheme.active ? BarbaraTheme.accentBorder : Theme.rgba(Theme.highlightColor, 0.4)

    // Assorbe i tap sulla barra: non devono arrivare all'header sotto.
    MouseArea {
        anchors.fill: parent
    }

    // Tasti stretti (larghi quanto l'icona): la pillola non deve crescere troppo
    // verso il titolo della chat.
    IconButton {
        id: previousButton
        anchors {
            left: parent.left
            leftMargin: Theme.paddingSmall
            verticalCenter: parent.verticalCenter
        }
        visible: bar.hasPlaylist
        width: visible ? Theme.iconSizeMedium : 0
        icon.source: "image://theme/icon-m-previous"
        onClicked: bar.playlist.step(-1, false)
    }

    IconButton {
        id: playPauseButton
        anchors {
            left: previousButton.right
            verticalCenter: parent.verticalCenter
        }
        icon.source: bar.playing ? "image://theme/icon-m-pause" : "image://theme/icon-m-play"
        onClicked: {
            if (bar.playing) {
                bar.player.pause();
            } else {
                bar.player.play();
            }
        }
    }

    IconButton {
        id: nextButton
        anchors {
            left: playPauseButton.right
            verticalCenter: parent.verticalCenter
        }
        visible: bar.hasPlaylist
        width: visible ? Theme.iconSizeMedium : 0
        icon.source: "image://theme/icon-m-next"
        onClicked: bar.playlist.step(1, false)
    }

    Column {
        anchors {
            left: nextButton.right
            right: closeButton.left
            leftMargin: Theme.paddingSmall
            rightMargin: Theme.paddingSmall
            verticalCenter: parent.verticalCenter
        }
        Label {
            width: parent.width
            text: bar.active ? bar.player.title : ""
            truncationMode: TruncationMode.Fade
            font.pixelSize: Theme.fontSizeSmall
            color: BarbaraTheme.active ? BarbaraTheme.ink : Theme.highlightColor
        }
        Label {
            width: parent.width
            text: bar.active
                  ? Format.formatDuration(bar.player.position / 1000, Formatter.DurationShort)
                    + (bar.player.duration > 0
                       ? " / " + Format.formatDuration(bar.player.duration / 1000, Formatter.DurationShort)
                       : "")
                  : ""
            font.pixelSize: Theme.fontSizeExtraSmall
            color: BarbaraTheme.active ? BarbaraTheme.inkSecondary : Theme.secondaryHighlightColor
        }
    }

    IconButton {
        id: closeButton
        anchors {
            right: parent.right
            rightMargin: Theme.paddingSmall
            verticalCenter: parent.verticalCenter
        }
        icon.source: "image://theme/icon-m-clear"
        onClicked: appWindow.stopSharedAudio()
    }

    // Avanzamento: una riga sottile sul bordo inferiore.
    Rectangle {
        anchors {
            left: parent.left
            bottom: parent.bottom
        }
        height: Math.max(2, Theme.paddingSmall / 3)
        width: (bar.active && bar.player.duration > 0)
               ? parent.width * Math.min(1, bar.player.position / bar.player.duration) : 0
        color: BarbaraTheme.active ? BarbaraTheme.accent : Theme.highlightColor
    }
}
