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
import "../../js/twemoji.js" as Emoji

// Rendering di un messaggio "contatto" (messageContact), compatibile con i
// contatti inviati da Telegram ufficiale (#7): avatar a 2 iniziali, nome,
// numero, separatore e pulsante azione. Long-press sul resto della scheda apre
// il menu del messaggio; "Aggiungi ai contatti" salva in rubrica Sailfish.
MessageContentBase {
    id: contentItem
    width: parent ? parent.width : implicitWidth
    height: contactColumn.height + 2 * Theme.paddingMedium

    readonly property var contact: (rawMessage && rawMessage.content && rawMessage.content.contact) ? rawMessage.content.contact : ({})
    readonly property string firstName: contact.first_name || ""
    readonly property string lastName: contact.last_name || ""
    readonly property string fullName: ((firstName + " " + lastName).trim())
    readonly property string phoneText: contact.phone_number ? ("+" + String(contact.phone_number).replace(/^\+/, "")) : ""
    readonly property bool isTelegramUser: !!(contact.user_id && contact.user_id.toString() !== "0")

    function initials() {
        var a = firstName ? firstName.charAt(0) : "";
        var b = lastName ? lastName.charAt(0) : "";
        var r = (a + b).toUpperCase().trim();
        return r !== "" ? r : "?";
    }

    function avatarColor() {
        var palette = ["#e17076", "#7bc862", "#65aadd", "#a695e7", "#ee7aae", "#6ec9cb", "#faa774"];
        var s = fullName + (contact.phone_number || "");
        var h = 0;
        for (var i = 0; i < s.length; i++) { h = (h * 31 + s.charCodeAt(i)) % 100000; }
        return palette[h % palette.length];
    }

    // Salvataggio in rubrica Sailfish: il PeopleModel/Person nemomobile è pesante
    // (carica l'intera rubrica), quindi lo creiamo SOLO al momento del salvataggio.
    function saveToAddressBook() {
        if (phoneText === "") {
            return;
        }
        if (!appSettings.isPermissionGranted("contacts")) {
            appNotification.show(qsTr("Contacts are turned off in RooTelegram settings."));
            return;
        }
        contactSaverLoader.active = true;
        contactSaverLoader.item.save(firstName, lastName, phoneText);
    }

    Loader {
        id: contactSaverLoader
        active: false
        sourceComponent: Component {
            Item {
                property var _model: peopleModelInstance
                function save(fn, ln, num) {
                    contactPerson.firstName = fn;
                    contactPerson.lastName = ln;
                    contactPerson.phoneDetails = [{
                        "type": Person.PhoneNumberType,
                        "subType": Person.PhoneSubTypeMobile,
                        "number": num
                    }];
                    peopleModelInstance.savePerson(contactPerson);
                }
                PeopleModel {
                    id: peopleModelInstance
                    onSavePersonSucceeded: appNotification.show(qsTr("Contact saved to address book"))
                    onSavePersonFailed: appNotification.show(qsTr("Could not save the contact"))
                }
                Person { id: contactPerson }
            }
        }
    }

    onClicked: {
        // Tap sulla scheda (non sul pulsante): apri la chat se è su Telegram.
        if (isTelegramUser) {
            tdLibWrapper.createPrivateChat(contact.user_id.toString(), "openDirectly");
        }
    }

    Column {
        id: contactColumn
        y: Theme.paddingMedium
        width: parent.width
        spacing: Theme.paddingMedium

        Row {
            width: parent.width
            spacing: Theme.paddingMedium

            Rectangle {
                id: avatar
                width: Theme.itemSizeSmall
                height: width
                radius: width / 2
                color: contentItem.avatarColor()
                Label {
                    anchors.centerIn: parent
                    text: contentItem.initials()
                    color: "white"
                    font.pixelSize: Theme.fontSizeMedium
                    font.bold: true
                }
            }

            Column {
                width: parent.width - avatar.width - parent.spacing
                anchors.verticalCenter: avatar.verticalCenter

                Label {
                    width: parent.width
                    text: Emoji.emojify(contentItem.fullName || qsTr("Contact"), font.pixelSize)
                    textFormat: Text.StyledText
                    truncationMode: TruncationMode.Fade
                    font.bold: true
                    color: contentItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeMedium
                }
                Label {
                    width: parent.width
                    visible: text !== ""
                    text: contentItem.phoneText
                    truncationMode: TruncationMode.Fade
                    color: contentItem.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        Separator {
            width: parent.width
            color: Theme.secondaryColor
            opacity: 0.4
            horizontalAlignment: Qt.AlignHCenter
        }

        // Pulsanti azione: "Message" (solo per utenti Telegram) e sempre
        // "Add to contacts" per salvare in rubrica Sailfish (#7).
        Row {
            width: parent.width
            height: Theme.itemSizeExtraSmall

            BackgroundItem {
                id: messageButton
                visible: contentItem.isTelegramUser
                width: visible ? parent.width / 2 : 0
                height: parent.height
                Label {
                    anchors.centerIn: parent
                    text: qsTr("Message")
                    color: messageButton.highlighted ? Theme.highlightColor : Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                }
                onClicked: tdLibWrapper.createPrivateChat(contact.user_id.toString(), "openDirectly")
            }

            BackgroundItem {
                id: addButton
                width: contentItem.isTelegramUser ? parent.width / 2 : parent.width
                height: parent.height
                Label {
                    anchors.centerIn: parent
                    text: qsTr("Add to contacts")
                    color: addButton.highlighted ? Theme.highlightColor : Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                }
                onClicked: contentItem.saveToAddressBook()
            }
        }
    }
}
