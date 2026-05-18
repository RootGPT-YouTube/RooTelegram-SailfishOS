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

Item {
    visible: !!(parent && parent.thumbnailVisible) && chatPictureDetail.imageStatus === Image.Ready
    property bool isActive: !!(parent && parent.thumbnailActive)
    opacity: isActive ? 1.0 : 0.0
    Behavior on opacity { FadeAnimation {} }
    ProfileThumbnail {
        id: chatPictureDetail
        anchors.fill: parent
        photoData: (typeof chatInformation.photo !== "undefined") ? chatInformation.photo.big : ""
        replacementStringHint: ""
        radius: chatPictureThumbnail.radius
        optimizeImageSize: false
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            var preparedPhotoData = {sizes:[{width:640,height: 640,photo:chatPictureDetail.photoData}]};
            pageStack.push(Qt.resolvedUrl("../../pages/ImagePage.qml"), { "photoData" : preparedPhotoData });
        }
    }
}
