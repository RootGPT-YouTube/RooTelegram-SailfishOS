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
                    callScreen.muted = false;
                    callScreen.speakerOn = false;   // default: auricolare, non vivavoce
                    callScreen.connectedAt = 0;
                    callScreen.elapsed = 0;
                    if (!outgoing) {
                        appWindow.startCallRingtone();   // entrante: squilla + vibra
                    }
                }
                callScreen.callState = st;
                if (st !== "callStatePending") {
                    appWindow.stopCallRingtone();        // accettata/in connessione: stop
                }
                if (st === "callStateReady" && callScreen.connectedAt === 0) {
                    callScreen.connectedAt = Date.now();
                    // Allinea l'uscita audio allo stato del toggle all'attivazione.
                    if (typeof callManager !== 'undefined') {
                        callManager.setSpeakerphoneOn(callScreen.speakerOn);
                    }
                }
                callScreen.visible = true;
                appWindow.activate();
            } else if (cid === callScreen.callId) {
                appWindow.stopCallRingtone();
                if (st === "callStateHangingUp") {
                    callScreen.callState = st;
                } else if (st === "callStateDiscarded" || st === "callStateError") {
                    // Edge-case (T5): feedback breve sul motivo di chiusura.
                    var reason = (call.state && call.state.reason && call.state.reason["@type"]) ? call.state.reason["@type"] : "";
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
                }
            }
        }
    }

    Rectangle {
        id: callScreen
        property int callId: 0
        property string callerName: ""
        property var callerPhoto: ({})   // ProfileThumbnail.photoData è un QVariantMap: mai stringa
        property bool outgoing: false
        property string callState: ""
        property bool muted: false
        property bool speakerOn: false   // default: auricolare (no vivavoce)
        property double connectedAt: 0
        property int elapsed: 0
        readonly property bool ringingIncoming: callState === "callStatePending" && !outgoing
        readonly property bool connected: callState === "callStateReady"

        visible: false
        anchors.fill: parent
        z: 10000
        color: Qt.rgba(0, 0, 0, 0.96)

        // Assorbe i tap così non raggiungono la pagina sottostante.
        MouseArea { anchors.fill: parent }

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

        Column {
            anchors.centerIn: parent
            width: parent.width - 2 * Theme.horizontalPageMargin
            spacing: Theme.paddingLarge

            ProfileThumbnail {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.itemSizeHuge * 1.5
                height: width
                photoData: callScreen.callerPhoto
                replacementStringHint: callScreen.callerName
                optimizeImageSize: false
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
                text: {
                    switch (callScreen.callState) {
                    case "callStatePending":
                        return callScreen.outgoing ? qsTr("Calling…") : qsTr("Incoming voice call");
                    case "callStateExchangingKeys":
                        return qsTr("Exchanging encryption keys…");
                    case "callStateReady":
                        return callScreen.formatElapsed(callScreen.elapsed);
                    case "callStateHangingUp":
                        return qsTr("Ending call…");
                    default:
                        return "";
                    }
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
                        tdLibWrapper.acceptVoiceCall(callScreen.callId, false);
                    }
                }
            }

            // Chiamata in corso (uscente o entrante accettata): Muto / Vivavoce.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingLarge * 2
                visible: !callScreen.ringingIncoming
                Button {
                    text: callScreen.muted ? qsTr("Unmute") : qsTr("Mute")
                    enabled: callScreen.connected
                    onClicked: {
                        callScreen.muted = !callScreen.muted;
                        if (typeof callManager !== 'undefined') {
                            callManager.setMicrophoneMuted(callScreen.muted);
                        }
                    }
                }
                Button {
                    text: callScreen.speakerOn ? qsTr("Speaker off") : qsTr("Speaker")
                    enabled: callScreen.connected
                    onClicked: {
                        callScreen.speakerOn = !callScreen.speakerOn;
                        if (typeof callManager !== 'undefined') {
                            callManager.setSpeakerphoneOn(callScreen.speakerOn);
                        }
                    }
                }
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !callScreen.ringingIncoming
                text: qsTr("End call")
                color: "#ff4444"
                onClicked: {
                    tdLibWrapper.discardVoiceCall(callScreen.callId, false, 0, false, 0);
                    callScreen.visible = false;
                }
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
            var isBackground = (s === Qt.ApplicationSuspended
                                || s === Qt.ApplicationHidden
                                || (s === Qt.ApplicationInactive && !appWindow.visible));
            if (isBackground) {
                if (pageStack && pageStack.depth > 1) {
                    pageStack.pop(null, PageStackAction.Immediate);
                }
                // Libera gli oggetti QML cache-ati dal motore JS: in modalità
                // daemon l'app resta viva e senza un gc esplicito chiusure /
                // model / proxy continuano ad accumularsi. Mitigazione minima
                // per la crescita di RAM osservata; i caching C++ (scheduled
                // messages, discussion threads, custom emoji) restano e vanno
                // ripuliti separatamente.
                gc();
            }
        }
    }
}
