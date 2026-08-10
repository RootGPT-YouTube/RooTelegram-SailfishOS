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
    // Un solo auto-retry per tentativo di play quando il player fallisce con
    // ResourceError (file locale sparito): vedi onError nel Video.
    property bool errorRetryDone: false;
    // Posizione (ms) a cui riprendere dopo il seek utente. MAI fare seek "a
    // caldo" sulla pipeline droid: il flush con codec in volo può deadlockare
    // il MAIN THREAD (futex, verificato con /proc/<pid>/stack il 2026-07-17:
    // app intera congelata, D-Bus muto). Al rilascio dello slider smontiamo il
    // player e lo ricreiamo, posizionandoci in preroll a codec appena nato.
    property int resumePositionMs: 0;
    // Anti-blink del seek: durante lo smonta-e-ricrea copriamo il buco visivo
    // con un fermo-immagine dell'ultimo frame (grab del loader) e mutiamo
    // l'audio (il nuovo player parte da 0 per un attimo prima del preroll-seek).
    property bool seekRebuilding: false;
    property int lastSeekTarget: 0;
    // Target dell'ultimo tap in attesa di essere applicato (-1 = nessuno). I tap
    // sulla timeline si COALIZZANO: una raffica → un solo smonta-e-ricrea finale.
    property int pendingSeekTarget: -1;
    // Un ciclo teardown→preroll è in corso: VIETATO avviarne un altro finché non
    // finisce. Sovrapporre i teardown sul decoder HW droid (istanza unica,
    // rilascio ASINCRONO) fa deadlockare il MAIN THREAD sul seek → freeze totale
    // NON recuperabile (watchdog/timer girano sullo stesso thread congelato).
    // Quindi il seek va SERIALIZZATO e prevenuto, non recuperato. (Firma del bug
    // vista nel journal 2026-07-17: dopo 4 tap ravvicinati i log si fermavano di
    // netto subito dopo un preroll-seek = app appesa.)
    property bool seekRebuildInFlight: false;
    // Posizione effettivamente applicata al ciclo in volo (per riconoscere il
    // "target raggiunto" anche se nel frattempo sono arrivati altri tap).
    property int appliedSeekTarget: 0;
    // Riferimento vivo al risultato del grab: l'URL è valido finché
    // l'oggetto non viene garbage-collected.
    property var seekFrameGrab: null;

    function endSeekRebuild() {
        seekRebuildFallback.stop();
        seekRevealDelay.stop();
        seekCoalesce.stop();
        seekRebuilding = false;
        seekRebuildInFlight = false;
        pendingSeekTarget = -1;
        seekFreezeFrame.source = "";
        seekFrameGrab = null;
    }

    // Tap/rilascio sulla timeline. NON smonta subito: registra il target, alza
    // il fermo-immagine (una sola volta per raffica) e riavvia il debounce; il
    // vero smonta-e-ricrea parte solo quando i tap si fermano (seekCoalesce).
    function seekViaRebuild(targetMs) {
        pendingSeekTarget = targetMs;
        lastSeekTarget = targetMs;
        if (!seekRebuilding) {
            seekRebuilding = true;       // alza la cover: muta l'audio, mostra il frame
            armSeekCover();
        }
        seekRebuildFallback.restart();
        seekCoalesce.restart();
    }

    // Grab dell'ultimo frame per coprire il buco visivo durante il rebuild.
    function armSeekCover() {
        try {
            videoComponentLoader.grabToImage(function(result) {
                videoMessageComponent.seekFrameGrab = result;
                seekFreezeFrame.source = result.url;
            });
        } catch (e) {
            // Nessuna cover disponibile: best effort, il rebuild avverrà comunque.
        }
    }

    // Applica UN solo seek (il più recente) — e SOLO se non c'è già un ciclo in
    // volo. È questo il cancello che impedisce i teardown sovrapposti.
    function applyPendingSeek() {
        if (pendingSeekTarget < 0 || seekRebuildInFlight) {
            return;   // niente da fare, o ciclo in corso (riproverà a target raggiunto)
        }
        seekRebuildInFlight = true;
        resumePositionMs = pendingSeekTarget;
        appliedSeekTarget = pendingSeekTarget;
        pendingSeekTarget = -1;
        videoComponentLoader.active = false;
        videoComponentLoader.active = true;
    }

    // Il player in volo ha raggiunto il target. Se altri tap sono arrivati nel
    // frattempo applica il prossimo (sempre uno solo, mai sovrapposto); altrimenti
    // togli la cover dopo il reveal delay (tempo al decoder di presentare il frame).
    function handleSeekReached() {
        if (!seekRebuildInFlight) {
            return;
        }
        seekRebuildInFlight = false;
        if (pendingSeekTarget >= 0) {
            applyPendingSeek();
        } else {
            seekRevealDelay.restart();
        }
    }
    // Stato di riproduzione: pilota la visibilità di anteprima/controlli/badge via
    // BINDING (gli assegnamenti imperativi a playButton.visible dall'interno del
    // Loader non "attaccavano" → i controlli non tornavano a fine video).
    property bool isPlaying: false;

    // [2.8.8 STRADA 1b] Mentre la chat scorre NON scarichiamo né decodifichiamo il
    // thumbnail pieno del video: resta il minithumbnail inline (già in RAM, zero
    // download). I canali di video (Durov & co.) hanno thumbnail spesso 1280px che,
    // decodificati a risoluzione nativa a ogni delegato scrollato, ratchettavano la
    // RAM fino al freeze (misurato 2026-06-30: cresceva solo la cartella thumbnails/,
    // non photos/ già coperta da STRADA 1). A vista ferma (deferThumbnail→false) il
    // thumbnail viene scaricato e decodificato. Default false: nelle viste senza
    // scroll (manca messageListItem) il comportamento è invariato.
    property bool deferThumbnail: !!messageListItem && !!messageListItem.precalculatedValues
                                  && messageListItem.precalculatedValues.viewMoving === true

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

    // Vista tornata ferma: aggancia/decodifica il thumbnail dei video a schermo.
    onDeferThumbnailChanged: {
        if (!deferThumbnail) {
            updateVideoThumbnail();
        }
    }

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
                if (deferThumbnail) {
                    // In scroll: resta il minithumbnail, niente download/decode del
                    // thumbnail pieno. Riproveremo a vista ferma (onDeferThumbnailChanged).
                } else if (videoData.thumbnail.file.local.is_downloading_completed) {
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
        errorRetryDone = false;
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
                    // In scroll non decodifichiamo: un download in volo che si completa
                    // NON deve assegnare il source (= decode). A vista ferma
                    // onDeferThumbnailChanged riesegue updateVideoThumbnail e lo aggancia.
                    if (!deferThumbnail) {
                        placeholderImage.source = fileInformation.local.path;
                    }
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
        // [2.8.8 STRADA 1b] Come TDLibImage per le preview inline: NON tenere il
        // thumbnail decodificato nella QQuickPixmapCache globale. Scrollando un canale
        // di video ogni thumbnail si vede una sola volta → cache=true non dà riuso ma
        // RATCHETTA la RAM (pixmap trattenute anche dopo che il delegate muore).
        // cache=false le libera all'uscita dallo schermo.
        cache: false
        // [2.8.8 STRADA 1b] Cap di decodifica come le foto (TDLibImage.maxSourceDimension):
        // i thumbnail video dei canali sono spesso 1280px → senza cap decodificavano a
        // risoluzione nativa (~3.7MB RGBA l'uno) e scrollando un canale di video
        // ratchettavano la RAM fino al freeze. 720px è abbondante per un'anteprima inline
        // e taglia la RAM per-thumbnail ~4-8×. (parent, non self, per evitare binding loop.)
        sourceSize {
            width: parent ? Math.min(parent.width, 720) : 0
            height: parent ? Math.min(parent.height, 720) : 0
        }
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

    // Fermo-immagine anti-blink: copre il loader durante lo smonta-e-ricrea
    // del seek finché il nuovo player non raggiunge la posizione richiesta.
    Image {
        id: seekFreezeFrame
        anchors.fill: videoComponentLoader
        z: videoComponentLoader.z + 1
        visible: videoMessageComponent.seekRebuilding && status === Image.Ready
        cache: false
    }

    // Debounce dei tap sulla timeline: finché i tap arrivano il timer si riavvia;
    // quando si fermano si applica UN solo smonta-e-ricrea al target finale. È il
    // cuore della prevenzione del deadlock: niente tempesta di teardown.
    Timer {
        id: seekCoalesce
        interval: 320
        onTriggered: videoMessageComponent.applyPendingSeek()
    }

    // Paracadute: se il nuovo player non arriva mai a destinazione (errore,
    // watchdog...), il fermo-immagine e il mute non devono restare per sempre.
    Timer {
        id: seekRebuildFallback
        interval: 4000
        onTriggered: videoMessageComponent.endSeekRebuild()
    }

    // Reveal ritardato: quando il nuovo player RAGGIUNGE il target diamo al
    // decoder droid un istante per PRESENTARE il frame post-seek prima di
    // togliere il fermo-immagine. Senza questa attesa si scopre il loader di un
    // frame nero/vecchio → il blink residuo. Vive nel root (non nel Loader) per
    // sopravvivere allo smonta-e-ricrea.
    Timer {
        id: seekRevealDelay
        interval: 200
        onTriggered: videoMessageComponent.endSeekRebuild()
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
                    // Posizionamento post-seek utente: pipeline appena
                    // prerollata, codec giovane — l'unico momento in cui il
                    // seek è digeribile per il decoder droid.
                    if ((status == MediaPlayer.Loaded || status == MediaPlayer.Buffered)
                            && videoMessageComponent.resumePositionMs > 0 && messageVideo.seekable) {
                        var resumeTo = videoMessageComponent.resumePositionMs;
                        videoMessageComponent.resumePositionMs = 0;
                        messageVideo.seek(resumeTo);
                        seekWatchdog.arm();
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
                // Durante il rebuild da seek il player riparte da 0 per un
                // attimo prima del preroll-seek: muto, sotto il fermo-immagine.
                muted: videoMessageComponent.seekRebuilding
                onPositionChanged: {
                    // Ciclo in volo arrivato a destinazione (preroll-seek applicato:
                    // resumePositionMs==0). Delega al root: se ci sono tap in coda fa
                    // UN altro rebuild (mai sovrapposto), altrimenti arma il reveal
                    // della cover. Confronto con appliedSeekTarget (non lastSeekTarget:
                    // può essere già avanzato per tap successivi ancora in coda).
                    if (videoMessageComponent.seekRebuildInFlight
                            && videoMessageComponent.resumePositionMs === 0
                            && Math.abs(position - videoMessageComponent.appliedSeekTarget) < 3000) {
                        videoMessageComponent.handleSeekReached();
                    }
                }
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
                // onErrorChanged (proprietà con notify), NON onError: il tipo
                // Video di QtMultimedia 5.6 è un wrapper QML che non inoltra
                // il segnale error(error, errorString) → "Cannot assign to
                // non-existent property" e l'intero componente non carica più.
                onErrorChanged: {
                    if (error === MediaPlayer.NoError) {
                        return;
                    }
                    // Pipeline in errore: annulla la raffica di seek (cover + coda),
                    // così un pendingSeekTarget stantìo non rilancia un rebuild.
                    videoMessageComponent.endSeekRebuild();
                    if (error === MediaPlayer.ResourceError && !videoMessageComponent.errorRetryDone) {
                        // File locale sparito sotto i piedi: TDLib ripulisce lo
                        // storage, ma lo snapshot del messaggio (in fullscreen è
                        // congelato al push di VideoPage) crede il file ancora
                        // scaricato → il play parte su un path inesistente e
                        // senza questo retry resterebbe morto ("il pulsante play
                        // non funziona più"). downloadFile fa verificare il file
                        // a TDLib, che lo riscarica se manca; al termine
                        // onFileUpdated rilancia il play via playRequested.
                        videoMessageComponent.errorRetryDone = true;
                        videoMessageComponent.playRequested = true;
                        videoDownloadBusyIndicator.running = true;
                        tdLibWrapper.downloadFile(videoFileId);
                        restorePreview();
                    } else {
                        // Pipeline morta (es. seek indigesto al decoder hardware
                        // droid): niente player nero inerte, tornano anteprima e
                        // controlli e il play può ripartire da zero.
                        restorePreview();
                    }
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

            // Watchdog anti-appensione: il seek sul decoder hardware droid a
            // volte incanta la pipeline SENZA emettere errori (posizione ferma,
            // frame congelato) → onErrorChanged non può scattare. Se in
            // PlayingState la posizione non avanza per 2 tick consecutivi,
            // smontiamo il player: tornano anteprima e play, e da lì riparte
            // anche l'auto-recovery (ri-download se il file è sparito).
            Timer {
                id: seekWatchdog
                interval: 2000
                repeat: true
                property real lastPosition: -1
                property int stuckCount: 0
                function arm() {
                    lastPosition = -1;
                    stuckCount = 0;
                    restart();
                }
                onTriggered: {
                    if (!videoComponentLoader.active
                            || messageVideo.playbackState !== MediaPlayer.PlayingState) {
                        stop();
                        stuckCount = 0;
                        lastPosition = -1;
                        return;
                    }
                    if (messageVideo.position === lastPosition) {
                        stuckCount++;
                        if (stuckCount >= 2) {
                            stop();
                            stuckCount = 0;
                            // Seek soft-stuck (non deadlock: il timer è scattato):
                            // annulla la raffica così la coda non resta appesa.
                            videoMessageComponent.endSeekRebuild();
                            messageVideo.restorePreview();
                            return;
                        }
                    } else {
                        stuckCount = 0;
                    }
                    lastPosition = messageVideo.position;
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
                        // Niente seek sulla pipeline viva (deadlock droid):
                        // fermo-immagine + smonta-e-ricrea, orchestrato da una
                        // funzione del root (questo handler vive dentro il
                        // componente che verrà distrutto). Leggere `value` prima.
                        videoMessageComponent.seekViaRebuild(Math.floor(value));
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
