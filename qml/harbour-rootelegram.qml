/*
    Copyright (C) 2020 Sebastian J. Wolf and other contributors
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
import QtQuick 2.6
import QtMultimedia 5.6
import Sailfish.Silica 1.0
import Sailfish.Share 1.0
import Nemo.DBus 2.0
import "pages"
import "components"
import "./js/functions.js" as Functions

ApplicationWindow
{
    id: appWindow

    initialPage: Qt.resolvedUrl("pages/OverviewPage.qml")
    cover: Qt.resolvedUrl("pages/CoverPage.qml")
    allowedOrientations: defaultAllowedOrientations
    property var pendingShareResources: []

    // Velocità di riproduzione per vocali e audio, condivisa tra i player e
    // valida per la sessione. Il backend GStreamer di Jolla usa scaletempo
    // come audio-filter: il tempo cambia, il pitch no. SOLO audio: sui video
    // il cambio rate è un seek trick-play che il decoder hardware droid non
    // regge (crash dell'app verificato sul campo, 2026-07-17).
    property real mediaPlaybackRate: 1.0
    function cycleMediaPlaybackRate() {
        mediaPlaybackRate = (mediaPlaybackRate === 1.0) ? 1.25
                          : (mediaPlaybackRate === 1.25) ? 1.5 : 1.0;
    }

    function openShareDialog(resources) {
        if (!resources || resources.length === 0) {
            return;
        }
        var normalizedResources = [];
        var requiredPermissions = [];
        var hasTextResources = false;
        var hasFileResources = false;
        for (var i = 0; i < resources.length; i += 1) {
            var resource = resources[i];
            if (!resource) {
                continue;
            }
            if (typeof resource === 'string') {
                var asString = resource.toString();
                if (asString.indexOf("file://") === 0 || asString.indexOf("/") === 0) {
                    normalizedResources.push({
                        type: "file",
                        filePath: asString.indexOf("file://") === 0 ? asString.substring(7) : asString
                    });
                    hasFileResources = true;
                } else {
                    normalizedResources.push({
                        type: "text",
                        name: "",
                        data: asString
                    });
                    hasTextResources = true;
                }
                continue;
            }
            var filePath = resource.filePath ? resource.filePath.toString() : "";
            if (filePath !== "") {
                normalizedResources.push({
                    type: "file",
                    filePath: filePath
                });
                hasFileResources = true;
                continue;
            }
            var statusText = resource.status ? resource.status.toString() : "";
            if (statusText !== "") {
                normalizedResources.push({
                    type: "text",
                    name: resource.linkTitle ? resource.linkTitle.toString() : "",
                    data: statusText
                });
                hasTextResources = true;
                continue;
            }
            var resourceData = resource.data ? resource.data.toString() : "";
            if (resourceData !== "") {
                normalizedResources.push({
                    type: "text",
                    name: resource.name ? resource.name.toString() : "",
                    data: resourceData
                });
                hasTextResources = true;
            }
        }
        if (normalizedResources.length === 0) {
            return;
        }
        if (hasFileResources) {
            requiredPermissions = [
                "can_send_media_messages",
                "can_send_other_messages",
                "can_send_documents",
                "can_send_photos",
                "can_send_videos"
            ];
        } else if (hasTextResources) {
            requiredPermissions = [ "can_send_basic_messages" ];
        }
        pageStack.push(Qt.resolvedUrl("pages/ChatSelectionPage.qml"), {
            myUserId: tdLibWrapper.getUserInformation().id,
            headerDescription: qsTr("Send shared content"),
            payload: {
                resources: normalizedResources,
                neededPermissions: requiredPermissions
            },
            state: "shareResources"
        });
    }

    Timer {
        id: shareDispatchTimer
        interval: 0
        running: false
        repeat: false
        onTriggered: {
            if (appWindow.pendingShareResources && appWindow.pendingShareResources.length > 0) {
                var nextResources = appWindow.pendingShareResources;
                appWindow.pendingShareResources = [];
                appWindow.openShareDialog(nextResources);
            }
        }
    }

    ShareAction {
        id: shareActionParser
    }

    DBusAdaptor {
        service: "com.github.RootGPT_YouTube.rootelegram"
        path: "/share/rootelegram_share"
        iface: "org.sailfishos.share"

        function share(shareConfiguration) {
            shareActionParser.loadConfiguration(shareConfiguration);
            appWindow.activate();
            var queuedResources = [];
            if (shareActionParser.resources && shareActionParser.resources.length > 0) {
                for (var i = 0; i < shareActionParser.resources.length; i += 1) {
                    queuedResources.push(shareActionParser.resources[i]);
                }
            }
            appWindow.pendingShareResources = queuedResources;
            shareDispatchTimer.restart();
        }
    }

    Connections {
        target: dBusAdaptor
        onPleaseActivateApp: {
            appWindow.activate();
        }
        onPleaseOpenMessage: {
            appWindow.activate();
        }
        onPleaseOpenUrl: {
            appWindow.activate();
        }
        onPleaseOpenStories: {
            appWindow.activate();
        }
    }

    Connections {
        target: tdLibWrapper
        onOpenFileExternally: {
            Qt.openUrlExternally(filePath);
        }
        onTgUrlFound: {
            Functions.handleLink(tgUrl);
        }
    }

    AppNotification {
        id: appNotification
        parent: pageStack.currentPage
    }

    Component.onCompleted: {
        Functions.setGlobals({
            tdLibWrapper: tdLibWrapper,
            appNotification: appNotification
        });
    }

    // ── Schermata chiamata vocale (T3 entranti + T4 UI) ──────────────────────
    // Handler GLOBALE a livello di ApplicationWindow: l'onCallUpdated della
    // ChatInformationTabView vive solo sulla pagina info di quella chat. Gestisce
    // sia entranti che uscenti. Guardato da voiceCallsAvailable: build spedibile
    // (voce OFF) → callUpdated non arriva mai, overlay invisibile, nessun cambio.
    readonly property bool voiceCallsEnabled: (typeof voiceCallsAvailable !== 'undefined') && voiceCallsAvailable === true

    // Suoneria + vibrazione su chiamata entrante via ngfd (evento voip_ringtone:
    // suono e vibrazione gestiti dal profilo di sistema). ngfd è sul SYSTEM bus.
    DBusInterface {
        id: callFeedback
        bus: DBus.SystemBus
        service: "com.nokia.NonGraphicFeedback1.Backend"
        path: "/com/nokia/NonGraphicFeedback1"
        iface: "com.nokia.NonGraphicFeedback1"
    }
    property int ringtoneEventId: 0
    function startCallRingtone() {
        if (appWindow.ringtoneEventId !== 0) {
            return;
        }
        callFeedback.typedCall("Play",
            [ {"type": "s", "value": "voip_ringtone"}, {"type": "a{sv}", "value": {}} ],
            function(result) { appWindow.ringtoneEventId = result; },
            function() { /* ngf non disponibile: ignora */ });
    }
    function stopCallRingtone() {
        if (appWindow.ringtoneEventId === 0) {
            return;
        }
        callFeedback.typedCall("Stop", [ {"type": "u", "value": appWindow.ringtoneEventId} ]);
        appWindow.ringtoneEventId = 0;
    }

    // Toni telefonici della chiamata USCENTE, riprodotti localmente nell'auricolare
    // (nessun evento ngfd standard li copre): ringback "libero" mentre l'altro
    // squilla, tono di occupato/irraggiungibile rapido se non si connette.
    SoundEffect {
        id: ringbackTone
        source: Qt.resolvedUrl("../sounds/ringback.wav")
        loops: SoundEffect.Infinite
    }
    SoundEffect {
        id: busyTone
        source: Qt.resolvedUrl("../sounds/callbusy.wav")
        loops: 1
    }
    function startRingback() {
        // Instrada nell'auricolare prima di suonare (di default il sink droid è
        // sull'altoparlante). callManager esiste solo con la voce abilitata.
        if (typeof callManager !== 'undefined') {
            callManager.setSpeakerphoneOn(false);
        }
        ringbackTone.play();
    }
    function stopRingback() {
        ringbackTone.stop();
    }
    function playBusyTone() {
        busyTone.play();
    }

    Connections {
        target: tdLibWrapper
        onCallUpdated: {
            if (!appWindow.voiceCallsEnabled) {
                return;
            }
            var st = (call && call.state && call.state["@type"]) ? call.state["@type"] : "";
            var cid = call.id;
            var outgoing = call.is_outgoing === true;
            var ongoing = (st === "callStatePending" || st === "callStateExchangingKeys" || st === "callStateReady");
            if (ongoing) {
                if (callScreen.callId !== cid) {
                    // Nuova chiamata: risolvi nome + foto del partner.
                    var info = tdLibWrapper.getUserInformation(call.user_id.toString());
                    var nm = "";
                    if (info) {
                        nm = ((info.first_name || "") + " " + (info.last_name || "")).trim();
                    }
                    callScreen.callerName = nm !== "" ? nm : qsTr("Unknown caller");
                    callScreen.callerPhoto = (info && info.profile_photo) ? info.profile_photo.small : ({});
                    callScreen.callId = cid;
                    callScreen.outgoing = outgoing;
                    callScreen.isVideo = call.is_video === true;
                    callScreen.videoEnabled = true;
                    callScreen.muted = false;
                    // Vivavoce: OFF di default nelle vocali (auricolare), ON nelle
                    // videochiamate (si tiene il telefono lontano per inquadrarsi).
                    callScreen.speakerOn = (call.is_video === true);
                    callScreen.connectedAt = 0;
                    callScreen.elapsed = 0;
                    callScreen.verifyEmojis = [];
                    if (!outgoing) {
                        appWindow.startCallRingtone();   // entrante: squilla + vibra
                    } else {
                        appWindow.startRingback();       // uscente: "tu-tu" nell'auricolare
                    }
                }
                callScreen.callState = st;
                if (st !== "callStatePending") {
                    appWindow.stopCallRingtone();        // accettata/in connessione: stop
                    appWindow.stopRingback();            // l'altro ha risposto: stop ringback
                }
                if (st === "callStateReady" && callScreen.connectedAt === 0) {
                    callScreen.connectedAt = Date.now();
                    // Allinea l'uscita audio allo stato del toggle all'attivazione.
                    if (typeof callManager !== 'undefined') {
                        callManager.setSpeakerphoneOn(callScreen.speakerOn);
                    }
                }
                // Emoji di verifica cifratura: disponibili da callStateReady in poi.
                if (st === "callStateReady" && call.state && call.state.emojis
                        && callScreen.verifyEmojis.length === 0) {
                    callScreen.verifyEmojis = call.state.emojis;
                }
                callScreen.visible = true;
                appWindow.activate();
                // Blocca l'orientamento a portrait per la durata della chiamata
                // (l'overlay è disegnato verticale). Salva il precedente una volta.
                if (callScreen.savedOrientations === undefined && pageStack.currentPage) {
                    callScreen.savedOrientations = pageStack.currentPage.allowedOrientations;
                    pageStack.currentPage.allowedOrientations = Orientation.Portrait;
                }
            } else if (cid === callScreen.callId) {
                appWindow.stopCallRingtone();
                appWindow.stopRingback();
                if (st === "callStateHangingUp") {
                    callScreen.callState = st;
                } else if (st === "callStateDiscarded" || st === "callStateError") {
                    // Edge-case (T5): feedback breve sul motivo di chiusura.
                    var reason = (call.state && call.state.reason && call.state.reason["@type"]) ? call.state.reason["@type"] : "";
                    // Chiamata uscente mai connessa per occupato/irraggiungibile/
                    // rifiuto/errore: tono "tu-tu-tu" rapido di linea non disponibile.
                    var failedOutgoing = callScreen.outgoing && callScreen.connectedAt === 0
                            && (reason === "callDiscardReasonDeclined"
                                || reason === "callDiscardReasonDisconnected"
                                || reason === "callDiscardReasonEmpty"
                                || st === "callStateError");
                    if (failedOutgoing) {
                        appWindow.playBusyTone();
                    }
                    if (reason === "callDiscardReasonDeclined") {
                        appNotification.show(qsTr("Call declined"));
                    } else if (reason === "callDiscardReasonMissed") {
                        appNotification.show(callScreen.outgoing ? qsTr("No answer") : qsTr("Missed call"));
                    } else if (reason === "callDiscardReasonDisconnected" || st === "callStateError") {
                        appNotification.show(qsTr("Call failed"));
                    }
                    callScreen.visible = false;
                    callScreen.callId = 0;
                    callScreen.callState = "";
                    callScreen.verifyEmojis = [];
                    // Ripristina l'orientamento della pagina sotto.
                    if (callScreen.savedOrientations !== undefined && pageStack.currentPage) {
                        pageStack.currentPage.allowedOrientations = callScreen.savedOrientations;
                    }
                    callScreen.savedOrientations = undefined;
                }
            }
        }
    }

    Rectangle {
        id: callScreen
        property int callId: 0
        property string callerName: ""
        property var callerPhoto: ({})   // ProfileThumbnail.photoData è un QVariantMap: mai stringa
        // V4: avatar dell'utente locale (per il placeholder della PiP a video spento).
        readonly property var ownPhoto: (tdLibWrapper.userInformation && tdLibWrapper.userInformation.profile_photo)
                                        ? tdLibWrapper.userInformation.profile_photo.small : ({})
        property bool outgoing: false
        property bool isVideo: false   // V3: videochiamata
        property bool videoEnabled: true  // V4: invio video attivo (toggle on/off)
        // V3: l'overlay chiamata è disegnato per il portrait → blocchiamo
        // l'orientamento della pagina sotto mentre la chiamata è visibile, e lo
        // ripristiniamo a fine chiamata. (var = orientamenti salvati, undefined = nessun lock)
        property var savedOrientations: undefined
        property string callState: ""
        property bool muted: false
        property bool speakerOn: false   // default: auricolare (no vivavoce)
        property double connectedAt: 0
        property int elapsed: 0
        // Emoji di verifica cifratura E2E: le 4 emoji fornite da TDLib in
        // callStateReady (state.emojis), derivate dalla chiave condivisa. Se
        // combaciano con quelle dell'interlocutore la chiamata è cifrata e non
        // intercettata. Azzerate a ogni nuova chiamata / a fine chiamata.
        property var verifyEmojis: []
        readonly property bool ringingIncoming: callState === "callStatePending" && !outgoing
        readonly property bool connected: callState === "callStateReady"
        // V3c: videochiamata connessa → layout dedicato (info in alto, controlli in basso).
        readonly property bool videoConnected: isVideo && connected

        function toggleMute() {
            muted = !muted;
            if (typeof callManager !== 'undefined') {
                callManager.setMicrophoneMuted(muted);
            }
        }
        function toggleSpeaker() {
            speakerOn = !speakerOn;
            if (typeof callManager !== 'undefined') {
                callManager.setSpeakerphoneOn(speakerOn);
            }
        }
        function toggleVideo() {
            videoEnabled = !videoEnabled;
            if (typeof callManager !== 'undefined') {
                callManager.setVideoEnabled(videoEnabled);
            }
        }
        function switchCamera() {
            if (typeof callManager !== 'undefined') {
                callManager.switchCamera();
            }
        }
        function endCall() {
            appWindow.stopRingback();
            tdLibWrapper.discardVoiceCall(callScreen.callId, false, 0, false, 0);
            callScreen.visible = false;
        }
        function statusText() {
            switch (callScreen.callState) {
            case "callStatePending":
                return callScreen.outgoing
                       ? qsTr("Calling…")
                       : (callScreen.isVideo ? qsTr("Incoming video call") : qsTr("Incoming voice call"));
            case "callStateExchangingKeys": return qsTr("Exchanging encryption keys…");
            case "callStateReady": return callScreen.formatElapsed(callScreen.elapsed);
            case "callStateHangingUp": return qsTr("Ending call…");
            default: return "";
            }
        }

        visible: false
        anchors.fill: parent
        z: 10000
        color: Qt.rgba(0, 0, 0, 0.96)

        // Assorbe i tap così non raggiungono la pagina sottostante.
        MouseArea { anchors.fill: parent }

        // V3c: video remoto a tutto schermo (sotto i controlli) + anteprima
        // locale in PiP. Visibili solo nelle videochiamate.
        VideoOutput {
            id: remoteVideoOut
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectFit
            source: (typeof callManager !== 'undefined') ? callManager.remoteVideo : null
            // Visibile finché arrivano frame remoti (lo spegnimento del remoto
            // azzera il renderer → hasFrame=false → compare il placeholder).
            visible: callScreen.isVideo && typeof callManager !== 'undefined'
                     && callManager.remoteVideo && callManager.remoteVideo.hasFrame
        }

        // V4: quando il remoto NON invia video, al posto dell'ultimo frame congelato
        // mostriamo l'avatar del contatto, oppure (se non c'è) schermo nero con
        // scritta rossa "Video non / disponibile".
        Rectangle {
            id: remoteVideoPlaceholder
            anchors.fill: parent
            color: "black"
            // Mostrato quando NON arrivano frame dal remoto (camera spenta o non
            // ancora avviata): avatar del contatto, o "Video non disponibile".
            visible: callScreen.videoConnected
                     && !(typeof callManager !== 'undefined'
                          && callManager.remoteVideo && callManager.remoteVideo.hasFrame)
            property bool hasAvatar: callScreen.callerPhoto
                                     && Object.keys(callScreen.callerPhoto).length > 0
            ProfileThumbnail {
                anchors.centerIn: parent
                width: Theme.itemSizeHuge * 1.5
                height: width
                photoData: callScreen.callerPhoto
                replacementStringHint: callScreen.callerName
                optimizeImageSize: false
                visible: remoteVideoPlaceholder.hasAvatar
            }
            Label {
                anchors.centerIn: parent
                visible: !remoteVideoPlaceholder.hasAvatar
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Video not\navailable")
                color: "#ff4444"
                font.pixelSize: Theme.fontSizeExtraLarge
                font.bold: true
            }
        }
        VideoOutput {
            id: localVideoOut
            width: parent.width * 0.28
            height: width * 4 / 3
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.paddingMedium
            fillMode: VideoOutput.PreserveAspectFit
            source: (typeof callManager !== 'undefined') ? callManager.localVideo : null
            // Nascosta se il video è disattivato (V4) o non è una videochiamata.
            visible: callScreen.isVideo && callScreen.videoEnabled
            z: 1
            // V5: mirror "selfie" dell'anteprima locale con la frontale (il video
            // INVIATO resta non specchiato → l'altro ti vede correttamente).
            transform: Scale {
                origin.x: localVideoOut.width / 2
                xScale: (typeof callManager !== 'undefined' && callManager.frontCamera) ? -1 : 1
            }
        }

        // V4: placeholder della PiP quando spegni il TUO video → tuo avatar, o
        // "Video non disponibile" se non hai avatar (stesso trattamento del remoto).
        Rectangle {
            id: localVideoPlaceholder
            width: localVideoOut.width
            height: localVideoOut.height
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.paddingMedium
            z: 1
            color: "black"
            visible: callScreen.videoConnected && !callScreen.videoEnabled
            property bool hasAvatar: callScreen.ownPhoto
                                     && Object.keys(callScreen.ownPhoto).length > 0
            ProfileThumbnail {
                anchors.centerIn: parent
                width: parent.height * 0.6
                height: width
                photoData: callScreen.ownPhoto
                replacementStringHint: ""
                optimizeImageSize: false
                visible: localVideoPlaceholder.hasAvatar
            }
            Label {
                anchors.centerIn: parent
                width: parent.width - 2 * Theme.paddingSmall
                visible: !localVideoPlaceholder.hasAvatar
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: qsTr("Video not\navailable")
                color: "#ff4444"
                font.pixelSize: Theme.fontSizeTiny
                font.bold: true
            }
        }

        Timer {
            interval: 1000
            repeat: true
            running: callScreen.visible && callScreen.connected
            onTriggered: callScreen.elapsed = Math.floor((Date.now() - callScreen.connectedAt) / 1000)
        }

        function formatElapsed(s) {
            var m = Math.floor(s / 60);
            var sec = s % 60;
            return (m < 10 ? "0" + m : m) + ":" + (sec < 10 ? "0" + sec : sec);
        }

        // Layout centrato: chiamate audio e fase di squillo (anche video non ancora
        // connessa). Nelle videochiamate connesse cede il posto ai blocchi top/bottom.
        Column {
            anchors.centerIn: parent
            width: parent.width - 2 * Theme.horizontalPageMargin
            spacing: Theme.paddingLarge
            visible: !callScreen.videoConnected

            ProfileThumbnail {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.itemSizeHuge * 1.5
                height: width
                photoData: callScreen.callerPhoto
                replacementStringHint: callScreen.callerName
                optimizeImageSize: false
                visible: !callScreen.isVideo   // V3c: nelle video lo schermo è il video remoto
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: callScreen.callerName
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeHuge
                truncationMode: TruncationMode.Fade
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeLarge
                text: callScreen.statusText()
            }

            // Emoji di verifica cifratura E2E (le 4 emoji di callStateReady).
            Column {
                width: parent.width
                spacing: Theme.paddingSmall
                visible: callScreen.connected && callScreen.verifyEmojis.length > 0
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.paddingLarge
                    Repeater {
                        model: callScreen.verifyEmojis
                        Label {
                            text: modelData
                            font.pixelSize: Theme.fontSizeExtraLarge * 1.4
                        }
                    }
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: qsTr("If these emoji match your contact's, the call is end-to-end encrypted")
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                }
            }

            Item { width: 1; height: Theme.paddingLarge }

            // Entrante che squilla: Accetta / Rifiuta.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingLarge * 2
                visible: callScreen.ringingIncoming
                Button {
                    text: qsTr("Decline")
                    color: "#ff4444"
                    onClicked: {
                        appWindow.stopCallRingtone();
                        tdLibWrapper.discardVoiceCall(callScreen.callId, false, 0, false, 0);
                        callScreen.visible = false;
                    }
                }
                Button {
                    text: qsTr("Accept")
                    color: "#44dd44"
                    onClicked: {
                        appWindow.stopCallRingtone();
                        tdLibWrapper.acceptVoiceCall(callScreen.callId, callScreen.isVideo);
                    }
                }
            }

            // Chiamata in corso (audio): Muto / Vivavoce.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingLarge * 2
                visible: !callScreen.ringingIncoming
                Button {
                    text: callScreen.muted ? qsTr("Unmute") : qsTr("Mute")
                    enabled: callScreen.connected
                    onClicked: callScreen.toggleMute()
                }
                Button {
                    text: callScreen.speakerOn ? qsTr("Speaker off") : qsTr("Speaker")
                    enabled: callScreen.connected
                    onClicked: callScreen.toggleSpeaker()
                }
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !callScreen.ringingIncoming
                text: qsTr("End call")
                color: "#ff4444"
                onClicked: callScreen.endCall()
            }
        }

        // ── V3c: videochiamata connessa — info in ALTO, controlli in BASSO ──
        // Striscia scura in alto per leggibilità di nome + timer sul video.
        Rectangle {
            visible: callScreen.videoConnected
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: videoTopInfo.height + 2 * Theme.paddingLarge
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.6) }
                GradientStop { position: 1.0; color: "transparent" }
            }
            Column {
                id: videoTopInfo
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: Theme.paddingLarge }
                spacing: Theme.paddingSmall
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: callScreen.callerName
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeLarge
                    truncationMode: TruncationMode.Fade
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeMedium
                    text: callScreen.statusText()
                }
                // Emoji di verifica cifratura E2E (compatte, sopra il video).
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.paddingMedium
                    visible: callScreen.connected && callScreen.verifyEmojis.length > 0
                    Repeater {
                        model: callScreen.verifyEmojis
                        Label {
                            text: modelData
                            font.pixelSize: Theme.fontSizeLarge
                        }
                    }
                }
            }
        }

        // V4: barra di controllo a icone (sta comoda in una riga): microfono,
        // vivavoce, cambia camera, video on/off, termina.
        Row {
            id: videoControls
            visible: callScreen.videoConnected
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                bottomMargin: Theme.paddingLarge * 2
            }
            spacing: Theme.paddingLarge
            IconButton {
                icon.source: callScreen.muted ? "image://theme/icon-m-mic-mute"
                                              : "image://theme/icon-m-mic"
                onClicked: callScreen.toggleMute()
            }
            IconButton {
                icon.source: callScreen.speakerOn ? "image://theme/icon-m-speaker-on"
                                                  : "image://theme/icon-m-speaker"
                onClicked: callScreen.toggleSpeaker()
            }
            IconButton {
                icon.source: "image://theme/icon-m-flip"
                onClicked: callScreen.switchCamera()
            }
            IconButton {
                icon.source: "image://theme/icon-m-video"
                icon.color: callScreen.videoEnabled ? Theme.primaryColor : Theme.secondaryColor
                onClicked: {
                    // Gate soft fotocamera: se l'utente l'ha disattivata in
                    // Impostazioni → Privacy, non attiviamo il video.
                    if (!callScreen.videoEnabled && !appSettings.isPermissionGranted("camera")) {
                        appNotification.show(qsTr("Camera is turned off in RooTelegram settings."));
                        return;
                    }
                    callScreen.toggleVideo();
                }
            }
            IconButton {
                icon.source: "image://theme/icon-m-call"
                icon.color: "#ff4444"
                onClicked: callScreen.endCall()
            }
        }
    }

    Connections {
        target: Qt.application
        onStateChanged: {
            // Quando l'app va in background, riportiamo lo stack alla Home
            // così la prossima attivazione riparte da OverviewPage.
            //
            // Su Sailfish swipe-close NON emette ApplicationHidden/Suspended,
            // resta in ApplicationInactive ma con appWindow.visible=false.
            // Dim display / notifica → Inactive con visible=true: NON pop.
            //
            // Il daemon è sempre attivo: l'app resta viva indipendentemente.
            var s = Qt.application.state;
            // ANTI-RAM Strada C: informa il wrapper se la UI è in primo piano.
            // Active è l'unico stato "davvero visibile": Inactive copre sia il
            // cover sia lo swipe-close (che NON cambia stato, ma a quel punto
            // siamo già passati per Inactive). Il riciclo del client TDLib parte
            // solo dopo che la UI è rimasta non-attiva per il periodo di grazia.
            tdLibWrapper.setUiVisible(s === Qt.ApplicationActive);
            var isBackground = (s === Qt.ApplicationSuspended
                                || s === Qt.ApplicationHidden
                                || (s === Qt.ApplicationInactive && !appWindow.visible));
            if (isBackground) {
                // Se l'utente ha scelto di restare nella chat alla chiusura
                // (Impostazioni → Comportamento), NON riportiamo lo stack alla
                // Home: riaprendo l'app si ritrova la chat aperta.
                if (pageStack && pageStack.depth > 1 && !appSettings.keepCurrentChatOnMinimize) {
                    pageStack.pop(null, PageStackAction.Immediate);
                }
                // Libera gli oggetti QML cache-ati dal motore JS: in modalità
                // daemon l'app resta viva e senza un gc esplicito chiusure /
                // model / proxy continuano ad accumularsi. Mitigazione minima
                // per la crescita di RAM osservata; i caching C++ (scheduled
                // messages, discussion threads, custom emoji) restano e vanno
                // ripuliti separatamente.
                gc();
                // [RAM #1] Restituisci al kernel le pagine heap liberate dai
                // MessageData (QVariantMap pesanti): senza trim la RSS resta
                // gonfia anche dopo i delete. Logga anche le istanze vive.
                chatModel.trimMemory();
            }
        }
    }
}
