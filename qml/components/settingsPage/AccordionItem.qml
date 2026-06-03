/*
    Copyright (C) 2021 Sebastian J. Wolf and other contributors

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
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0

Item {
    id: area
    width: parent.width
    height: button.height + content.height
    property alias icon: image
    property alias text: label.text
    property alias asynchronous: content.asynchronous
    property bool expanded: false
    default property alias els: content.sourceComponent
    states: [
        State {
            when: area.expanded
            PropertyChanges { target: image; rotation: 90 }
            PropertyChanges { target: content; height: content.implicitHeight + Theme.paddingLarge; opacity: 1.0 }
        }
    ]
    transitions: Transition {
        to: "*"
        enabled: area.parent.animate
        NumberAnimation { target: content; properties: "height, opacity"; duration: 200}
        NumberAnimation { target: image; properties: "rotation"; duration: 200}
    }
    Connections {
        target: area.parent
        onSetActiveArea: {
            var expand = (activeAreaTitle === area.text);
            if(area.expanded && !expand && area.parent.scrollUpFlickable) {
                area.parent.scrollUpFlickable(content.implicitHeight + Theme.paddingLarge);
            }

            area.expanded = expand;
        }
    }
    BackgroundItem {
        id: button
        height: Theme.itemSizeMedium
        onClicked: {
            area.parent.animate = true;
            area.parent.setActiveArea(area.expanded ? -1 : area.text)
        }
        // "Cartello di vetro": pannello translucido + bordo arancione luminoso
        // (stesso linguaggio dei fumetti glassmorphism delle chat). Niente blur (CPU).
        Rectangle {
            id: glassCard
            anchors.fill: parent
            anchors.leftMargin: Theme.horizontalPageMargin
            anchors.rightMargin: Theme.horizontalPageMargin
            anchors.topMargin: Theme.paddingSmall / 2
            anchors.bottomMargin: Theme.paddingSmall / 2
            radius: Theme.paddingLarge
            color: Theme.rgba("#ffffff", (button.highlighted || area.expanded) ? 0.14 : 0.06)
            border.width: 2
            border.color: Theme.rgba("#ff8a3d", (button.highlighted || area.expanded) ? 0.80 : 0.45)
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }
        }
        // Scritta della scheda in NEON BIANCO, centrata: alone (Glow) + nucleo nitido.
        Label {
            id: labelHalo
            anchors {
                left: glassCard.left
                right: glassCard.right
                verticalCenter: glassCard.verticalCenter
                leftMargin: Theme.paddingLarge
                rightMargin: Theme.paddingLarge
            }
            horizontalAlignment: Text.AlignHCenter
            truncationMode: TruncationMode.Fade
            text: label.text
            font.family: Theme.fontFamilyHeading
            font.italic: true
            color: "#ffffff"
            textFormat: Text.PlainText
            layer.enabled: true
            layer.effect: Glow {
                color: "#ffffff"
                radius: 12
                samples: 25
                spread: 0.20
                transparentBorder: true
            }
        }
        Label {
            id: label
            anchors {
                left: glassCard.left
                right: glassCard.right
                verticalCenter: glassCard.verticalCenter
                leftMargin: Theme.paddingLarge
                rightMargin: Theme.paddingLarge
            }
            horizontalAlignment: Text.AlignHCenter
            truncationMode: TruncationMode.Fade
            font.family: Theme.fontFamilyHeading
            font.italic: true
            color: "#ffffff"
            textFormat: Text.PlainText
        }
        // Freccia rimossa dall'UI (id mantenuto per alias `icon` e stato expanded).
        HighlightImage {
            id: image
            visible: false
            width: 0
            source: "image://theme/icon-m-left"
            rotation: -90
        }
    }
    Loader {
        id: content
        width: parent.width
        height: 0
        opacity: 0
        anchors.top: button.bottom
        asynchronous: true
        clip: true
    }
}
