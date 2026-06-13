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
    // Live location: live_period > 0 e expires_in > 0 finché è attiva. Alla
    // ricezione di updateMessageContent locationData cambia → updatePicture()
    // ri-scarica la thumbnail (il pin "si muove") senza altro codice.
    property bool isLiveLocation: (rawMessage.content.live_period || 0) > 0
    property int liveExpiresIn: rawMessage.content.expires_in || 0

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

    // Badge "LIVE" per le posizioni in tempo reale (proprie e altrui).
    Rectangle {
        visible: contentItem.isLiveLocation
        anchors {
            left: parent.left
            top: parent.top
            margins: Theme.paddingSmall
        }
        radius: Theme.paddingSmall
        color: Theme.rgba("#000000", 0.55)
        width: liveRow.width + 2 * Theme.paddingSmall
        height: liveRow.height + Theme.paddingSmall
        Row {
            id: liveRow
            anchors.centerIn: parent
            spacing: Theme.paddingSmall
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.paddingSmall
                height: width
                radius: width / 2
                color: contentItem.liveExpiresIn > 0 ? "#ff4444" : Theme.secondaryColor
                opacity: liveBlink.running ? blinkOpacity : 1.0
                property real blinkOpacity: 1.0
                SequentialAnimation on blinkOpacity {
                    id: liveBlink
                    running: contentItem.isLiveLocation && contentItem.liveExpiresIn > 0
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 800 }
                    NumberAnimation { to: 1.0; duration: 800 }
                }
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: Theme.fontSizeExtraSmall
                font.bold: true
                color: Theme.primaryColor
                text: contentItem.liveExpiresIn > 0 ? qsTr("LIVE") : qsTr("Live ended")
            }
        }
    }

    Component.onCompleted: {
        updatePicture();
    }
}
