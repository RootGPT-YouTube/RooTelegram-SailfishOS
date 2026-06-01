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
import QtMultimedia 5.6
import Sailfish.Silica 1.0
import WerkWolf.RooTelegram 1.0
import "../components"
import "../js/twemoji.js" as Emoji
import "../js/functions.js" as Functions
import "../js/debug.js" as Debug

Page {
    id: debugPage
    allowedOrientations: Orientation.All

    SilicaFlickable {
        id: aboutContainer
        contentHeight: column.height
        anchors.fill: parent

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge
            PageHeader {
                title: "Debug Page"
                description: "here be dragons"

            }

            SectionHeader {
                text: "Chats"
            }

            TextSwitch {
                checked: chatListModel.showAllChats
                text: "Show all chats"
                description: "Including the ones referenced by the chats you have joined."
                automaticCheck: false
                onClicked: chatListModel.showAllChats = !chatListModel.showAllChats
            }

            Row {
                TextField {
                    id: chatId
                    anchors.bottom: parent.bottom
                    width: column.width - joinButton.width - Theme.horizontalPageMargin
                    placeholderText: "Chat id"
                    labelVisible: false
                    EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                    EnterKey.enabled: text.length > 0
                    EnterKey.onClicked: tdLibWrapper.joinChat(text)
                }
                Button {
                    id: joinButton
                    text: "Join by id"
                    anchors.bottom: parent.bottom
                    enabled: chatId.text.length > 0
                    onClicked: tdLibWrapper.joinChat(chatId.text)
                }
            }

            // ── V1 videochiamate: test cattura camera ────────────────────────
            SectionHeader {
                text: "Videochiamate — V1 cattura camera"
                visible: voiceCallsAvailable
            }

            Column {
                width: parent.width
                spacing: Theme.paddingMedium
                visible: voiceCallsAvailable

                Row {
                    spacing: Theme.paddingMedium
                    Button {
                        text: cameraCaptureProbe.active ? "Ferma" : "Avvia frontale"
                        onClicked: cameraCaptureProbe.active
                                   ? cameraCaptureProbe.stop()
                                   : cameraCaptureProbe.start(true)
                    }
                    Button {
                        text: "Avvia posteriore"
                        enabled: !cameraCaptureProbe.active
                        onClicked: cameraCaptureProbe.start(false)
                    }
                }

                Label {
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    x: Theme.horizontalPageMargin
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.highlightColor
                    text: "Stato: " + (cameraCaptureProbe.status || "—")
                }
                Label {
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    x: Theme.horizontalPageMargin
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeExtraSmall
                    text: "Frame: " + cameraCaptureProbe.frameCount
                }
                Label {
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    x: Theme.horizontalPageMargin
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeExtraSmall
                    text: cameraCaptureProbe.lastInfo || "(nessun frame ancora)"
                }

                // V2: anteprima del frame I420→RGB renderizzato in QML.
                VideoOutput {
                    id: cameraPreview
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    height: width * 3 / 4
                    fillMode: VideoOutput.PreserveAspectFit
                    source: cameraCaptureProbe
                    visible: cameraCaptureProbe.active
                }
            }
        }

        VerticalScrollDecorator {}
    }

    Timer {
        id: profileTimer
        interval: 1000
        property bool hasRun
        property var cases: []
        onTriggered: {
            if(cases.length === 0) {
                return;
            }

            if(!hasRun) {
                hasRun = true;
                Debug.profile();
            }
            cases.pop()();

            if(cases.length > 0) {
                restart();
            } else {
                Debug.profileEnd();
            }
        }
    }

    onStatusChanged: {
        if (status === PageStatus.Active) {
            // example runner for comparing function calls

//            profileTimer.cases.push(function(){
//                Debug.compareAndRepeat(
//                            "getUserName",
//                            Functions.getUserName,
//                            Functions.getUserName,
//                            [
//                                [{first_name: "Test", last_name: "User"}],
//                                [{first_name: "Test", last_name: ""}],
//                                [{first_name: "Test"}],
//                                [{first_name: "", last_name: "User"}],
//                                [{last_name: "User"}]
//                            ],
//                            800
//                            )
//            });
//            profileTimer.start();
        }
    }
}
