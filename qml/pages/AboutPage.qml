
/*
    Copyright (C) 2020-21 Sebastian J. Wolf and other contributors
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
import "../components"

Page {
    id: aboutPage
    allowedOrientations: Orientation.All

    SilicaFlickable {
        id: aboutContainer
        contentHeight: column.height
        anchors.fill: parent

        Column {
            id: column
            width: aboutPage.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: qsTr("About RooTelegram")
            }

            Rectangle {
                id: avatarClip
                width: Math.min(2 * Theme.itemSizeHuge, Math.min(aboutPage.width, aboutPage.height) / 2)
                height: width
                radius: width / 2
                anchors.horizontalCenter: parent.horizontalCenter
                color: "transparent"
                clip: true

                Image {
                    id: wunderfitzImage
                    source: Qt.resolvedUrl("../../images/rootgpt-avatar.png")
                    width: parent.width
                    height: parent.height
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            Label {
                text: "RooTelegram " + appVersion
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.fontSizeExtraLarge
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
            }

            Label {
                wrapMode: Text.Wrap
                x: Theme.horizontalPageMargin
                width: parent.width - ( 2 * Theme.horizontalPageMargin )
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("A Telegram client for Sailfish OS")
                font.pixelSize: Theme.fontSizeSmall
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
            }

            Label {
                text: qsTr("Fork by RootGPT - based on Fernschreiber by Sebastian J. Wolf and Yottagram by Michal Szczepaniak.")
                font.pixelSize: Theme.fontSizeSmall
                width: parent.width - ( 2 * Theme.horizontalPageMargin )
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
            }

            Text {
                text: "<a href=\"https://github.com/Wunderfitz/harbour-fernschreiber\">" + qsTr("Fernschreiber") + "</a>"
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
                font.pixelSize: Theme.fontSizeSmall
                linkColor: Theme.highlightColor
                onLinkActivated: Qt.openUrlExternally("https://github.com/Wunderfitz/harbour-fernschreiber")
            }

            Text {
                text: "<a href=\"https://github.com/Michal-Szczepaniak/Yottagram\">" + qsTr("Yottagram") + "</a>"
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
                font.pixelSize: Theme.fontSizeSmall
                linkColor: Theme.highlightColor

                onLinkActivated: Qt.openUrlExternally("https://github.com/Michal-Szczepaniak/Yottagram")
            }

            Text {
                text: "<a href=\"https://github.com/RootGPT-YouTube/RooTelegram-SailfishOS\">" + qsTr("Source code on GitHub") + "</a>"
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
                font.pixelSize: Theme.fontSizeSmall
                linkColor: Theme.highlightColor

                onLinkActivated: Qt.openUrlExternally("https://github.com/RootGPT-YouTube/RooTelegram-SailfishOS")
            }

            NeonSeparator {
                width: parent.width
            }

            Label {
                text: qsTr("Licensed under GNU GPLv3")
                font.pixelSize: Theme.fontSizeSmall
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
            }


            Text {
                text: qsTr("About Telegram")
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width  - ( 2 * Theme.horizontalPageMargin )
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("This product uses the Telegram API but is not endorsed or certified by Telegram.")
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width  - ( 2 * Theme.horizontalPageMargin )
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("TDLib version %1").arg(tdLibWrapper.getVersion())
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
            }

            NeonButton {
                text: qsTr("Terms of Service")
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
                onClicked: {
                    Qt.openUrlExternally("https://telegram.org/tos");
                }
            }

            NeonButton {
                text: qsTr("Privacy Policy")
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
                onClicked: {
                    Qt.openUrlExternally("https://telegram.org/privacy")
                }
            }

            Text {
                text: qsTr("Credits")
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width  - ( 2 * Theme.horizontalPageMargin )
                text: qsTr("Slovak translation by okruhliak. Thanks to everyone helping translate RooTelegram!")
                font.pixelSize: Theme.fontSizeExtraSmall
                wrapMode: Text.Wrap
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width  - ( 2 * Theme.horizontalPageMargin )
                text: qsTr("This project uses the Telegram Database Library (TDLib). Thanks for making it available under the conditions of the Boost Software License 1.0!")
                font.pixelSize: Theme.fontSizeExtraSmall
                wrapMode: Text.Wrap
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
            }

            Text {
                text: "<a href=\"https://github.com/tdlib/td\">" + qsTr("Open Telegram Database Library on GitHub") + "</a>"
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
                font.pixelSize: Theme.fontSizeSmall
                linkColor: Theme.highlightColor

                onLinkActivated: Qt.openUrlExternally("https://github.com/tdlib/td")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width  - ( 2 * Theme.horizontalPageMargin )
                text: qsTr("This project uses Twemoji (jdecked fork). Copyright the Twemoji contributors. Thanks for making it available under the conditions of the MIT License (coding) and CC-BY 4.0 (graphics)!")
                font.pixelSize: Theme.fontSizeExtraSmall
                wrapMode: Text.Wrap
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
            }

            Text {
                text: "<a href=\"https://github.com/jdecked/twemoji\">" + qsTr("Open Twemoji on GitHub") + "</a>"
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
                font.pixelSize: Theme.fontSizeSmall
                linkColor: Theme.highlightColor

                onLinkActivated: Qt.openUrlExternally("https://github.com/jdecked/twemoji")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width  - ( 2 * Theme.horizontalPageMargin )
                text: qsTr("This project uses rlottie. Copyright 2020 Samsung Electronics Co., Ltd. and other contributors. Thanks for making it available under the conditions of the MIT License!")
                font.pixelSize: Theme.fontSizeExtraSmall
                wrapMode: Text.Wrap
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
            }

            Text {
                text: "<a href=\"https://github.com/Samsung/rlottie\">" + qsTr("Open rlottie on GitHub") + "</a>"
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
                font.pixelSize: Theme.fontSizeSmall
                linkColor: Theme.highlightColor

                onLinkActivated: Qt.openUrlExternally("https://github.com/Samsung/rlottie")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width  - ( 2 * Theme.horizontalPageMargin )
                text: qsTr("This project bundles FFmpeg, built with libx264, to normalize videos before upload. Thanks for making it available under the conditions of the LGPL v2.1+ / GPL v2+ (libx264)!")
                font.pixelSize: Theme.fontSizeExtraSmall
                wrapMode: Text.Wrap
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
            }

            Text {
                text: "<a href=\"https://ffmpeg.org\">" + qsTr("Open FFmpeg website") + "</a>"
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
                font.pixelSize: Theme.fontSizeSmall
                linkColor: Theme.highlightColor

                onLinkActivated: Qt.openUrlExternally("https://ffmpeg.org")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width  - ( 2 * Theme.horizontalPageMargin )
                text: qsTr("For SailfishOS 5.0/5.1 compatibility this package also bundles FFmpeg's multimedia dependencies: libvpx, Opus, Ogg, Vorbis, Theora, Speex, WebP, libsharpyuv (BSD) and OpenJPEG (BSD-2). Copyright their respective contributors. The full license texts are shipped in /usr/share/harbour-rootelegram/licenses/.")
                font.pixelSize: Theme.fontSizeExtraSmall
                wrapMode: Text.Wrap
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width  - ( 2 * Theme.horizontalPageMargin )
                text: qsTr("This project uses tgcalls and tg_owt (WebRTC) for voice and video calls. Thanks for making them available under the conditions of the GPL v2+!")
                font.pixelSize: Theme.fontSizeExtraSmall
                wrapMode: Text.Wrap
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
            }

            Text {
                text: "<a href=\"https://github.com/TelegramMessenger/tgcalls\">" + qsTr("Open tgcalls on GitHub") + "</a>"
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
                font.pixelSize: Theme.fontSizeSmall
                linkColor: Theme.highlightColor

                onLinkActivated: Qt.openUrlExternally("https://github.com/TelegramMessenger/tgcalls")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width  - ( 2 * Theme.horizontalPageMargin )
                text: qsTr("This project uses the voicecall plugin interfaces by Jolla, so that calls are handled by the system: the screen turns on and the answer screen appears above the lock screen. Thanks for making them available under the conditions of the LGPL v2.1+!")
                font.pixelSize: Theme.fontSizeExtraSmall
                wrapMode: Text.Wrap
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
            }

            Text {
                text: "<a href=\"https://github.com/sailfishos/voicecall\">" + qsTr("Open voicecall on GitHub") + "</a>"
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
                font.pixelSize: Theme.fontSizeSmall
                linkColor: Theme.highlightColor

                onLinkActivated: Qt.openUrlExternally("https://github.com/sailfishos/voicecall")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width  - ( 2 * Theme.horizontalPageMargin )
                text: qsTr("This project uses OpenStreetMap Nominatim for reverse geocoding of location attachments. Thanks for making it available as web service!")
                font.pixelSize: Theme.fontSizeExtraSmall
                wrapMode: Text.Wrap
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
            }

            Text {
                text: "<a href=\"https://wiki.openstreetmap.org/wiki/Nominatim\">" + qsTr("Open OSM Nominatim Wiki") + "</a>"
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
                font.pixelSize: Theme.fontSizeSmall
                linkColor: Theme.highlightColor

                onLinkActivated: Qt.openUrlExternally("https://wiki.openstreetmap.org/wiki/Nominatim")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width  - ( 2 * Theme.horizontalPageMargin )
                text: qsTr("This project uses the QR Code generator library by Project Nayuki for QR-code login. Thanks for making it available under the conditions of the MIT License!")
                font.pixelSize: Theme.fontSizeExtraSmall
                wrapMode: Text.Wrap
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
            }

            Label {
                id: separatorLabel
                x: Theme.horizontalPageMargin
                width: parent.width  - ( 2 * Theme.horizontalPageMargin )
                font.pixelSize: Theme.fontSizeExtraSmall
                wrapMode: Text.Wrap
                anchors {
                    horizontalCenter: parent.horizontalCenter
                }
            }

            VerticalScrollDecorator {}
        }

    }
}
