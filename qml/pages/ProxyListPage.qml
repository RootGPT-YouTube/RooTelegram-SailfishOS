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
import "../components"

Page {
    id: proxyListPage
    allowedOrientations: Orientation.All

    function typeLabel(type) {
        switch (type["@type"]) {
        case "proxyTypeMtproto": return qsTr("MTProto");
        case "proxyTypeSocks5":  return qsTr("SOCKS5");
        case "proxyTypeHttp":    return qsTr("HTTP");
        }
        return "";
    }

    function rebuildModel() {
        proxyModel.clear();
        var proxies = tdLibWrapper.getCachedProxies();
        for (var i = 0; i < proxies.length; i++) {
            var p = proxies[i];
            proxyModel.append({
                proxyId: p.id,
                server: p.server,
                port: p.port,
                isEnabled: p.is_enabled === true,
                proxyTypeName: typeLabel(p.type),
                pingText: ""
            });
        }
    }

    Connections {
        target: tdLibWrapper
        onProxiesReceived: rebuildModel()
        onProxyPinged: {
            for (var i = 0; i < proxyModel.count; i++) {
                if (proxyModel.get(i).proxyId === proxyId) {
                    proxyModel.setProperty(i, "pingText", qsTr("%1 ms").arg(Math.round(seconds * 1000)));
                    break;
                }
            }
        }
    }

    Component.onCompleted: {
        tdLibWrapper.getProxies();
        rebuildModel();
    }

    ListModel { id: proxyModel }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: proxyModel

        header: NeonPageHeader {
            text: qsTr("Proxy")
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Add proxy")
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("AddProxyDialog.qml"));
                }
            }
            MenuItem {
                text: qsTr("Disable proxy (direct connection)")
                onClicked: {
                    tdLibWrapper.disableProxy();
                    appNotification.show(qsTr("Proxy disabled"));
                }
            }
        }

        ViewPlaceholder {
            enabled: proxyModel.count === 0
            text: qsTr("No proxies")
            hintText: qsTr("Pull down to add a proxy, or paste a tg://proxy link.")
        }

        delegate: ListItem {
            id: proxyItem
            contentHeight: Theme.itemSizeMedium
            width: listView.width

            menu: ContextMenu {
                MenuItem {
                    text: model.isEnabled ? qsTr("Disable") : qsTr("Enable")
                    onClicked: {
                        if (model.isEnabled) {
                            tdLibWrapper.disableProxy();
                        } else {
                            tdLibWrapper.enableProxy(model.proxyId);
                        }
                    }
                }
                MenuItem {
                    text: qsTr("Test connection")
                    onClicked: tdLibWrapper.pingProxy(model.proxyId)
                }
                MenuItem {
                    text: qsTr("Remove")
                    onClicked: proxyItem.remorseAction(qsTr("Removing proxy"), function() {
                        tdLibWrapper.removeProxy(model.proxyId);
                    })
                }
            }

            Column {
                anchors {
                    left: parent.left
                    right: enabledIcon.left
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                }
                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    text: model.server + ":" + model.port
                    color: model.isEnabled ? Theme.highlightColor : Theme.primaryColor
                }
                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    text: model.proxyTypeName + (model.pingText ? (" · " + model.pingText) : "")
                }
            }

            Icon {
                id: enabledIcon
                anchors {
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                visible: model.isEnabled
                source: "image://theme/icon-s-checkmark?" + Theme.highlightColor
            }

            onClicked: {
                if (!model.isEnabled) {
                    tdLibWrapper.enableProxy(model.proxyId);
                } else {
                    tdLibWrapper.pingProxy(model.proxyId);
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
