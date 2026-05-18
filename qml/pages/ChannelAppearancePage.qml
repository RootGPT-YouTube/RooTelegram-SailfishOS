/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), which is
    licensed under the GNU General Public License v3.0. The original
    license is available at:
    https://github.com/Wunderfitz/harbour-fernschreiber/blob/master/LICENSE
*/
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../js/twemoji.js" as Emoji

Page {
    id: channelAppearancePage
    allowedOrientations: Orientation.All

    property var channelChat: ({})
    property string currentThemeName: ""

    function intToColor(intColor) {
        if (typeof intColor !== "number" || intColor === 0) {
            return Theme.primaryColor;
        }
        var hex = (intColor & 0xFFFFFF).toString(16);
        while (hex.length < 6) {
            hex = "0" + hex;
        }
        return "#" + hex;
    }

    function reload() {
        themesModel.clear();
        themesModel.append({ "themeName": "", "accentColor": 0, "isDefault": true });
        var themes = tdLibWrapper.getAvailableChatThemes();
        for (var i = 0; i < themes.length; i++) {
            var t = themes[i];
            var accent = 0;
            if (t.light_settings && typeof t.light_settings.accent_color === "number") {
                accent = t.light_settings.accent_color;
            }
            themesModel.append({
                "themeName": t.name || "",
                "accentColor": accent,
                "isDefault": false
            });
        }
    }

    function applyTheme(themeName) {
        var channelId = Number(channelChat.id);
        if (isNaN(channelId)) {
            return;
        }
        tdLibWrapper.setChatTheme(channelId, themeName);
        currentThemeName = themeName;
        appNotification.show(themeName === ""
            ? qsTr("Theme cleared")
            : qsTr("Theme set: %1").arg(themeName));
        pageStack.pop();
    }

    Component.onCompleted: {
        currentThemeName = (channelChat && typeof channelChat.theme_name === "string")
            ? channelChat.theme_name : "";
        reload();
    }

    Connections {
        target: tdLibWrapper
        onAvailableChatThemesUpdated: reload()
    }

    ListModel {
        id: themesModel
    }

    SilicaListView {
        id: themesListView
        anchors.fill: parent
        clip: true

        header: Column {
            width: themesListView.width

            PageHeader {
                title: qsTr("Appearance")
                description: channelChat.title ? Emoji.emojify(channelChat.title, Theme.fontSizeLarge) : ""
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("Pick a chat theme. The selected preset is applied to every member viewing this channel.")
            }

            Item { width: 1; height: Theme.paddingMedium }
        }

        model: themesModel

        delegate: ListItem {
            id: themeItem
            width: ListView.view.width
            contentHeight: Theme.itemSizeMedium

            property bool isSelected: themeName === channelAppearancePage.currentThemeName

            onClicked: applyTheme(themeName)

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.horizontalPageMargin
                anchors.rightMargin: Theme.horizontalPageMargin
                spacing: Theme.paddingMedium

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.iconSizeMedium
                    height: width
                    radius: width / 2
                    color: isDefault ? "transparent" : channelAppearancePage.intToColor(accentColor)
                    border.color: Theme.secondaryColor
                    border.width: isDefault ? 2 : 0
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: isDefault ? qsTr("Default (no theme)") : themeName
                    color: themeItem.isSelected ? Theme.highlightColor : Theme.primaryColor
                    width: parent.width - Theme.iconSizeMedium - Theme.iconSizeSmall - 2 * Theme.paddingMedium
                    truncationMode: TruncationMode.Fade
                }

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.iconSizeSmall
                    height: width
                    visible: themeItem.isSelected
                    source: "image://theme/icon-s-accept"
                }
            }
        }

        ViewPlaceholder {
            enabled: themesModel.count <= 1
            text: qsTr("No themes available yet")
            hintText: qsTr("Themes are pushed by Telegram after sign-in. Try again in a moment.")
        }

        VerticalScrollDecorator {}
    }
}
