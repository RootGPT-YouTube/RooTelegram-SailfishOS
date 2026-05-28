/*
    Copyright (C) 2026 RootGPT

    This file is part of RooTelegram.

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/
import QtQuick 2.6
import QtMultimedia 5.6
import Sailfish.Silica 1.0
import "../components"

Page {
    id: storiesViewerPage
    allowedOrientations: Orientation.All
    backgroundColor: "black"
    showNavigationIndicator: false

    property var storyInfos: []         // list of {story_id, date, is_for_close_friends} (Main/Archived)
    property var fullStories: []        // list of full story objects (My Archive). Se valorizzato, non chiamiamo getStory/viewStory.
    property var chatId: 0
    property string chatTitle: ""
    property int maxReadStoryId: 0
    property int currentIndex: 0
    property var currentStory: null     // full story object once received
    property int totalCount: fullStories && fullStories.length > 0
                              ? fullStories.length
                              : (storyInfos ? storyInfos.length : 0)
    property bool usingFullStories: fullStories && fullStories.length > 0
    property int currentStoryId: usingFullStories
                                  ? (currentStory ? currentStory.id || 0 : 0)
                                  : (storyInfos && currentIndex < storyInfos.length
                                     ? storyInfos[currentIndex].story_id : 0)
    property int photoDurationMs: 5000
    // È una mia storia? Confronto via stringa per evitare perdita di precisione int64.
    property bool isOwnStory: chatId != 0 && (("" + chatId) === ("" + tdLibWrapper.getUserInformation().id))

    Component.onCompleted: {
        if (totalCount === 0) {
            pageStack.pop();
            return;
        }
        if (!usingFullStories) {
            // Main/Archived: TDLib richiede che la chat sia "conosciuta" per
            // getStory/openStory. Per user-chat (id positivo) preflight.
            if (chatId > 0) {
                tdLibWrapper.createPrivateChat(chatId.toString(), "");
            }
            tdLibWrapper.openChat(chatId.toString());
        }
        loadStoryAt(currentIndex);
    }

    property bool closing: false
    property bool paused: false
    // Pausa innescata da noi all'apertura di un overlay (lista viewer o dialog di
    // reply): serve a distinguere dal caso in cui l'utente aveva già messo in
    // pausa manualmente, così al ritorno riprendiamo solo se eravamo stati noi.
    property bool autoPausedForOverlay: false

    property var interactionInfo: currentStory && currentStory.interaction_info
                                  ? currentStory.interaction_info : null
    // Pill viewer visibile solo sulle mie storie quando TDLib consente le interazioni.
    property bool canViewInteractions: isOwnStory && currentStoryId !== 0
                                       && currentStory && currentStory.can_get_interactions === true

    // Reaction (solo cuore) sulle storie altrui. Stato locale ottimistico,
    // riallineato a currentStory.chosen_reaction_type a ogni cambio storia.
    readonly property string heartEmoji: "❤"
    property string myReactionEmoji: ""
    property string reactionPrev: ""

    onStatusChanged: {
        if (status === PageStatus.Active && autoPausedForOverlay) {
            autoPausedForOverlay = false;
            if (paused) togglePause();
        }
    }

    function toggleHeart() {
        var next = (myReactionEmoji === heartEmoji) ? "" : heartEmoji;
        reactionPrev = myReactionEmoji;
        myReactionEmoji = next; // feedback ottimistico, revert in onErrorReceived
        tdLibWrapper.setStoryReaction("" + chatId, currentStoryId, next, true);
    }

    function openReply() {
        if (!paused) {
            togglePause();
            autoPausedForOverlay = true;
        }
        pageStack.push(Qt.resolvedUrl("StoryReplyDialog.qml"), {
            storyPosterChatId: "" + chatId,
            storyId: currentStoryId,
            posterName: chatTitle
        });
    }

    function togglePause() {
        paused = !paused;
        if (paused) {
            progressTimer.stop();
            if (currentContentLoader && currentContentLoader.item
                    && typeof currentContentLoader.item.pausePlayback === "function") {
                currentContentLoader.item.pausePlayback();
            }
        } else {
            if (currentContentLoader && currentContentLoader.item
                    && typeof currentContentLoader.item.resumePlayback === "function") {
                currentContentLoader.item.resumePlayback();
            }
            // progressTimer non resetta elapsedMs: riprende da dove era.
            progressTimer.start();
        }
    }

    function closeViewer() {
        // Forziamo l'unload del Loader content PRIMA di pop: il MediaPlayer
        // GStreamer su Sailfish crasha silenziosamente se la pipeline è ancora
        // in buffering quando l'Item viene distrutto. Settando sourceComponent
        // a null si invocano sincronamente i Component.onDestruction dei
        // photoComponent/videoComponent che fermano il media.
        closing = true;
        progressTimer.stop();
        storyLoadTimeout.stop();
        if (currentContentLoader) {
            currentContentLoader.sourceComponent = null;
        }
        pageStack.pop();
    }

    Component.onDestruction: {
        progressTimer.stop();
        if (currentContentLoader) {
            currentContentLoader.sourceComponent = null;
        }
        if (chatId && !usingFullStories) {
            tdLibWrapper.closeChat(chatId.toString());
        }
    }

    function loadStoryAt(idx) {
        if (idx < 0 || idx >= totalCount) return;
        currentIndex = idx;
        paused = false;
        progressTimer.stop();
        progressTimer.elapsedMs = 0;
        if (usingFullStories) {
            // Story già completa nel payload: niente getStory né viewStory.
            currentStory = fullStories[idx];
        } else {
            currentStory = null;
            tdLibWrapper.getStory(chatId.toString(), storyInfos[idx].story_id, false);
            tdLibWrapper.viewStory(chatId.toString(), storyInfos[idx].story_id);
            // Storia non raggiungibile (es. scaduta, aperta da un chip reply-storia):
            // se i metadati non arrivano entro il timeout, esci con un avviso.
            storyLoadTimeout.restart();
        }
    }

    Timer {
        id: storyLoadTimeout
        interval: 6000
        repeat: false
        onTriggered: {
            if (!currentStory && !closing) {
                appNotification.show(qsTr("Story not available"));
                closeViewer();
            }
        }
    }

    function advance() {
        if (closing) return;
        if (currentIndex + 1 < totalCount) {
            loadStoryAt(currentIndex + 1);
        } else {
            closeViewer();
        }
    }

    function rewind() {
        if (currentIndex > 0) {
            loadStoryAt(currentIndex - 1);
        }
    }

    function startProgress() {
        progressTimer.elapsedMs = 0;
        progressTimer.totalMs = currentContentLoader.contentDurationMs;
        progressTimer.start();
    }

    onCurrentStoryChanged: {
        if (currentStory) storyLoadTimeout.stop();
        // Quando la story cambia ma il sourceComponent del Loader resta lo stesso
        // (es. photo→photo in My Archive), QML non re-istanzia il delegate e i
        // binding derivati dal vecchio currentStory non ricomputerebbero, perché
        // li alimentiamo via armPlayback() per evitare la rottura del source
        // binding nell'Image/Video. Richiamiamo armPlayback() esplicitamente.
        if (currentContentLoader && currentContentLoader.item
                && typeof currentContentLoader.item.armPlayback === "function") {
            currentContentLoader.item.armPlayback();
        }
        // Riallinea lo stato cuore alla reaction già scelta su questa storia.
        myReactionEmoji = (currentStory && currentStory.chosen_reaction_type
                           && currentStory.chosen_reaction_type["@type"] === "reactionTypeEmoji")
                          ? (currentStory.chosen_reaction_type.emoji || "") : "";
    }

    Connections {
        target: storiesModel
        onStoryContentReady: {
            if (chatId === storiesViewerPage.chatId && storyId === storiesViewerPage.currentStoryId) {
                storiesViewerPage.currentStory = story;
            }
        }
    }

    // Errori server sulla reaction (es. emoji non valida): revert ottimistico + toast.
    Connections {
        target: tdLibWrapper
        onErrorReceived: {
            if (extra === "storyReaction") {
                storiesViewerPage.myReactionEmoji = storiesViewerPage.reactionPrev;
                appNotification.show(message !== "" ? message : qsTr("Could not set reaction."));
            }
        }
    }

    // Tutta la story area
    Item {
        id: stage
        anchors.fill: parent

        Loader {
            id: currentContentLoader
            anchors.fill: parent
            sourceComponent: !currentStory ? loadingComponent
                              : (resolveContentType(currentStory) === "photo" ? photoComponent
                                 : resolveContentType(currentStory) === "video" ? videoComponent
                                                                                : unsupportedComponent)
            property int contentDurationMs: storiesViewerPage.photoDurationMs

            function resolveContentType(story) {
                if (!story || !story.content) return "";
                var t = story.content["@type"];
                if (t === "storyContentPhoto") return "photo";
                if (t === "storyContentVideo") return "video";
                return "unsupported";
            }

            onLoaded: {
                if (item && typeof item.armPlayback === "function") {
                    item.armPlayback();
                }
            }
        }

        // Tap zones: sinistra (1/3) = prev, destra (2/3) = next
        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width / 3
            onClicked: rewind()
        }

        MouseArea {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * 2 / 3
            onClicked: advance()
        }
    }

    // Progress bar segmentata in alto
    Row {
        id: progressRow
        anchors.top: parent.top
        anchors.topMargin: Theme.paddingMedium
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.paddingMedium
        anchors.rightMargin: Theme.paddingMedium
        height: Theme.paddingSmall
        spacing: Theme.paddingSmall / 2

        Repeater {
            model: storiesViewerPage.totalCount
            delegate: Rectangle {
                width: progressRow.width / Math.max(storiesViewerPage.totalCount, 1)
                       - progressRow.spacing
                height: progressRow.height
                radius: height / 2
                color: Theme.rgba("white", 0.25)

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: height / 2
                    color: "white"
                    width: index < storiesViewerPage.currentIndex
                           ? parent.width
                           : (index === storiesViewerPage.currentIndex && progressTimer.totalMs > 0
                              ? parent.width * (progressTimer.elapsedMs / progressTimer.totalMs)
                              : 0)
                }
            }
        }
    }

    // Header con avatar + nome chat + close
    Row {
        id: headerRow
        anchors.top: progressRow.bottom
        anchors.topMargin: Theme.paddingMedium
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.horizontalPageMargin
        anchors.rightMargin: Theme.horizontalPageMargin
        spacing: Theme.paddingMedium

        IconButton {
            id: pauseButton
            anchors.verticalCenter: parent.verticalCenter
            icon.source: storiesViewerPage.paused
                         ? "image://theme/icon-m-play?white"
                         : "image://theme/icon-m-pause?white"
            onClicked: storiesViewerPage.togglePause()
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: chatTitle || qsTr("Story")
            color: "white"
            font.pixelSize: Theme.fontSizeMedium
            width: parent.width - pauseButton.width - headerRow.spacing
                   - closeButton.width - Theme.paddingMedium
                   - (deleteButton.visible ? deleteButton.width + headerRow.spacing : 0)
            truncationMode: TruncationMode.Fade
        }

        IconButton {
            id: deleteButton
            visible: storiesViewerPage.isOwnStory && storiesViewerPage.currentStoryId !== 0
            anchors.verticalCenter: parent.verticalCenter
            icon.source: "image://theme/icon-m-delete?white"
            onClicked: {
                var sid = storiesViewerPage.currentStoryId;
                storyRemorse.execute(qsTr("Deleting story"), function() {
                    tdLibWrapper.deleteStory(storiesViewerPage.chatId.toString(), sid);
                    // Aggiorna anche la lista My Archive (no-op per le storie Main).
                    storiesModel.removeMyArchiveRow(sid);
                    storiesViewerPage.closeViewer();
                });
            }
        }

        IconButton {
            id: closeButton
            anchors.verticalCenter: parent.verticalCenter
            icon.source: "image://theme/icon-m-close?white"
            onClicked: closeViewer()
        }
    }

    RemorsePopup { id: storyRemorse }

    // Pill viewer (👁 N + ❤ N) — solo sulle mie storie, apre la lista viewer.
    Rectangle {
        id: viewersPill
        visible: storiesViewerPage.canViewInteractions
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: Theme.paddingLarge
        anchors.leftMargin: Theme.paddingLarge
        height: Theme.itemSizeExtraSmall
        width: viewersPillRow.width + Theme.paddingLarge * 2
        radius: height / 2
        color: Theme.rgba("black", 0.5)

        Row {
            id: viewersPillRow
            anchors.centerIn: parent
            spacing: Theme.paddingSmall

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconSizeSmall
                height: Theme.iconSizeSmall
                sourceSize.width: Theme.iconSizeSmall
                sourceSize.height: Theme.iconSizeSmall
                source: "image://theme/icon-m-people?white"
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                color: "white"
                font.pixelSize: Theme.fontSizeSmall
                text: storiesViewerPage.interactionInfo
                      ? (storiesViewerPage.interactionInfo.view_count || 0) : 0
            }

            Image {
                anchors.verticalCenter: parent.verticalCenter
                visible: storiesViewerPage.interactionInfo
                         && (storiesViewerPage.interactionInfo.reaction_count || 0) > 0
                width: Theme.iconSizeSmall
                height: Theme.iconSizeSmall
                sourceSize.width: Theme.iconSizeSmall
                sourceSize.height: Theme.iconSizeSmall
                source: "image://theme/icon-s-favorite?white"
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: storiesViewerPage.interactionInfo
                         && (storiesViewerPage.interactionInfo.reaction_count || 0) > 0
                color: "white"
                font.pixelSize: Theme.fontSizeSmall
                text: storiesViewerPage.interactionInfo
                      ? (storiesViewerPage.interactionInfo.reaction_count || 0) : 0
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                // Mettiamo in pausa mentre l'utente guarda i viewer; al ritorno
                // riprendiamo (vedi onStatusChanged + autoPausedForOverlay).
                if (!storiesViewerPage.paused) {
                    storiesViewerPage.togglePause();
                    storiesViewerPage.autoPausedForOverlay = true;
                }
                pageStack.push(Qt.resolvedUrl("StoryViewersPage.qml"), {
                    storyId: storiesViewerPage.currentStoryId,
                    viewCount: storiesViewerPage.interactionInfo
                               ? (storiesViewerPage.interactionInfo.view_count || 0) : 0,
                    reactionCount: storiesViewerPage.interactionInfo
                                   ? (storiesViewerPage.interactionInfo.reaction_count || 0) : 0
                });
            }
        }
    }

    // Azioni sulle storie altrui: reply (dialog) + reaction cuore.
    Row {
        id: storyActions
        visible: !storiesViewerPage.isOwnStory && storiesViewerPage.currentStoryId !== 0
                 && currentStory
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: Theme.paddingLarge
        anchors.rightMargin: Theme.paddingLarge
        spacing: Theme.paddingMedium

        IconButton {
            id: replyButton
            anchors.verticalCenter: parent.verticalCenter
            visible: currentStory && currentStory.can_be_replied === true
            icon.source: "image://theme/icon-m-message-reply?white"
            onClicked: storiesViewerPage.openReply()
        }

        IconButton {
            id: reactionButton
            anchors.verticalCenter: parent.verticalCenter
            icon.source: storiesViewerPage.myReactionEmoji === storiesViewerPage.heartEmoji
                         ? "image://theme/icon-m-favorite-selected?#ff4060"
                         : "image://theme/icon-m-favorite?white"
            onClicked: storiesViewerPage.toggleHeart()
        }
    }

    // Caption story
    Item {
        id: captionItem
        anchors.bottom: viewersPill.visible ? viewersPill.top
                        : (storyActions.visible ? storyActions.top : parent.bottom)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.paddingLarge
        height: captionLabel.implicitHeight + Theme.paddingMedium * 2
        visible: captionLabel.text.length > 0

        Rectangle {
            anchors.fill: parent
            color: Theme.rgba("black", 0.5)
            radius: Theme.paddingSmall
        }

        Label {
            id: captionLabel
            anchors.fill: parent
            anchors.margins: Theme.paddingMedium
            color: "white"
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
            text: currentStory && currentStory.caption
                  ? currentStory.caption.text || ""
                  : ""
        }
    }

    // Timer di avanzamento (foto: 5s; video: durata; ticchetta ogni 50ms)
    Timer {
        id: progressTimer
        property int elapsedMs: 0
        property int totalMs: storiesViewerPage.photoDurationMs
        interval: 50
        repeat: true
        onTriggered: {
            elapsedMs += interval;
            if (totalMs > 0 && elapsedMs >= totalMs) {
                stop();
                advance();
            }
        }
    }

    // ---------------- Components per il content ----------------

    Component {
        id: loadingComponent
        Item {
            BusyIndicator {
                anchors.centerIn: parent
                size: BusyIndicatorSize.Large
                running: true
                _forceAnimation: true
            }
        }
    }

    Component {
        id: unsupportedComponent
        Item {
            Label {
                anchors.centerIn: parent
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: "white"
                text: qsTr("This story type is not supported yet")
            }
            Component.onCompleted: {
                // Skip dopo 2s
                unsupportedSkip.start();
            }
            Timer {
                id: unsupportedSkip
                interval: 2000
                repeat: false
                onTriggered: advance()
            }
        }
    }

    Component {
        id: photoComponent
        Item {
            id: photoItem
            // Non sono binding-derived (verrebbero ricalcolati al primo set di
            // currentStory ma non rispondono ai cambi successivi quando il
            // sourceComponent del Loader resta lo stesso). Li ricalcoliamo
            // dentro armPlayback() su ogni story change.
            property int photoFileId: 0
            property string resolvedPath: ""

            Component.onDestruction: {
                resolvedPath = "";
            }

            function armPlayback() {
                var photo = currentStory && currentStory.content
                              ? currentStory.content.photo : null;
                var sizes = photo ? photo.sizes : null;
                var selected = sizes && sizes.length > 0 ? sizes[sizes.length - 1] : null;
                var pfile = selected ? selected.photo : null;
                photoFileId = pfile ? pfile.id : 0;
                if (pfile && pfile.local && pfile.local.is_downloading_completed) {
                    resolvedPath = pfile.local.path;
                } else {
                    resolvedPath = "";
                    if (photoFileId > 0) {
                        tdLibWrapper.downloadFile(photoFileId);
                    }
                }
            }

            Image {
                id: photoImage
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                source: photoItem.resolvedPath !== ""
                          ? ("file://" + photoItem.resolvedPath) : ""
                onStatusChanged: {
                    if (status === Image.Ready) {
                        storiesViewerPage.startProgress();
                    }
                }
            }

            BusyIndicator {
                anchors.centerIn: parent
                size: BusyIndicatorSize.Medium
                running: photoItem.resolvedPath === ""
                visible: running
            }

            Connections {
                target: tdLibWrapper
                onFileUpdated: {
                    if (fileId === photoItem.photoFileId
                            && fileInformation.local.is_downloading_completed) {
                        photoItem.resolvedPath = fileInformation.local.path;
                    }
                }
            }
        }
    }

    Component {
        id: videoComponent
        Item {
            id: videoItem
            // Stesso pattern di photoComponent: ricalcolo via armPlayback().
            property int videoFileId: 0
            property int videoDurationS: 0
            property string resolvedPath: ""

            // Fermare GStreamer prima della distruzione: se il MediaPlayer resta
            // in pipeline mentre l'Item è distrutto, il processo segfaulta
            // silenziosamente (notorio su Sailfish — memoria gif-loop-unsupported).
            Component.onDestruction: {
                if (videoPlayer) {
                    videoPlayer.stop();
                    videoPlayer.source = "";
                }
            }

            function pausePlayback() {
                if (videoPlayer) videoPlayer.pause();
            }

            function resumePlayback() {
                if (videoPlayer) videoPlayer.play();
            }

            function armPlayback() {
                var videoContent = currentStory && currentStory.content
                                     ? currentStory.content.video : null;
                var vfile = videoContent ? videoContent.video : null;
                videoFileId = vfile ? vfile.id : 0;
                videoDurationS = videoContent ? (videoContent.duration || 0) : 0;
                if (vfile && vfile.local && vfile.local.is_downloading_completed) {
                    resolvedPath = vfile.local.path;
                    videoPlayer.source = "file://" + resolvedPath;
                } else {
                    resolvedPath = "";
                    videoPlayer.source = "";
                    if (videoFileId > 0) {
                        tdLibWrapper.downloadFile(videoFileId);
                    }
                }
            }

            Video {
                id: videoPlayer
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectFit
                autoLoad: true
                muted: false
                onStatusChanged: {
                    if ((status === MediaPlayer.Buffered || status === MediaPlayer.Loaded)
                            && playbackState !== MediaPlayer.PlayingState
                            && !storiesViewerPage.paused) {
                        currentContentLoader.contentDurationMs = duration > 0
                                ? duration
                                : (videoItem.videoDurationS > 0
                                    ? videoItem.videoDurationS * 1000
                                    : storiesViewerPage.photoDurationMs);
                        play();
                        storiesViewerPage.startProgress();
                    } else if (status === MediaPlayer.EndOfMedia) {
                        advance();
                    }
                }
            }

            BusyIndicator {
                anchors.centerIn: parent
                size: BusyIndicatorSize.Medium
                running: videoItem.resolvedPath === ""
                visible: running
            }

            Connections {
                target: tdLibWrapper
                onFileUpdated: {
                    if (fileId === videoItem.videoFileId
                            && fileInformation.local.is_downloading_completed) {
                        videoItem.resolvedPath = fileInformation.local.path;
                        videoPlayer.source = "file://" + fileInformation.local.path;
                    }
                }
            }
        }
    }
}
