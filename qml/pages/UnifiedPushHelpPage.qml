/*
    Copyright (C) 2026 RootGPT

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

// Istruzioni passo passo per le notifiche via UnifiedPush/Foghorn (BETA), per
// un utente non tecnico. Lo stesso contenuto, piu' esteso, sta in
// docs/UNIFIEDPUSH.md. Un blocco di testo per sezione: meno stringhe da tradurre.

import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: unifiedPushHelpPage
    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height

        VerticalScrollDecorator {}

        Column {
            id: contentColumn
            width: parent.width
            bottomPadding: Theme.paddingLarge
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("UnifiedPush (BETA)")
            }

            Repeater {
                model: [
                    { header: qsTr("What it is"),
                      body: qsTr("Normally RooTelegram stays in memory in the background to receive messages. With this option it closes completely instead, and a small separate app, Foghorn, wakes it up when a new message arrives. RooTelegram then downloads the message, shows the notification and closes again by itself. It uses much less memory; a notification may arrive a few seconds later than usual.<br><br><b>This is a BETA feature</b>, and Foghorn itself is young software: if notifications stop arriving, turn the option off to go back to the usual background service.") },
                    { header: qsTr("Who it is for"),
                      body: qsTr("UnifiedPush is useful above all on phones with little memory, where keeping RooTelegram always in memory weighs a lot. On recent phones, with <b>6 GB of RAM or more</b>, the usual background service is usually the better choice: UnifiedPush uses fewer resources, but with this option on, tapping a notification always starts RooTelegram from scratch (a \"cold start\"), so the chat takes a few seconds longer to open. With the background service it opens at once.") },
                    { header: qsTr("1. Install Foghorn"),
                      body: qsTr("Install <b>Foghorn</b> from OpenRepos (for example with the Storeman app): <a href=\"https://openrepos.net/content/projectmoon/foghorn\">openrepos.net/content/projectmoon/foghorn</a><br>Open Foghorn once and check that its service is running.") },
                    { header: qsTr("2. Leave Foghorn on Mozilla"),
                      body: qsTr("Foghorn's default push service, <b>Mozilla</b>, works well with Telegram: you don't have to change anything.<br><br><b>Don't choose ntfy:</b> in our tests Telegram almost never delivered its wake-ups through the public ntfy.sh server, so notifications didn't arrive. If you had changed it, go back to Mozilla in Foghorn's settings: RooTelegram notices it and re-registers by itself.") },
                    { header: qsTr("3. Open RooTelegram from its icon"),
                      body: qsTr("After installing or updating RooTelegram, open it once by tapping its icon. SailfishOS may ask you to allow the app's permissions, including the new \"UnifiedPush\" one: accept. Without this step Foghorn cannot start RooTelegram in the background.") },
                    { header: qsTr("4. Turn on the option"),
                      body: qsTr("In RooTelegram go to Settings → Behavior and turn on <b>Notifications via UnifiedPush (BETA)</b>. After a few seconds the status below the switch should say that it is active and show the name of the server (for example updates.push.services.mozilla.com).") },
                    { header: qsTr("5. Try it"),
                      body: qsTr("Close RooTelegram completely (close it from the home screen, don't just minimize it). About ten seconds later it is no longer in memory. Ask someone to write to you: the notification should appear within a few seconds.<br><br>If Telegram is open on another device (another phone, a computer), Telegram itself waits a little before waking up this phone: then the notification may arrive up to about half a minute later. That is normal.") },
                    { header: qsTr("How it behaves"),
                      body: qsTr("• While the app window is open, or minimized, RooTelegram works as usual.<br>• When you close it, it stays in memory only while music or a voice message is playing, or during a call.<br>• When a message arrives with the app closed, RooTelegram starts without a window for 20–60 seconds, shows the notifications and closes.<br>• At phone start-up the background service is not started any more: Foghorn takes care of it.<br>• Tapping a notification while the app is closed starts RooTelegram from scratch (a \"cold start\"), so it takes a few seconds longer to open than usual: the background service that normally keeps it ready is not running, because Foghorn takes its place.") },
                    { header: qsTr("If it doesn't work"),
                      body: qsTr("• Status \"no distributor\": Foghorn is not installed or its service is stopped.<br>• Status \"error\": open RooTelegram from its icon (step 3), then use \"Try again\".<br>• No notifications although the status is active: check that Foghorn uses Mozilla (step 2), that RooTelegram is listed among Foghorn's registered apps, and the Internet connection.<br>• When in doubt: turn the option off. Everything goes back to how it was before.") },
                    { header: qsTr("Privacy"),
                      body: qsTr("The wake-up that Telegram sends through the push service is encrypted, and RooTelegram doesn't even read it: it uses it only as a signal, then downloads the messages directly from Telegram, encrypted as usual. Telegram and Mozilla only learn the address where to deliver the wake-ups: whoever learned it could only wake RooTelegram up, not read anything.") },
                    { header: qsTr("Turning it off"),
                      body: qsTr("Turn the switch off: RooTelegram tells Telegram to forget the address, unregisters from Foghorn and goes back to the usual background service (from the next phone start-up it is started automatically again, if that option is on).") },
                    { header: qsTr("Thanks"),
                      body: qsTr("Thanks to <b>projectmoon</b>, the developer of Foghorn, for the pioneering work that brought UnifiedPush to SailfishOS: without Foghorn this option would not exist.") }
                ]
                delegate: Column {
                    width: contentColumn.width
                    spacing: Theme.paddingSmall
                    SectionHeader {
                        text: modelData.header
                    }
                    Label {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        wrapMode: Text.Wrap
                        textFormat: Text.StyledText
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.highlightColor
                        linkColor: Theme.primaryColor
                        text: modelData.body
                        onLinkActivated: Qt.openUrlExternally(link)
                    }
                }
            }
        }
    }
}
