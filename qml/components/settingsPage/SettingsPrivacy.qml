/*
    Copyright (C) 2021 Sebastian J. Wolf and other contributors

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
    text: qsTr("Privacy")
    Component {
        Column {
            bottomPadding: Theme.paddingMedium
            Connections {
                target: tdLibWrapper
                onUserPrivacySettingUpdated: {
                    Debug.log("Received updated privacy setting: " + setting + ":" + rule);
                    switch (setting) {
                    case TelegramAPI.SettingAllowChatInvites:
                        allowChatInvitesComboBox.currentIndex = rule;
                        break;
                    case TelegramAPI.SettingAllowFindingByPhoneNumber:
                        allowFindingByPhoneNumberComboBox.currentIndex = rule;
                        break;
                    case TelegramAPI.SettingAllowCalls:
                        allowCallsComboBox.currentIndex = rule;
                        break;
                    case TelegramAPI.SettingShowLinkInForwardedMessages:
                        showLinkInForwardedMessagesComboBox.currentIndex = rule;
                        break;
                    case TelegramAPI.SettingShowPhoneNumber:
                        showPhoneNumberComboBox.currentIndex = rule;
                        break;
                    case TelegramAPI.SettingShowProfilePhoto:
                        showProfilePhotoComboBox.currentIndex = rule;
                        break;
                    case TelegramAPI.SettingShowStatus:
                        showStatusComboBox.currentIndex = rule;
                        break;
                    case TelegramAPI.SettingAllowPrivateVoiceAndVideoNoteMessages:
                        voiceMessagesComboBox.refreshIndex();
                        break;
                    }
                }
            }
            ResponsiveGrid {
                ComboBox {
                    id: allowChatInvitesComboBox
                    width: parent.columnWidth
                    label: qsTr("Allow adding me to groups and channels")
                    description: qsTr("Privacy setting for managing who can add you to groups and channels.")
                    menu: ContextMenu {
                        x: 0
                        width: allowChatInvitesComboBox.width

                        MenuItem {
                            text: qsTr("Yes")
                            onClicked: {
                                tdLibWrapper.setUserPrivacySettingRule(TelegramAPI.SettingAllowChatInvites, TelegramAPI.RuleAllowAll);
                            }
                        }
                        MenuItem {
                            text: qsTr("Your contacts only")
                            onClicked: {
                                tdLibWrapper.setUserPrivacySettingRule(TelegramAPI.SettingAllowChatInvites, TelegramAPI.RuleAllowContacts);
                            }
                        }
                        MenuItem {
                            text: qsTr("No")
                            onClicked: {
                                tdLibWrapper.setUserPrivacySettingRule(TelegramAPI.SettingAllowChatInvites, TelegramAPI.RuleRestrictAll);
                            }
                        }
                    }

                    Component.onCompleted: {
                        currentIndex = tdLibWrapper.getUserPrivacySettingRule(TelegramAPI.SettingAllowChatInvites);
                    }
                }

                ComboBox {
                    id: allowFindingByPhoneNumberComboBox
                    width: parent.columnWidth
                    label: qsTr("Allow finding by phone number")
                    description: qsTr("Privacy setting for managing whether you can be found by your phone number.")
                    menu: ContextMenu {
                        x: 0
                        width: allowFindingByPhoneNumberComboBox.width

                        MenuItem {
                            text: qsTr("Yes")
                            onClicked: {
                                tdLibWrapper.setUserPrivacySettingRule(TelegramAPI.SettingAllowFindingByPhoneNumber, TelegramAPI.RuleAllowAll);
                            }
                        }
                        MenuItem {
                            text: qsTr("Your contacts only")
                            onClicked: {
                                tdLibWrapper.setUserPrivacySettingRule(TelegramAPI.SettingAllowFindingByPhoneNumber, TelegramAPI.RuleAllowContacts);
                            }
                        }
                    }

                    Component.onCompleted: {
                        currentIndex = tdLibWrapper.getUserPrivacySettingRule(TelegramAPI.SettingAllowFindingByPhoneNumber);
                    }
                }

                ComboBox {
                    id: allowCallsComboBox
                    width: parent.columnWidth
                    label: qsTr("Allow calls")
                    description: qsTr("Privacy setting for managing who can call you.")
                    menu: ContextMenu {
                        x: 0
                        width: allowCallsComboBox.width

                        MenuItem {
                            text: qsTr("Everybody")
                            onClicked: {
                                tdLibWrapper.setUserPrivacySettingRule(TelegramAPI.SettingAllowCalls, TelegramAPI.RuleAllowAll);
                            }
                        }
                        MenuItem {
                            text: qsTr("Your contacts only")
                            onClicked: {
                                tdLibWrapper.setUserPrivacySettingRule(TelegramAPI.SettingAllowCalls, TelegramAPI.RuleAllowContacts);
                            }
                        }
                        MenuItem {
                            text: qsTr("Nobody")
                            onClicked: {
                                tdLibWrapper.setUserPrivacySettingRule(TelegramAPI.SettingAllowCalls, TelegramAPI.RuleRestrictAll);
                            }
                        }
                    }

                    Component.onCompleted: {
                        currentIndex = tdLibWrapper.getUserPrivacySettingRule(TelegramAPI.SettingAllowCalls);
                    }
                }

                ComboBox {
                    id: voiceMessagesComboBox
                    property int voiceSetting: TelegramAPI.SettingAllowPrivateVoiceAndVideoNoteMessages
                    width: parent.columnWidth
                    label: qsTr("Voice and video messages")
                    description: qsTr("Who can send you voice messages and video notes (round videos). Premium feature.")
                    // Voci: 0=Tutti(AllowAll), 1=Nessuno(RestrictAll), 2=Solo i selezionati
                    // (AllowUsers), 3=Tutti tranne (RestrictUsers).
                    function isPremium() {
                        return !!(tdLibWrapper.userInformation && tdLibWrapper.userInformation.is_premium);
                    }
                    function refreshIndex() {
                        if (tdLibWrapper.getUserPrivacySettingAllowedUserIds(voiceSetting).length > 0) {
                            currentIndex = 2;     // Solo i selezionati
                        } else if (tdLibWrapper.getUserPrivacySettingRestrictedUserIds(voiceSetting).length > 0) {
                            currentIndex = 3;     // Tutti tranne
                        } else {
                            currentIndex = (tdLibWrapper.getUserPrivacySettingRule(voiceSetting) === TelegramAPI.RuleAllowAll) ? 0 : 1;
                        }
                    }
                    function applyVoiceRule(rule) {
                        if (!isPremium()) {
                            appNotification.show(qsTr("This is a Premium-only feature."));
                            refreshIndex();
                            return;
                        }
                        tdLibWrapper.setUserPrivacySettingRule(voiceSetting, rule);
                    }
                    // allow=true: "Solo i selezionati"; allow=false: "Tutti tranne".
                    function chooseSelectedUsers(allow) {
                        if (!isPremium()) {
                            appNotification.show(qsTr("This is a Premium-only feature."));
                            refreshIndex();
                            return;
                        }
                        var prefill = allow ? tdLibWrapper.getUserPrivacySettingAllowedUserIds(voiceSetting)
                                            : tdLibWrapper.getUserPrivacySettingRestrictedUserIds(voiceSetting);
                        var dlg = pageStack.push(Qt.resolvedUrl("../../pages/StoryAudiencePickerDialog.qml"), {
                            mode: "selected",
                            headerTitle: qsTr("Voice and video messages"),
                            headerDescription: allow
                                ? qsTr("Choose who can send you voice messages and video notes.")
                                : qsTr("Choose who cannot send you voice messages and video notes."),
                            initialSelectedIds: prefill
                        });
                        dlg.accepted.connect(function() {
                            tdLibWrapper.setUserPrivacySettingAllowedUsers(voiceSetting, dlg.selectedUserIds, allow);
                            appNotification.show(qsTr("Privacy updated"));
                            voiceMessagesComboBox.currentIndex = dlg.selectedUserIds.length > 0 ? (allow ? 2 : 3) : (allow ? 1 : 0);
                        });
                    }
                    menu: ContextMenu {
                        x: 0
                        width: voiceMessagesComboBox.width
                        MenuItem {
                            text: qsTr("Everybody")
                            onClicked: voiceMessagesComboBox.applyVoiceRule(TelegramAPI.RuleAllowAll)
                        }
                        MenuItem {
                            text: qsTr("Nobody")
                            onClicked: voiceMessagesComboBox.applyVoiceRule(TelegramAPI.RuleRestrictAll)
                        }
                        MenuItem {
                            text: qsTr("Only selected")
                            onClicked: voiceMessagesComboBox.chooseSelectedUsers(true)
                        }
                        MenuItem {
                            text: qsTr("Everybody except")
                            onClicked: voiceMessagesComboBox.chooseSelectedUsers(false)
                        }
                    }
                    Component.onCompleted: refreshIndex()
                }

                ComboBox {
                    id: showLinkInForwardedMessagesComboBox
                    width: parent.columnWidth
                    label: qsTr("Show link in forwarded messages")
                    description: qsTr("Privacy setting for managing whether a link to your account is included in forwarded messages.")
                    menu: ContextMenu {
                        x: 0
                        width: showLinkInForwardedMessagesComboBox.width

                        MenuItem {
                            text: qsTr("Yes")
                            onClicked: {
                                tdLibWrapper.setUserPrivacySettingRule(TelegramAPI.SettingShowLinkInForwardedMessages, TelegramAPI.RuleAllowAll);
                            }
                        }
                        MenuItem {
                            text: qsTr("Your contacts only")
                            onClicked: {
                                tdLibWrapper.setUserPrivacySettingRule(TelegramAPI.SettingShowLinkInForwardedMessages, TelegramAPI.RuleAllowContacts);
                            }
                        }
                        MenuItem {
                            text: qsTr("No")
                            onClicked: {
                                tdLibWrapper.setUserPrivacySettingRule(TelegramAPI.SettingShowLinkInForwardedMessages, TelegramAPI.RuleRestrictAll);
                            }
                        }
                    }

                    Component.onCompleted: {
                        currentIndex = tdLibWrapper.getUserPrivacySettingRule(TelegramAPI.SettingShowLinkInForwardedMessages);
                    }
                }

                ComboBox {
                    id: showPhoneNumberComboBox
                    width: parent.columnWidth
                    label: qsTr("Show phone number")
                    description: qsTr("Privacy setting for managing whether your phone number is visible.")
                    menu: ContextMenu {
                        x: 0
                        width: showPhoneNumberComboBox.width

                        MenuItem {
                            text: qsTr("Yes")
                            onClicked: {
                                tdLibWrapper.setUserPrivacySettingRule(TelegramAPI.SettingShowPhoneNumber, TelegramAPI.RuleAllowAll);
                            }
                        }
                        MenuItem {
                            text: qsTr("Your contacts only")
                            onClicked: {
                                tdLibWrapper.setUserPrivacySettingRule(TelegramAPI.SettingShowPhoneNumber, TelegramAPI.RuleAllowContacts);
                            }
                        }
                        MenuItem {
                            text: qsTr("No")
                            onClicked: {
                                tdLibWrapper.setUserPrivacySettingRule(TelegramAPI.SettingShowPhoneNumber, TelegramAPI.RuleRestrictAll);
                            }
                        }
                    }

                    Component.onCompleted: {
                        currentIndex = tdLibWrapper.getUserPrivacySettingRule(TelegramAPI.SettingShowPhoneNumber);
                    }
                }

                ComboBox {
                    id: showProfilePhotoComboBox
                    width: parent.columnWidth
                    label: qsTr("Show profile photo")
                    description: qsTr("Privacy setting for managing whether your profile photo is visible.")
                    menu: ContextMenu {
                        x: 0
                        width: showProfilePhotoComboBox.width

                        MenuItem {
                            text: qsTr("Yes")
                            onClicked: {
                                tdLibWrapper.setUserPrivacySettingRule(TelegramAPI.SettingShowProfilePhoto, TelegramAPI.RuleAllowAll);
                            }
                        }
                        MenuItem {
                            text: qsTr("Your contacts only")
                            onClicked: {
                                tdLibWrapper.setUserPrivacySettingRule(TelegramAPI.SettingShowProfilePhoto, TelegramAPI.RuleAllowContacts);
                            }
                        }
                        MenuItem {
                            text: qsTr("No")
                            onClicked: {
                                tdLibWrapper.setUserPrivacySettingRule(TelegramAPI.SettingShowProfilePhoto, TelegramAPI.RuleRestrictAll);
                            }
                        }
                    }

                    Component.onCompleted: {
                        currentIndex = tdLibWrapper.getUserPrivacySettingRule(TelegramAPI.SettingShowProfilePhoto);
                    }
                }

                ComboBox {
                    id: showStatusComboBox
                    width: parent.columnWidth
                    label: qsTr("Show status")
                    description: qsTr("Privacy setting for managing whether your online status is visible.")
                    menu: ContextMenu {
                        x: 0
                        width: showStatusComboBox.width

                        MenuItem {
                            text: qsTr("Yes")
                            onClicked: {
                                tdLibWrapper.setUserPrivacySettingRule(TelegramAPI.SettingShowStatus, TelegramAPI.RuleAllowAll);
                            }
                        }
                        MenuItem {
                            text: qsTr("Your contacts only")
                            onClicked: {
                                tdLibWrapper.setUserPrivacySettingRule(TelegramAPI.SettingShowStatus, TelegramAPI.RuleAllowContacts);
                            }
                        }
                        MenuItem {
                            text: qsTr("No")
                            onClicked: {
                                tdLibWrapper.setUserPrivacySettingRule(TelegramAPI.SettingShowStatus, TelegramAPI.RuleRestrictAll);
                            }
                        }
                    }

                    Component.onCompleted: {
                        currentIndex = tdLibWrapper.getUserPrivacySettingRule(TelegramAPI.SettingShowStatus);
                    }
                }
            }

            TextSwitch {
                checked: appSettings.allowInlineBotLocationAccess
                text: qsTr("Allow sending Location to inline bots")
                description: qsTr("Some inline bots request location data when using them")
                automaticCheck: false
                onClicked: {
                    appSettings.allowInlineBotLocationAccess = !checked
                }
            }

            ValueButton {
                width: parent.width
                label: qsTr("Blocklist")
                value: qsTr("View")
                description: qsTr("Show the list of Telegram users you have blocked.")
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("../../pages/BlacklistPage.qml"));
                }
            }
        }
    }
}
