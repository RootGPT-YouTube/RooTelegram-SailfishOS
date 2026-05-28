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
import "../js/functions.js" as Functions
import "../js/twemoji.js" as Emoji

Page {
    id: viewersPage
    allowedOrientations: Orientation.All

    // storyId della storia di cui mostrare le interazioni (mie storie).
    property int storyId: 0
    // Aggregati passati dal viewer (da story.interaction_info), per l'header.
    property int viewCount: 0
    property int reactionCount: 0

    property string nextOffset: ""
    property bool loading: false
    property bool firstLoadDone: false

    function requestMore() {
        if (loading) return;
        if (firstLoadDone && nextOffset === "") return;
        loading = true;
        tdLibWrapper.getStoryInteractions(storyId, nextOffset, 50);
    }

    function actorUserId(it) {
        var a = it ? it.actor_id : null;
        return (a && a["@type"] === "messageSenderUser") ? a.user_id : 0;
    }

    function reactionEmojiOf(it) {
        var t = it ? it.type : null;
        if (t && t["@type"] === "storyInteractionTypeView" && t.chosen_reaction_type
                && t.chosen_reaction_type["@type"] === "reactionTypeEmoji") {
            return t.chosen_reaction_type.emoji || "";
        }
        return "";
    }

    function kindOf(it) {
        var t = it ? it.type : null;
        if (t && t["@type"] === "storyInteractionTypeForward") return "forward";
        if (t && t["@type"] === "storyInteractionTypeRepost") return "repost";
        return "view";
    }

    function formatDate(epoch) {
        if (!epoch) return "";
        return new Date(epoch * 1000).toLocaleString(Qt.locale(), Locale.ShortFormat);
    }

    Component.onCompleted: requestMore()

    Connections {
        target: tdLibWrapper
        onStoryInteractionsReceived: {
            if (storyId !== viewersPage.storyId) return;
            for (var i = 0; i < interactions.length; i++) {
                var it = interactions[i];
                viewersModel.append({
                    userId: viewersPage.actorUserId(it),
                    interactionDate: it.interaction_date || 0,
                    reactionEmoji: viewersPage.reactionEmojiOf(it),
                    kind: viewersPage.kindOf(it)
                });
            }
            viewersPage.nextOffset = nextOffset;
            viewersPage.loading = false;
            viewersPage.firstLoadDone = true;
        }
    }

    ListModel { id: viewersModel }

    SilicaListView {
        id: viewersList
        anchors.fill: parent
        model: viewersModel
        clip: true

        header: PageHeader {
            title: qsTr("Viewers")
            description: {
                var parts = [];
                parts.push(qsTr("%n view(s)", "", viewersPage.viewCount));
                if (viewersPage.reactionCount > 0)
                    parts.push(qsTr("%n reaction(s)", "", viewersPage.reactionCount));
                return parts.join(" · ");
            }
        }

        delegate: ListItem {
            id: viewerItem
            width: viewersList.width
            contentHeight: Theme.itemSizeMedium

            property var userInfo: model.userId > 0
                                   ? tdLibWrapper.getUserInformation("" + model.userId)
                                   : ({})
            property string displayName: {
                var n = Functions.getUserName(userInfo || {});
                return n.length > 0 ? n : qsTr("Telegram user");
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.horizontalPageMargin
                anchors.rightMargin: Theme.horizontalPageMargin
                spacing: Theme.paddingMedium

                ProfileThumbnail {
                    id: viewerAvatar
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.itemSizeSmall
                    height: Theme.itemSizeSmall
                    photoData: (viewerItem.userInfo && viewerItem.userInfo.profile_photo)
                               ? viewerItem.userInfo.profile_photo.small : ({})
                    replacementStringHint: viewerItem.displayName
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - viewerAvatar.width - reactionLabel.width
                           - 2 * parent.spacing
                    spacing: Theme.paddingSmall / 2

                    Label {
                        width: parent.width
                        textFormat: Text.StyledText
                        truncationMode: TruncationMode.Fade
                        color: viewerItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                        text: Emoji.emojify(viewerItem.displayName, font.pixelSize)
                    }

                    Label {
                        width: parent.width
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                        truncationMode: TruncationMode.Fade
                        text: {
                            var d = viewersPage.formatDate(model.interactionDate);
                            if (model.kind === "forward") return qsTr("Forwarded") + (d ? " · " + d : "");
                            if (model.kind === "repost") return qsTr("Reposted") + (d ? " · " + d : "");
                            return d;
                        }
                    }
                }

                Label {
                    id: reactionLabel
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.StyledText
                    width: model.reactionEmoji.length > 0 ? Theme.iconSizeMedium : 0
                    visible: model.reactionEmoji.length > 0
                    horizontalAlignment: Text.AlignRight
                    text: model.reactionEmoji.length > 0
                          ? Emoji.emojify(model.reactionEmoji, Theme.fontSizeLarge) : ""
                }
            }
        }

        onAtYEndChanged: {
            if (atYEnd && firstLoadDone && nextOffset !== "")
                requestMore();
        }

        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: viewersPage.loading && viewersModel.count === 0
            visible: running
        }

        ViewPlaceholder {
            enabled: !viewersPage.loading && viewersModel.count === 0 && viewersPage.firstLoadDone
            text: qsTr("No viewers yet")
        }

        VerticalScrollDecorator {}
    }
}
