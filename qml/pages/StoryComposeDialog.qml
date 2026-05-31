/*
    Copyright (C) 2026 RootGPT

    This file is part of RooTelegram.

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/
import QtQuick 2.6
import Sailfish.Silica 1.0
import Nemo.Thumbnailer 1.0

// Compose + pubblicazione di una storia (foto o video). È una Page (non Dialog)
// perché i video richiedono due fasi visibili con barra di avanzamento —
// "Conversione video" (crop landscape→9:16 via ffmpeg bundlato) e "Upload" —
// che un Dialog non potrebbe mostrare (l'accept lo chiuderebbe subito).
Page {
    id: composePage
    allowedOrientations: Orientation.All

    property string mediaPath: ""
    property bool isVideo: false
    property real videoDurationS: 0      // significativo solo se isVideo
    property int videoWidth: 0
    property int videoHeight: 0
    // Rotazione del tag contenitore MP4 (0/90/180/270): ffmpeg la applica da solo,
    // ma ci serve per capire l'orientamento "vero" su cui decidere il crop.
    property int videoContainerRotation: 0

    // Rotazione manuale (gradi orari, 0/90/180/270) impostata dal pulsante "ruota":
    // vale sia per foto che per video. Bruciata nel media solo al publish.
    property int userRotation: 0

    // Rotazione che l'EXIF della foto imporrebbe (l'anteprima QML non onora l'EXIF,
    // quindi la pre-applichiamo a mano per restare coerenti col risultato pubblicato).
    property int photoExifRotation: 0

    // Rotazione totale da applicare all'ANTEPRIMA. Foto: EXIF + manuale. Video: solo
    // manuale, perché il backend Video di Sailfish onora già il tag del contenitore.
    readonly property int previewRotation: isVideo
                                            ? (userRotation % 360)
                                            : ((photoExifRotation + userRotation) % 360)
    readonly property bool previewSwapped: (previewRotation % 180) !== 0

    // Le dimensioni grezze (videoWidth/Height) vanno scambiate se l'orientamento
    // FINALE (tag contenitore + rotazione utente) è ruotato di un quarto dispari.
    readonly property bool dimsSwapped:
        isVideo && ((Math.round(videoContainerRotation / 90) + Math.round(userRotation / 90)) % 2) !== 0
    readonly property int finalVideoWidth: dimsSwapped ? videoHeight : videoWidth
    readonly property int finalVideoHeight: dimsSwapped ? videoWidth : videoHeight

    // Storie Telegram = verticale 9:16. Convertiamo (center-crop ai lati) solo i
    // video PIÙ LARGHI di 9:16; portrait e tall restano intatti. Decisione presa
    // sulle dimensioni FINALI così un portrait ruotato non viene scambiato per landscape.
    readonly property bool needsCrop: isVideo && finalVideoWidth > 0 && finalVideoHeight > 0
                                       && (finalVideoWidth * 16 > finalVideoHeight * 9)

    readonly property int maxVideoDurationS: 60
    readonly property bool videoTooLong: isVideo && videoDurationS > maxVideoDurationS
    readonly property bool videoDurationKnown: !isVideo || videoDurationS > 0

    // compose | encoding | uploading
    property string phase: "compose"
    property real encodePercent: 0
    property real uploadPercent: 0
    property bool uploadDone: false
    property string postPath: ""         // file effettivamente postato (orig o transcodato)

    // Opzioni publish: bind iniziale ad AppSettings (sticky), modificabili in-page.
    // L'AppSettings viene aggiornato solo al momento del publish, così se l'utente
    // annulla la modifica non resta scritta.
    // Eccezione: privacyMode NON è sticky, parte sempre da "everyone" — la scelta
    // dell'audience per UNA storia non deve influenzare la successiva.
    property string privacyMode: "everyone"
    property bool allowScreenshots: appSettings.storyAllowScreenshots
    property bool postToProfile: appSettings.storyPostToProfile
    // "Selected contacts" è ephemeral: lista sempre vuota all'apertura,
    // l'utente la compone via picker ogni volta.
    property var selectedUserIds: []
    // "Custom audience" è persistente: rispecchio il valore di AppSettings così
    // il count "Custom audience (N)" si aggiorna live se l'utente lo modifica.
    property int customAudienceCount: appSettings.storyCustomAudienceUserIds().length

    readonly property bool canPublish: mediaPath !== "" && videoDurationKnown && !videoTooLong
                                       && !(privacyMode === "selected" && selectedUserIds.length === 0)
                                       && !(privacyMode === "customAudience" && customAudienceCount === 0)

    function fmtDuration(s) {
        var m = Math.floor(s / 60);
        var sec = Math.floor(s % 60);
        return m + ":" + (sec < 10 ? "0" : "") + sec;
    }

    function choosePhoto() {
        var picker = pageStack.push("Sailfish.Pickers.ImagePickerPage");
        picker.selectedContentPropertiesChanged.connect(function() {
            if (picker.selectedContentProperties && picker.selectedContentProperties.filePath) {
                composePage.isVideo = false;
                composePage.videoDurationS = 0;
                composePage.videoWidth = 0; composePage.videoHeight = 0;
                composePage.videoContainerRotation = 0;
                composePage.userRotation = 0;
                composePage.mediaPath = picker.selectedContentProperties.filePath;
                composePage.photoExifRotation = rootelegramUtils.imageDisplayRotation(composePage.mediaPath);
            }
        });
    }

    function chooseVideo() {
        var picker = pageStack.push("Sailfish.Pickers.VideoPickerPage");
        picker.selectedContentPropertiesChanged.connect(function() {
            if (picker.selectedContentProperties && picker.selectedContentProperties.filePath) {
                composePage.isVideo = true;
                composePage.videoDurationS = 0;
                composePage.videoWidth = 0; composePage.videoHeight = 0;
                composePage.videoContainerRotation = 0;
                composePage.userRotation = 0;
                composePage.photoExifRotation = 0;
                composePage.mediaPath = picker.selectedContentProperties.filePath;
                // Sonda C++ (ffmpeg `-i`, software) per i metadati. La miniatura
                // dell'anteprima la fa il thumbnailer di sistema (Thumbnail, sotto).
                var info = videoTranscoder.probeVideo(composePage.mediaPath);
                if (info) {
                    composePage.videoDurationS = info.durationS ? info.durationS : 0;
                    composePage.videoWidth = info.width ? info.width : 0;
                    composePage.videoHeight = info.height ? info.height : 0;
                    composePage.videoContainerRotation = info.rotation ? info.rotation : 0;
                }
            }
        });
    }

    function openAudiencePicker() {
        // Mode "selected": picker ad-hoc, lista vuota all'apertura, niente persistenza.
        var dlg = pageStack.push(Qt.resolvedUrl("StoryAudiencePickerDialog.qml"),
                                 { mode: "selected" });
        dlg.accepted.connect(function() {
            composePage.selectedUserIds = dlg.selectedUserIds.slice();
        });
    }

    function openCustomAudienceEditor() {
        // Mode "custom": picker per il gruppo persistente; preselezione dai
        // membri salvati, salvataggio in AppSettings all'accept.
        var dlg = pageStack.push(Qt.resolvedUrl("StoryAudiencePickerDialog.qml"),
                                 { mode: "custom" });
        dlg.accepted.connect(function() {
            composePage.customAudienceCount = appSettings.storyCustomAudienceUserIds().length;
        });
    }

    function persistOptions() {
        // Persistenza sticky: scritta solo all'atto del publish.
        // privacyMode NON viene persistito: torna a "everyone" alla prossima
        // apertura della compose (vedi commento sulla property).
        appSettings.storyAllowScreenshots = allowScreenshots;
        appSettings.storyPostToProfile = postToProfile;
    }

    function publish() {
        if (!canPublish || phase !== "compose")
            return;
        var info = tdLibWrapper.getUserInformation();
        var selfId = info ? info.id : 0;
        if (!selfId) {
            appNotification.show(qsTr("Cannot determine your account."));
            return;
        }
        persistOptions();
        // A livello TDLib esistono solo "everyone" e "selected" (lista di user_ids).
        // "customAudience" è una scelta puramente UI: si traduce in "selected"
        // con gli id presi dal gruppo persistente.
        var tdMode = (privacyMode === "everyone") ? "everyone" : "selected";
        var ids = [];
        if (privacyMode === "selected") {
            ids = selectedUserIds;
        } else if (privacyMode === "customAudience") {
            ids = appSettings.storyCustomAudienceUserIds();
        }
        if (!isVideo) {
            // Foto: le storie sono 9:16. Se è landscape la mettiamo su tela verticale
            // (bande sopra/sotto) così non deborda sui client ufficiali. Portrait
            // invariate (ritorna il path originale). userRotation = rotazione manuale.
            var photoPath = rootelegramUtils.padImageToVerticalStory(mediaPath, userRotation);
            tdLibWrapper.postStory(selfId.toString(), photoPath, captionField.text, 86400,
                                   tdMode, ids, allowScreenshots, postToProfile);
            appNotification.show(qsTr("Posting story…"));
            pageStack.pop();
            return;
        }
        // Transcodifichiamo se serve croppare un landscape OPPURE se l'utente ha
        // ruotato manualmente (la rotazione va bruciata nel file). Altrimenti upload diretto.
        if ((needsCrop || userRotation !== 0) && videoTranscoder.available()) {
            phase = "encoding";
            encodePercent = 0;
            videoTranscoder.cropToVerticalStory(mediaPath, videoDurationS, userRotation, needsCrop);
        } else {
            startUpload(mediaPath);
        }
    }

    function startUpload(path) {
        var info = tdLibWrapper.getUserInformation();
        var selfId = info ? info.id : 0;
        if (!selfId) {
            appNotification.show(qsTr("Cannot determine your account."));
            phase = "compose";
            return;
        }
        postPath = path;
        phase = "uploading";
        uploadPercent = 0;
        uploadDone = false;
        var tdMode = (privacyMode === "everyone") ? "everyone" : "selected";
        var ids = [];
        if (privacyMode === "selected") {
            ids = selectedUserIds;
        } else if (privacyMode === "customAudience") {
            ids = appSettings.storyCustomAudienceUserIds();
        }
        tdLibWrapper.postVideoStory(selfId.toString(), path, videoDurationS, captionField.text, 86400,
                                    tdMode, ids, allowScreenshots, postToProfile);
    }

    // Annullamento (back gesture): se sta convertendo, ferma ffmpeg.
    Component.onDestruction: {
        if (phase === "encoding")
            videoTranscoder.cancel();
    }

    Connections {
        target: videoTranscoder
        onProgress: composePage.encodePercent = percent
        onFinished: composePage.startUpload(outputPath)
        onError: {
            appNotification.show(qsTr("Video conversion failed."));
            composePage.phase = "compose";
        }
    }

    // Chiude la pagina poco dopo il completamento dell'upload (lascia un attimo
    // la barra al 100% per feedback). Timer perché dopo il 100% TDLib può inviare
    // altri updateFile (con uploaded_size azzerato) che NON devono resettare la UI.
    Timer {
        id: closeTimer
        interval: 1500
        onTriggered: {
            appNotification.show(qsTr("Story posted"));
            pageStack.pop();
        }
    }

    Connections {
        target: tdLibWrapper
        // Avanzamento upload: abbino il file in upload al path che abbiamo postato.
        onFileUpdated: {
            if (composePage.phase !== "uploading" || composePage.postPath === "" || composePage.uploadDone)
                return;
            if (!fileInformation.local || fileInformation.local.path !== composePage.postPath)
                return;
            var r = fileInformation.remote;
            var total = fileInformation.size || fileInformation.expected_size || 0;
            var up = (r && r.uploaded_size) ? r.uploaded_size : 0;
            if (total > 0) {
                var pct = Math.min(100, up / total * 100);
                if (pct > composePage.uploadPercent)   // monotonico: niente reset a 0
                    composePage.uploadPercent = pct;
            }
            // Chiudiamo quando i byte sono saliti al 100% (file caricato): le flag
            // is_uploading_completed/_active di TDLib non arrivano affidabili qui,
            // ma raggiungere il 100% è segnale sufficiente (la storia si finalizza
            // server-side subito dopo). Belt-and-suspenders con la flag se c'è.
            if (!composePage.uploadDone
                    && (composePage.uploadPercent >= 100 || (r && r.is_uploading_completed))) {
                composePage.uploadDone = true;
                composePage.uploadPercent = 100;
                closeTimer.start();
            }
        }
        // Errore server sul post (formato rifiutato, ecc.): instradato via @extra.
        onErrorReceived: {
            if (extra === "postStory" && composePage.phase === "uploading") {
                appNotification.show(message !== "" ? message : qsTr("Could not post story."));
                composePage.phase = "compose";
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("New story")
            }

            // ---- Anteprima (solo quando un media è scelto) ----
            Item {
                id: previewArea
                width: parent.width
                visible: composePage.mediaPath !== ""
                height: visible ? composePage.height * 0.45 : 0
                clip: true

                // Anteprima FOTO. Ruotata (EXIF + manuale): a 90°/270° scambio
                // width/height per restare dentro il riquadro con PreserveAspectFit,
                // poi rotation attorno al centro.
                Image {
                    anchors.centerIn: parent
                    width: composePage.previewSwapped ? parent.height : parent.width
                    height: composePage.previewSwapped ? parent.width : parent.height
                    rotation: composePage.previewRotation
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    source: (composePage.mediaPath !== "" && !composePage.isVideo) ? "file://" + composePage.mediaPath : ""
                    visible: composePage.mediaPath !== "" && !composePage.isVideo
                }

                // Anteprima VIDEO via thumbnailer di sistema (daemon thumbnaild-video,
                // fuori processo): genera il frame come fa la Galleria, SENZA aprire
                // il decoder HW nel nostro processo — quindi nessun teardown che impalli
                // la UI. La miniatura è già dritta (il daemon rispetta l'orientamento),
                // perciò applico solo la rotazione manuale (previewRotation = userRotation
                // per i video) con lo stesso swap width/height delle foto.
                Thumbnail {
                    anchors.centerIn: parent
                    width: composePage.previewSwapped ? parent.height : parent.width
                    height: composePage.previewSwapped ? parent.width : parent.height
                    rotation: composePage.previewRotation
                    fillMode: Thumbnail.PreserveAspectFit
                    sourceSize.width: width
                    sourceSize.height: height
                    priority: Thumbnail.HighPriority
                    mimeType: "video/mp4"
                    source: (composePage.mediaPath !== "" && composePage.isVideo) ? "file://" + composePage.mediaPath : ""
                    visible: composePage.mediaPath !== "" && composePage.isVideo
                }

                Rectangle {
                    anchors.centerIn: parent
                    visible: composePage.mediaPath !== "" && composePage.isVideo
                    width: Theme.iconSizeLarge
                    height: width
                    radius: width / 2
                    color: Theme.rgba("black", 0.4)
                    Image {
                        anchors.centerIn: parent
                        width: Theme.iconSizeMedium
                        height: width
                        sourceSize.width: width
                        sourceSize.height: width
                        source: "image://theme/icon-m-play?white"
                    }
                }

                // Tap per cambiare media (solo in compose).
                BackgroundItem {
                    anchors.fill: parent
                    visible: composePage.phase === "compose"
                    onClicked: composePage.isVideo ? composePage.chooseVideo() : composePage.choosePhoto()
                    Label {
                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: Theme.paddingSmall }
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                        text: qsTr("Tap to change")
                    }
                }

                // Ruota di 90° orari a ogni tap (foto e video). Sopra il tap-per-cambiare
                // così il tocco nell'angolo ruota invece di aprire il picker.
                BackgroundItem {
                    id: rotateButton
                    visible: composePage.phase === "compose"
                    width: Theme.iconSizeMedium + Theme.paddingMedium
                    height: width
                    anchors {
                        top: parent.top
                        right: parent.right
                        margins: Theme.paddingMedium
                    }
                    onClicked: composePage.userRotation = (composePage.userRotation + 90) % 360
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.rgba("black", rotateButton.highlighted ? 0.6 : 0.4)
                    }
                    Image {
                        anchors.centerIn: parent
                        width: Theme.iconSizeMedium
                        height: width
                        sourceSize.width: width
                        sourceSize.height: width
                        source: "image://theme/icon-m-rotate?white"
                    }
                }
            }

            // ---- Chooser foto/video (solo quando vuoto) ----
            Row {
                id: chooserRow
                visible: composePage.mediaPath === ""
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingLarge * 2

                property real iconDim: Theme.iconSizeMedium * 2
                property real btnSize: iconDim + Theme.paddingMedium * 2

                BackgroundItem {
                    id: photoBtn
                    width: chooserRow.btnSize
                    height: width
                    onClicked: composePage.choosePhoto()
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.paddingMedium
                        color: Theme.rgba(Theme.highlightBackgroundColor, photoBtn.highlighted ? 0.4 : 0.18)
                    }
                    Image {
                        anchors.centerIn: parent
                        width: chooserRow.iconDim; height: width
                        sourceSize.width: width; sourceSize.height: width
                        source: "image://theme/icon-m-image?" + (photoBtn.highlighted ? Theme.highlightColor : Theme.primaryColor)
                    }
                }
                BackgroundItem {
                    id: videoBtn
                    width: chooserRow.btnSize
                    height: width
                    onClicked: composePage.chooseVideo()
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.paddingMedium
                        color: Theme.rgba(Theme.highlightBackgroundColor, videoBtn.highlighted ? 0.4 : 0.18)
                    }
                    Image {
                        anchors.centerIn: parent
                        width: chooserRow.iconDim; height: width
                        sourceSize.width: width; sourceSize.height: width
                        source: "image://theme/icon-m-video?" + (videoBtn.highlighted ? Theme.highlightColor : Theme.primaryColor)
                    }
                }
            }

            // ---- Durata video / avviso troppo lungo ----
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: composePage.isVideo && composePage.mediaPath !== "" && composePage.phase === "compose"
                font.pixelSize: Theme.fontSizeSmall
                color: composePage.videoTooLong ? Theme.errorColor : Theme.secondaryColor
                text: {
                    if (!composePage.videoDurationKnown) return qsTr("Reading video…");
                    if (composePage.videoTooLong)
                        return qsTr("Video too long: %1 (max %2)")
                                .arg(composePage.fmtDuration(composePage.videoDurationS))
                                .arg(composePage.fmtDuration(composePage.maxVideoDurationS));
                    return qsTr("Duration: %1").arg(composePage.fmtDuration(composePage.videoDurationS));
                }
            }

            TextArea {
                id: captionField
                width: parent.width
                enabled: composePage.phase === "compose"
                label: qsTr("Caption")
                placeholderText: qsTr("Add a caption (optional)")
            }

            // ---- Audience + opzioni (solo in compose) ----
            Column {
                width: parent.width
                visible: composePage.phase === "compose"

                ComboBox {
                    id: privacyCombo
                    width: parent.width
                    label: qsTr("Audience")
                    currentIndex: composePage.privacyMode === "selected" ? 1
                                  : (composePage.privacyMode === "customAudience" ? 2 : 0)
                    menu: ContextMenu {
                        MenuItem { text: qsTr("Everyone") }
                        MenuItem { text: qsTr("Selected contacts") }
                        MenuItem { text: qsTr("Custom audience") }
                    }
                    onCurrentIndexChanged: {
                        composePage.privacyMode = (currentIndex === 1) ? "selected"
                                                : (currentIndex === 2 ? "customAudience" : "everyone");
                    }
                }

                // Riga riassunto + "Choose contacts" (solo se selected).
                BackgroundItem {
                    width: parent.width
                    height: Theme.itemSizeSmall
                    visible: composePage.privacyMode === "selected"
                    onClicked: composePage.openAudiencePicker()
                    Label {
                        anchors {
                            left: parent.left
                            leftMargin: Theme.horizontalPageMargin
                            right: chevron.left
                            rightMargin: Theme.paddingMedium
                            verticalCenter: parent.verticalCenter
                        }
                        text: composePage.selectedUserIds.length > 0
                              ? qsTr("%n contact(s) selected", "", composePage.selectedUserIds.length)
                              : qsTr("Choose contacts")
                        color: composePage.selectedUserIds.length > 0 ? Theme.primaryColor : Theme.highlightColor
                        truncationMode: TruncationMode.Fade
                    }
                    Icon {
                        id: chevron
                        source: "image://theme/icon-m-right?" + Theme.secondaryColor
                        width: Theme.iconSizeSmall
                        height: Theme.iconSizeSmall
                        anchors {
                            right: parent.right
                            rightMargin: Theme.horizontalPageMargin
                            verticalCenter: parent.verticalCenter
                        }
                    }
                }

                TextSwitch {
                    width: parent.width
                    text: qsTr("Allow screenshots")
                    description: qsTr("If off, the story is marked as protected: official clients block screenshots and forwarding.")
                    checked: composePage.allowScreenshots
                    onCheckedChanged: composePage.allowScreenshots = checked
                }

                TextSwitch {
                    width: parent.width
                    text: qsTr("Post to my profile")
                    description: qsTr("Keep the story visible on your profile after the 24h expiration.")
                    checked: composePage.postToProfile
                    onCheckedChanged: composePage.postToProfile = checked
                }

                // ---- Custom audience: gruppo persistente di destinatari ----
                // Visibile SOLO quando l'utente sceglie "Custom audience" come
                // mode: simmetrico con "Choose contacts" che appare solo per
                // "Selected contacts". Tap → picker (mode "custom") con i membri
                // ordinati in cima. Il count si aggiorna live dopo l'editing.
                BackgroundItem {
                    width: parent.width
                    visible: composePage.privacyMode === "customAudience"
                    height: visible ? Theme.itemSizeSmall : 0
                    onClicked: composePage.openCustomAudienceEditor()
                    Label {
                        anchors {
                            left: parent.left
                            leftMargin: Theme.horizontalPageMargin
                            right: customChevron.left
                            rightMargin: Theme.paddingMedium
                            verticalCenter: parent.verticalCenter
                        }
                        text: composePage.customAudienceCount > 0
                              ? qsTr("Custom audience (%1)").arg(composePage.customAudienceCount)
                              : qsTr("Custom audience")
                        color: Theme.primaryColor
                        truncationMode: TruncationMode.Fade
                    }
                    Icon {
                        id: customChevron
                        source: "image://theme/icon-m-right?" + Theme.secondaryColor
                        width: Theme.iconSizeSmall
                        height: Theme.iconSizeSmall
                        anchors {
                            right: parent.right
                            rightMargin: Theme.horizontalPageMargin
                            verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // ---- Pulsante Pubblica (compose) ----
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: composePage.phase === "compose"
                enabled: composePage.canPublish
                text: qsTr("Publish")
                onClicked: composePage.publish()
            }

            // ---- Avanzamento (sotto la caption): conversione + upload ----
            Column {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                spacing: Theme.paddingSmall
                visible: composePage.phase !== "compose"

                // Spiegazione del perché serve la conversione (solo se croppiamo).
                Label {
                    width: parent.width
                    visible: composePage.needsCrop
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    text: qsTr("Telegram stories are vertical (9:16). Your landscape video is being adapted before publishing.")
                }

                ProgressBar {
                    width: parent.width
                    visible: composePage.phase === "encoding"
                    minimumValue: 0; maximumValue: 100
                    value: composePage.encodePercent
                    label: qsTr("Converting video") + " " + Math.round(composePage.encodePercent) + "%"
                }

                ProgressBar {
                    width: parent.width
                    visible: composePage.phase === "uploading"
                    minimumValue: 0; maximumValue: 100
                    value: composePage.uploadPercent
                    // Se non conosciamo ancora i byte, mostra indeterminato.
                    indeterminate: composePage.uploadPercent <= 0
                    label: qsTr("Uploading video") + (composePage.uploadPercent > 0 ? " " + Math.round(composePage.uploadPercent) + "%" : "")
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
