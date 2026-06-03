/*
    Copyright (C) 2026 RootGPT

    This file is part of RooTelegram.

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/
import QtQuick 2.6
import Sailfish.Silica 1.0
import QtGraphicalEffects 1.0
import "../components"

// Elenco delle cartelle in cui inserire una chat (aperta dal long-press sulla chat).
// Tema Neon-Cyberpunk: titolo neon (come RooTelegram), elenco puntato con pallini
// bianchi al neon e nomi cartella bianchi al neon.
Page {
    id: addToFolderPage
    // var, non qlonglong (i tipi C++ non esistono in QML).
    property var chatId: 0

    SilicaListView {
        anchors.fill: parent
        model: chatFoldersModel ? chatFoldersModel.count : 0

        header: NeonPageHeader {
            text: qsTr("Add to folder")
        }

        delegate: BackgroundItem {
            id: folderDelegate
            width: parent.width
            height: Theme.itemSizeSmall

            Row {
                anchors {
                    left: parent.left
                    leftMargin: Theme.horizontalPageMargin
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.paddingLarge

                // Pallino bianco al neon (alone via layer.effect con transparentBorder,
                // come il brand: senza transparentBorder l'alone verrebbe clippato).
                Rectangle {
                    id: dot
                    width: Theme.paddingMedium
                    height: width
                    radius: width / 2
                    color: "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                    layer.enabled: true
                    layer.effect: Glow {
                        color: "#ffffff"
                        radius: 10
                        samples: 21
                        spread: 0.4
                        transparentBorder: true
                    }
                }

                // Nome cartella bianco al neon.
                Label {
                    id: folderLabel
                    width: parent.width - dot.width - Theme.paddingLarge
                    anchors.verticalCenter: parent.verticalCenter
                    truncationMode: TruncationMode.Fade
                    font.italic: true
                    text: chatFoldersModel.getName(index)
                    color: folderDelegate.highlighted ? Theme.highlightColor : "#ffffff"
                    layer.enabled: true
                    layer.effect: Glow {
                        color: "#ffffff"
                        radius: 8
                        samples: 17
                        spread: 0.3
                        transparentBorder: true
                    }
                }
            }

            onClicked: {
                var folderName = chatFoldersModel.getName(index);
                tdLibWrapper.addChatToFolder(addToFolderPage.chatId, chatFoldersModel.getId(index));
                appNotification.show(qsTr("Added to folder: %1").arg(folderName));
                pageStack.pop();
            }
        }

        ViewPlaceholder {
            enabled: !chatFoldersModel || chatFoldersModel.count === 0
            text: qsTr("No folders")
        }

        VerticalScrollDecorator {}
    }
}
