/*
    Copyright (C) 2020 Sebastian J. Wolf and other contributors
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), which is
    licensed under the GNU General Public License v3.0. The original
    license is available at:
    https://github.com/Wunderfitz/harbour-fernschreiber/blob/master/LICENSE

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
import "../../pages"
import "../"

Item {
    id: tabItem
    property string title
    property url image
    property bool loading
    //overrideable:
    property alias loadingVisible: loadingColumn.loadingVisible
    property string loadingText

    property int tabIndex: -1
    property bool active: tabIndex >= 0 && tabIndex === tabView.currentIndex

    default property alias _data: contentItem.data

    opacity: active ? 1.0 : 0.0
    Behavior on opacity { FadeAnimation {}}

    Column {
        id: loadingColumn
        property bool loadingVisible: tabItem.loading
        width: tabItem.width
        height: loadingLabel.height + loadingBusyIndicator.height + Theme.paddingMedium
        spacing: Theme.paddingMedium
        topPadding: Theme.paddingLarge
        anchors.top: parent.top
        opacity: loadingVisible ? 1.0 : 0.0
        Behavior on opacity { FadeAnimation {} }
        visible: tabItem.loading

        InfoLabel {
            id: loadingLabel
            text: tabItem.loadingText
        }

        BusyIndicator {
            id: loadingBusyIndicator
            anchors.horizontalCenter: parent.horizontalCenter
            running: parent.loadingVisible
            size: BusyIndicatorSize.Large
        }
    }
    Item {
        id: contentItem
        width: parent.width
        height: childrenRect.height
    }

}
