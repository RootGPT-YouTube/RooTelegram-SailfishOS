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
import "."

// Menù a comparsa in stile neon (card fluttuante) che sostituisce i ContextMenu
// Silica per i long-press: i ContextMenu Silica non sono ricolorabili (opacità
// sfondo bloccata). Coerente col menù titolo: sfondo arancio scuro, bordo rosso,
// voci bianche neon corsive.
// Uso: instanziare nella pagina, poi chiamare open([{text, visible, callback}, ...]).
Item {
    id: overlay
    anchors.fill: parent
    visible: false
    z: 1000

    readonly property bool neon: appSettings.useNeonTheme
    // Barbara: stessa card, ma vetro del tema — niente bordo rosso da 4px e
    // niente Glow sulle voci.
    readonly property bool barbara: BarbaraTheme.active

    // Lista azioni: array di { text:string, visible:bool(opz), callback:function }.
    property var actions: []

    function open(actionList) {
        overlay.actions = actionList || [];
        overlay.visible = true;
    }
    function close() {
        overlay.visible = false;
        overlay.actions = [];
    }

    // Velo scuro + chiusura tappando fuori dalla card.
    Rectangle {
        anchors.fill: parent
        color: Theme.rgba("#000000", 0.5)
        MouseArea {
            anchors.fill: parent
            onClicked: overlay.close()
        }
    }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 2 * Theme.horizontalPageMargin
        height: Math.min(menuColumn.height + 2 * Theme.paddingLarge, parent.height - 2 * Theme.paddingLarge)
        // Tema Silica: card opaca piatta (niente vetro/trasparenza/angoli stondati/bordo neon).
        radius: overlay.neon ? Theme.paddingLarge
              : (overlay.barbara ? BarbaraTheme.radiusBubble : 0)
        color: overlay.neon ? Theme.rgba("#803500", 0.82)
             : (overlay.barbara ? BarbaraTheme.panel : Theme.overlayBackgroundColor)
        border.width: overlay.neon ? 4 : (overlay.barbara ? BarbaraTheme.borderWidth : 0)
        border.color: overlay.barbara ? BarbaraTheme.glassBorder : "#ff2d2d"
        clip: true

        Column {
            id: menuColumn
            anchors.top: parent.top
            anchors.topMargin: overlay.barbara ? Theme.paddingMedium : Theme.paddingLarge
            anchors.left: parent.left
            anchors.right: parent.right

            // Barbara: intestazione in mono accento sopra le voci.
            Label {
                visible: overlay.barbara
                height: visible ? implicitHeight + Theme.paddingMedium : 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignBottom
                //: Intestazione della card del menu di scelta rapida (tema Barbara)
                text: qsTr("Actions")
                font.family: BarbaraTheme.fontFamilyMono
                font.pixelSize: BarbaraTheme.fontSizeMeta
                font.capitalization: Font.AllUppercase
                color: BarbaraTheme.accent
            }

            Repeater {
                // NB: usiamo il CONTEGGIO come model e indicizziamo overlay.actions[index]:
                // passare l'array di oggetti come `model:` li convertirebbe in QVariantMap
                // PERDENDO le funzioni callback (diventano undefined).
                model: overlay.actions.length
                delegate: BackgroundItem {
                    property var act: overlay.actions[index]
                    width: parent.width
                    height: (act && act.visible === false) ? 0 : Theme.itemSizeSmall
                    visible: !act || act.visible !== false
                    onClicked: {
                        var cb = act ? act.callback : null;
                        overlay.close();
                        if (cb) cb();
                    }
                    // Barbara: voci separate da una linea di 1px.
                    Rectangle {
                        visible: overlay.barbara && index > 0
                                 && (!parent.act || parent.act.visible !== false)
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        height: BarbaraTheme.borderWidth
                        color: BarbaraTheme.glassBorder
                    }
                    Label {
                        anchors.centerIn: parent
                        width: parent.width - 2 * Theme.paddingLarge
                        horizontalAlignment: Text.AlignHCenter
                        truncationMode: TruncationMode.Fade
                        text: act ? act.text : ""
                        font.italic: overlay.neon
                        font.pixelSize: overlay.barbara ? Theme.fontSizeSmall : Theme.fontSizeMedium
                        color: overlay.neon ? (parent.highlighted ? "#fff3e6" : "#ffffff")
                             : overlay.barbara ? ((act && act.destructive)
                                                  ? BarbaraTheme.danger
                                                  : (parent.highlighted ? BarbaraTheme.accent : BarbaraTheme.ink))
                                               : (parent.highlighted ? Theme.highlightColor : Theme.primaryColor)
                        // Glow solo in tema Neon.
                        layer.enabled: overlay.neon
                        layer.effect: Glow {
                            color: "#ffffff"
                            radius: 6
                            samples: 13
                            spread: 0.2
                            transparentBorder: true
                        }
                    }
                }
            }
        }
    }
}
