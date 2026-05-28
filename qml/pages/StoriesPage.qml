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
import "../components"

Page {
    id: storiesPage
    allowedOrientations: Orientation.All

    Component.onCompleted: {
        storiesModel.activeList = "main";
        storiesModel.refresh();
    }

    function headerTitle() {
        switch (storiesModel.activeList) {
        case "archive":   return qsTr("Blacklist");
        case "myArchive": return qsTr("My Archive");
        case "myProfile": return qsTr("My Profile");
        default:          return qsTr("Stories");
        }
    }

    function emptyText() {
        switch (storiesModel.activeList) {
        case "archive":   return qsTr("Blacklist is empty");
        case "myArchive": return qsTr("You have no archived stories");
        case "myProfile": return qsTr("You have no stories on your profile");
        default:          return qsTr("No stories from your contacts");
        }
    }

    function formatStoryDate(epoch) {
        if (!epoch) return "";
        var d = new Date(epoch * 1000);
        return d.toLocaleString(Qt.locale(), Locale.ShortFormat);
    }

    // Pubblica una nuova storia (foto o video): la compose page gestisce da sé
    // l'intero flusso (pick, eventuale conversione 9:16 con avanzamento, upload).
    function postNewStory() {
        pageStack.push(Qt.resolvedUrl("StoryComposeDialog.qml"));
    }

    SilicaListView {
        id: storiesList
        anchors.fill: parent
        model: storiesModel
        clip: true

        header: Column {
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: headerTitle()
            }

            Row {
                id: tabsRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.horizontalPageMargin
                anchors.rightMargin: Theme.horizontalPageMargin
                spacing: Theme.paddingSmall
                bottomPadding: Theme.paddingMedium

                property real tabWidth: (width - 3 * spacing) / 4

                Button {
                    width: tabsRow.tabWidth
                    text: qsTr("Main")
                    opacity: storiesModel.activeList === "main" ? 1.0 : 0.4
                    onClicked: storiesModel.activeList = "main"
                }

                Button {
                    width: tabsRow.tabWidth
                    text: qsTr("Blacklist")
                    opacity: storiesModel.activeList === "archive" ? 1.0 : 0.4
                    onClicked: storiesModel.activeList = "archive"
                }

                // Label corte sui tab (Archive/Profile); il titolo lungo
                // ("My Archive"/"My Profile") sta nel PageHeader.
                Button {
                    width: tabsRow.tabWidth
                    text: qsTr("Archive", "Short label for the My Archive tab")
                    opacity: storiesModel.activeList === "myArchive" ? 1.0 : 0.4
                    onClicked: storiesModel.activeList = "myArchive"
                }

                Button {
                    width: tabsRow.tabWidth
                    text: qsTr("Profile", "Short label for the My Profile tab")
                    opacity: storiesModel.activeList === "myProfile" ? 1.0 : 0.4
                    onClicked: storiesModel.activeList = "myProfile"
                }
            }
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: storiesModel.refresh()
            }
            MenuItem {
                text: qsTr("New story")
                onClicked: storiesPage.postNewStory()
            }
        }

        delegate: ListItem {
            id: storyChatItem
            width: storiesList.width
            contentHeight: Theme.itemSizeLarge

            // Collassa la riga quando viene rimossa dal modello (delete remorse),
            // altrimenti la ListView lascia uno spazio vuoto al suo posto.
            ListView.onRemove: animateRemoval(storyChatItem)

            property bool isMyArchive: storiesModel.activeList === "myArchive"
            property bool isMyProfile: storiesModel.activeList === "myProfile"
            // Vista "personale" (storia singola per riga): My Archive + My Profile
            // condividono delegate layout, click behavior e menu (solo Delete).
            property bool isOwnStoryList: isMyArchive || isMyProfile
            // Valori catturati nel contesto del delegate, dove `model` è sicuramente
            // valido (dentro la Component del menu potrebbe non esserlo).
            property int archiveStoryId: model.story_id ? model.story_id : 0
            property string archivePosterChatId: {
                var c = model.chat_id ? model.chat_id : 0;
                if (!c) c = tdLibWrapper.getUserInformation().id;
                return "" + c;
            }
            property var rowChatId: model.chat_id ? model.chat_id : 0

            menu: storyChatItem.isOwnStoryList ? ownStoryMenu : chatMenu

            Component {
                id: ownStoryMenu
                ContextMenu {
                    MenuItem {
                        text: qsTr("Delete story")
                        onClicked: {
                            var sid = storyChatItem.archiveStoryId;
                            var pcid = storyChatItem.archivePosterChatId;
                            // Cancellazione immediata: il remorse differito veniva
                            // annullato dai re-fetch che resettano il modello.
                            tdLibWrapper.deleteStory(pcid, sid);
                            if (storyChatItem.isMyProfile) {
                                storiesModel.removeMyProfileRow(sid);
                            } else {
                                storiesModel.removeMyArchiveRow(sid);
                            }
                        }
                    }
                }
            }

            // Sposta le storie del contatto tra Main e Blacklist.
            Component {
                id: chatMenu
                ContextMenu {
                    MenuItem {
                        text: storiesModel.activeList === "archive"
                              ? qsTr("Remove from blacklist")
                              : qsTr("Add to blacklist")
                        onClicked: {
                            var cid = "" + storyChatItem.rowChatId;
                            var target = storiesModel.activeList === "archive" ? "main" : "archive";
                            tdLibWrapper.setChatActiveStoriesList(cid, target);
                            // Rimozione ottimistica dalla tab corrente.
                            storiesModel.removeChatRow(storyChatItem.rowChatId);
                            appNotification.show(target === "archive"
                                                 ? qsTr("Added to blacklist")
                                                 : qsTr("Removed from blacklist"));
                        }
                    }
                }
            }

            onClicked: {
                if (isOwnStoryList) {
                    pageStack.push(Qt.resolvedUrl("StoriesViewerPage.qml"), {
                        chatId: model.chat_id,
                        chatTitle: isMyProfile ? qsTr("My Profile") : qsTr("My Archive"),
                        fullStories: isMyProfile
                                     ? storiesModel.myProfileStories()
                                     : storiesModel.myArchiveStories(),
                        currentIndex: model.index
                    });
                } else {
                    pageStack.push(Qt.resolvedUrl("StoriesViewerPage.qml"), {
                        chatId: model.chat_id,
                        chatTitle: model.chat_title,
                        maxReadStoryId: model.max_read_story_id,
                        storyInfos: model.stories
                    });
                }
            }

            // ---------- Riga "chat" (Main / Blacklist) ----------
            Row {
                visible: !storyChatItem.isOwnStoryList
                anchors.fill: parent
                anchors.leftMargin: Theme.horizontalPageMargin
                anchors.rightMargin: Theme.horizontalPageMargin
                spacing: Theme.paddingMedium

                ProfileThumbnail {
                    id: avatarWrap
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.itemSizeMedium
                    height: Theme.itemSizeMedium
                    photoData: model.chat_photo_small || ({})
                    replacementStringHint: model.chat_title || "?"
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - avatarWrap.width - Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: model.chat_title || qsTr("Unknown chat")
                        truncationMode: TruncationMode.Fade
                        color: storyChatItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                    }

                    Label {
                        width: parent.width
                        font.pixelSize: Theme.fontSizeSmall
                        color: model.has_unread ? Theme.highlightColor : Theme.secondaryColor
                        text: model.has_unread
                              ? qsTr("%n new story(es)", "", model.story_count || 0)
                              : qsTr("%n story(es)", "", model.story_count || 0)
                    }
                }
            }

            // ---------- Riga "story" (My Archive / My Profile) ----------
            Row {
                visible: storyChatItem.isOwnStoryList
                anchors.fill: parent
                anchors.leftMargin: Theme.horizontalPageMargin
                anchors.rightMargin: Theme.horizontalPageMargin
                spacing: Theme.paddingMedium

                Rectangle {
                    id: thumbBox
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.itemSizeMedium
                    height: Theme.itemSizeMedium
                    color: Theme.rgba(Theme.primaryColor, 0.1)
                    radius: Theme.paddingSmall
                    clip: true

                    property var storyContent: model.story_content
                    property bool isVideo: storyContent
                                           && storyContent["@type"] === "storyContentVideo"
                    property bool isPhoto: storyContent
                                           && storyContent["@type"] === "storyContentPhoto"

                    // Anteprima reale: scarica il file di thumbnail e usa la
                    // minithumbnail come placeholder (gestito da TDLibPhoto/Thumbnail).
                    Loader {
                        id: thumbLoader
                        anchors.fill: parent
                        sourceComponent: thumbBox.isPhoto ? photoThumbComp
                                         : (thumbBox.isVideo ? videoThumbComp : null)
                    }

                    Component {
                        id: photoThumbComp
                        TDLibPhoto {
                            photo: thumbBox.storyContent.photo
                            highlighted: storyChatItem.highlighted
                            Component.onCompleted: image.fillMode = Image.PreserveAspectCrop
                        }
                    }

                    Component {
                        id: videoThumbComp
                        TDLibThumbnail {
                            thumbnail: thumbBox.storyContent.video.thumbnail
                            minithumbnail: thumbBox.storyContent.video.minithumbnail
                            fillMode: Image.PreserveAspectCrop
                            highlighted: storyChatItem.highlighted
                        }
                    }

                    // Fallback se il tipo è sconosciuto / niente contenuto.
                    Label {
                        anchors.centerIn: parent
                        visible: !thumbBox.isPhoto && !thumbBox.isVideo
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.highlightColor
                        text: "?"
                    }

                    // Indicatore ▶ sopra l'anteprima dei video.
                    Rectangle {
                        anchors.centerIn: parent
                        visible: thumbBox.isVideo
                        width: Theme.iconSizeSmall
                        height: width
                        radius: width / 2
                        color: Theme.rgba("black", 0.5)
                        Label {
                            anchors.centerIn: parent
                            color: "white"
                            font.pixelSize: Theme.fontSizeExtraSmall
                            text: "▶"
                        }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - thumbBox.width - Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: formatStoryDate(model.story_date)
                        color: storyChatItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                    }

                    Label {
                        width: parent.width
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.secondaryColor
                        truncationMode: TruncationMode.Fade
                        text: model.story_caption && model.story_caption.length > 0
                              ? model.story_caption
                              : qsTr("(no caption)")
                    }
                }
            }
        }

        ViewPlaceholder {
            enabled: storiesList.count === 0
            text: emptyText()
            hintText: qsTr("Pull down to refresh")
        }

        VerticalScrollDecorator {}
    }
}
