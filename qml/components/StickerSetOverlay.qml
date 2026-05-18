/*
    Copyright (C) 2020-21 Sebastian J. Wolf and other contributors

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
import "./messageContent"
import "../js/functions.js" as Functions
import "../js/twemoji.js" as Emoji
import "../js/debug.js" as Debug

Flickable {
    id: stickerSetOverlayFlickable
    anchors.fill: parent
    boundsBehavior: Flickable.StopAtBounds
    contentHeight: stickerSetContentColumn.height
    clip: true

    property string stickerSetId;
    property var stickerSet;
    signal requestClose;

    Component.onCompleted: {
        if (!stickerManager.hasStickerSet(stickerSetId)) {
            tdLibWrapper.getStickerSet(stickerSetId);
        } else {
            stickerSet = stickerManager.getStickerSet(stickerSetId);
        }
    }

    Connections {
        target: tdLibWrapper
        onStickerSetReceived: {
            if (stickerSet.id === stickerSetOverlayFlickable.stickerSetId) {
                stickerSetOverlayFlickable.stickerSet = stickerSet;
            }
        }
        onOkReceived: {
            if (!request) return;
            // Nuovo formato extra: "<action>:<Type>:<setId>" (Regular|CustomEmoji)
            // Legacy: "<action>" senza type. Manteniamo retrocompatibilità.
            var parts = request.split(":");
            var action = parts[0];
            var typeToken = parts.length >= 2 ? parts[1] : "Regular";
            if (action === "installStickerSet") {
                appNotification.show(qsTr("Sticker set successfully installed!"));
                installSetButton.visible = false;
            } else if (action === "removeStickerSet") {
                appNotification.show(qsTr("Sticker set successfully removed!"));
                installSetButton.visible = true;
            } else {
                return;
            }
            if (typeToken === "CustomEmoji") {
                tdLibWrapper.getInstalledCustomEmojiSets();
            } else {
                tdLibWrapper.getInstalledStickerSets();
            }
        }
    }

    Rectangle {
        id: stickerSetContentBackground
        color: Theme.overlayBackgroundColor
        opacity: 0.7
        anchors.fill: parent
        MouseArea {
            anchors.fill: parent
            onClicked: {
                stickerSetOverlayFlickable.requestClose();
            }
        }
    }

    Column {
        id: stickerSetContentColumn
        spacing: Theme.paddingMedium
        width: parent.width
        height: parent.height

        Row {
            id: stickerSetTitleRow
            width: parent.width - ( 2 * Theme.horizontalPageMargin )
            height: overlayStickerTitleText.height + ( 2 * Theme.paddingMedium )
            anchors.horizontalCenter: parent.horizontalCenter

            Label {
                id: overlayStickerTitleText

                width: parent.width - installSetButton.width - closeSetButton.width
                text: stickerSet.title
                font.pixelSize: Theme.fontSizeExtraLarge
                font.weight: Font.ExtraBold
                maximumLineCount: 1
                truncationMode: TruncationMode.Fade
                textFormat: Text.StyledText
                anchors.verticalCenter: parent.verticalCenter
            }

            IconButton {
                id: installSetButton
                icon.source: "image://theme/icon-m-add"
                anchors.verticalCenter: parent.verticalCenter
                visible: !stickerManager.isStickerSetInstalled(stickerSet.id)
                onClicked: {
                    var stickerType = (stickerSet && stickerSet.sticker_type && stickerSet.sticker_type["@type"])
                                      ? stickerSet.sticker_type["@type"] : "stickerTypeRegular";
                    tdLibWrapper.changeStickerSet(stickerSet.id, true, stickerType);
                }
            }

            IconButton {
                id: removeSetButton
                icon.source: "image://theme/icon-m-remove"
                anchors.verticalCenter: parent.verticalCenter
                visible: !installSetButton.visible
                onClicked: {
                    var stickerType = (stickerSet && stickerSet.sticker_type && stickerSet.sticker_type["@type"])
                                      ? stickerSet.sticker_type["@type"] : "stickerTypeRegular";
                    tdLibWrapper.changeStickerSet(stickerSet.id, false, stickerType);
                }
            }

            IconButton {
                id: closeSetButton
                icon.source: "image://theme/icon-m-clear"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    stickerSetOverlayFlickable.requestClose();
                }
            }
        }

        SilicaGridView {
            id: stickerSetGridView

            width: parent.width - ( 2 * Theme.horizontalPageMargin )
            height: parent.height - stickerSetTitleRow.height - Theme.paddingMedium
            anchors.horizontalCenter: parent.horizontalCenter

            cellWidth: chatPage.isLandscape ? (width / 5) : (width / 3);
            cellHeight: cellWidth

            visible: count > 0

            clip: true

            model: stickerSet.stickers
            delegate: Item {
                width: stickerSetGridView.cellWidth - Theme.paddingSmall
                height: stickerSetGridView.cellHeight - Theme.paddingSmall

                TDLibThumbnail {
                    id: singleStickerThumbnail
                    thumbnail: modelData.thumbnail
                    anchors.fill: parent
                }

                Label {
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    text: Emoji.emojify(modelData.emoji, font.pixelSize)
                }

            }

            VerticalScrollDecorator {}
        }

    }

}
