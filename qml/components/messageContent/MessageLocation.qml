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
import Sailfish.Silica 1.0
import "../"

MessageContentBase {
    id: contentItem
    height: width * 0.66666666;

    property var locationData : rawMessage.content.location
    property string fileExtra;

    onClicked: {
        Qt.openUrlExternally("geo:" + locationData.latitude + "," + locationData.longitude);
    }
    onLocationDataChanged: updatePicture()
    onWidthChanged: updatePicture()

    function updatePicture() {
        if (locationData) {
            fileExtra = "location:" + locationData.latitude + ":" + locationData.longitude + ":" + Math.round(contentItem.width) + ":" + Math.round(contentItem.height);
            tdLibWrapper.getMapThumbnailFile(rawMessage.chat_id, locationData.latitude, locationData.longitude, Math.round(contentItem.width), Math.round(contentItem.height), fileExtra);
        }
    }

    Connections {
        target: tdLibWrapper
        onFileUpdated: {
            if(fileInformation["@extra"] === contentItem.fileExtra) {
                if(fileInformation.id !== image.file.fileId) {
                    image.fileInformation = fileInformation
                }
            }
        }
    }

    AppNotification {
        id: imageNotification
    }
    TDLibImage {
        id: image
        anchors.fill: parent
        cache: false
        highlighted: contentItem.highlighted
        Item {
            anchors.centerIn: parent
            width: markerImage.width
            height: markerImage.height * 1.75 // 0.875 (vertical pin point) * 2
            Icon {
                id: markerImage
                source: 'image://theme/icon-m-location'
            }

            Rectangle { color: Theme.overlayBackgroundColor; opacity: 0.5 }
        }
    }

    BackgroundImage {
        visible: image.status !== Image.Ready
    }

    Component.onCompleted: {
        updatePicture();
    }
}
