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

    SilicaListView {
        id: stickerPickerListView
        anchors.fill: parent
        clip: true

        model: stickerPickerOverlayItem.installedStickerSets

        header: Column {
            spacing: Theme.paddingSmall
            width: stickerPickerListView.width
            height: recentStickersLabel.visible ? implicitHeight : 0
            topPadding: Theme.paddingSmall
            Label {
                id: recentStickersLabel
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
                width: recentStickersGridView.width
                leftPadding: Theme.paddingMedium
                visible: recentStickersGridView.count > 0
                maximumLineCount: 1
                truncationMode: TruncationMode.Elide
                text: qsTr("Recently used")
            }
            SilicaGridView {
                id: recentStickersGridView
                width: stickerPickerListView.width
                height: Theme.itemSizeExtraLarge + Theme.paddingSmall
                cellWidth: Theme.itemSizeExtraLarge;
                cellHeight: Theme.itemSizeExtraLarge;
                visible: count > 0
                clip: true
                flow: GridView.FlowTopToBottom

                model: stickerPickerOverlayItem.recentStickers
                delegate: stickerComponent

                HorizontalScrollDecorator {}

            }
        }
        delegate: Column {
            id: stickerSetColumn

            property bool isExpanded: false
            function toggleDisplaySet() {
                stickerSetColumn.isExpanded = !stickerSetColumn.isExpanded;
                if (stickerSetColumn.isExpanded) {
                    stickerSetLoader.myStickerSet = modelData.stickers;
                }
            }

            spacing: Theme.paddingSmall
            width: parent.width

            Row {
                id: stickerSetTitleRow
                width: parent.width
                height: Theme.itemSizeMedium + ( 2 * Theme.paddingSmall )
                spacing: Theme.paddingMedium
                BackgroundItem {
                    id: stickerSetToggle
                    width: parent.width - removeSetButton.width - Theme.paddingMedium * 2
                    height: parent.height

                    onClicked: {
                        toggleDisplaySet();
                    }
                    TDLibThumbnail {
                        id: stickerSetThumbnail
                        thumbnail: modelData.thumbnail ? modelData.thumbnail : modelData.stickers[0].thumbnail
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: Theme.paddingMedium
                        }
                        width: Theme.itemSizeMedium
                        height: Theme.itemSizeMedium
                        highlighted: stickerSetToggle.down
                    }

                    Label {
                        id: setTitleText
                        font.pixelSize: Theme.fontSizeLarge
                        font.bold: true

                        anchors {
                            left: stickerSetThumbnail.right
                            right: expandSetButton.left
                            verticalCenter: parent.verticalCenter
                            margins: Theme.paddingSmall
                        }
                        truncationMode: TruncationMode.Fade
                        text: modelData.title
                    }

                    Icon {
                        id: expandSetButton
                        source: stickerSetColumn.isExpanded ? "image://theme/icon-m-up" : "image://theme/icon-m-down"
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            rightMargin: Theme.paddingMedium
                        }
                    }


                }


                IconButton {
                    id: removeSetButton
                    icon.source: "image://theme/icon-m-remove"
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: {
                        // Cattura ID e tipo PRIMA del Remorse: dopo il commit
                        // il delegate potrebbe già essere stato distrutto.
                        var stickerSetId = modelData.id;
                        var stickerType = (modelData.sticker_type && modelData.sticker_type["@type"])
                                          ? modelData.sticker_type["@type"] : "stickerTypeRegular";
                        Remorse.popupAction(chatPage, qsTr("Removing sticker set"), function() {
                            tdLibWrapper.changeStickerSet(stickerSetId, false, stickerType);
                        });
                    }
                }

            }

            Loader {
                id: stickerSetLoader
                width: parent.width
                active: stickerSetColumn.isExpanded || height > 0
                height: stickerSetColumn.isExpanded ? Theme.itemSizeExtraLarge + Theme.paddingSmall : 0
                opacity: stickerSetColumn.isExpanded ? 1.0 : 0.0

                Behavior on height {
                    NumberAnimation { duration: 200 }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }

                property var myStickerSet
                onActiveChanged: {
                    if(!active) {
                        myStickerSet = ({});
                    }
                }

                sourceComponent: Component {
                    SilicaListView {
                        id: installedStickerSetGridView
                        width: stickerSetLoader.width
                        height: stickerSetLoader.height

                        orientation: Qt.Horizontal
                        visible: count > 0

                        model: stickerSetLoader.myStickerSet
                        delegate: stickerComponent

                        HorizontalScrollDecorator {}
                    }
                }
            }
        }
    }
}
