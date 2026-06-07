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
import Sailfish.Share 1.0
import QtMultimedia 5.6
import "../components"
import "../components/messageContent"
import "../js/functions.js" as Functions
import "../js/debug.js" as Debug

Page {
    id: videoPage
    allowedOrientations: Orientation.All

    property var videoData;
    property alias videoType: myVideoComponent.videoType
    property alias isVideoNote: myVideoComponent.isVideoNote
    property var sourceMessage;

    property int videoWidth : videoData.width
    property int videoHeight : videoData.height
    property string videoUrl;

    property real imageSizeFactor : videoWidth / videoHeight;
    property real screenSizeFactor: videoPage.width / videoPage.height;
    property real sizingFactor    : imageSizeFactor >= screenSizeFactor ? videoPage.width / videoWidth : videoPage.height / videoHeight;

    // "ove non vietato esplicitamente": Telegram blocca il salvataggio quando
    // can_be_saved è false (contenuto protetto). Se manca il campo, consenti.
    readonly property bool canSave: !sourceMessage || sourceMessage.can_be_saved !== false
    // Azione richiesta in attesa che il download finisca ('save' | 'share').
    property string pendingAction: ""

    function performSave() {
        if (videoPage.videoUrl) tdLibWrapper.copyFileToDownloads(videoPage.videoUrl);
    }
    function triggerAction(action) {
        if (!canSave) return;
        if (videoPage.videoUrl !== "") {
            if (action === 'share') shareAction.trigger();
            else performSave();
        } else {
            pendingAction = action;
            tdLibWrapper.downloadFile(videoData[videoType].id);
        }
    }

    Component.onCompleted: {
        updateVideoData();
    }

    // Reclama l'heap JS V4 alla chiusura del player (vedi riduzione RAM #4).
    Component.onDestruction: gc()

    ShareAction {
        id: shareAction
        mimeType: (videoData && videoData.mime_type) ? videoData.mime_type : "video/mp4"
        resources: videoPage.videoUrl ? [videoPage.videoUrl] : []
    }

    function updateVideoData() {
        if (typeof videoData === "object") {
            if (videoData[videoType].local.is_downloading_completed) {
                videoPage.videoUrl = videoData[videoType].local.path;
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent

        PullDownMenu {
            id: videoPagePullDownMenu
            visible: (videoPage.videoUrl !== "")
            MenuItem {
                text: qsTr("Copy video to gallery")
                onClicked: {
                    tdLibWrapper.copyFileToDownloads(videoPage.videoUrl);
                }
            }
        }

        Connections {
            target: tdLibWrapper
            onFileUpdated: {
                if (fileId === videoPage.videoData[videoType].id) {
                    if (fileInformation.local.is_downloading_completed) {
                        videoPage.videoUrl = fileInformation.local.path;
                        videoPagePullDownMenu.visible = true;
                        // Esegui l'azione richiesta dall'utente mentre il download
                        // era in corso (salva in galleria / condividi).
                        if (videoPage.pendingAction === 'share') {
                            shareAction.trigger();
                        } else if (videoPage.pendingAction === 'save') {
                            videoPage.performSave();
                        }
                        videoPage.pendingAction = "";
                    }
                }
            }
            onCopyToDownloadsSuccessful: {
                appNotification.show(qsTr("Download of %1 successful.").arg(fileName), filePath);
            }

            onCopyToDownloadsError: {
                appNotification.show(qsTr("Download failed."));
            }
        }

        Item {
            width: videoPage.videoWidth * videoPage.sizingFactor
            height: videoPage.videoHeight * videoPage.sizingFactor
            anchors.centerIn: parent

            MessageVideo {
                id: myVideoComponent
                videoData: videoPage.videoData
                fullscreen: true
                onScreen: videoPage.status === PageStatus.Active
                rawMessage: sourceMessage
                anchors.fill: parent
            }
        }

    }

    // Tasti download + condividi, sovrapposti in alto a destra per non coprire
    // i controlli del player (play centrale, barra di scorrimento in basso).
    // Nascosti quando il salvataggio è vietato dal canale (can_be_saved=false).
    Row {
        id: videoActionButtons
        visible: videoPage.canSave
        spacing: Theme.paddingMedium
        anchors {
            right: parent.right
            top: parent.top
            margins: Theme.horizontalPageMargin
        }

        IconButton {
            icon.source: "image://theme/icon-m-downloads?" + (pressed
                         ? Theme.highlightColor
                         : Theme.lightPrimaryColor)
            onClicked: videoPage.triggerAction('save')
            BusyIndicator {
                anchors.centerIn: parent
                size: BusyIndicatorSize.Small
                running: videoPage.pendingAction === 'save' && videoPage.videoUrl === ""
            }
        }
        IconButton {
            icon.source: "image://theme/icon-m-share?" + (pressed
                         ? Theme.highlightColor
                         : Theme.lightPrimaryColor)
            onClicked: videoPage.triggerAction('share')
            BusyIndicator {
                anchors.centerIn: parent
                size: BusyIndicatorSize.Small
                running: videoPage.pendingAction === 'share' && videoPage.videoUrl === ""
            }
        }
    }
}

