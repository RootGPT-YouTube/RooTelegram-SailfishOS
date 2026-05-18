/*
    Copyright (C) 2021 Sebastian J. Wolf and other contributors
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
import WerkWolf.RooTelegram 1.0
import "../../js/functions.js" as Functions

AccordionItem {
    text: qsTr("Behavior")
    Component {
        ResponsiveGrid {
            bottomPadding: Theme.paddingMedium
            TextSwitch {
                width: parent.columnWidth
                checked: appSettings.sendByEnter
                text: qsTr("Send message by enter")
                description: qsTr("Send your message by pressing the enter key")
                automaticCheck: false
                onClicked: {
                    appSettings.sendByEnter = !checked
                }
            }

            TextSwitch {
                width: parent.columnWidth
                checked: appSettings.focusTextAreaOnChatOpen
                text: qsTr("Focus text input on chat open")
                description: qsTr("Focus the text input area when entering a chat")
                automaticCheck: false
                onClicked: {
                    appSettings.focusTextAreaOnChatOpen = !checked
                }
            }

            TextSwitch {
                width: parent.columnWidth
                checked: appSettings.focusTextAreaAfterSend
                text: qsTr("Focus text input area after send")
                description: qsTr("Focus the text input area after sending a message")
                automaticCheck: false
                onClicked: {
                    appSettings.focusTextAreaAfterSend = !checked
                }
            }

            TextSwitch {
                width: parent.columnWidth
                checked: appSettings.delayMessageRead
                text: qsTr("Delay before marking messages as read")
                description: qsTr("RooTelegram will wait a bit before messages are marked as read")
                automaticCheck: false
                onClicked: {
                    appSettings.delayMessageRead = !checked
                }
            }

            TextSwitch {
                width: parent.columnWidth
                checked: appSettings.highlightUnreadConversations
                text: qsTr("Highlight unread messages")
                description: qsTr("Highlight Conversations with unread messages")
                automaticCheck: false
                onClicked: {
                    appSettings.highlightUnreadConversations = !checked
                }
            }

            TextSwitch {
                width: parent.columnWidth
                checked: appSettings.coverHideGroupChannelUnread
                text: qsTr("Cover: only private chats in unread count")
                description: qsTr("Exclude groups and channels from the unread message and chat counts shown on the cover preview")
                automaticCheck: false
                onClicked: {
                    appSettings.coverHideGroupChannelUnread = !checked
                }
            }

            TextSwitch {
                width: parent.columnWidth
                checked: appSettings.useOpenWith
                text: qsTr("Open-with menu integration")
                description: qsTr("Integrate RooTelegram into open-with menu of Sailfish OS")
                automaticCheck: false
                onClicked: {
                    appSettings.useOpenWith = !checked
                }
            }

            TextSwitch {
                width: parent.columnWidth
                checked: appSettings.daemonEnabled
                text: qsTr("Run as daemon in background")
                description: qsTr("Keep RooTelegram running in background and allow DBus daemon startup. Restart the app after changing this setting.")
                automaticCheck: false
                onClicked: {
                    appSettings.daemonEnabled = !checked
                }
            }

            TextSwitch {
                width: parent.columnWidth
                checked: appSettings.notificationAlwaysShowPreview
                text: qsTr("Always append message preview to notifications")
                description: qsTr("In addition to showing the number of unread messages, the latest message will also be appended to notifications.")
                automaticCheck: false
                onClicked: {
                    appSettings.notificationAlwaysShowPreview = !checked
                }
            }

            TextSwitch {
                width: parent.columnWidth
                checked: appSettings.goToQuotedMessage
                text: qsTr("Go to quoted message")
                description: qsTr("When tapping a quoted message, open it in chat instead of showing it in an overlay.")
                automaticCheck: false
                onClicked: {
                    appSettings.goToQuotedMessage = !checked
                }
            }

            TextSwitch {
                width: parent.columnWidth
                checked: appSettings.disableVideoPreload
                text: qsTr("Disable video preloading")
                description: qsTr("Disables automatic video preloading to reduce RAM/GPU and mobile data usage. Photos are still downloaded automatically.")
                automaticCheck: false
                onClicked: {
                    var desired = !checked
                    appSettings.disableVideoPreload = desired
                    if (desired) {
                        Functions.applyVideoPreloadOverride()
                    } else {
                        Functions.restoreAutoDownloadDefaults()
                    }
                }
            }

            ComboBox {
                id: feedbackComboBox
                width: parent.columnWidth
                label: qsTr("Notification feedback")
                description: qsTr("Use non-graphical feedback (sound, vibration) for notifications")
                menu: ContextMenu {
                    id: feedbackMenu
                    x: 0
                    width: feedbackComboBox.width

                    MenuItem {
                        readonly property int value: AppSettings.NotificationFeedbackAll
                        text: qsTr("All events")
                        onClicked: {
                            appSettings.notificationFeedback = value
                        }
                    }
                    MenuItem {
                        readonly property int value: AppSettings.NotificationFeedbackNew
                        text: qsTr("Only new events")
                        onClicked: {
                            appSettings.notificationFeedback = value
                        }
                    }
                    MenuItem {
                        readonly property int value: AppSettings.NotificationFeedbackNone
                        text: qsTr("None")
                        onClicked: {
                            appSettings.notificationFeedback = value
                        }
                    }
                }

                Component.onCompleted: updateFeedbackSelection()

                function updateFeedbackSelection() {
                    var menuItems = feedbackMenu.children
                    var n = menuItems.length
                    for (var i=0; i<n; i++) {
                        if (menuItems[i].value === appSettings.notificationFeedback) {
                            currentIndex = i
                            return
                        }
                    }
                }

                Connections {
                    target: appSettings
                    onNotificationFeedbackChanged: {
                        feedbackComboBox.updateFeedbackSelection()
                    }
                }
            }

            Item {
                // Occupies one grid cell so that the column ends up under the combo box
                // in the landscape layout
                visible: parent.columns === 2
                width: 1
                height: 1
            }

            Column {
                enabled: appSettings.notificationFeedback !== AppSettings.NotificationFeedbackNone
                width: parent.columnWidth
                height: enabled ? implicitHeight: 0
                clip: height < implicitHeight
                visible: height > 0

                Behavior on height { SmoothedAnimation { duration: 200 } }

                TextSwitch {
                    checked: appSettings.notificationSuppressContent && enabled
                    text: qsTr("Hide content in notifications")
                    enabled: parent.enabled
                    automaticCheck: false
                    onClicked: {
                        appSettings.notificationSuppressContent = !checked
                    }
                }

                TextSwitch {
                    checked: appSettings.notificationTurnsDisplayOn && enabled
                    text: qsTr("Notification turns on the display")
                    enabled: parent.enabled
                    automaticCheck: false
                    onClicked: {
                        appSettings.notificationTurnsDisplayOn = !checked
                    }
                }

                TextSwitch {
                    checked: appSettings.notificationSoundsEnabled && enabled
                    text: qsTr("Enable notification sounds")
                    description: qsTr("When sounds are enabled, RooTelegram will use the current Sailfish OS notification sound for chats, which can be configured in the system settings.")
                    enabled: parent.enabled
                    automaticCheck: false
                    onClicked: {
                        appSettings.notificationSoundsEnabled = !checked
                    }
                }
            }
        }
    }
}
