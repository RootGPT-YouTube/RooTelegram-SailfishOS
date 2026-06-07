/*
    Copyright (C) 2020 Sebastian J. Wolf and other contributors
    Forked in 2026 by RootGPT

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
import "../"
import "../../js/functions.js" as Functions

// GIF Telegram (messageAnimation): i file sono quasi sempre MP4 H.264.
// Il decoder GStreamer di Sailfish (droidvdec, HW) NON svuota il reorder-buffer
// dei B-frame all'EOS → perde gli ultimi ~0.5-1s ("si troncava"). AnimatedImage
// non decodifica MP4 (i plugin Qt fanno solo gif/webp).
//
// Soluzione: al primo play transcodifichiamo l'MP4 -> GIF animata con l'ffmpeg
// bundlato (cache su disco per uniqueId) e la riproduciamo con AnimatedImage,
// bypassando del tutto GStreamer: niente troncatura, niente leak (quindi può
// anche ciclare). Le animazioni già image/gif/webp vanno dirette in AnimatedImage.
//   - Loader active=false finché non si tappa: lo scroll non decodifica nulla.
//   - onScreen=false → stop e teardown.
MessageContentBase {
    id: animationComponent

    property var animationData: rawMessage.content.animation
    // Download REATTIVO via TDLibFile (come foto/video): una GIF che arriva mentre
    // sei già nella chat si aggiorna da sola, senza dover uscire e rientrare.
    readonly property string animationUrl: animFile.isDownloadingCompleted ? animFile.path : ""
    readonly property string mimeType: animationData ? (animationData.mime_type || "") : ""
    // AnimatedImage decodifica nativamente solo gif/webp; gli MP4 vanno transcodificati.
    readonly property bool nativeAnimated: mimeType === "image/gif" || mimeType === "image/webp"
    // Path effettivo dato ad AnimatedImage: il file stesso se nativo, altrimenti la
    // GIF transcodificata (gifPath, valorizzata quando la conversione è pronta).
    readonly property string playSource: nativeAnimated ? animationUrl : gifPath
    property string gifPath: ""
    property bool converting: false
    // Chiave di cache stabile (content-based) letta dal messaggio grezzo:
    // animFile.uniqueId risultava vuoto, qui il campo c'è sempre.
    readonly property string fileUniqueId: (animationData && animationData.animation && animationData.animation.remote)
                                           ? (animationData.animation.remote.unique_id || "") : ""

    readonly property bool downloading: !!animationData && !animFile.isDownloadingCompleted
    property bool playing: false
    property bool onScreen: messageListItem ? messageListItem.page.status === PageStatus.Active : true

    height: Functions.getVideoHeight(width, animationData)

    TDLibFile {
        id: animFile
        tdlib: tdLibWrapper
        autoLoad: true
        fileInformation: animationData ? animationData.animation : ({})
    }

    // Avvia la transcodifica MP4->GIF (se serve) e poi riproduce.
    function startPlayback() {
        if (animationUrl === "") {
            return;
        }
        if (nativeAnimated) {
            playing = true;
            return;
        }
        if (gifPath !== "") {
            playing = true;
            return;
        }
        // MP4: serve la GIF. Se è già in cache la otteniamo subito (segnale sync),
        // altrimenti parte la conversione e riprodurremo a conversione pronta.
        converting = true;
        playing = true;
        videoTranscoder.requestGifConversion(animationUrl, fileUniqueId);
    }

    Connections {
        target: videoTranscoder
        onGifConversionReady: {
            if (uniqueId === animationComponent.fileUniqueId) {
                animationComponent.gifPath = gifPath;
                animationComponent.converting = false;
            }
        }
        onGifConversionFailed: {
            if (uniqueId === animationComponent.fileUniqueId) {
                animationComponent.converting = false;
                animationComponent.playing = false;
            }
        }
    }

    // Lasciare la pagina: ferma e libera tutto.
    onOnScreenChanged: {
        if (!onScreen) {
            playing = false;
        }
    }

    TDLibThumbnail {
        id: placeholderThumbnail
        anchors.fill: parent
        thumbnail: animationData ? animationData.thumbnail : undefined
        minithumbnail: animationData ? animationData.minithumbnail : undefined
        highlighted: animationComponent.highlighted
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Medium
        running: animationComponent.downloading || animationComponent.converting
        visible: running
    }

    // Lazy loading: nessun decoder finché non si tappa play.
    Loader {
        id: animationLoader
        anchors.fill: parent
        asynchronous: true
        active: animationComponent.playing && animationComponent.playSource !== "" && animationComponent.onScreen
        sourceComponent: animatedImageComponent
    }

    Component {
        id: animatedImageComponent
        AnimatedImage {
            anchors.fill: parent
            source: animationComponent.playSource
            playing: true   // cicla mentre è in play (niente leak: è AnimatedImage, non GStreamer)
            fillMode: Image.PreserveAspectFit
            cache: false
            asynchronous: true
            smooth: true
            layer.enabled: animationComponent.highlighted
            layer.effect: PressEffect { source: parent }
        }
    }

    // Icona play sul thumbnail quando non sta riproducendo.
    Rectangle {
        anchors.centerIn: parent
        width: playIcon.width + Theme.paddingMedium * 2
        height: playIcon.height + Theme.paddingMedium * 2
        radius: width / 2
        color: Theme.rgba("black", 0.4)
        visible: !animationComponent.playing && !animationComponent.downloading
                 && !animationComponent.converting && animationUrl !== ""

        Icon {
            id: playIcon
            anchors.centerIn: parent
            source: "image://theme/icon-l-play?white"
        }
    }

    // Tap = play / pausa.
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (animationUrl === "") {
                return;
            }
            if (animationComponent.playing) {
                animationComponent.playing = false;
            } else {
                animationComponent.startPlayback();
            }
        }
    }
}
