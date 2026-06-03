import QtQuick 2.6
import Sailfish.Silica 1.0
import WerkWolf.RooTelegram 1.0
import "../js/functions.js" as Functions

ListItem {
    id: chatListViewItem

    property alias primaryText: primaryText //usually chat name
    property alias prologSecondaryText: prologSecondaryText //usually last sender name
    property alias secondaryText: secondaryText //usually last message
    property alias tertiaryText: tertiaryText //usually last message date

    property int unreadCount: 0
    property int unreadMentionCount: 0
    property int unreadReactionCount: 0
    property bool isSecret: false
    property bool isVerified: false
    property bool isMarkedAsUnread: false
    property bool isPinned: false
    property bool isMuted: false
    property alias pictureThumbnail: pictureThumbnail
    // Home: rende nome+ultimo messaggio come FLUSSO UNICO su 2 righe con l'orario in
    // basso a destra. Le altre pagine restano sul layout classico (3 righe separate).
    property bool useCompactPreview: false

    contentHeight: Theme.itemSizeExtraLarge
    contentWidth: parent.width


    ShaderEffectSource {
        id: pictureItem
        height: Theme.itemSizeLarge
        width: height
        anchors {
            left: parent.left
            leftMargin: Theme.horizontalPageMargin
            verticalCenter: parent.verticalCenter
        }

        sourceItem: Item {
            width: pictureItem.width
            height: pictureItem.width

            ProfileThumbnail {
                id: pictureThumbnail
                replacementStringHint: primaryText.text
                width: parent.width
                height: parent.width
            }

            Rectangle {
                id: chatPinnedBackground
                color: Theme.rgba(Theme.overlayBackgroundColor, Theme.opacityFaint)
                width: Theme.fontSizeLarge
                height: Theme.fontSizeLarge
                anchors.top: parent.top
                radius: parent.width / 2
                visible: chatListViewItem.isPinned
            }

            Icon {
                source: "../../images/icon-s-pin.svg"
                height: Theme.iconSizeExtraSmall
                width: Theme.iconSizeExtraSmall
                highlighted: chatListViewItem.highlighted
                sourceSize: Qt.size(Theme.iconSizeExtraSmall, Theme.iconSizeExtraSmall)
                anchors.centerIn: chatPinnedBackground
                visible: chatListViewItem.isPinned
            }

            Rectangle {
                id: chatSecretBackground
                color: Theme.rgba(Theme.overlayBackgroundColor, Theme.opacityFaint)
                width: Theme.fontSizeLarge
                height: Theme.fontSizeLarge
                anchors.bottom: parent.bottom
                radius: parent.width / 2
                visible: chatListViewItem.isSecret
            }

            Icon {
                source: "image://theme/icon-s-secure"
                height: Theme.iconSizeExtraSmall
                width: Theme.iconSizeExtraSmall
                highlighted: chatListViewItem.highlighted
                anchors.centerIn: chatSecretBackground
                visible: chatListViewItem.isSecret
            }

            Rectangle {
                id: chatUnreadMessagesCountBackground
                color: isMuted ? ((Theme.colorScheme === Theme.DarkOnLight) ? "lightgray" : "dimgray") : Theme.highlightBackgroundColor
                width: Theme.fontSizeLarge
                height: Theme.fontSizeLarge
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                radius: parent.width / 2
                visible: chatListViewItem.unreadCount > 0 || chatListViewItem.isMarkedAsUnread
            }

            Text {
                id: chatUnreadMessagesCount
                font.pixelSize: Theme.fontSizeExtraSmall
                font.bold: true
                color: Theme.primaryColor
                anchors.centerIn: chatUnreadMessagesCountBackground
                visible: chatListViewItem.unreadCount > 0
                opacity: isMuted ? Theme.opacityHigh : 1.0
                text: Functions.formatUnreadCount(chatListViewItem.unreadCount)
            }

            Rectangle {
                color: isMuted ? ((Theme.colorScheme === Theme.DarkOnLight) ? "lightgray" : "dimgray") : Theme.highlightBackgroundColor
                width: Theme.fontSizeLarge
                height: Theme.fontSizeLarge
                anchors.right: parent.right
                anchors.top: parent.top
                radius: parent.width / 2
                visible: chatListViewItem.unreadMentionCount > 0

                Text {
                    font {
                        pixelSize: Theme.iconSizeExtraSmall
                        bold: true
                    }
                    color: Theme.primaryColor
                    anchors.centerIn: parent
                    visible: chatListViewItem.unreadMentionCount > 0
                    opacity: isMuted ? Theme.opacityHigh : 1.0
                    text: "@"
                }
            }
        }
    }

    Column {
        id: contentColumn
        anchors {
            verticalCenter: parent.verticalCenter
            left: pictureItem.right
            leftMargin: Theme.paddingSmall
            right: parent.right
            rightMargin: Theme.horizontalPageMargin
        }
        spacing: Theme.paddingSmall / 2

        FontMetrics {
            id: primaryTextMetrics
            font.pixelSize: Theme.fontSizeMedium
        }
        FontMetrics {
            id: secondaryTextMetrics
            font.pixelSize: Theme.fontSizeExtraSmall
        }
        FontMetrics {
            id: tertiaryTextMetrics
            font.pixelSize: Theme.fontSizeTiny
        }

        Item {
            id: primaryTextRow
            width: parent.width
            // In home (compatta) la riga del titolo è alta quanto il TESTO, così il
            // titolo sta vicino all'anteprima (niente spazio morto dovuto all'icona).
            // Le icone (muto/verificato), centrate, sporgono di poco a destra: ok.
            // Nelle altre pagine resta il comportamento classico (max con iconSizeSmall).
            clip: !chatListViewItem.useCompactPreview
            height: chatListViewItem.useCompactPreview
                    ? primaryTextMetrics.lineSpacing
                    : Math.max(primaryTextMetrics.lineSpacing, Theme.iconSizeSmall)

            Row {
                id: primaryTextRowInner
                spacing: Theme.paddingMedium
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                Label {
                    id: primaryText
                    textFormat: Text.StyledText
                    font.pixelSize: Theme.fontSizeMedium
                    truncationMode: TruncationMode.Fade
                    maximumLineCount: 1
                    // L'altezza costante è data dal contenitore (primaryTextRow) + clip:
                    // le emoji <img> più alte del testo vengono ritagliate dalla riga e
                    // non la allargano. Il Label rende il testo in modo NATURALE (niente
                    // FixedHeight, che tagliava gli ascendenti in alto).
                    verticalAlignment: Text.AlignVCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(contentColumn.width - (verifiedImage.visible ? (verifiedImage.width + primaryTextRowInner.spacing) :  0) - (mutedImage.visible ? (mutedImage.width + primaryTextRowInner.spacing) :  0), implicitWidth)
                    font.bold: appSettings.highlightUnreadConversations && ( !chatListViewItem.isMuted && (chatListViewItem.unreadCount > 0 || chatListViewItem.isMarkedAsUnread) )
                    color: (appSettings.highlightUnreadConversations && (chatListViewItem.unreadCount > 0)) ? Theme.highlightColor : Theme.primaryColor
                }

                Image {
                    id: verifiedImage
                    anchors.verticalCenter: parent.verticalCenter
                    source: chatListViewItem.isVerified ? "../../images/icon-verified.svg" : ""
                    sourceSize: Qt.size(Theme.iconSizeExtraSmall, Theme.iconSizeExtraSmall)
                    width: Theme.iconSizeSmall
                    height: Theme.iconSizeSmall
                    visible: status === Image.Ready
                }
            }

            // Icona "muto": allineata a destra della riga del titolo
            Image {
                id: mutedImage
                anchors.right: parent.right
                anchors.verticalCenter: primaryTextRowInner.verticalCenter
                source: chatListViewItem.isMuted ? "../js/emoji/1f507.svg" : ""
                sourceSize: Qt.size(Theme.iconSizeExtraSmall, Theme.iconSizeExtraSmall)
                width: Theme.iconSizeSmall
                height: Theme.iconSizeSmall
                visible: status === Image.Ready
            }
        }

        // === Layout CLASSICO (pagine non-home): riga nome + riga messaggio separate ===
        // prologSecondaryText / secondaryText restano i target degli alias: in modalità
        // compatta la Row è invisibile e fa solo da contenitore-dati per combinedPreview.
        Row {
            width: parent.width
            spacing: Theme.paddingSmall
            clip: true
            visible: !chatListViewItem.useCompactPreview
            // lineSpacing (non height) così il testo non viene tagliato.
            height: secondaryTextMetrics.lineSpacing
            Label {
                id: prologSecondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width)
                color: Theme.highlightColor
                textFormat: Text.StyledText
                truncationMode: TruncationMode.Fade
                maximumLineCount: 1
            }
            Label {
                id: secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Theme.paddingMedium - prologSecondaryText.width
                truncationMode: TruncationMode.Fade
                textFormat: Text.StyledText
                maximumLineCount: 1
                visible: prologSecondaryText.width < ( parent.width - Theme.paddingLarge )
            }
        }

        // === Anteprima COMPATTA (home): nome + messaggio in FLUSSO UNICO, fino a 2 righe ===
        // Un solo Text: nome e messaggio condividono la baseline (niente più
        // disallineamento) e le emoji scorrono inline senza tagli (come nei messaggi).
        // L'orario sta in basso a destra, sull'ultima riga.
        Item {
            id: compactPreviewBlock
            width: parent.width
            // Altezza = contenuto, MA cappata a 2 righe (clip). Così:
            // - msg corti (1 riga) → blocco basso, layout compatto (niente spazio vuoto);
            // - msg lunghi → 2 righe e il resto è ritagliato.
            // Il cap via clip funziona con RichText (dove maximumLineCount/elide di Silica
            // non agivano), che ci serve per allineare bene le emoji a inizio riga.
            height: Math.min(combinedPreview.implicitHeight, 2 * secondaryTextMetrics.lineSpacing)
            clip: true
            visible: chatListViewItem.useCompactPreview

            Text {
                id: combinedPreview
                anchors { left: parent.left; top: parent.top }
                // Riserva la colonna dell'orario a destra (su entrambe le righe) per non
                // farci finire il testo sotto.
                width: parent.width - (compactDate.text !== "" ? (compactDate.implicitWidth + Theme.paddingMedium) : 0)
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.primaryColor
                // RichText (come i messaggi): allinea correttamente le emoji a INIZIO riga,
                // che StyledText invece buttava in basso. Il cap a 2 righe è dato dal clip
                // del contenitore (non da maximumLineCount, che con RichText non elideva).
                textFormat: Text.RichText
                wrapMode: Text.Wrap
                text: (prologSecondaryText.text !== ""
                       ? ("<font color=\"" + Theme.highlightColor + "\">" + prologSecondaryText.text + "</font> ")
                       : "")
                      + secondaryText.text
            }

            Label {
                id: compactDate
                anchors { right: parent.right; bottom: parent.bottom }
                font.pixelSize: Theme.fontSizeTiny
                color: Theme.secondaryColor
                maximumLineCount: 1
                text: tertiaryText.text
            }
        }

        // Target alias dell'orario/info-line. In home (compatta) è nascosto e fa solo
        // da contenitore-dati per compactDate; nelle altre pagine è la riga piena.
        Label {
            id: tertiaryText
            width: parent.width
            height: tertiaryTextMetrics.lineSpacing
            clip: true
            visible: !chatListViewItem.useCompactPreview
            font.pixelSize: Theme.fontSizeTiny
            color: Theme.secondaryColor
            truncationMode: TruncationMode.Fade
            maximumLineCount: 1
            verticalAlignment: Text.AlignVCenter
        }
    }

    NeonSeparator {
        id: separator
        anchors {
            bottom: parent.bottom
            bottomMargin: -1
        }

        width: parent.width
    }

}
