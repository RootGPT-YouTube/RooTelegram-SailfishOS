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

BackgroundItem {
    id: optionItem

    property string title
    property string value
    property url iconSource
    property bool showDisclosure: false
    property bool destructive: false

    width: parent ? parent.width : Screen.width
    height: Theme.itemSizeLarge

    Icon {
        id: optionIcon
        anchors {
            left: parent.left
            leftMargin: Theme.horizontalPageMargin
            verticalCenter: parent.verticalCenter
        }
        source: optionItem.iconSource
        highlighted: optionItem.pressed
        visible: source !== ""
    }

    Label {
        id: titleLabel
        anchors {
            left: optionIcon.visible ? optionIcon.right : parent.left
            leftMargin: optionIcon.visible ? Theme.paddingMedium : Theme.horizontalPageMargin
            right: valueLabel.left
            rightMargin: Theme.paddingMedium
            verticalCenter: parent.verticalCenter
        }
        color: optionItem.destructive ? Theme.errorColor : Theme.primaryColor
        text: optionItem.title
        truncationMode: TruncationMode.Fade
    }

    Label {
        id: valueLabel
        anchors {
            right: disclosureIcon.visible ? disclosureIcon.left : parent.right
            rightMargin: Theme.horizontalPageMargin
            verticalCenter: parent.verticalCenter
        }
        color: optionItem.destructive ? Theme.errorColor : Theme.highlightColor
        text: optionItem.value
        visible: text !== ""
        truncationMode: TruncationMode.Fade
    }

    Icon {
        id: disclosureIcon
        anchors {
            right: parent.right
            rightMargin: Theme.horizontalPageMargin
            verticalCenter: parent.verticalCenter
        }
        source: "image://theme/icon-m-right"
        highlighted: optionItem.pressed
        visible: optionItem.showDisclosure
    }

    Separator {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        color: Theme.primaryColor
        horizontalAlignment: Qt.AlignHCenter
    }
}
