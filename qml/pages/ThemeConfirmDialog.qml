/*
    Copyright (C) 2026 RooTelegram contributors

    This file is part of RooTelegram.

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/

// Popup di conferma cambio tema: mostra nome + descrizione del tema scelto e
// chiede "Applica ora?" (Sì = accept, No = cancel). Innescato dalla tendina
// in Impostazioni → Aspetto.

import QtQuick 2.6
import Sailfish.Silica 1.0

Dialog {
    id: themeDialog
    allowedOrientations: Orientation.All

    // true = Neon (cyberpunk), false = Silica (base).
    property bool wantNeon: false

    Column {
        width: parent.width
        spacing: Theme.paddingLarge

        DialogHeader {
            acceptText: qsTr("Apply now")
            cancelText: qsTr("No")
            title: themeDialog.wantNeon ? qsTr("Neon theme") : qsTr("Silica theme")
        }

        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            wrapMode: Text.WordWrap
            color: Theme.highlightColor
            font.pixelSize: Theme.fontSizeMedium
            text: themeDialog.wantNeon
                ? qsTr("Cyberpunk look")
                : qsTr("Base theme")
        }

        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            wrapMode: Text.WordWrap
            color: Theme.secondaryColor
            font.pixelSize: Theme.fontSizeSmall
            text: themeDialog.wantNeon
                ? qsTr("Circuit background, neon glow on menus, buttons and titles, rounded avatars and glass cards. Heavier: requires a dark and orange theme for the perfect experience.")
                : qsTr("Native flat menus, square avatars, no custom background, standard Silica colors. Lighter and clearly readable also on light system themes.")
        }

        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            wrapMode: Text.WordWrap
            color: Theme.primaryColor
            font.pixelSize: Theme.fontSizeMedium
            text: qsTr("Apply this theme now?")
        }
    }
}
