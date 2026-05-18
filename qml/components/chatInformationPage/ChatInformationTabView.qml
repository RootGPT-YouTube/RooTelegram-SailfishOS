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
import "../../js/twemoji.js" as Emoji

import "./"
import "../"
import "../../pages"

Item {
    id: tabViewItem
    property alias count: tabView.count
    readonly property bool callBackendAvailable: false
    readonly property bool isPrivateLikeInfo: chatInformationPage.isPrivateChat || chatInformationPage.isSecretChat
    readonly property var groupStatus: chatInformationPage.groupInformation && chatInformationPage.groupInformation.status ? chatInformationPage.groupInformation.status : ({})
    function statusFlag(flagName) {
        if (!flagName) {
            return false;
        }
        if (typeof groupStatus[flagName] === "boolean") {
            return groupStatus[flagName];
        }
        var rights = groupStatus.rights || {};
        if (typeof rights[flagName] === "boolean") {
            return rights[flagName];
        }
        var permissions = groupStatus.permissions || {};
        if (typeof permissions[flagName] === "boolean") {
            return permissions[flagName];
        }
        return false;
    }
    readonly property bool canManageMembers: statusFlag("can_restrict_members") || groupStatus["@type"] === "chatMemberStatusCreator"
    readonly property bool canManageInfo: statusFlag("can_change_info") || groupStatus["@type"] === "chatMemberStatusCreator"
    readonly property bool callActionVisible: (chatInformationPage.isPrivateChat || chatInformationPage.isSecretChat)
                                              && chatPartnerGroupId !== myUserId.toString()
                                              && (!chatInformationPage.privateChatUserInformation.type || chatInformationPage.privateChatUserInformation.type["@type"] !== "userTypeBot")
                                              && (typeof chatInformationPage.chatPartnerFullInformation.can_be_called === "undefined" || chatInformationPage.chatPartnerFullInformation.can_be_called)
    height: Screen.width
    opacity: count > 0 ? 1.0 : 0.0
    Behavior on height { PropertyAnimation {duration: 300}}
    Behavior on opacity { PropertyAnimation {duration: 300}}

    function openTabByName(tabName) {
        for (var tabIndex = 0; tabIndex < tabModel.count; tabIndex += 1) {
            var tabEntry = tabModel.get(tabIndex);
            if (tabEntry && tabEntry.tab === tabName) {
                tabView.openTab(tabIndex);
                return true;
            }
        }
        return false;
    }
    Item {
        id: callActionRow
        height: visible ? Theme.itemSizeLarge + Theme.paddingSmall : 0
        visible: tabView.count > 0 && tabViewItem.callActionVisible
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }

        BackgroundItem {
            id: callActionItem
            anchors.centerIn: parent
            width: Math.min(parent.width - (2 * Theme.horizontalPageMargin), Theme.itemSizeHuge * 2.2)
            height: Theme.itemSizeLarge

            Row {
                anchors.centerIn: parent
                spacing: Theme.paddingMedium

                Image {
                    width: Theme.iconSizeSmall
                    height: width
                    source: Emoji.getEmojiPath("📞")
                    fillMode: Image.PreserveAspectFit
                    opacity: callActionItem.pressed ? 0.7 : 1.0
                }

                Label {
                    text: qsTr("Call", "Button: start voice call")
                    highlighted: callActionItem.pressed
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            onClicked: {
                if (!tabViewItem.callBackendAvailable) {
                    appNotification.show(qsTr("Voice calls are not available in this build yet."));
                    return;
                }
                tdLibWrapper.createVoiceCall(chatPartnerGroupId, false);
            }
        }
    }

    Item {
        id: tabViewHeader
        /*
         * Tab view was prepared for
         * shared media/links/…, but for this
         * we need message search with filters
         */

        height: visible ? headerGrid.height : 0
        clip: true
        visible: tabView.count > 0

        anchors {
            left: parent.left
            right: parent.right
            top: callActionRow.bottom
        }

        Grid {
            id: headerGrid
            width: parent.width
            columns: Math.max(1, tabView.count)
            Repeater {
                model: tabModel
                delegate: BackgroundItem {
                    id: headerItem
                    property bool loaded: image !== "" && title !== ""
                    width: loaded ? (headerGrid.width / Math.max(1, headerGrid.columns)) : 0
                    opacity: loaded ? 1.0 : 0.0

                    Behavior on opacity { FadeAnimation {}}
                    height: Theme.itemSizeLarge
                    property int itemIndex: index
                    property bool itemIsActive: tabView.currentIndex === itemIndex
                    Icon {
                        id: headerIcon
                        source: image
                        highlighted: headerItem.pressed || headerItem.itemIsActive
                        anchors {
                            top: parent.top
                            horizontalCenter: parent.horizontalCenter
                        }
                    }
                    Label {
                        text: title
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        anchors.top: headerIcon.bottom
                        highlighted: headerItem.pressed || headerItem.itemIsActive
                        font.pixelSize: Theme.fontSizeTiny
                    }
                    onClicked: {
                        pageContent.scrollDown()
                        tabView.openTab(itemIndex)
                    }
                }
            }
        }
    }

    Component {
        id: filteredMessagesTabComponent
        ChatInformationTabItemFilteredMessages {}
    }

    ListView {
        id: tabView
        orientation: ListView.Horizontal
        clip: true
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightFollowsCurrentItem: true
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: 0
        highlightMoveDuration: 500
        property int maxHeight: tabViewItem.height - tabViewHeader.height - callActionRow.height

        anchors {
            top: tabViewHeader.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        function openTab(index) {
            currentIndex = index;
        }
        model: ListModel {
            id: tabModel
        }
        delegate: Loader {
            width: tabView.width
            height: tabView.maxHeight
            asynchronous: true
            source: tab === "ChatInformationTabItemFilteredMessages" ? "" : Qt.resolvedUrl(tab + ".qml")
            sourceComponent: tab === "ChatInformationTabItemFilteredMessages" ? filteredMessagesTabComponent : undefined
            onLoaded: {
                if (item) {
                    item.tabIndex = index;
                }
                if (item && tab === "ChatInformationTabItemFilteredMessages") {
                    item.tabKey = tabKey;
                    item.emptyPlaceholderText = emptyPlaceholderText;
                    item.filterTypes = filterTypes;
                    item.mediaGridMode = !!mediaGridMode;
                }
            }
        }
    }
    Component.onCompleted: {
        if (isPrivateLikeInfo && chatPartnerGroupId !== myUserId.toString()) {
            tabModel.append({
                tab: "ChatInformationTabItemFilteredMessages",
                tabKey: "media",
                filterTypes: ["searchMessagesFilterPhotoAndVideo"],
                mediaGridMode: true,
                title: qsTr("Media"),
                image: "image://theme/icon-m-image",
                emptyPlaceholderText: qsTr("No media available.")
            });
            tabModel.append({
                tab: "ChatInformationTabItemFilteredMessages",
                tabKey: "audio",
                filterTypes: ["searchMessagesFilterVoiceAndVideoNote", "searchMessagesFilterAudio"],
                title: qsTr("Audio"),
                image: "image://theme/icon-m-mic",
                emptyPlaceholderText: qsTr("No audio available.")
            });
            tabModel.append({
                tab: "ChatInformationTabItemFilteredMessages",
                tabKey: "documents",
                filterTypes: ["searchMessagesFilterDocument"],
                title: qsTr("Documents"),
                image: "image://theme/icon-m-document",
                emptyPlaceholderText: qsTr("No documents available.")
            });
            tabModel.append({
                tab: "ChatInformationTabItemFilteredMessages",
                tabKey: "links",
                filterTypes: ["searchMessagesFilterUrl"],
                title: qsTr("Link"),
                image: "image://theme/icon-m-link",
                emptyPlaceholderText: qsTr("No links available.")
            });
            tabModel.append({
                tab: "ChatInformationTabItemMembersGroups",
                title: qsTr("Groups", "Button: groups in common (short)"),
                image: "image://theme/icon-m-people"
            });
            return;
        }
        if(!((isPrivateChat || isSecretChat) && chatPartnerGroupId === myUserId.toString())) {
            tabModel.append({
                tab:"ChatInformationTabItemMembersGroups",
                title: ( chatInformationPage.isPrivateChat || chatInformationPage.isSecretChat ) ? qsTr("Groups", "Button: groups in common (short)") : qsTr("Members", "Button: Group Members"),
                image: "image://theme/icon-m-people"
            });
        }
        if(!(isPrivateChat || isSecretChat) && (tabViewItem.canManageMembers || tabViewItem.canManageInfo)) {
            tabModel.append({
                tab:"ChatInformationTabItemSettings",
                title: qsTr("Settings", "Button: Chat Settings"),
                image: "image://theme/icon-m-developer-mode"
            });
        }
//        tabModel.append({tab:"ChatInformationTabItemDebug"});

    }

}
