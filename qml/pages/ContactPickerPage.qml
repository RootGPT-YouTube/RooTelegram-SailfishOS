/*
    Copyright (C) 2026 RooTelegram contributors

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
import org.nemomobile.contacts 1.0

// Selettore contatto dalla rubrica di SailfishOS, per inviarlo in chat (#7B).
// Emette contactPicked(nome, cognome, telefono) e torna indietro.
Page {
    id: page
    allowedOrientations: Orientation.All

    signal contactPicked(string firstName, string lastName, string phoneNumber)

    PeopleModel {
        id: peopleModel
        requiredProperty: PeopleModel.PhoneNumberRequired
        filterType: PeopleModel.FilterAll
        // NB: il filtro va impostato imperativamente da SearchField.onTextChanged
        // (l'id searchField è nell'header della ListView, non visibile qui).
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        currentIndex: -1
        model: peopleModel

        header: Column {
            width: listView.width
            PageHeader { title: qsTr("Send contact") }
            SearchField {
                id: searchField
                width: parent.width
                placeholderText: qsTr("Search contact")
                inputMethodHints: Qt.ImhNoAutoUppercase
                onTextChanged: peopleModel.filterPattern = text
            }
        }

        delegate: ListItem {
            id: contactItem
            contentHeight: Theme.itemSizeMedium
            readonly property var person: peopleModel.get(index)
            readonly property string phone: (person && person.phoneNumbers && person.phoneNumbers.length > 0)
                                            ? person.phoneNumbers[0] : ""

            Column {
                anchors {
                    left: parent.left; right: parent.right
                    leftMargin: Theme.horizontalPageMargin; rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                Label {
                    width: parent.width
                    text: contactItem.person ? contactItem.person.displayLabel : ""
                    truncationMode: TruncationMode.Fade
                    color: contactItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                }
                Label {
                    width: parent.width
                    text: contactItem.phone
                    visible: text !== ""
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: Theme.fontSizeSmall
                    color: contactItem.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                }
            }

            onClicked: {
                if (!phone) {
                    return;
                }
                page.contactPicked(person.firstName || "", person.lastName || "", phone);
                pageStack.pop();
            }
        }

        ViewPlaceholder {
            enabled: listView.count === 0
            text: qsTr("No contacts with a phone number")
        }

        VerticalScrollDecorator {}
    }
}
