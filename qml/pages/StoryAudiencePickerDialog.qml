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
import "../components"
import "../js/functions.js" as Functions
import "../js/twemoji.js" as Emoji

// Multi-select degli utenti che potranno vedere la storia. Due mode:
//   "selected" — ad-hoc per la storia corrente: niente preselezione, niente
//                persistenza, ordinamento alfabetico.
//   "custom"   — Custom audience persistente: preselezione dalla lista salvata
//                in AppSettings, membri sortati in cima, salvataggio all'accept.
// Sorgenti contatti: getContacts (rubrica) + chat private esistenti (anche utenti
// non in rubrica), via display.type del chatListModel.
Dialog {
    id: audiencePicker
    allowedOrientations: Orientation.All

    // "selected" (default) | "custom"
    property string mode: "selected"

    // Lista user_id selezionati (come stringhe). Letta dal chiamante in onAccepted.
    property var selectedUserIds: []

    property bool contactsLoaded: false
    property var rawUsers: []                  // {user_id, title, username, photo_small, user_status, user_last_online}
    property var selectedMap: ({})             // userIdString -> true
    // Query di ricerca: deve vivere sul Dialog perché il delegate è una
    // Component separata e non vede gli id dichiarati nel header della ListView.
    property string searchQuery: ""
    readonly property string contactsExtra: "storyAudiencePicker:contacts"
    readonly property bool isCustomMode: mode === "custom"

    canAccept: true

    function userIdKey(id) {
        return id !== undefined && id !== null ? id.toString() : "";
    }

    function isSelected(id) {
        return !!selectedMap[userIdKey(id)];
    }

    function setSelected(id, on) {
        var key = userIdKey(id);
        if (!key) return;
        var next = {};
        for (var k in selectedMap) next[k] = selectedMap[k];
        if (on) next[key] = true;
        else delete next[key];
        selectedMap = next;
    }

    function toggleSelected(id) {
        setSelected(id, !isSelected(id));
    }

    function preselect(ids) {
        var map = {};
        if (ids) {
            for (var i = 0; i < ids.length; i++) {
                var k = userIdKey(ids[i]);
                if (k) map[k] = true;
            }
        }
        selectedMap = map;
    }

    function lowerTitle(entry) {
        return ((entry.title || "") + "").toLowerCase();
    }

    function buildFromIds(userIds) {
        // Unione: contatti dalla rubrica + partner di chat private.
        var seen = {};
        var union = [];
        function pushId(idRaw) {
            var k = userIdKey(idRaw);
            if (!k || seen[k]) return;
            seen[k] = true;
            union.push(k);
        }
        for (var i = 0; i < userIds.length; i++) pushId(userIds[i]);

        // Aggiungo gli utenti delle chat private (anche se non in rubrica).
        // ChatListModel espone il role `display` (QVariantMap completo TDLib),
        // NON un role `type`: il chat type vive in display.type.
        if (typeof chatListModel !== "undefined") {
            var total = chatListModel.count;
            for (var r = 0; r < total; r++) {
                var entry = chatListModel.get(r);
                if (!entry || !entry.display) continue;
                var chatTypeObj = entry.display.type;
                if (!chatTypeObj || chatTypeObj["@type"] !== "chatTypePrivate") continue;
                var uid = chatTypeObj.user_id ? chatTypeObj.user_id : 0;
                if (uid) pushId(uid);
            }
        }

        var arr = [];
        for (var j = 0; j < union.length; j++) {
            var idStr = union[j];
            var u = tdLibWrapper.getUserInformation(idStr);
            if (!u || !u.id) continue;
            var usernames = u.usernames || {};
            var displayName = ((u.first_name || "") + " " + (u.last_name || "")).replace(/^\s+|\s+$/g, "");
            var fallbackName = usernames.editable_username
                                   || (usernames.active_usernames && usernames.active_usernames[0])
                                   || u.username || ("#" + u.id);
            if (displayName === "") displayName = fallbackName;
            arr.push({
                user_id: u.id,
                title: displayName,
                username: usernames.editable_username
                              || (usernames.active_usernames && usernames.active_usernames.length > 0
                                      ? usernames.active_usernames[0] : "")
                              || u.username || "",
                photo_small: u.profile_photo ? u.profile_photo.small : null,
                user_status: u.status ? (u.status["@type"] || "") : "",
                user_last_online: u.status && u.status.was_online !== undefined ? u.status.was_online : 0
            });
        }
        sortRawUsers(arr);
        rawUsers = arr;
        rebuildListModel();
        contactsLoaded = true;
    }

    // Ordinamento: in mode "custom" i membri salvati vanno in cima (così
    // l'utente vede sempre chi compone il gruppo); il resto è alfabetico.
    // In mode "selected" tutto alfabetico (nessuna preselezione).
    function sortRawUsers(arr) {
        var byTitle = function(a, b) {
            var ta = lowerTitle(a), tb = lowerTitle(b);
            return ta < tb ? -1 : (ta > tb ? 1 : 0);
        };
        if (!isCustomMode) {
            arr.sort(byTitle);
            return;
        }
        arr.sort(function(a, b) {
            var sa = isSelected(a.user_id) ? 0 : 1;
            var sb = isSelected(b.user_id) ? 0 : 1;
            if (sa !== sb) return sa - sb;
            return byTitle(a, b);
        });
    }

    function rebuildListModel() {
        usersListModel.clear();
        for (var i = 0; i < rawUsers.length; i++) {
            usersListModel.append(rawUsers[i]);
        }
    }

    function emitSelection() {
        var ids = [];
        for (var k in selectedMap) {
            if (selectedMap[k]) ids.push(k);
        }
        selectedUserIds = ids;
    }

    onAccepted: {
        emitSelection();
        if (isCustomMode) {
            appSettings.setStoryCustomAudienceUserIds(selectedUserIds);
        }
    }

    Component.onCompleted: {
        if (isCustomMode) {
            preselect(appSettings.storyCustomAudienceUserIds());
        }
        tdLibWrapper.sendRequest({
            "@type": "getContacts",
            "@extra": contactsExtra
        });
    }

    ListModel { id: usersListModel }

    SilicaListView {
        id: listView
        anchors.fill: parent
        clip: true
        model: usersListModel

        header: Column {
            width: parent.width
            spacing: Theme.paddingMedium

            DialogHeader {
                title: audiencePicker.isCustomMode
                       ? qsTr("Custom audience")
                       : qsTr("Audience")
                acceptText: qsTr("Done")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                text: audiencePicker.isCustomMode
                      ? qsTr("Members of your custom audience (%n selected). Saved across stories.", "", selectionCounter.count)
                      : qsTr("Choose who will see your next story (%n selected).", "", selectionCounter.count)
            }

            SearchField {
                id: searchField
                width: parent.width
                placeholderText: qsTr("Search...")
                visible: audiencePicker.contactsLoaded
                onTextChanged: audiencePicker.searchQuery = text
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }
        }

        QtObject {
            id: selectionCounter
            property int count: 0
            function refresh() {
                var n = 0;
                for (var k in audiencePicker.selectedMap) {
                    if (audiencePicker.selectedMap[k]) n++;
                }
                count = n;
            }
        }

        Connections {
            target: audiencePicker
            onSelectedMapChanged: selectionCounter.refresh()
        }

        ViewPlaceholder {
            enabled: audiencePicker.contactsLoaded && listView.count === 0
            text: qsTr("No contacts or private chats.")
        }

        delegate: ListItem {
            id: row
            width: ListView.view.width
            contentHeight: Theme.itemSizeLarge

            property int rowUserId: Number(user_id)
            property bool rowSelected: audiencePicker.isSelected(rowUserId)
            property bool filterMatches: {
                var q = audiencePicker.searchQuery.toLowerCase();
                if (q.length === 0) return true;
                var hay = ((title || "") + " " + (username || "")).toLowerCase();
                return hay.indexOf(q) > -1;
            }

            visible: filterMatches
            height: filterMatches ? Theme.itemSizeLarge : 0

            onClicked: {
                audiencePicker.toggleSelected(rowUserId);
                rowSelected = audiencePicker.isSelected(rowUserId);
            }

            Icon {
                id: checkIcon
                source: row.rowSelected
                            ? "image://theme/icon-s-installed?" + Theme.highlightColor
                            : "image://theme/icon-s-checkmark?" + Theme.secondaryColor
                width: Theme.iconSizeSmall
                height: Theme.iconSizeSmall
                anchors {
                    left: parent.left
                    leftMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                }
                opacity: row.rowSelected ? 1.0 : 0.4
            }

            ProfileThumbnail {
                id: avatar
                photoData: typeof photo_small !== "undefined" && photo_small ? photo_small : ({})
                replacementStringHint: title
                width: Theme.itemSizeMedium
                height: Theme.itemSizeMedium
                radius: width / 2
                anchors {
                    left: checkIcon.right
                    leftMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                }
            }

            Column {
                anchors {
                    left: avatar.right
                    leftMargin: Theme.paddingMedium
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.paddingSmall / 2

                Label {
                    width: parent.width
                    text: title ? Emoji.emojify(title, font.pixelSize, "../js/emoji/") : "?"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.primaryColor
                    truncationMode: TruncationMode.Fade
                    textFormat: Text.StyledText
                }

                Label {
                    width: parent.width
                    text: username !== "" ? "@" + username : ""
                    visible: username !== ""
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.highlightColor
                    truncationMode: TruncationMode.Fade
                }

                Label {
                    width: parent.width
                    text: Functions.getChatPartnerStatusText(user_status, user_last_online)
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    truncationMode: TruncationMode.Fade
                }
            }
        }

        VerticalScrollDecorator {}
    }

    Column {
        visible: !audiencePicker.contactsLoaded
        width: parent.width
        spacing: Theme.paddingMedium
        anchors.verticalCenter: parent.verticalCenter

        InfoLabel { text: qsTr("Loading contacts...") }
        BusyIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            running: !audiencePicker.contactsLoaded
            size: BusyIndicatorSize.Large
        }
    }

    Connections {
        target: tdLibWrapper
        onUsersReceived: {
            if (extra === audiencePicker.contactsExtra) {
                audiencePicker.buildFromIds(userIds);
                selectionCounter.refresh();
            }
        }
        onErrorReceived: {
            if (extra === audiencePicker.contactsExtra) {
                audiencePicker.contactsLoaded = true;
            }
        }
    }
}
