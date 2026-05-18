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
import "../"

MessageContentBase {
    id: messagePhotoContent

    readonly property alias photoData: photo.photo;
    readonly property real landscapePreviewAspectRatio: (16.0 / 9.0)
    readonly property real portraitPreviewAspectRatio: (9.0 / 16.0)
    property real targetPreviewAspectRatio: landscapePreviewAspectRatio
    // Once teardown begins we stop touching aliases — accessing `photo.photo`
    // (photoData) during incubation cancellation is what surfaces the
    // "Object destroyed during incubation" warning on fast scroll.
    property bool _destroying: false

    // Height comes directly from width and aspect ratio — no intermediate properties,
    // no Math.min(width, ...). TDLibPhoto fills parent via a single anchors.fill binding.
    height: Math.max(Theme.itemSizeExtraSmall, Math.round(width / targetPreviewAspectRatio))

    onPhotoDataChanged: updateAspectRatio()
    Component.onCompleted: updateAspectRatio()
    Component.onDestruction: _destroying = true

    onClicked: {
        pageStack.push(Qt.resolvedUrl("../../pages/MediaAlbumPage.qml"), {
            "messages" : [rawMessage],
        })
    }
    function updateAspectRatio() {
        if (_destroying) {
            return;
        }
        targetPreviewAspectRatio = getAspectRatio() < 1 ? portraitPreviewAspectRatio : landscapePreviewAspectRatio;
    }
    function getAspectRatio() {
        if (!photoData || !photoData.sizes || photoData.sizes.length === 0) {
            return 1;
        }
        var candidate = photoData.sizes[photoData.sizes.length - 1];
        if ((!candidate || candidate.width === 0 || candidate.height === 0) && photoData.sizes.length > 1) {
           for (var i = (photoData.sizes.length - 2); i >= 0; i--) {
               candidate = photoData.sizes[i];
               if (candidate.width > 0 && candidate.height > 0) {
                   break;
               }
           }
        }
        if (!candidate || candidate.width <= 0 || candidate.height <= 0) {
            return 1;
        }
        return candidate.width / candidate.height;
    }
    TDLibPhoto {
        id: photo
        anchors.fill: parent
        photo: rawMessage.content.photo
        highlighted: messagePhotoContent.highlighted
        // Cap decoded texture size for inline previews. Channels like Durov's
        // load many high-res photos in a row; without this cap the GPU/EGL
        // pipeline runs out of texture memory during fast scroll and stalls
        // (visible as multi-second freezes once Qt's pixmap cache fills and
        // starts evicting). 720px is HD-ish — plenty for an inline preview
        // and roughly half the memory of Screen.width on a 1080-wide device.
        // Full-quality decode is preserved in MediaAlbumPage/ImagePage which
        // don't set this property.
        Component.onCompleted: image.maxSourceDimension = 720
    }
}
