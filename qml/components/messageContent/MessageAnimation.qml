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
import QtMultimedia 5.6
import "../"
import "../../js/functions.js" as Functions

// GIF Telegram (messageAnimation): i file sono MP4, non GIF nativi.
// AnimatedImage di Qt Quick non decodifica MP4 → mostrava solo il thumbnail
// grigio. Serve GStreamer via Video/MediaPlayer.
//
// Per evitare il crash scroll-multi-pipeline e i leak di GStreamer (memoria
// project_gif_loop_unsupported):
//   - Loader active=false: NESSUN pipeline finché l'utente non tappa.
//     Lo scroll della chat non crea decoder, niente saturazione GPU/EGL.
//   - autoLoad=true sul Video: il file MP4 entra nel buffer di MediaPlayer
//     (cache effettiva — l'OS lo tiene in page cache, il MediaPlayer apre
//     il pipeline una volta).
//   - Play una volta sola: onStopped → active=false libera il pipeline.
//     Niente loop (su GStreamer Sailfish: leak buffer dopo ~10 iter).
//   - Tap successivo riattiva il Loader → nuovo pipeline pulito.
MessageContentBase {
    id: animationComponent

    property var animationData: rawMessage.content.animation
    property int animationFileId
    property string animationUrl
    property bool downloading: false
    property bool playing: false
    property bool onScreen: messageListItem ? messageListItem.page.status === PageStatus.Active : true

    height: Functions.getVideoHeight(width, animationData)

    Component.onCompleted: {
        if (!animationData) {
            return;
        }
        animationFileId = animationData.animation.id;
        if (animationData.animation.local.is_downloading_completed) {
            animationUrl = animationData.animation.local.path;
        } else {
            downloading = true;
            tdLibWrapper.downloadFile(animationFileId);
        }
    }

    Connections {
        target: tdLibWrapper
        onFileUpdated: {
            if (!animationData) {
                return;
            }
            if (!fileInformation.remote.is_uploading_active && fileInformation.local.is_downloading_completed && fileId === animationFileId) {
                downloading = false;
                animationData.animation = fileInformation;
                animationUrl = fileInformation.local.path;
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
        running: animationComponent.downloading
        visible: running
    }

    // Lazy loading del pipeline GStreamer.
    Loader {
        id: videoLoader
        anchors.fill: parent
        asynchronous: true
        active: animationComponent.playing && animationUrl !== "" && animationComponent.onScreen
        sourceComponent: videoComponent
    }

    Component {
        id: videoComponent
        Video {
            id: animationVideo
            anchors.fill: parent
            source: "file://" + animationUrl
            autoLoad: true
            muted: true
            layer.enabled: animationComponent.highlighted
            layer.effect: PressEffect { source: animationVideo }

            // play() solo a media caricato. Se chiamato prima (in
            // Component.onCompleted), GStreamer fa partire il pipeline mentre
            // il VideoOutput non è ancora pronto e il timing scivola.
            //
            // Nota: con MP4 H.264 + B-frame (frequenti nelle GIF Telegram)
            // il decoder di Sailfish/Qt5.6 NON flusha l'intero reorder buffer
            // all'EOS: gli ultimi ~5-10 frame vanno persi (≈0.5-1s a 10fps).
            // È un bug del plugin GStreamer, non fixabile da QML. Accettato
            // come limite — vedi project_gif_loop_unsupported.
            onStatusChanged: {
                if ((status === MediaPlayer.Buffered || status === MediaPlayer.Loaded)
                        && playbackState !== MediaPlayer.PlayingState) {
                    play();
                } else if (status === MediaPlayer.EndOfMedia) {
                    animationComponent.playing = false;
                }
            }
        }
    }

    // Icona play sovrapposta al thumbnail quando non sta riproducendo.
    Rectangle {
        anchors.centerIn: parent
        width: playIcon.width + Theme.paddingMedium * 2
        height: playIcon.height + Theme.paddingMedium * 2
        radius: width / 2
        color: Theme.rgba("black", 0.4)
        visible: !animationComponent.playing && !animationComponent.downloading && animationUrl !== ""

        Icon {
            id: playIcon
            anchors.centerIn: parent
            source: "image://theme/icon-l-play?white"
        }
    }

    // Tap = play / pausa anticipata (libera subito il pipeline).
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (animationUrl === "") {
                return;
            }
            animationComponent.playing = !animationComponent.playing;
        }
    }
}
