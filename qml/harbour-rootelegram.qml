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
