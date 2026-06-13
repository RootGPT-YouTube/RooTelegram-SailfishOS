import QtQuick 2.6
import Sailfish.Silica 1.0

// Chooser allegato-posizione, sullo stile dell'app ufficiale Telegram:
// "Invia posizione attuale" oppure "Condividi posizione in tempo reale" per una
// durata. Se sulla chat è già attiva una live location, offre lo stop.
// L'esito viene comunicato al chiamante via le property result* su accepted.
Dialog {
    id: dialog

    property bool sharingActive: false

    // Esito: "" (annullato), "current", "live", "stop"; period in secondi se live.
    property string resultMode: ""
    property int resultPeriod: 0

    canAccept: resultMode !== ""

    function choose(mode, period) {
        dialog.resultMode = mode;
        dialog.resultPeriod = period || 0;
        dialog.accept();
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            DialogHeader {
                title: qsTr("Location")
                acceptText: qsTr("Close")
            }

            BackgroundItem {
                visible: dialog.sharingActive
                width: parent.width
                height: Theme.itemSizeMedium
                onClicked: dialog.choose("stop")
                Row {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    height: parent.height
                    spacing: Theme.paddingLarge
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "image://theme/icon-m-clear?" + Theme.highlightColor
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Stop sharing live location")
                        color: Theme.highlightColor
                    }
                }
            }

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeMedium
                onClicked: dialog.choose("current")
                Row {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    height: parent.height
                    spacing: Theme.paddingLarge
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "image://theme/icon-m-location"
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Send current location")
                    }
                }
            }

            SectionHeader { text: qsTr("Share live location") }

            Repeater {
                model: [
                    { "label": qsTr("for 15 minutes"), "period": 900 },
                    { "label": qsTr("for 1 hour"), "period": 3600 },
                    { "label": qsTr("for 8 hours"), "period": 28800 }
                ]
                delegate: BackgroundItem {
                    width: column.width
                    height: Theme.itemSizeSmall
                    onClicked: dialog.choose("live", modelData.period)
                    Row {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        height: parent.height
                        spacing: Theme.paddingLarge
                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            source: "image://theme/icon-m-whereami"
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                        }
                    }
                }
            }
        }
    }
}
