/*
    Forked in 2026 by RootGPT

    Picker emoji standard per il composer chat:
    - Categorie Unicode (recenti + 9 standard) accessibili da tab-bar in basso
    - Search per nome (short_names da iamcal/emoji-data)
    - Recenti persistenti via AppSettings.addRecentEmoji
    - Sole emoji "gialle" (no skin tone modifier)
*/
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../js/emoji_data.js" as EmojiData
import "../js/twemoji.js" as Emoji

Item {
    id: root
    width: parent ? parent.width : 0
    height: pickerColumn.height

    property real cellSize: Math.max(Math.round(Theme.itemSizeSmall * 0.78), Theme.itemSizeExtraSmall)
    property int visibleRows: 5
    property string currentCategoryKey: "recent"
    property bool searchActive: false
    property var recentList: appSettings ? appSettings.recentEmojis() : []
    property var searchResults: []
    readonly property var fallbackRecents: ["😀","😂","😍","🥰","😎","🤔","😭","😡","👍","🙏","👏","🔥","🎉","❤️","💯","🤗"]

    signal emojiPicked(string emoji)

    Connections {
        target: appSettings
        onRecentEmojisChanged: root.recentList = appSettings.recentEmojis()
    }

    function currentModel() {
        if (searchActive) {
            return searchResults;
        }
        if (currentCategoryKey === "recent") {
            return recentList.length > 0 ? recentList : fallbackRecents;
        }
        for (var i = 0; i < EmojiData.CATEGORIES.length; i++) {
            if (EmojiData.CATEGORIES[i].key === currentCategoryKey) {
                return EmojiData.CATEGORIES[i].emojis;
            }
        }
        return [];
    }

    function pickEmoji(ch) {
        if (!ch) {
            return;
        }
        if (appSettings) {
            appSettings.addRecentEmoji(ch);
        }
        emojiPicked(ch);
    }

    Column {
        id: pickerColumn
        width: parent.width
        spacing: Theme.paddingSmall

        SearchField {
            id: searchField
            width: parent.width
            visible: root.searchActive
            height: visible ? implicitHeight : 0
            placeholderText: qsTr("Search emoji")
            onTextChanged: {
                root.searchResults = EmojiData.search(text);
            }
        }

        SilicaGridView {
            id: emojiGrid
            width: parent.width
            height: root.cellSize * root.visibleRows
            cellWidth: root.cellSize
            cellHeight: root.cellSize
            clip: true
            cacheBuffer: Math.round(root.cellSize * 8)
            model: root.currentModel()
            delegate: BackgroundItem {
                width: emojiGrid.cellWidth
                height: emojiGrid.cellHeight
                onClicked: root.pickEmoji(modelData)
                Image {
                    anchors.centerIn: parent
                    width: Math.round(parent.width * 0.74)
                    height: width
                    source: modelData ? Emoji.getEmojiPath(modelData) : ""
                    sourceSize.width: width
                    sourceSize.height: height
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
            }
            VerticalScrollDecorator {}

            Label {
                anchors.centerIn: parent
                visible: emojiGrid.count === 0
                text: root.searchActive ? qsTr("No results") : qsTr("No emoji")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
            }
        }


        Rectangle {
            width: parent.width
            height: 1
            color: Theme.rgba(Theme.primaryColor, 0.12)
        }

        Flickable {
            id: tabBarFlickable
            width: parent.width
            height: root.cellSize
            contentWidth: Math.max(width, tabBarRow.width)
            contentHeight: tabBarRow.height
            clip: true

            Row {
                id: tabBarRow
                height: parent.height
                x: width <= parent.width ? ((parent.width - width) / 2) : 0
                spacing: Theme.paddingSmall
                leftPadding: Theme.paddingSmall
                rightPadding: Theme.paddingSmall

                BackgroundItem {
                    id: searchTab
                    width: root.cellSize
                    height: root.cellSize
                    highlighted: down || root.searchActive
                    onClicked: {
                        if (root.searchActive) {
                            root.searchActive = false;
                            searchField.text = "";
                            root.searchResults = [];
                        } else {
                            root.searchActive = true;
                            searchField.forceActiveFocus();
                        }
                    }
                    Icon {
                        anchors.centerIn: parent
                        source: root.searchActive ? "image://theme/icon-m-clear" : "image://theme/icon-m-search"
                        sourceSize.width: Theme.iconSizeSmall
                        sourceSize.height: Theme.iconSizeSmall
                    }
                }

                BackgroundItem {
                    id: recentTab
                    width: root.cellSize
                    height: root.cellSize
                    highlighted: down || (!root.searchActive && root.currentCategoryKey === "recent")
                    onClicked: {
                        root.searchActive = false;
                        root.currentCategoryKey = "recent";
                        emojiGrid.contentY = 0;
                    }
                    Image {
                        anchors.centerIn: parent
                        width: Math.round(parent.width * 0.6)
                        height: width
                        source: Emoji.getEmojiPath("🕐")
                        sourceSize.width: width
                        sourceSize.height: height
                        fillMode: Image.PreserveAspectFit
                    }
                }

                Repeater {
                    model: EmojiData.CATEGORIES
                    BackgroundItem {
                        width: root.cellSize
                        height: root.cellSize
                        highlighted: down || (!root.searchActive && root.currentCategoryKey === modelData.key)
                        onClicked: {
                            root.searchActive = false;
                            root.currentCategoryKey = modelData.key;
                            emojiGrid.contentY = 0;
                        }
                        Image {
                            anchors.centerIn: parent
                            width: Math.round(parent.width * 0.6)
                            height: width
                            source: Emoji.getEmojiPath(modelData.icon)
                            sourceSize.width: width
                            sourceSize.height: height
                            fillMode: Image.PreserveAspectFit
                        }
                    }
                }
            }
        }
    }
}
