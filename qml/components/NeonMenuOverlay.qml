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
        radius: overlay.neon ? Theme.paddingLarge : 0
        color: overlay.neon ? Theme.rgba("#803500", 0.82) : Theme.overlayBackgroundColor
        border.width: overlay.neon ? 4 : 0
        border.color: "#ff2d2d"
        clip: true

        Column {
            id: menuColumn
            anchors.top: parent.top
            anchors.topMargin: Theme.paddingLarge
            anchors.left: parent.left
            anchors.right: parent.right

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
                    Label {
                        anchors.centerIn: parent
                        width: parent.width - 2 * Theme.paddingLarge
                        horizontalAlignment: Text.AlignHCenter
                        truncationMode: TruncationMode.Fade
                        text: act ? act.text : ""
                        font.italic: overlay.neon
                        color: overlay.neon ? (parent.highlighted ? "#fff3e6" : "#ffffff")
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
