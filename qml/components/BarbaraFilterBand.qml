/*
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

// Fascia del tema Barbara sotto l'header della home, su DUE righe adiacenti che
// non si confondono:
//
//   riga A — filtri per TIPO (Tutte / Gruppi / Canali): occupano tutta la
//            larghezza in TRE COLONNE UGUALI, testo centrato, mono maiuscolo,
//            angoli retti;
//   riga B — CARTELLE (chatFoldersModel): chip a pillola su UNA SOLA RIGA
//            scorrevole in orizzontale, che non va MAI a capo, con in coda il
//            pulsante «+» tratteggiato che apre l'elenco cartelle.
//
// Tema Classic (BarbaraTheme.classic): niente filtri per tipo; UNA riga di
// schede «Tutte | cartelle…» dentro una pillola, come le cartelle di Telegram
// per Android (scheda attiva = pillola chiara con testo blu, conteggi in un
// cerchietto grigio). Senza cartelle la fascia sparisce, come nell'app ufficiale.
//
// Il componente e' solo presentazione: non tocca i modelli, emette segnali e la
// pagina decide cosa fare (cosi' la logica di cambio cartella resta una sola,
// quella gia' collaudata di OverviewPage).

import QtQuick 2.6
import Sailfish.Silica 1.0
import "."

Item {
    id: band

    // Cartella attiva (0 = nessuna) e filtro per tipo (0 tutte, 1 gruppi, 2 canali).
    property int activeFolderId: 0
    property int typeFilter: 0
    // Mappa "<folderId>" -> messaggi non letti, da chatListModel.getFolderUnreadCounts().
    property var folderUnread: ({})

    signal folderClicked(int folderId)
    signal typeFilterClicked(int filterType)
    signal editFoldersClicked()

    readonly property bool hasFolders: chatFoldersModel.count > 0
    readonly property bool classic: BarbaraTheme.classic
    readonly property real sidePadding: Theme.paddingLarge
    readonly property real rowGap: Theme.paddingSmall

    width: parent ? parent.width : 0
    height: !visible ? 0
            : classic ? (hasFolders ? (Theme.paddingSmall + folderRow.height + Theme.paddingSmall) : 0)
            : (Theme.paddingMedium + typeFilterRow.height
               + (hasFolders ? (rowGap + folderRow.height) : 0) + Theme.paddingMedium)

    // Fondo del pannello: superficie DEL TEMA, con bordo inferiore da 1px.
    Rectangle {
        anchors.fill: parent
        color: band.classic ? BarbaraTheme.surface : BarbaraTheme.panelTranslucent
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: BarbaraTheme.borderWidth
            color: BarbaraTheme.glassBorder
        }
    }

    // ── Riga A: filtri per tipo, tre colonne uguali a tutta larghezza ──────
    Row {
        id: typeFilterRow
        visible: !band.classic
        anchors {
            top: parent.top
            topMargin: Theme.paddingMedium
            left: parent.left
            right: parent.right
            leftMargin: band.sidePadding
            rightMargin: band.sidePadding
        }
        spacing: Theme.paddingSmall
        height: !band.classic ? Math.round(Theme.fontSizeSmall * 1.2) + 2 * Theme.paddingSmall : 0

        Repeater {
            model: 3
            delegate: Item {
                id: typeCell
                // Tre colonne UGUALI: la larghezza e' la stessa per tutte e tre,
                // lo spazio che avanza per l'arrotondamento resta a destra.
                width: Math.floor((typeFilterRow.width - 2 * typeFilterRow.spacing) / 3)
                height: typeFilterRow.height

                readonly property bool isCurrent: band.typeFilter === index

                Rectangle {
                    anchors.fill: parent
                    // Angoli retti: e' cio' che distingue i filtri di tipo dalle
                    // pillole delle cartelle nella riga sotto.
                    radius: 0
                    color: typeCell.isCurrent ? BarbaraTheme.accent
                         : (typeArea.pressed ? BarbaraTheme.accentWash : "transparent")
                    border.width: typeCell.isCurrent ? 0 : BarbaraTheme.borderWidth
                    border.color: BarbaraTheme.glassBorder
                    Behavior on color { ColorAnimation { duration: BarbaraTheme.pressDuration } }
                }

                Label {
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: index === 0 ? qsTr("All")
                        : (index === 1 ? qsTr("Groups") : qsTr("Channels"))
                    font.family: BarbaraTheme.fontFamilyMono
                    font.pixelSize: BarbaraTheme.fontSizeMeta
                    font.capitalization: Font.AllUppercase
                    font.bold: typeCell.isCurrent
                    color: typeCell.isCurrent ? BarbaraTheme.onAccent : BarbaraTheme.inkSecondary
                    truncationMode: TruncationMode.Fade
                    maximumLineCount: 1
                }

                MouseArea {
                    id: typeArea
                    anchors.fill: parent
                    onClicked: band.typeFilterClicked(index)
                }
            }
        }
    }

    // ── Riga B: cartelle, una sola riga scorrevole, mai a capo ─────────────
    // Classic: la pillola che contiene le schede.
    Rectangle {
        visible: band.classic && band.hasFolders
        anchors.fill: folderRow
        radius: height / 2
        color: BarbaraTheme.glass
    }

    ListView {
        id: folderRow
        visible: band.hasFolders
        anchors {
            top: band.classic ? parent.top : typeFilterRow.bottom
            topMargin: band.classic ? Theme.paddingSmall : band.rowGap
            left: parent.left
            right: parent.right
            leftMargin: band.classic ? Theme.horizontalPageMargin : 0
            rightMargin: band.classic ? Theme.horizontalPageMargin : 0
        }
        height: !visible ? 0
                : band.classic ? Math.round(Theme.itemSizeExtraSmall * 0.85)
                : Math.round(Theme.itemSizeExtraSmall * 0.62)
        orientation: ListView.Horizontal
        // I chip sfiorano i bordi della pagina quando si scorre, ma partono
        // allineati al margine come il resto della fascia.
        leftMargin: band.classic ? Theme.paddingSmall : band.sidePadding
        rightMargin: band.classic ? Theme.paddingSmall : band.sidePadding
        spacing: band.classic ? 0 : Theme.paddingSmall
        clip: true

        // Classic: prima scheda fissa «Tutte» (spegne cartella e filtro).
        header: Item {
            visible: band.classic
            // ⚠️ Larghezza legata al TEMA, non a `visible`: all'avvio le cartelle non
            // sono ancora caricate, la ListView è invisibile e un `visible ? … : 0`
            // faceva nascere l'intestazione larga 0; arrivate le cartelle si
            // allargava, ma la vista restava ferma e «Tutte» finiva fuori a sinistra.
            width: band.classic ? allTabLabel.implicitWidth + 2 * Theme.paddingLarge : 0
            height: folderRow.height
            // Cambio di tema dal vivo (Barbara → Classic): l'intestazione passa da 0
            // alla sua larghezza; si riporta la vista all'inizio per mostrarla.
            onWidthChanged: if (band.classic) folderRow.positionViewAtBeginning()
            readonly property bool isCurrent: band.activeFolderId === 0
            Rectangle {
                anchors.fill: parent
                anchors.margins: Theme.paddingSmall / 2
                radius: height / 2
                color: parent.isCurrent ? Theme.rgba(BarbaraTheme.ink, BarbaraTheme.dark ? 0.08 : 0.06)
                     : (allTabArea.pressed ? BarbaraTheme.accentWash : "transparent")
            }
            Label {
                id: allTabLabel
                anchors.centerIn: parent
                text: qsTr("All")
                font.pixelSize: Theme.fontSizeSmall
                font.bold: parent.isCurrent
                color: parent.isCurrent ? BarbaraTheme.accent : BarbaraTheme.inkSecondary
            }
            MouseArea {
                id: allTabArea
                anchors.fill: parent
                onClicked: band.typeFilterClicked(0)
            }
        }
        // Niente decoratore: la scrollbar qui e' nascosta per scelta di design.
        model: chatFoldersModel

        delegate: Item {
            id: chip
            width: chipRow.width + 2 * (band.classic ? Theme.paddingLarge : Theme.paddingMedium)
            height: folderRow.height

            readonly property int chipFolderId: folderId
            readonly property bool isCurrent: band.activeFolderId === chipFolderId
            readonly property int chipUnread: {
                var counts = band.folderUnread;
                if (!counts) {
                    return 0;
                }
                var value = counts[String(chip.chipFolderId)];
                return value ? value : 0;
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: band.classic ? Theme.paddingSmall / 2 : 0
                radius: height / 2
                color: band.classic
                       ? (chip.isCurrent ? Theme.rgba(BarbaraTheme.ink, BarbaraTheme.dark ? 0.08 : 0.06)
                          : (chipArea.pressed ? BarbaraTheme.accentWash : "transparent"))
                     : chip.isCurrent ? BarbaraTheme.accent
                     : (chipArea.pressed ? BarbaraTheme.accentWash : BarbaraTheme.glass)
                border.width: BarbaraTheme.borderWidth
                border.color: chip.isCurrent ? BarbaraTheme.accent : BarbaraTheme.glassBorder
                Behavior on color { ColorAnimation { duration: BarbaraTheme.pressDuration } }
            }

            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: Theme.paddingSmall
                height: parent.height

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !band.classic
                    source: "image://theme/icon-m-folder?"
                            + (chip.isCurrent ? BarbaraTheme.onAccent : BarbaraTheme.inkSecondary)
                    width: !band.classic ? Theme.iconSizeExtraSmall : 0
                    height: width
                    sourceSize: Qt.size(Theme.iconSizeExtraSmall, Theme.iconSizeExtraSmall)
                    fillMode: Image.PreserveAspectFit
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: folderName
                    font.pixelSize: band.classic ? Theme.fontSizeSmall : Theme.fontSizeExtraSmall
                    font.bold: band.classic && chip.isCurrent
                    color: band.classic ? (chip.isCurrent ? BarbaraTheme.accent : BarbaraTheme.inkSecondary)
                         : (chip.isCurrent ? BarbaraTheme.onAccent : BarbaraTheme.ink)
                    maximumLineCount: 1
                }

                // Badge non letti della cartella.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: chip.chipUnread > 0
                    width: visible ? Math.max(height, folderBadge.implicitWidth + Theme.paddingSmall) : 0
                    height: Math.round(Theme.fontSizeTiny * 1.6)
                    radius: Math.round(height / 2)
                    // Sul chip attivo il badge poggia su un velo dell'inchiostro,
                    // non sull'ambra: sull'accento pieno non si leggerebbe.
                    // Classic: cerchietto grigio (blu sulla scheda attiva).
                    color: band.classic ? (chip.isCurrent ? BarbaraTheme.attention : BarbaraTheme.mutedBadge)
                         : chip.isCurrent ? Theme.rgba(BarbaraTheme.onAccent, BarbaraTheme.dark ? 0.22 : 0.28)
                                          : BarbaraTheme.attention
                    Label {
                        id: folderBadge
                        anchors.centerIn: parent
                        text: chip.chipUnread > 99 ? "99+" : chip.chipUnread
                        font.family: BarbaraTheme.fontFamilyMono
                        font.pixelSize: BarbaraTheme.fontSizeMetaSmall
                        font.bold: true
                        color: band.classic ? "#ffffff"
                             : (chip.isCurrent ? BarbaraTheme.onAccent : BarbaraTheme.onAttention)
                    }
                }
            }

            MouseArea {
                id: chipArea
                anchors.fill: parent
                onClicked: band.folderClicked(chip.chipFolderId)
            }
        }

        // In coda: «+» tondo col bordo TRATTEGGIATO (unico bordo tratteggiato del
        // tema), che apre la pagina delle cartelle.
        footer: Item {
            // Classic: nessun «+» (le cartelle si gestiscono dal menu).
            visible: !band.classic
            width: !band.classic ? plusButton.width + Theme.paddingMedium : 0
            height: folderRow.height

            Item {
                id: plusButton
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Theme.paddingSmall
                width: Math.round(folderRow.height * 0.78)
                height: width

                // Rectangle non sa fare i bordi tratteggiati: serve il Canvas.
                Canvas {
                    id: plusBorder
                    anchors.fill: parent
                    readonly property color strokeColor: BarbaraTheme.glassBorder
                    onStrokeColorChanged: requestPaint()
                    onPaint: {
                        // Durante la transizione hasFolders=false -> true (badge
                        // cartella che compaiono all'apertura della home) folderRow.height
                        // passa per 0/1px per un frame: senza clamp (Math.min(w,h)-2)/2
                        // diventa negativo e ctx.arc() abortisce con "Incorrect argument
                        // radius", che ha fatto crashare il QSGRenderThread.
                        var radius = (Math.min(width, height) - 2) / 2;
                        if (radius <= 0) {
                            return;
                        }
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.clearRect(0, 0, width, height);
                        ctx.strokeStyle = plusBorder.strokeColor;
                        ctx.lineWidth = 1;
                        if (ctx.setLineDash) {
                            ctx.setLineDash([3, 3]);
                        }
                        ctx.beginPath();
                        ctx.arc(width / 2, height / 2, radius, 0, 2 * Math.PI);
                        ctx.stroke();
                    }
                }

                Label {
                    anchors.centerIn: parent
                    text: "+"
                    font.family: BarbaraTheme.fontFamilyMono
                    font.pixelSize: Theme.fontSizeSmall
                    color: BarbaraTheme.inkSecondary
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: band.editFoldersClicked()
                }
            }
        }
    }
}
