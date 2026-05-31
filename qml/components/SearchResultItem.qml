/*
    Forked in 2026 by RootGPT — part of RooTelegram.

    Delegate leggero per i risultati di ricerca GLOBALE (utenti/gruppi/canali
    pubblici trovati su Telegram, non necessariamente già nelle proprie chat).
    Usato nella sezione "Risultati globali" della home (OverviewPage).
*/
import QtQuick 2.6
import Sailfish.Silica 1.0

ListItem {
    id: searchResultItem
    contentHeight: Theme.itemSizeMedium

    property var resultChatId: 0
    property string resultTitle: ""
    property string resultSubtitle: ""
    property var resultPhoto: ({})

    ProfileThumbnail {
        id: resultThumbnail
        photoData: searchResultItem.resultPhoto || ({})
        replacementStringHint: searchResultItem.resultTitle
        width: searchResultItem.contentHeight - 2 * Theme.paddingMedium
        height: width
        radius: width / 2
        highlighted: searchResultItem.highlighted
        anchors {
            left: parent.left
            leftMargin: Theme.horizontalPageMargin
            verticalCenter: parent.verticalCenter
        }
    }

    Column {
        anchors {
            left: resultThumbnail.right
            leftMargin: Theme.paddingMedium
            right: parent.right
            rightMargin: Theme.horizontalPageMargin
            verticalCenter: parent.verticalCenter
        }

        Label {
            width: parent.width
            text: searchResultItem.resultTitle
            truncationMode: TruncationMode.Fade
            color: searchResultItem.highlighted ? Theme.highlightColor : Theme.primaryColor
        }
        Label {
            width: parent.width
            visible: text.length > 0
            text: searchResultItem.resultSubtitle
            truncationMode: TruncationMode.Fade
            font.pixelSize: Theme.fontSizeSmall
            color: searchResultItem.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
        }
    }
}
