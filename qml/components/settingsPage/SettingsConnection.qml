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

AccordionItem {
    text: qsTr("Connection")
    Component {
        Column {
            bottomPadding: Theme.paddingMedium

            property int proxyCount: 0
            property bool hasEnabledProxy: false

            function refreshProxyStatus() {
                var proxies = tdLibWrapper.getCachedProxies();
                proxyCount = proxies.length;
                hasEnabledProxy = false;
                for (var i = 0; i < proxies.length; i++) {
                    if (proxies[i].is_enabled) { hasEnabledProxy = true; break; }
                }
            }

            Connections {
                target: tdLibWrapper
                onProxiesReceived: refreshProxyStatus()
            }

            Component.onCompleted: {
                tdLibWrapper.getProxies();
                refreshProxyStatus();
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                text: qsTr("Proxies route your Telegram traffic through another server to bypass censorship. MTProto proxies (especially with Fake-TLS) are the most resistant to blocking. SOCKS5 proxies also cover voice and video calls.")
            }

            ValueButton {
                width: parent.width
                label: qsTr("Proxy")
                value: hasEnabledProxy
                       ? qsTr("On (%n configured)", "", proxyCount)
                       : (proxyCount > 0 ? qsTr("Off (%n configured)", "", proxyCount) : qsTr("Off"))
                description: qsTr("Add, enable and test connection proxies.")
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("../../pages/ProxyListPage.qml"));
                }
            }
        }
    }
}
