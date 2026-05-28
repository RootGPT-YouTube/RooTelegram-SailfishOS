/*
    Copyright (C) 2020-21 Sebastian J. Wolf and other contributors

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
import WerkWolf.RooTelegram 1.0
import "../"
import "../../js/twemoji.js" as Emoji

MessageContentBase {
    id: thisItem

    property var stickerData: messageListItem ? messageListItem.myMessage.content.sticker : overlayFlickable.overlayMessage.content.sticker;
    readonly property bool asEmoji: appSettings.showStickersAsEmojis
    readonly property bool animated: stickerData.format["@type"] === "stickerFormatTgs" && appSettings.animateStickers
    // WEBM (stickerFormatWebm): è un video, l'Image non lo decodifica.
    // webmHandling = lo trattiamo col pipeline GStreamer (tranne in modalità
    // "as emoji", dove mostriamo comunque l'emoji unicode statica).
    readonly property bool isWebm: stickerData.format["@type"] === "stickerFormatWebm"
    readonly property bool webmHandling: isWebm && !asEmoji
    property bool playing: false
    property bool onScreen: messageListItem ? messageListItem.page.status === PageStatus.Active : true
    readonly property bool stickerVisible: staticStickerLoader.item ? staticStickerLoader.item.visible :
        animatedStickerLoader.item ? animatedStickerLoader.item.visible : false
    readonly property bool isOwnSticker : messageListItem ? messageListItem.isOwnMessage : overlayFlickable.isOwnMessage
    readonly property real aspectRatio: stickerData.width / stickerData.height

    implicitWidth: stickerData.width
    implicitHeight: stickerData.height

    TDLibFile {
        id: file
        tdlib: tdLibWrapper
        fileInformation: stickerData.sticker
        autoLoad: true
    }

    Item {

        width: Math.min( stickerData.width, parent.width )
        height: width * aspectRatio
        // (centered in image mode, text-like in sticker mode)
        x: appSettings.showStickersAsImages ? (parent.width - width) / 2 :
            isOwnSticker ? (parent.width - width) : 0
        anchors.verticalCenter: parent.verticalCenter

        Loader {
            id: animatedStickerLoader
            anchors.fill: parent
            active: animated && !asEmoji
            sourceComponent: Component {
                AnimatedImage {
                    id: animatedSticker
                    anchors.fill: parent
                    source: file.path
                    asynchronous: true
                    // CPU fix: pausa anche quando la pagina del messaggio non è
                    // più attiva. Senza onScreen rlottie continua a renderizzare
                    // i frame di tutti gli sticker Lottie caricati anche dopo che
                    // l'utente ha lasciato la chat — 4 worker pool al 40% l'uno
                    // (stack confermato via gdb 2026-05-28: drawRle→blend_gradient
                    // →process_in_chunk→src_SourceOver).
                    paused: !Qt.application.active || !thisItem.onScreen
                    cache: false
                    layer.enabled: thisItem.highlighted
                    layer.effect: PressEffect { source: animatedSticker }
                }
            }
        }

        Loader {
            id: staticStickerLoader
            anchors.fill: parent
            active: (!animated || asEmoji) && !webmHandling
            sourceComponent: Component {
                Image {
                    id: staticSticker
                    anchors.fill: parent
                    source: asEmoji ? Emoji.getEmojiPath(stickerData.emoji) : file.path
                    sourceSize {
                        width: width
                        height: height
                    }
                    fillMode: Image.PreserveAspectFit
                    autoTransform: true
                    asynchronous: true
                    visible: opacity > 0
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { FadeAnimation {} }
                    layer.enabled: thisItem.highlighted
                    layer.effect: PressEffect { source: staticSticker }
                }
            }
        }

        // WEBM: thumbnail statico mostrato finché non si riproduce.
        TDLibThumbnail {
            anchors.fill: parent
            visible: webmHandling && !thisItem.playing
            thumbnail: stickerData.thumbnail
            useBackgroundImage: false
            highlighted: thisItem.highlighted
        }

        // WEBM: pipeline GStreamer lazy (active solo a tap), play one-shot.
        // Stesso pattern di MessageAnimation: niente pipeline durante lo scroll,
        // onStopped/EndOfMedia libera tutto. Vedi project_gif_loop_unsupported.
        Loader {
            id: webmStickerLoader
            anchors.fill: parent
            asynchronous: true
            active: webmHandling && thisItem.playing && thisItem.onScreen && file.isDownloadingCompleted
            sourceComponent: Component {
                Video {
                    id: webmSticker
                    anchors.fill: parent
                    source: "file://" + file.path
                    autoLoad: true
                    muted: true
                    fillMode: VideoOutput.PreserveAspectFit
                    layer.enabled: thisItem.highlighted
                    layer.effect: PressEffect { source: webmSticker }
                    onStatusChanged: {
                        if ((status === MediaPlayer.Buffered || status === MediaPlayer.Loaded)
                                && playbackState !== MediaPlayer.PlayingState) {
                            play();
                        } else if (status === MediaPlayer.EndOfMedia) {
                            thisItem.playing = false;
                        }
                    }
                }
            }
        }

        // Badge play finché non riproduce (e solo a download completato).
        Rectangle {
            anchors.centerIn: parent
            width: webmPlayIcon.width + Theme.paddingSmall * 2
            height: webmPlayIcon.height + Theme.paddingSmall * 2
            radius: width / 2
            color: Theme.rgba("black", 0.4)
            visible: webmHandling && !thisItem.playing && file.isDownloadingCompleted

            Icon {
                id: webmPlayIcon
                anchors.centerIn: parent
                source: "image://theme/icon-m-play?white"
            }
        }

        Loader {
            anchors.fill: parent
            sourceComponent: Component {
                BackgroundImage {}
            }

            active: opacity > 0
            opacity: !stickerVisible && !placeHolderDelayTimer.running && !webmHandling ? 0.15 : 0
            Behavior on opacity { FadeAnimation {} }
        }

        // Tap su WEBM = play one-shot. Intercetta il tap (non apre l'overlay
        // del set), coerente col tap-to-play delle GIF.
        MouseArea {
            anchors.fill: parent
            enabled: webmHandling
            visible: enabled
            onClicked: {
                if (file.isDownloadingCompleted) {
                    thisItem.playing = !thisItem.playing;
                }
            }
        }
    }

    // Uscita dalla pagina: ferma e libera il pipeline.
    onOnScreenChanged: {
        if (!onScreen) {
            playing = false;
        }
    }

    onClicked: {
        stickerSetOverlayLoader.stickerSetId = stickerData.set_id
        stickerSetOverlayLoader.active = true
    }

    Timer {
        id: placeHolderDelayTimer
        interval: 1000
        running: true
    }
}
