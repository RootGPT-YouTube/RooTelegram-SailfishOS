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
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0
import WerkWolf.RooTelegram 1.0

Item {
    id: profileThumbnail

    property alias photoData: file.fileInformation
    property string replacementStringHint: "X"
    // 2.0 abbellimento (#3): angoli stondati (rounded-square) nel tema Neon.
    // Tema Silica: avatar quadrati (look base, più leggero).
    property int radius: appSettings.useNeonTheme ? Math.round(width * 0.3) : 0
    property int imageStatus: -1
    property bool optimizeImageSize: true
    property bool highlighted

    layer.enabled: highlighted
    layer.effect: PressEffect { source: profileThumbnail }

    function getReplacementString() {
        if (replacementStringHint.length > 2) {
            // Remove all emoji images
            var strippedText = replacementStringHint.replace(/\<[^>]+\>/g, "").trim();
            if (strippedText.length > 0) {
                var textElements = strippedText.split(" ");
                if (textElements.length > 1) {
                    return textElements[0].charAt(0) + textElements[textElements.length - 1].charAt(0);
                } else {
                    return textElements[0].charAt(0);
                }
            }
        }
        return replacementStringHint;
    }

    TDLibFile {
        id: file
        tdlib: tdLibWrapper
        autoLoad: true
    }

    Component {
        id: profileImageComponent
        Item {
            width: profileThumbnail.width
            height: width
            visible: opacity > 0
            opacity: singleImage.status === Image.Ready ? 1 : 0
            Behavior on opacity { FadeAnimation {} }

            Image {
                id: singleImage
                width: parent.width - Theme.paddingSmall
                height: width
                source: file.path
                sourceSize.width: optimizeImageSize ? width : undefined
                sourceSize.height: optimizeImageSize ? height : undefined
                fillMode: Image.PreserveAspectCrop
                autoTransform: true
                asynchronous: true
                visible: true
                layer.enabled: true
                layer.effect: OpacityMask { maskSource: profileThumbnailMask }
                onStatusChanged: {
                    profileThumbnail.imageStatus = status
                }
            }

            Rectangle {
                id: profileThumbnailMask
                width: singleImage.width
                height: singleImage.height
                color: "white"
                radius: profileThumbnail.radius
                anchors.centerIn: singleImage
                visible: false
            }
        }
    }

    Loader {
        id: profileImageLoader
        active: file.isDownloadingCompleted
        asynchronous: true
        width: parent.width
        sourceComponent: profileImageComponent
    }

    Item {
        width: parent.width - Theme.paddingSmall
        height: parent.height - Theme.paddingSmall
        visible: !profileImageLoader.item || !profileImageLoader.item.visible

        Rectangle {
            id: replacementThumbnailBackground
            anchors.fill: parent
            color: (Theme.colorScheme === Theme.LightOnDark) ? Theme.darkSecondaryColor : Theme.lightSecondaryColor
            radius: profileThumbnail.radius
            opacity: 0.8
        }

        Text {
            anchors.centerIn: replacementThumbnailBackground
            text: getReplacementString()
            color: Theme.primaryColor
            font.bold: true
            font.pixelSize: ( profileThumbnail.height >= Theme.itemSizeSmall ) ? Theme.fontSizeLarge : Theme.fontSizeMedium
        }
    }
}
