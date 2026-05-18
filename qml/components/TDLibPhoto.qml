/*
    Copyright (C) 2020 Sebastian J. Wolf and other contributors

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
import WerkWolf.RooTelegram 1.0
import Sailfish.Silica 1.0

Item {
    id: tdLibPhoto
    property var photo
    property bool highlighted
    readonly property alias fileInformation: tdLibImage.fileInformation
    readonly property alias image: tdLibImage

    // Debounce window before the photo is handed to the Image element. On
    // photo-heavy channels (Durov & co.) a fast scroll creates and destroys
    // many MessagePhoto delegates within a few hundred ms; without this delay
    // each one would kick off a JPEG decode + GPU upload even though it
    // disappears before the user sees it, saturating the render thread and
    // freezing the UI for seconds at a time. The minithumbnail stays on
    // screen while the timer is pending.
    onWidthChanged: setImageFileDeferred()
    onPhotoChanged: setImageFileDeferred()

    function setImageFileDeferred() {
        setImageFileTimer.restart();
    }

    Timer {
        id: setImageFileTimer
        interval: 250
        repeat: false
        onTriggered: setImageFile()
    }

    function setImageFile() {
        // Guard against being called during teardown / incubation cancellation,
        // when `photo` may still be a live alias but `tdLibImage` / its
        // `fileInformation` are no longer assignable.
        if (!photo || !photo.sizes || !tdLibImage) {
            return;
        }
        var photoSize;
        for (var i = 0; i < photo.sizes.length; i++) {
            photoSize = photo.sizes[i].photo;
            if (photo.sizes[i].width >= width) {
                break;
            }
        }
        var currentInfo = tdLibImage.fileInformation;
        if (photoSize && (!currentInfo || photoSize.id !== currentInfo.id)) {
            tdLibImage.fileInformation = photoSize;
        }
    }

    TDLibMinithumbnail {
        id: minithumbnailLoader
        active: !!minithumbnail && tdLibImage.opacity < 1.0
        minithumbnail: tdLibPhoto.photo.minithumbnail
        highlighted: parent.highlighted
    }

    BackgroundImage {
        visible: !tdLibImage.visible && !(minithumbnailLoader.item && minithumbnailLoader.item.visible)
    }

    TDLibImage {
        id: tdLibImage
        width: parent.width //don't use anchors here for easier custom scaling
        height: parent.height
        highlighted: parent.highlighted
    }

    Component.onCompleted: setImageFileDeferred()
}
