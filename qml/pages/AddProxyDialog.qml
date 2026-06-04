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
import WerkWolf.RooTelegram 1.0

Dialog {
    id: addProxyDialog
    allowedOrientations: Orientation.All

    // 0 = MTProto, 1 = SOCKS5, 2 = HTTP
    property int proxyType: 0

    canAccept: serverField.text.trim() !== "" && portField.text.trim() !== ""
               && (proxyType !== 0 || secretField.text.trim() !== "")

    function parseProxyLink(link) {
        link = link.trim();
        var q = link.indexOf("?");
        if (q < 0) {
            return false;
        }
        var lower = link.toLowerCase();
        var isSocks = lower.indexOf("/socks") >= 0 || lower.indexOf("type=socks") >= 0;
        var params = link.substring(q + 1).split("&");
        var map = {};
        for (var i = 0; i < params.length; i++) {
            var kv = params[i].split("=");
            if (kv.length >= 1 && kv[0]) {
                map[kv[0].toLowerCase()] = decodeURIComponent((kv[1] || "").replace(/\+/g, " "));
            }
        }
        if (map.server) serverField.text = map.server;
        if (map.port) portField.text = map.port;
        if (map.secret) {
            typeComboBox.currentIndex = 0;   // MTProto
            secretField.text = map.secret;
        } else if (isSocks || map.user || map.pass) {
            typeComboBox.currentIndex = 1;   // SOCKS5
            if (map.user) usernameField.text = map.user;
            if (map.pass) passwordField.text = map.pass;
        }
        return !!map.server;
    }

    onAccepted: {
        var server = serverField.text.trim();
        var port = parseInt(portField.text.trim(), 10);
        if (proxyType === 0) {
            tdLibWrapper.addProxyMtproto(server, port, secretField.text.trim(), true);
        } else if (proxyType === 1) {
            tdLibWrapper.addProxySocks5(server, port, usernameField.text, passwordField.text, true);
        } else {
            tdLibWrapper.addProxyHttp(server, port, usernameField.text, passwordField.text, httpOnlySwitch.checked, true);
        }
        appNotification.show(qsTr("Proxy added and enabled"));
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height

        Column {
            id: contentColumn
            width: parent.width

            DialogHeader {
                title: qsTr("Add proxy")
                acceptText: qsTr("Add")
            }

            TextField {
                id: linkField
                width: parent.width
                label: qsTr("Paste a proxy link (optional)")
                placeholderText: qsTr("tg://proxy?server=…  or  https://t.me/proxy?…")
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                onTextChanged: {
                    if (text.indexOf("?") >= 0) {
                        if (parseProxyLink(text)) {
                            appNotification.show(qsTr("Link recognised"));
                            text = "";
                        }
                    }
                }
            }

            ComboBox {
                id: typeComboBox
                width: parent.width
                label: qsTr("Type")
                currentIndex: addProxyDialog.proxyType
                onCurrentIndexChanged: addProxyDialog.proxyType = currentIndex
                menu: ContextMenu {
                    MenuItem { text: qsTr("MTProto (recommended)") }
                    MenuItem { text: qsTr("SOCKS5 (also for calls)") }
                    MenuItem { text: qsTr("HTTP") }
                }
            }

            TextField {
                id: serverField
                width: parent.width
                label: qsTr("Server")
                placeholderText: qsTr("Server (host or IP)")
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: portField.focus = true
            }

            TextField {
                id: portField
                width: parent.width
                label: qsTr("Port")
                placeholderText: qsTr("Port")
                inputMethodHints: Qt.ImhDigitsOnly
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
            }

            TextField {
                id: secretField
                width: parent.width
                visible: addProxyDialog.proxyType === 0
                label: qsTr("Secret")
                placeholderText: qsTr("Secret (supports dd… and ee… Fake-TLS)")
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
            }

            TextField {
                id: usernameField
                width: parent.width
                visible: addProxyDialog.proxyType !== 0
                label: qsTr("Username (optional)")
                placeholderText: qsTr("Username")
                inputMethodHints: Qt.ImhNoAutoUppercase
            }

            TextField {
                id: passwordField
                width: parent.width
                visible: addProxyDialog.proxyType !== 0
                label: qsTr("Password (optional)")
                placeholderText: qsTr("Password")
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhNoAutoUppercase
            }

            TextSwitch {
                id: httpOnlySwitch
                visible: addProxyDialog.proxyType === 2
                text: qsTr("HTTP only")
                description: qsTr("The proxy supports only HTTP requests (no HTTPS tunnelling).")
            }
        }

        VerticalScrollDecorator {}
    }
}
