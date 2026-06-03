/*
    Copyright (C) 2020 Sebastian J. Wolf and other contributors

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
import "../../js/debug.js" as Debug

MessageContentBase {
    id: videoMessageComponent

    property var videoData:  ( rawMessage.content['@type'] === "messageVideo" )
                             ? rawMessage.content.video
                             : (
                                   ( rawMessage.content['@type'] === "messageAnimation" )
                                   ? rawMessage.content.animation
                                   : rawMessage.content.video_note )
    property string videoUrl;
    property int previewFileId;
    property int videoFileId;
    property bool isVideoNote : false;
    property bool fullscreen : false;
    property bool onScreen: messageListItem ? messageListItem.page.status === PageStatus.Active : true;
    property string videoType : "video";
    property bool playRequested: false;
    // Stato di riproduzione: pilota la visibilità di anteprima/controlli/badge via
    // BINDING (gli assegnamenti imperativi a playButton.visible dall'interno del
    // Loader non "attaccavano" → i controlli non tornavano a fine video).
    property bool isPlaying: false;

    // Dimensionamento come le foto (#5): primo frame mostrato COMPLETO, ridotto
    // all'80% della finestra (portrait e landscape), fumetto stretto sul media.
    property real mediaAspect: (videoData && videoData.width > 0 && videoData.height > 0)
                               ? (videoData.width / videoData.height) : 1.0
    readonly property real maxBoxWidth: {
        var screenCap = Math.round(appWindow.width * 0.8);
        var avail = messageListItem ? (messageListItem.precalculatedValues.textItemWidth - 2 * Theme.paddingSmall) : screenCap;
        return Math.min(screenCap, avail);
    }
    readonly property real maxBoxHeight: Math.round(appWindow.height * 0.8)
    readonly property real preferredWidth: Math.max(Theme.itemSizeSmall,
        Math.min(maxBoxWidth, maxBoxHeight * mediaAspect))

    height: videoMessageComponent.isVideoNote
            ? width
            : Math.max(Theme.itemSizeExtraSmall, Math.round(width / Math.max(mediaAspect, 0.05)))

    Timer {
        id: screensaverTimer
        interval: 30000
        running: false
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            tdLibWrapper.controlScreenSaver(false);
        }
    }

    function getTimeString(rawSeconds) {
        var minutes = Math.floor( rawSeconds / 60 );
        var seconds = rawSeconds - ( minutes * 60 );

        if ( minutes < 10 ) {
            minutes = "0" + minutes;
        }
        if ( seconds < 10 ) {
            seconds = "0" + seconds;
        }
        return minutes + ":" + seconds;
    }

    function disableScreensaver() {
        screensaverTimer.start();
    }

    function enableScreensaver() {
        screensaverTimer.stop();
        tdLibWrapper.controlScreenSaver(true);
    }

    Component.onCompleted: {
        updateVideoThumbnail();
    }

    // Quando il messaggio si aggiorna (es. il server completa l'elaborazione del
    // video appena inviato e aggiunge thumbnail/minithumbnail), videoData cambia:
    // ri-eseguiamo l'aggancio dell'anteprima, altrimenti la preview resta vuota
    // finché non si riapre la chat.
    onVideoDataChanged: updateVideoThumbnail();

    function updateVideoThumbnail() {
        if (videoData) {
            if (typeof rawMessage !== "undefined") {
                videoMessageComponent.isVideoNote = rawMessage.content['@type'] === "messageVideoNote";
            }

            videoMessageComponent.videoType = videoMessageComponent.isVideoNote ? "video" : videoData['@type'];
            videoFileId = videoData[videoType].id;
            if (typeof rawMessage !== "undefined" && rawMessage.content['@type'] === "messageAnimation") {
                playButton.visible = true;
                fullscreenButton.visible = !videoMessageComponent.fullscreen;
                handlePlay();
            } else if (typeof videoData.thumbnail !== "undefined") {
                previewFileId = videoData.thumbnail.file.id;
                if (videoData.thumbnail.file.local.is_downloading_completed) {
                    placeholderImage.source = videoData.thumbnail.file.local.path;
                } else {
                    tdLibWrapper.downloadFile(previewFileId);
                }
            }
            // Niente più icona videocamera di ripiego: se manca la thumbnail resta
            // il BackgroundImage scuro, con i controlli discreti in basso.
        }
    }

    function handlePlay() {
        playRequested = true;
        if (videoData[videoType].local.is_downloading_completed) {
            videoUrl = videoData[videoType].local.path;
            videoComponentLoader.active = true;
        } else {
            videoDownloadBusyIndicator.running = true;
            tdLibWrapper.downloadFile(videoFileId);
        }
    }

    Connections {
        target: tdLibWrapper
        onFileUpdated: {
            if (videoData) {
                if (fileInformation.local.is_downloading_completed && fileId === previewFileId) {
                    videoData.thumbnail.photo = fileInformation;
                    placeholderImage.source = fileInformation.local.path;
                }
                if (!fileInformation.remote.is_uploading_active && fileInformation.local.is_downloading_completed && fileId === videoFileId) {
                    videoDownloadBusyIndicator.running = false;
                    videoData[videoType] = fileInformation;
                    videoUrl = fileInformation.local.path;
                    if (onScreen && playRequested) {
                        playRequested = false;
                        videoComponentLoader.active = true;
                    }
                }
                if (fileId === videoFileId) {
                    downloadingProgressBar.maximumValue = fileInformation.size;
                    downloadingProgressBar.value = fileInformation.local.downloaded_size;
                }
            }
        }
    }

    // Anteprima del primo frame SFOCATA (minithumbnail, sempre presente nel
    // messaggio): usata quando manca/non è ancora pronta la thumbnail completa,
    // così la preview non resta vuota (niente più logo RT sui video).
    TDLibMinithumbnail {
        id: videoMinithumbnail
        anchors.fill: parent
        minithumbnail: videoData ? videoData.minithumbnail : undefined
        fillMode: Image.PreserveAspectFit
        highlighted: videoMessageComponent.highlighted
        visible: placeholderImage.status !== Image.Ready
    }

    Image {
        id: placeholderImage
        width: parent.width
        height: parent.height
        anchors.centerIn: parent
        // Primo frame mostrato INTERO (come le foto), niente crop.
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        visible: status === Image.Ready && !videoMessageComponent.isPlaying
        layer.enabled: videoMessageComponent.highlighted
        layer.effect: PressEffect { source: placeholderImage }
    }

    BackgroundImage {
        // Solo se non c'è NÉ thumbnail completa NÉ minithumbnail.
        visible: placeholderImage.status !== Image.Ready && !videoMinithumbnail.active
    }

    // Controlli DISCRETI in basso a sinistra (play + schermo intero), su una pill
    // scura semitrasparente: leggibili su qualsiasi frame senza rovinare la preview.
    Rectangle {
        id: videoControlsPill
        visible: !videoMessageComponent.isPlaying && !videoDownloadBusyIndicator.visible
        anchors {
            left: parent.left
            bottom: parent.bottom
            leftMargin: Theme.paddingMedium
            bottomMargin: Theme.paddingMedium
        }
        radius: height / 2
        color: Theme.rgba("#000000", 0.5)
        border.width: 1
        border.color: Theme.rgba("#ffffff", 0.25)
        width: videoControlsRow.width + 2 * Theme.paddingMedium
        height: videoControlsRow.height + Theme.paddingSmall

        Row {
            id: videoControlsRow
            anchors.centerIn: parent
            spacing: Theme.paddingLarge

            IconButton {
                id: playButton
                width: Theme.iconSizeSmall
                height: Theme.iconSizeSmall
                icon {
                    source: "image://theme/icon-m-play?white"
                    asynchronous: true
                }
                highlighted: videoMessageComponent.highlighted || down
                visible: true
                onClicked: {
                    handlePlay();
                }
            }

            Item {
                id: fullscreenItem
                width: videoMessageComponent.fullscreen ? 0 : Theme.iconSizeSmall
                height: Theme.iconSizeSmall
                visible: !videoMessageComponent.fullscreen
                IconButton {
                    id: fullscreenButton
                    anchors.centerIn: parent
                    width: Theme.iconSizeSmall
                    height: Theme.iconSizeSmall
                    icon {
                        asynchronous: true
                        source: "../../../images/icon-l-fullscreen.svg"
                        sourceSize {
                            width: Theme.iconSizeSmall
                            height: Theme.iconSizeSmall
                        }
                    }
                    highlighted: videoMessageComponent.highlighted || down
                    onClicked: {
                        pageStack.push(Qt.resolvedUrl("../../pages/VideoPage.qml"), {"videoData": videoData, "sourceMessage": rawMessage});
                    }
                }
            }
        }
    }

    // Badge durata in basso a destra (stile Telegram).
    Rectangle {
        id: durationBadge
        visible: !videoMessageComponent.isPlaying && !videoMessageComponent.isVideoNote && videoData && videoData.duration > 0
        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: Theme.paddingMedium
            bottomMargin: Theme.paddingMedium
        }
        radius: height / 2
        color: Theme.rgba("#000000", 0.5)
        border.width: 1
        border.color: Theme.rgba("#ffffff", 0.25)
        width: durationLabel.width + 2 * Theme.paddingMedium
        height: durationLabel.height + Theme.paddingSmall
        Label {
            id: durationLabel
            anchors.centerIn: parent
            text: getTimeString(videoData ? videoData.duration : 0)
            color: "white"
            font.pixelSize: Theme.fontSizeExtraSmall
        }
    }

    // Download in corso: indicatore al centro + barra di avanzamento in basso.
    BusyIndicator {
        id: videoDownloadBusyIndicator
        running: false
        visible: running
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
    }
    ProgressBar {
        id: downloadingProgressBar
        minimumValue: 0
        maximumValue: 100
        value: 0
        visible: videoDownloadBusyIndicator.visible
        width: parent.width
        anchors.bottom: parent.bottom
    }

    Rectangle {
        width: parent.width
        height: parent.height
        color: "lightgrey"
        visible: placeholderImage.status === Image.Error ? true : false
        opacity: 0.3
    }

    Rectangle {
        id: errorTextOverlay
        color: "black"
        opacity: 0.8
        width: parent.width
        height: parent.height
        visible: false
    }

    Text {
        id: errorText
        visible: false
        width: parent.width
        color: Theme.primaryColor
        font.pixelSize: Theme.fontSizeExtraSmall
        horizontalAlignment: Text.AlignHCenter
        anchors {
            verticalCenter: parent.verticalCenter
        }
        wrapMode: Text.Wrap
        text: ""
    }

    Loader {
        id: videoComponentLoader
        active: false
        width: parent.width
        height: videoMessageComponent.isVideoNote ? width : Functions.getVideoHeight(parent.width, videoData)
        sourceComponent: videoComponent
    }

    Component {
        id: videoComponent

        Item {
            width: parent ? parent.width : 0
            height: parent ? parent.height : 0

            Connections {
                target: messageVideo
                onPlaying: {
                    videoMessageComponent.isPlaying = true;
                    messageVideo.visible = true;
                }
            }

            Video {
                id: messageVideo

                Component.onCompleted: {
                    if (messageVideo.error === MediaPlayer.NoError) {
                        messageVideo.play();
                        timeLeftTimer.start();
                    } else {
                        errorText.text = qsTr("Error loading video! " + messageVideo.errorString)
                        errorTextOverlay.visible = true;
                        errorText.visible = true;
                    }
                }

                onStatusChanged: {
                    if (status == MediaPlayer.NoMedia) {
                        Debug.log("No Media");
                        videoBusyIndicator.visible = false;
                    }
                    if (status == MediaPlayer.Loading) {
                        Debug.log("Loading");
                        videoBusyIndicator.visible = true;
                    }
                    if (status == MediaPlayer.Loaded) {
                        Debug.log("Loaded");
                        videoBusyIndicator.visible = false;
                    }
                    if (status == MediaPlayer.Buffering) {
                        Debug.log("Buffering");
                        videoBusyIndicator.visible = true;
                    }
                    if (status == MediaPlayer.Stalled) {
                        Debug.log("Stalled");
                        videoBusyIndicator.visible = true;
                    }
                    if (status == MediaPlayer.Buffered) {
                        Debug.log("Buffered");
                        videoBusyIndicator.visible = false;
                    }
                    if (status == MediaPlayer.EndOfMedia) {
                        videoBusyIndicator.visible = false;
                        // A fine video ripristina anteprima + controlli (onStopped non
                        // sempre scatta su EndOfMedia): senza questo restavano nascosti.
                        messageVideo.restorePreview();
                    }
                    if (status == MediaPlayer.InvalidMedia) {
                        Debug.log("Invalid Media");
                        videoBusyIndicator.visible = false;
                    }
                    if (status == MediaPlayer.UnknownStatus) {
                        Debug.log("Unknown Status");
                        videoBusyIndicator.visible = false;
                    }
                }

                visible: false
                width: parent.width
                height: parent.height
                source: videoUrl
                layer.enabled: videoMessageComponent.highlighted
                layer.effect: PressEffect { source: messageVideo }
                function restorePreview() {
                    enableScreensaver();
                    messageVideo.visible = false;
                    videoMessageComponent.isPlaying = false;
                    videoComponentLoader.active = false;
                }
                onStopped: {
                    restorePreview();
                }
                onPlaybackStateChanged: {
                    // Alcuni backend GStreamer non emettono onStopped a fine video:
                    // a EOS lo stato diventa StoppedState → ripristiniamo qui.
                    if (playbackState === MediaPlayer.StoppedState) {
                        restorePreview();
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (messageVideo.playbackState === MediaPlayer.PlayingState) {
                            enableScreensaver();
                            messageVideo.pause();
                            timeLeftItem.visible = true;
                        } else {
                            disableScreensaver();
                            messageVideo.play();
                            timeLeftTimer.start();
                        }
                    }
                }
            }

            BusyIndicator {
                id: videoBusyIndicator
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                visible: false
                running: visible
                size: BusyIndicatorSize.Medium
                onVisibleChanged: {
                    if (visible) {
                        enableScreensaver();
                    } else {
                        disableScreensaver();
                    }
                }
            }

            Timer {
                id: timeLeftTimer
                repeat: false
                interval: 2000
                onTriggered: {
                    timeLeftItem.visible = false;
                }
            }

            Item {
                id: timeLeftItem
                width: parent.width
                height: parent.height
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                visible: messageVideo.visible
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation {} }

                Rectangle {
                    id: positionTextOverlay
                    color: "black"
                    opacity: 0.3
                    width: parent.width
                    height: parent.height
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: pausedRow.visible
                }

                Row {
                    id: pausedRow
                    width: parent.width
                    height: parent.height - ( messageVideoSlider.visible ? messageVideoSlider.height : 0 ) - ( positionText.visible ? positionText.height : 0 )
                    visible: videoComponentLoader.active && messageVideo.playbackState === MediaPlayer.PausedState
                    Item {
                        height: parent.height
                        width: videoMessageComponent.fullscreen ? parent.width : ( parent.width / 2 )
                        IconButton {
                            id: pausedPlayButton
                            anchors.centerIn: parent
                            width: Theme.iconSizeLarge
                            height: Theme.iconSizeLarge
                            highlighted: videoMessageComponent.highlighted || down
                            icon {
                                asynchronous: true
                                source: "image://theme/icon-l-play?white"
                            }
                            onClicked: {
                                disableScreensaver();
                                messageVideo.play();
                                timeLeftTimer.start();
                            }
                        }
                    }
                    Item {
                        id: pausedFullscreenItem
                        height: parent.height
                        width: parent.width / 2
                        visible: !videoMessageComponent.fullscreen
                        IconButton {
                            id: pausedFullscreenButton
                            anchors.centerIn: parent
                            width: Theme.iconSizeLarge
                            height: Theme.iconSizeLarge
                            highlighted: videoMessageComponent.highlighted || down
                            icon {
                                asynchronous: true
                                source: "../../../images/icon-l-fullscreen.svg"
                                sourceSize {
                                    width: Theme.iconSizeLarge
                                    height: Theme.iconSizeLarge
                                }
                            }
                            visible: ( videoComponentLoader.active && messageVideo.playbackState === MediaPlayer.PausedState ) ? true : false
                            onClicked: {
                                pageStack.push(Qt.resolvedUrl("../../pages/VideoPage.qml"), {"videoData": videoData, "sourceMessage": rawMessage});
                            }
                        }
                    }
                }

                Slider {
                    id: messageVideoSlider
                    width: parent.width
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: positionText.top
                    minimumValue: 0
                    maximumValue: messageVideo.duration ? messageVideo.duration : 0.1

                    highlighted: videoMessageComponent.highlighted || down
                    stepSize: 1
                    value: messageVideo.position
                    enabled: messageVideo.seekable
                    visible: (messageVideo.duration > 0)
                    onReleased: {
                        messageVideo.seek(Math.floor(value));
                        messageVideo.play();
                        timeLeftTimer.start();
                    }
                    valueText: getTimeString(Math.round((messageVideo.duration - messageVideoSlider.value) / 1000))
                }

                Text {
                    id: positionText
                    visible: messageVideo.visible && messageVideo.duration === 0
                    color: videoMessageComponent.highlighted ? Theme.secondaryColor : Theme.primaryColor
                    font.pixelSize: videoMessageComponent.fullscreen ? Theme.fontSizeSmall : Theme.fontSizeTiny
                    anchors {
                        bottom: parent.bottom
                        bottomMargin: Theme.paddingSmall
                        horizontalCenter: positionTextOverlay.horizontalCenter
                    }
                    wrapMode: Text.Wrap
                    text: ( messageVideo.duration - messageVideo.position ) > 0 ? getTimeString(Math.round((messageVideo.duration - messageVideo.position) / 1000)) : "-:-"
                }
            }

        }

    }

}
