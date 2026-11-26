/*
    Copyright (C) 2020 Sebastian J. Wolf and other contributors
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
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0
import "../"
import "../../js/albumlayout.js" as AlbumLayout

// Album (gruppo di foto/video) impaginato a MOSAICO come Telegram per Android:
// righe e colonne calcolate dalle proporzioni (js/albumlayout.js, porting di
// GroupedMessages.calculate()), ogni foto RITAGLIATA per riempire la sua cella,
// fra una cella e l'altra solo una fuga sottile.
// Prima: Flow a 2 colonne con celle fisse, spacing paddingMedium e foto «contenute»
// (PreserveAspectFit) ⇒ grandi spazi vuoti attorno e fra le immagini.
MessageContentBase {
    id: messageContent
    property string chatId
    readonly property var albumId: rawMessage.media_album_id
    property var albumMessageIds: messageListItem ? messageListItem.messageAlbumMessageIds : []
    onAlbumMessageIdsChanged: albumMessages = getMessages()
    property var albumMessages: getMessages()

    // Mosaico in «unità» (larghezza piena = mosaic.width); un solo fattore di scala.
    readonly property var mosaic: AlbumLayout.calculate(albumMessages.map(function(msg) {
        return AlbumLayout.aspectOf(msg);
    }))
    readonly property real unitScale: mosaic.width > 0 ? width / mosaic.width : 0
    // Fuga fra le celle: sottile come in Telegram (2 px sul POCO).
    readonly property int gap: Math.max(2, Math.round(Theme.paddingSmall / 3))

    clip: true
    height: (width > 0 && mosaic.height > 0) ? Math.round(mosaic.height * unitScale) : defaultExtraContentHeight

    onClicked: {
        if(messageListItem.precalculatedValues.pageIsSelecting) {
            page.toggleMessageSelection(rawMessage);
            return;
        }
        openDetail(-1);
    }
    function getMessages() {
        var msgs = [rawMessage];
        if(messageContent.albumId === '0' || messageContent.albumMessageIds.length < 2) {
            return msgs;
        }
        // getMessages da tdlib non e' piu' veloce: si leggono dal modello.
        chatModel.getMessagesForAlbum(messageContent.albumId, 1).forEach(function(msg){
            msgs.push(msg);
        });
        return msgs;
    }

    function openDetail(index) {
        pageStack.push(Qt.resolvedUrl("../../pages/MediaAlbumPage.qml"), {
                           "messages" : albumMessages,
                           "index": index || 0
                       })
    }

    Component {
        id: photoPreviewComponent
        TDLibPhoto {
            // Niente MessagePhoto qui: si da' l'altezza da solo (larghezza/aspetto) e
            // mostra la foto intera (Fit), cioe' proprio le bande vuote da evitare,
            // oltre al binding loop su height. TDLibImage di suo RITAGLIA (Crop).
            anchors.fill: parent
            photo: albumMessages[modelIndex].content.photo
            highlighted: modelHighlighted
            deferFullImage: !!messageContent.messageListItem && !!messageContent.messageListItem.precalculatedValues
                            && messageContent.messageListItem.precalculatedValues.viewMoving === true
            // Stesso tetto di decodifica delle anteprime singole (vedi MessagePhoto).
            Component.onCompleted: image.maxSourceDimension = 720
        }
    }
    Component {
        id: videoPreviewComponent
        Item {
            property bool highlighted: modelHighlighted
            anchors.fill: parent
            clip: true
            TDLibThumbnail {
                id: tdLibImage
                width: parent.width //don't use anchors here for easier custom scaling
                height: parent.height
                fillMode: Image.PreserveAspectCrop
                highlighted: parent.highlighted
                thumbnail: albumMessages[modelIndex].content.video.thumbnail
                minithumbnail: albumMessages[modelIndex].content.video.minithumbnail
            }
            Rectangle {
                anchors {
                    fill: videoIcon
                    leftMargin: -Theme.paddingSmall
                    topMargin: -Theme.paddingSmall
                    bottomMargin: -Theme.paddingSmall
                    rightMargin: -Theme.paddingLarge
                }
                radius: Theme.paddingSmall
                color: Theme.rgba(Theme.overlayBackgroundColor, 0.4)
            }

            Icon {
                id: videoIcon
                source: "image://theme/icon-m-video"
                width: Theme.iconSizeSmall
                height: Theme.iconSizeSmall
                highlighted: parent.highlighted
                anchors {
                    right: parent.right
                    rightMargin: Theme.paddingSmall
                    bottom: parent.bottom
                }
            }
        }
    }

    // Album senza cornice, in tutti i temi (vedi MessageListViewItem.bareAlbum):
    // il mosaico fa da fumetto, quindi angoli arrotondati come i fumetti del tema.
    readonly property bool bare: !!messageListItem && messageListItem.bareAlbum === true

    Item {
        id: mosaicArea
        anchors.fill: parent
        layer.enabled: messageContent.bare
        layer.effect: OpacityMask {
            maskSource: Item {
                width: mosaicArea.width
                height: mosaicArea.height
                Rectangle {
                    anchors.fill: parent
                    radius: messageListItem.bubbleRadius
                }
            }
        }

        Repeater {
            model: albumMessages
            delegate: BackgroundItem {
                id: mediaBackgroundItem
                // Rettangolo della cella in unità; i bordi interni cedono mezza fuga
                // per parte, quelli sul perimetro del mosaico nessuna.
                readonly property var cell: (index < messageContent.mosaic.rects.length)
                                            ? messageContent.mosaic.rects[index] : { x: 0, y: 0, w: 0, h: 0 }
                readonly property int half: Math.floor(messageContent.gap / 2)
                readonly property int rest: messageContent.gap - half
                readonly property bool innerLeft: cell.x > 0.5
                readonly property bool innerTop: cell.y > 0.5
                readonly property bool innerRight: cell.x + cell.w < messageContent.mosaic.width - 0.5
                readonly property bool innerBottom: cell.y + cell.h < messageContent.mosaic.height - 0.5
                readonly property int x0: Math.round(cell.x * messageContent.unitScale)
                readonly property int y0: Math.round(cell.y * messageContent.unitScale)
                readonly property int x1: Math.round((cell.x + cell.w) * messageContent.unitScale)
                readonly property int y1: Math.round((cell.y + cell.h) * messageContent.unitScale)

                x: x0 + (innerLeft ? half : 0)
                y: y0 + (innerTop ? half : 0)
                width: Math.max(0, x1 - x0 - (innerLeft ? half : 0) - (innerRight ? rest : 0))
                height: Math.max(0, y1 - y0 - (innerTop ? half : 0) - (innerBottom ? rest : 0))
                clip: true

                readonly property bool isSelected: messageListItem.precalculatedValues.pageIsSelecting && page.selectedMessages.some(function(existingMessage) {
                    return existingMessage.id === albumMessages[index].id
                });
                highlighted: isSelected || down || messageContent.highlighted
                onClicked: {
                    if(messageListItem.precalculatedValues.pageIsSelecting) {
                        page.toggleMessageSelection(albumMessages[index]);
                        return;
                    }
                    openDetail(index);
                }
                onPressAndHold: {
                    page.toggleMessageSelection(albumMessages[index]);
                }

                Loader {
                    anchors.fill: parent
                    readonly property int modelIndex: index
                    readonly property bool modelHighlighted: mediaBackgroundItem.highlighted
                    sourceComponent: albumMessages[index].content["@type"] === 'messageVideo' ? videoPreviewComponent : photoPreviewComponent
                    opacity: status === Loader.Ready
                    Behavior on opacity {FadeAnimator{}}
                }

                Rectangle {
                    visible: mediaBackgroundItem.isSelected
                    anchors.fill: parent
                    color: 'transparent'
                    border.color: Theme.highlightColor
                    border.width: Theme.paddingSmall
                }
            }
        }
    }

    // Album senza cornice: ora e spunte in una pillola scura sopra
    // l'angolo in basso a destra, come in Telegram.
    Rectangle {
        visible: messageContent.bare && dateLabel.text !== ""
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: Theme.paddingSmall
        }
        width: dateLabel.implicitWidth + 2 * Theme.paddingSmall
        height: dateLabel.implicitHeight + Theme.paddingSmall / 2
        radius: height / 2
        color: Qt.rgba(0, 0, 0, 0.45)
        Label {
            id: dateLabel
            anchors.centerIn: parent
            text: messageContent.bare ? messageListItem.dateStatusText : ""
            font.pixelSize: Theme.fontSizeTiny
            color: "#ffffff"
        }
    }
}
