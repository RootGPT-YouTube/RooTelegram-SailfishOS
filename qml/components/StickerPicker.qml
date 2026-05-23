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
import "../components"
import "../js/twemoji.js" as Emoji

Item {
    id: stickerPickerOverlayItem
    anchors.fill: parent

    property var recentStickers: stickerManager.getRecentStickers();
    property var installedStickerSets: stickerManager.getInstalledStickerSets();
    property var installedCustomEmojiSets: stickerManager.getInstalledCustomEmojiSets();
    property var customEmojiStickers: [];
    property int customEmojiPreviewLimit: 120;
    function stickerRemoteIdFromSticker(sticker) {
        if (!sticker || !sticker.sticker || !sticker.sticker.remote || !sticker.sticker.remote.id) {
            return "";
        }
        return sticker.sticker.remote.id.toString();
    }
    function customEmojiIdFromSticker(sticker) {
        if (!sticker) {
            return "";
        }
        if (sticker.custom_emoji_id) {
            return sticker.custom_emoji_id.toString();
        }
        if (sticker.full_type
                && sticker.full_type["@type"] === "stickerFullTypeCustomEmoji"
                && sticker.full_type.custom_emoji_id) {
            return sticker.full_type.custom_emoji_id.toString();
        }
        if (sticker.type
                && sticker.type["@type"] === "stickerTypeCustomEmoji"
                && sticker.type.custom_emoji_id) {
            return sticker.type.custom_emoji_id.toString();
        }
        return "";
    }

    function refreshCustomEmojiStickers() {
        var result = [];
        var seenEmojiIds = ({});
        var previewLimit = customEmojiPreviewLimit > 0 ? customEmojiPreviewLimit : 120;
        var sets = installedCustomEmojiSets || [];
        for (var i = 0; i < sets.length; i++) {
            var currentSet = sets[i];
            if (!currentSet || !currentSet.stickers) {
                continue;
            }
            var stickers = currentSet.stickers;
            for (var j = 0; j < stickers.length; j++) {
                var sticker = stickers[j];
                if (!sticker) {
                    continue;
                }
                var customEmojiId = customEmojiIdFromSticker(sticker);
                if (customEmojiId === "" || seenEmojiIds[customEmojiId]) {
                    continue;
                }
                seenEmojiIds[customEmojiId] = true;
                sticker.custom_emoji_id = customEmojiId;
                result.push(sticker);
                if (result.length >= previewLimit) {
                    break;
                }
            }
            if (result.length >= previewLimit) {
                break;
            }
        }
        customEmojiStickers = result;
    }

    onInstalledCustomEmojiSetsChanged: {
        refreshCustomEmojiStickers();
    }
    Component.onCompleted: {
        refreshCustomEmojiStickers();
        // Init bilanciato: fetcha entrambi i tipi se le rispettive cache
        // sono vuote, così il picker mostra subito sticker e custom emoji
        // anche se l'app non li aveva ancora caricati.
        if (!installedStickerSets || installedStickerSets.length === 0) {
            tdLibWrapper.getInstalledStickerSets();
        }
        if (!installedCustomEmojiSets || installedCustomEmojiSets.length === 0) {
            tdLibWrapper.getInstalledCustomEmojiSets();
        }
    }

    // Debounce delle ricostruzioni del model: durante il dismiss del Remorse
    // l'aggiornamento immediato della ListView causava un crash sul delegate
    // appena rimosso. Coalesciamo gli update entro ~80ms.
    Timer {
        id: refreshStickerSetsTimer
        interval: 80
        repeat: false
        onTriggered: {
            installedStickerSets = stickerManager.getInstalledStickerSets();
        }
    }
    Timer {
        id: refreshCustomEmojiSetsTimer
        interval: 80
        repeat: false
        onTriggered: {
            installedCustomEmojiSets = stickerManager.getInstalledCustomEmojiSets();
            refreshCustomEmojiStickers();
        }
    }

    Connections {
        target: tdLibWrapper
        onOkReceived: {
            if (!request) return;
            // Formato extra: "<action>:<Type>:<setId>" (Regular|CustomEmoji)
            var parts = request.split(":");
            if (parts[0] !== "removeStickerSet" && parts[0] !== "installStickerSet") {
                return;
            }
            var typeToken = parts.length >= 2 ? parts[1] : "Regular";
            if (parts[0] === "removeStickerSet") {
                appNotification.show(qsTr("Sticker set successfully removed!"));
            }
            if (typeToken === "CustomEmoji") {
                tdLibWrapper.getInstalledCustomEmojiSets();
            } else {
                tdLibWrapper.getInstalledStickerSets();
            }
        }
    }

    Connections {
        target: stickerManager
        onStickerSetsReceived: {
            refreshStickerSetsTimer.restart();
        }
        onCustomEmojiStickerSetsReceived: {
            refreshCustomEmojiSetsTimer.restart();
        }
    }
    Component {
        id: stickerComponent
        BackgroundItem {
           id: stickerSetItem
           width: Theme.itemSizeExtraLarge
           height: Theme.itemSizeExtraLarge
           onClicked: {
               var stickerId = stickerRemoteIdFromSticker(modelData);
               if (stickerId !== "") {
                   stickerPickerOverlayItem.stickerPicked(stickerId);
               }
           }

           TDLibThumbnail {
               thumbnail: modelData.thumbnail
               anchors.fill: parent
               highlighted: stickerSetItem.highlighted
           }

           Label {
               font.pixelSize: Theme.fontSizeSmall
               anchors.right: parent.right
               anchors.bottom: parent.bottom
               text: Emoji.emojify(modelData.emoji, font.pixelSize)
           }

       }
    }
    Component {
        id: customEmojiComponent
        BackgroundItem {
            id: customEmojiItem
            width: Theme.itemSizeExtraLarge
            height: Theme.itemSizeExtraLarge

            onClicked: {
                var customEmojiId = customEmojiIdFromSticker(modelData);
                if (customEmojiId !== "") {
                    stickerPickerOverlayItem.customEmojiPicked(customEmojiId, modelData.emoji);
                }
            }

            TDLibThumbnail {
                thumbnail: modelData.thumbnail
                anchors.fill: parent
                highlighted: customEmojiItem.highlighted
            }

            Label {
                font.pixelSize: Theme.fontSizeSmall
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                text: Emoji.emojify(modelData.emoji ? modelData.emoji : "⬜", font.pixelSize)
            }
        }
    }

    signal stickerPicked(var stickerId)
    signal customEmojiPicked(var customEmojiId, var fallbackEmoji)

    Rectangle {
        id: stickerPickerOverlayBackground
        anchors.fill: parent

        color: Theme.overlayBackgroundColor
        opacity: 0.7
    }

    property int selectedSetIndex: -1
    function currentStickers() {
        if (selectedSetIndex < 0) return stickerPickerOverlayItem.recentStickers || [];
        var sets = stickerPickerOverlayItem.installedStickerSets || [];
        if (selectedSetIndex >= sets.length) return [];
        var s = sets[selectedSetIndex];
        return (s && s.stickers) ? s.stickers : [];
    }

    Column {
        id: stickerPickerLayout
        anchors.fill: parent
        anchors.topMargin: Theme.paddingSmall
        spacing: Theme.paddingSmall

        Flickable {
            id: stickerSetChipStrip
            width: parent.width
            height: Theme.itemSizeSmall
            contentWidth: Math.max(width, stickerSetChipRow.width)
            contentHeight: stickerSetChipRow.height
            clip: true

            Row {
                id: stickerSetChipRow
                height: Theme.itemSizeSmall
                x: width <= parent.width ? ((parent.width - width) / 2) : 0
                spacing: Theme.paddingSmall
                leftPadding: Theme.paddingSmall
                rightPadding: Theme.paddingSmall

                BackgroundItem {
                    id: recentsChip
                    width: Math.max(recentsChipLabel.implicitWidth + Theme.paddingMedium * 2, Theme.itemSizeMedium)
                    height: Theme.itemSizeSmall
                    readonly property bool isCurrent: stickerPickerOverlayItem.selectedSetIndex === -1
                    onClicked: stickerPickerOverlayItem.selectedSetIndex = -1
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: recentsChip.isCurrent ? Theme.rgba(Theme.highlightColor, 0.28) : Theme.rgba(Theme.primaryColor, 0.12)
                    }
                    Label {
                        id: recentsChipLabel
                        anchors.centerIn: parent
                        text: qsTr("Recent")
                        color: recentsChip.isCurrent ? Theme.highlightColor : Theme.primaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }

                Repeater {
                    model: stickerPickerOverlayItem.installedStickerSets
                    BackgroundItem {
                        id: setChip
                        width: Math.min(Math.max(setChipLabel.implicitWidth + Theme.paddingMedium * 2, Theme.itemSizeMedium), Theme.itemSizeExtraLarge * 2)
                        height: Theme.itemSizeSmall
                        readonly property bool isCurrent: index === stickerPickerOverlayItem.selectedSetIndex
                        onClicked: stickerPickerOverlayItem.selectedSetIndex = index
                        onPressAndHold: {
                            var stickerType = (modelData.sticker_type && modelData.sticker_type["@type"])
                                              ? modelData.sticker_type["@type"] : "stickerTypeRegular";
                            chatPage.requestDeleteSet(modelData.id, stickerType, modelData.title);
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: setChip.isCurrent ? Theme.rgba(Theme.highlightColor, 0.28) : Theme.rgba(Theme.primaryColor, 0.12)
                        }
                        Label {
                            id: setChipLabel
                            anchors.centerIn: parent
                            width: parent.width - Theme.paddingSmall
                            text: modelData && modelData.title ? modelData.title : qsTr("Sticker set")
                            color: setChip.isCurrent ? Theme.highlightColor : Theme.primaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                            maximumLineCount: 1
                            truncationMode: TruncationMode.Elide
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }

        SilicaGridView {
            id: stickerPickerGrid
            width: parent.width
            height: parent.height - stickerSetChipStrip.height - Theme.paddingSmall
            cellWidth: Theme.itemSizeExtraLarge
            cellHeight: Theme.itemSizeExtraLarge
            clip: true
            cacheBuffer: Math.round(Theme.itemSizeExtraLarge * 4)
            model: stickerPickerOverlayItem.currentStickers()
            delegate: stickerComponent

            VerticalScrollDecorator {}

            Label {
                anchors.centerIn: parent
                visible: stickerPickerGrid.count === 0
                text: stickerPickerOverlayItem.selectedSetIndex === -1
                      ? qsTr("No recent stickers")
                      : qsTr("No stickers in this set")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
            }
        }
    }

}
