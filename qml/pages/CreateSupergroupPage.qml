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

Dialog {
    id: createSupergroupPage
    allowedOrientations: Orientation.All

    property bool isChannel: false

    canAccept: titleField.text.trim().length > 0

    onAccepted: {
        tdLibWrapper.sendRequest({
            "@type": "createNewSupergroupChat",
            "@extra": "openDirectly",
            "title": titleField.text.trim(),
            "is_channel": isChannel,
            "description": descriptionField.text.trim(),
            "for_import": false
        });
    }

    // DialogHeader svuotato: conserva il pulsante Accetta; il titolo lo rendiamo
    // noi in NEON (brand RooTelegram) come prima riga del contenuto.
    DialogHeader {
        id: dialogHeader
        title: ""
        // Annulla/Accetta in bianco per coerenza neon (le label del DialogHeader
        // usano palette.primaryColor; il glow non è aggiungibile su queste interne).
        palette.primaryColor: "#ffffff"
        palette.highlightColor: "#fff3e6"
    }

    SilicaFlickable {
        anchors {
            top: dialogHeader.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        contentHeight: contentColumn.height + Theme.paddingLarge

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            NeonPageHeader {
                text: isChannel ? qsTr("New Channel") : qsTr("New Group")
            }

            TextField {
                id: titleField
                width: parent.width
                label: isChannel ? "Titolo canale" : "Titolo gruppo"
                placeholderText: isChannel ? "Inserisci il titolo del canale" : "Inserisci il titolo del gruppo"
                EnterKey.iconSource: isChannel ? "image://theme/icon-m-enter-next" : "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: {
                    if (isChannel) {
                        descriptionField.forceActiveFocus();
                    } else if (titleField.text.trim().length > 0) {
                        createSupergroupPage.accept();
                    }
                }
            }

            TextArea {
                id: descriptionField
                visible: isChannel
                width: parent.width
                label: "Descrizione (opzionale)"
                placeholderText: "Inserisci una descrizione"
            }
        }

        VerticalScrollDecorator {}
    }
}
