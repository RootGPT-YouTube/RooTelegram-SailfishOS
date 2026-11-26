/*
    Copyright (C) 2026 RootGPT

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
import "../components"

// Scelta dello sfondo delle chat (tema Classic), SINCRONIZZATA con Telegram:
//   chatId = 0  → sfondo predefinito di tutte le chat (setDefaultBackground),
//                 per la palette in uso (chiara o scura, come Telegram);
//   chatId != 0 → sfondo della singola chat (setChatBackground, only_for_self:
//                 impostarlo anche all'altra persona è una funzione Premium).
Page {
    id: page
    allowedOrientations: Orientation.All

    property string chatId: "0"
    property string chatTitle: ""
    readonly property bool forChat: chatId !== "0" && chatId !== ""
    readonly property bool dark: BarbaraTheme.dark

    // Sfondi installati sull'account (getInstalledBackgrounds).
    property var installed: []
    property bool loading: true

    // Tinte e sfumature pronte (colori 0xRRGGBB, come le vuole TDLib).
    readonly property var presets: dark ? [
        { "@type": "backgroundFillSolid", "color": 0x17212b },
        { "@type": "backgroundFillSolid", "color": 0x0e1621 },
        { "@type": "backgroundFillSolid", "color": 0x1c2a22 },
        { "@type": "backgroundFillGradient", "top_color": 0x1d2733, "bottom_color": 0x0b1118, "rotation_angle": 0 },
        { "@type": "backgroundFillGradient", "top_color": 0x2b1d33, "bottom_color": 0x11141f, "rotation_angle": 45 },
        { "@type": "backgroundFillFreeformGradient", "colors": [0x1b2d3d, 0x2b2140, 0x14302a, 0x262035] }
    ] : [
        { "@type": "backgroundFillSolid", "color": 0xcfdcbd },
        { "@type": "backgroundFillSolid", "color": 0xdde5ec },
        { "@type": "backgroundFillSolid", "color": 0xf2e7d5 },
        { "@type": "backgroundFillGradient", "top_color": 0xd6e7c3, "bottom_color": 0xa9c9a0, "rotation_angle": 0 },
        { "@type": "backgroundFillGradient", "top_color": 0xd8e6f5, "bottom_color": 0xbfd0ea, "rotation_angle": 45 },
        { "@type": "backgroundFillFreeformGradient", "colors": [0xdbddbb, 0x6ba587, 0xd5d88d, 0x88b884] }
    ]

    function reload() {
        loading = true;
        tdLibWrapper.sendRequest({
            "@type": "getInstalledBackgrounds",
            "for_dark_theme": dark,
            "@extra": "chatBackgroundsPage"
        });
    }
    Component.onCompleted: reload()
    onDarkChanged: reload()

    // Applica: background = InputBackground o null, type = BackgroundType o null.
    function apply(inputBackground, type) {
        if (forChat) {
            tdLibWrapper.sendRequest({
                "@type": "setChatBackground",
                "chat_id": Number(chatId),
                "background": inputBackground,
                "type": type,
                "dark_theme_dimming": 0,
                "only_for_self": true,
                "@extra": "chatBackgroundsPage:set"
            });
        } else {
            tdLibWrapper.sendRequest({
                "@type": "setDefaultBackground",
                "background": inputBackground,
                "type": type,
                "for_dark_theme": dark,
                "@extra": "chatBackgroundsPage:set"
            });
        }
        appNotification.show(qsTr("Background changed"));
    }
    // Torna allo sfondo predefinito: per una chat quello generale, per lo sfondo
    // generale il motivo di RooTelegram (nessuno sfondo sull'account).
    function resetToDefault() {
        if (forChat) {
            tdLibWrapper.sendRequest({
                "@type": "deleteChatBackground",
                "chat_id": Number(chatId),
                "restore_previous": false,
                "@extra": "chatBackgroundsPage:set"
            });
        } else {
            tdLibWrapper.sendRequest({
                "@type": "setDefaultBackground",
                "background": null,
                "type": null,
                "for_dark_theme": dark,
                "@extra": "chatBackgroundsPage:set"
            });
        }
        appNotification.show(qsTr("Background changed"));
    }
    function pickFromGallery() {
        if (!appSettings.isPermissionGranted("pictures")) {
            appNotification.show(qsTr("Image access is turned off in RooTelegram settings."));
            return;
        }
        var picker = pageStack.push("Sailfish.Pickers.ImagePickerPage", { allowedOrientations: page.allowedOrientations });
        picker.selectedContentPropertiesChanged.connect(function() {
            var path = picker.selectedContentProperties ? picker.selectedContentProperties.filePath : "";
            if (path) {
                page.apply({ "@type": "inputBackgroundLocal", "background": { "@type": "inputFileLocal", "path": path } },
                           { "@type": "backgroundTypeWallpaper", "is_blurred": false, "is_moving": false });
            }
        });
    }

    Connections {
        target: tdLibWrapper
        onBackgroundsReceived: {
            if (extra === "chatBackgroundsPage") {
                page.installed = backgrounds.filter(function(b) {
                    var t = b && b.type ? b.type["@type"] : "";
                    return t === "backgroundTypeFill" || t === "backgroundTypePattern" || t === "backgroundTypeWallpaper";
                });
                page.loading = false;
            }
        }
        onErrorReceived: {
            if (extra === "chatBackgroundsPage") {
                page.loading = false;
            } else if (extra === "chatBackgroundsPage:set") {
                appNotification.show(qsTr("Telegram did not accept this background: %1").arg(message));
            }
        }
    }

    readonly property int columns: isPortrait ? 3 : 5
    readonly property real tileWidth: Math.floor((width - 2 * Theme.horizontalPageMargin - (columns - 1) * Theme.paddingMedium) / columns)
    readonly property real tileHeight: Math.round(tileWidth * 1.6)

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: page.forChat ? qsTr("Chat background") : qsTr("Chat backgrounds")
                description: page.forChat ? page.chatTitle
                                          : (page.dark ? qsTr("Dark palette") : qsTr("Light palette"))
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: page.forChat
                      ? qsTr("Saved on Telegram: you will see it on all your devices. Only you see it.")
                      : qsTr("Saved on Telegram for all chats, separately for the light and the dark palette: you will see it on all your devices.")
            }

            Flow {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingMedium

                // Predefinito: motivo di RooTelegram (generale) o sfondo generale (chat).
                BackgroundItem {
                    width: page.tileWidth
                    height: page.tileHeight
                    onClicked: page.resetToDefault()
                    ChatWallpaper {
                        anchors.fill: parent
                        clip: true
                        // Chat: anteprima dello sfondo generale; generale: il motivo.
                        chatBackground: null
                        useAccountDefault: page.forChat
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: defaultLabel.height + Theme.paddingSmall
                        color: Qt.rgba(0, 0, 0, 0.45)
                        Label {
                            id: defaultLabel
                            anchors.centerIn: parent
                            width: parent.width - Theme.paddingSmall
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSizeTiny
                            color: "#ffffff"
                            text: page.forChat ? qsTr("Default") : "RooTelegram"
                        }
                    }
                }

                // Dalla galleria.
                BackgroundItem {
                    width: page.tileWidth
                    height: page.tileHeight
                    onClicked: page.pickFromGallery()
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.rgba(Theme.primaryColor, 0.3)
                    }
                    Column {
                        anchors.centerIn: parent
                        width: parent.width
                        spacing: Theme.paddingSmall
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            source: "image://theme/icon-m-image"
                        }
                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSizeTiny
                            text: qsTr("From gallery")
                        }
                    }
                }

                // Tinte e sfumature pronte.
                Repeater {
                    model: page.presets
                    delegate: BackgroundItem {
                        width: page.tileWidth
                        height: page.tileHeight
                        onClicked: page.apply(null, { "@type": "backgroundTypeFill", "fill": modelData })
                        ChatWallpaper {
                            anchors.fill: parent
                            clip: true
                            chatBackground: ({ "background": { "type": { "@type": "backgroundTypeFill", "fill": modelData } },
                                               "dark_theme_dimming": 0 })
                        }
                    }
                }

                // Sfondi installati sull'account Telegram.
                Repeater {
                    model: page.installed
                    delegate: BackgroundItem {
                        width: page.tileWidth
                        height: page.tileHeight
                        onClicked: page.apply({ "@type": "inputBackgroundRemote", "background_id": modelData.id }, modelData.type)
                        ChatWallpaper {
                            anchors.fill: parent
                            clip: true
                            chatBackground: ({ "background": modelData, "dark_theme_dimming": 0 })
                        }
                    }
                }
            }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                size: BusyIndicatorSize.Medium
                running: page.loading
                visible: running
            }
        }

        VerticalScrollDecorator {}
    }
}
