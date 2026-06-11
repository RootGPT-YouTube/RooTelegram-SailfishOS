/*
    Copyright (C) 2026 RooTelegram contributors

    This file is part of RooTelegram.

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/

// Riga toggle di un permesso (gate soft). 'checked' viene aggiornato a mano
// perché appSettings.isPermissionGranted() non è una property bindabile.
import QtQuick 2.6
import Sailfish.Silica 1.0

TextSwitch {
    property string perm
    width: parent.width
    automaticCheck: false
    checked: appSettings.isPermissionGranted(perm)
    onClicked: {
        var granted = !checked
        appSettings.setPermissionGranted(perm, granted)
        checked = granted
    }
}
