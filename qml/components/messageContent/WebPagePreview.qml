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
import WerkWolf.RooTelegram 1.0
import "../"
import "../../js/functions.js" as Functions

Column {
    id: webPagePreviewColumn

    property var webPageData;
    property bool largerFontSize: false;
    property bool highlighted
    readonly property var resolvedPhotoData: getPhotoData()
    readonly property bool hasImage: picture.fileId !== 0
    readonly property int fontSize: largerFontSize ? Theme.fontSizeSmall : Theme.fontSizeExtraSmall

    spacing: Theme.paddingSmall

    Component.onCompleted: updatePhoto()

    onWebPageDataChanged: updatePhoto()
    function getPhotoData() {
        if (!webPageData) {
            return null;
        }
        if (webPageData.photo && webPageData.photo.sizes && webPageData.photo.sizes.length > 0) {
            return webPageData.photo;
        }
        if (webPageData.web_page && webPageData.web_page.photo && webPageData.web_page.photo.sizes && webPageData.web_page.photo.sizes.length > 0) {
            return webPageData.web_page.photo;
        }
        if (webPageData.type && webPageData.type.photo && webPageData.type.photo.sizes && webPageData.type.photo.sizes.length > 0) {
            return webPageData.type.photo;
        }
        return null;
    }
    function getThumbnailFile() {
        if (!webPageData) {
            return null;
        }
        if (webPageData.thumbnail && webPageData.thumbnail.file) {
            return webPageData.thumbnail.file;
        }
        if (webPageData.type && webPageData.type.thumbnail && webPageData.type.thumbnail.file) {
            return webPageData.type.thumbnail.file;
        }
        return null;
    }
    function getSiteNameText() {
        if (!webPageData) {
            return "";
        }
        if (webPageData.site_name) {
            return webPageData.site_name;
        }
        if (webPageData.type && webPageData.type.site_name) {
            return webPageData.type.site_name;
        }
        return "";
    }
    function getTitleText() {
        if (!webPageData) {
            return "";
        }
        if (webPageData.title) {
            return webPageData.title;
        }
        if (webPageData.type && webPageData.type.title) {
            return webPageData.type.title;
        }
        return "";
    }
    function getDescriptionText() {
        if (!webPageData) {
            return "";
        }
        var descriptionValue = webPageData.description;
        if (!descriptionValue && webPageData.type) {
            descriptionValue = webPageData.type.description;
        }
        if (!descriptionValue) {
            return "";
        }
        if (typeof descriptionValue === "string") {
            return descriptionValue;
        }
        if (typeof descriptionValue.text !== "undefined") {
            return Functions.enhanceMessageText(descriptionValue);
        }
        return "";
    }

    function updatePhoto() {
        picture.fileInformation = {};
        var photoData = webPagePreviewColumn.resolvedPhotoData;
        if (photoData && photoData.sizes && photoData.sizes.length > 0) {
            // Check first which size fits best...
            var photo;
            for (var i = 0; i < photoData.sizes.length; i++) {
                photo = photoData.sizes[i].photo;
                if (photoData.sizes[i].width >= webPagePreviewColumn.width) {
                    break;
                }
            }
            if (photo) {
                picture.fileInformation = photo;
                return;
            }
        }
        var thumbnailFile = getThumbnailFile();
        if (thumbnailFile) {
            picture.fileInformation = thumbnailFile;
        }
    }

    function clicked() {
        descriptionText.toggleMaxLineCount()
    }

    TDLibFile {
        id: picture
        tdlib: tdLibWrapper
        autoLoad: true
    }

    MultilineEmojiLabel {
        id: siteNameText

        width: parent.width
        rawText: getSiteNameText()
        font.pixelSize: webPagePreviewColumn.fontSize
        font.bold: true
        color: Theme.secondaryHighlightColor
        visible: (rawText !== "")
        maxLineCount: 1
    }

    MultilineEmojiLabel {
        id: titleText

        width: parent.width
        rawText: getTitleText()
        font.pixelSize: webPagePreviewColumn.fontSize
        font.bold: true
        visible: (rawText !== "")
        maxLineCount: 2
    }

    MultilineEmojiLabel {
        id: descriptionText

        width: parent.width
        rawText: getDescriptionText()
        font.pixelSize: webPagePreviewColumn.fontSize
        visible: (rawText !== "")
        readonly property int defaultMaxLineCount: 3
        maxLineCount: defaultMaxLineCount
        linkColor: Theme.highlightColor
        onLinkActivated: {
            Functions.handleLink(link);
        }
        function toggleMaxLineCount() {
            maxLineCount = maxLineCount > 0 ? 0 : defaultMaxLineCount
        }
    }

    Item {
        id: webPagePreviewImageItem
        width: parent.width
        height: width * 2 / 3
        visible: hasImage

        Image {
            id: singleImage
            width: parent.width - Theme.paddingSmall
            height: parent.height - Theme.paddingSmall
            anchors.centerIn: parent

            sourceSize.width: width
            sourceSize.height: height
            fillMode: Image.PreserveAspectCrop
            autoTransform: true
            asynchronous: true
            source: picture.isDownloadingCompleted ? picture.path : ""
            visible: opacity > 0
            opacity: hasImage && status === Image.Ready ? 1 : 0
            layer.enabled: webPagePreviewColumn.highlighted
            layer.effect: PressEffect { source: singleImage }
            Behavior on opacity { FadeAnimation {} }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("../../pages/ImagePage.qml"), { "photoData" : webPagePreviewColumn.resolvedPhotoData, "pictureFileInformation" : picture.fileInformation });
                }
            }
        }

        BackgroundImage {
            id: backgroundImage
            visible: hasImage && singleImage.status !== Image.Ready
            layer.enabled: webPagePreviewColumn.highlighted
            layer.effect: PressEffect { source: backgroundImage }
        }
    }

    Label {
        width: parent.width
        text: qsTr("Preview not supported for this link...")
        font.pixelSize: webPagePreviewColumn.largerFontSize ? Theme.fontSizeExtraSmall : Theme.fontSizeTiny
        font.italic: true
        color: Theme.secondaryColor
        truncationMode: TruncationMode.Fade
        visible: !siteNameText.visible && !titleText.visible && !descriptionText.visible && !webPagePreviewImageItem.visible
    }

}
