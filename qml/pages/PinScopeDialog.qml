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

Dialog {
    id: pinScopeDialog
    allowedOrientations: Orientation.All

    property string partnerName: ""
    // "both" oppure "self"
    property string selectedScope: "both"

    DialogHeader {
        id: dialogHeader
        acceptText: qsTr("Pin")
        cancelText: qsTr("Cancel")
    }

    Column {
        anchors {
            top: dialogHeader.bottom
            left: parent.left
            right: parent.right
            margins: Theme.horizontalPageMargin
        }
        spacing: Theme.paddingLarge

        Label {
            width: parent.width
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.highlightColor
            text: qsTr("Pin message")
        }

        Label {
            width: parent.width
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.secondaryHighlightColor
            text: partnerName.length > 0
                ? qsTr("Choose where to pin this message in the chat with %1.").arg(partnerName)
                : qsTr("Choose where to pin this message.")
        }

        ComboBox {
            id: scopeCombo
            width: parent.width
            label: qsTr("Pin for")
            currentIndex: pinScopeDialog.selectedScope === "self" ? 1 : 0
            menu: ContextMenu {
                MenuItem { text: qsTr("Both users") }
                MenuItem { text: qsTr("Only me") }
            }
            onCurrentIndexChanged: {
                pinScopeDialog.selectedScope = currentIndex === 1 ? "self" : "both"
            }
        }
    }
}
