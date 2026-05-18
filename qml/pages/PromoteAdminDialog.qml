/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), which is
    licensed under the GNU General Public License v3.0. The original
    license is available at:
    https://github.com/Wunderfitz/harbour-fernschreiber/blob/master/LICENSE
*/
import QtQuick 2.6
import Sailfish.Silica 1.0

Dialog {
    id: promoteAdminDialog
    allowedOrientations: Orientation.All

    property string userName: ""
    property bool isChannelChat: false

    // Compilato dal chiamante con i diritti di default; in caso di
    // modifica admin esistente si possono passare quelli correnti.
    property var initialRights: ({})
    property string initialCustomTitle: ""

    // Risultato esposto al chiamante quando il dialog è accettato.
    property var resultStatus: null

    canAccept: true

    onAccepted: {
        var rights = {
            "@type": "chatAdministratorRights",
            "can_manage_chat": canManageChatSwitch.checked,
            "can_change_info": canChangeInfoSwitch.checked,
            "can_post_messages": canPostMessagesSwitch.checked,
            "can_edit_messages": canEditMessagesSwitch.checked,
            "can_delete_messages": canDeleteMessagesSwitch.checked,
            "can_invite_users": canInviteUsersSwitch.checked,
            "can_restrict_members": canRestrictMembersSwitch.checked,
            "can_pin_messages": canPinMessagesSwitch.checked,
            "can_manage_topics": canManageTopicsSwitch.checked,
            "can_promote_members": canPromoteMembersSwitch.checked,
            "can_manage_video_chats": canManageVideoChatsSwitch.checked,
            "can_post_stories": canPostStoriesSwitch.checked,
            "can_edit_stories": canEditStoriesSwitch.checked,
            "can_delete_stories": canDeleteStoriesSwitch.checked,
            "is_anonymous": isAnonymousSwitch.checked
        }
        var trimmedTitle = customTitleField.text.trim()
        if (trimmedTitle.length > 16) {
            trimmedTitle = trimmedTitle.substring(0, 16)
        }
        resultStatus = {
            "@type": "chatMemberStatusAdministrator",
            "custom_title": trimmedTitle,
            "can_be_edited": true,
            "rights": rights,
            "can_manage_chat": rights.can_manage_chat,
            "can_change_info": rights.can_change_info,
            "can_post_messages": rights.can_post_messages,
            "can_edit_messages": rights.can_edit_messages,
            "can_delete_messages": rights.can_delete_messages,
            "can_invite_users": rights.can_invite_users,
            "can_restrict_members": rights.can_restrict_members,
            "can_pin_messages": rights.can_pin_messages,
            "can_manage_topics": rights.can_manage_topics,
            "can_promote_members": rights.can_promote_members,
            "can_manage_video_chats": rights.can_manage_video_chats,
            "is_anonymous": rights.is_anonymous
        }
    }

    function rightOrDefault(key, fallback) {
        if (initialRights && typeof initialRights[key] === "boolean") {
            return initialRights[key]
        }
        return fallback
    }

    SilicaFlickable {
        id: dialogFlickable
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        DialogHeader {
            id: dialogHeader
            acceptText: qsTr("Promote")
            cancelText: qsTr("Cancel")
        }

        Column {
            id: contentColumn
            anchors {
                top: dialogHeader.bottom
                left: parent.left
                right: parent.right
                margins: Theme.horizontalPageMargin
            }
            spacing: Theme.paddingMedium

            Label {
                width: parent.width
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.highlightColor
                text: userName.length > 0
                      ? qsTr("Promote %1 to Admin").arg(userName)
                      : qsTr("Promote to Admin")
            }

            TextField {
                id: customTitleField
                width: parent.width
                label: qsTr("Custom title (max 16 characters)")
                placeholderText: qsTr("e.g. Moderator")
                text: promoteAdminDialog.initialCustomTitle
                maximumLength: 16
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }

            SectionHeader {
                text: qsTr("Privileges")
            }

            TextSwitch {
                id: canManageChatSwitch
                text: qsTr("Manage chat", "admin privilege")
                description: qsTr("View admin log and chat statistics.")
                checked: rightOrDefault("can_manage_chat", true)
            }
            TextSwitch {
                id: canChangeInfoSwitch
                text: qsTr("Change group info", "admin privilege")
                description: qsTr("Title, photo and description.")
                checked: rightOrDefault("can_change_info", false)
            }
            TextSwitch {
                id: canDeleteMessagesSwitch
                text: qsTr("Delete messages", "admin privilege")
                checked: rightOrDefault("can_delete_messages", false)
            }
            TextSwitch {
                id: canRestrictMembersSwitch
                text: qsTr("Ban users", "admin privilege")
                checked: rightOrDefault("can_restrict_members", false)
            }
            TextSwitch {
                id: canInviteUsersSwitch
                text: qsTr("Invite users", "admin privilege")
                checked: rightOrDefault("can_invite_users", true)
            }
            TextSwitch {
                id: canPinMessagesSwitch
                text: qsTr("Pin messages", "admin privilege")
                visible: !promoteAdminDialog.isChannelChat
                checked: rightOrDefault("can_pin_messages", true)
            }
            TextSwitch {
                id: canManageTopicsSwitch
                text: qsTr("Manage topics", "admin privilege")
                visible: !promoteAdminDialog.isChannelChat
                checked: rightOrDefault("can_manage_topics", true)
            }
            TextSwitch {
                id: canManageVideoChatsSwitch
                text: qsTr("Manage video chats", "admin privilege")
                checked: rightOrDefault("can_manage_video_chats", true)
            }
            TextSwitch {
                id: canPostMessagesSwitch
                text: qsTr("Post messages", "admin privilege (channels)")
                visible: promoteAdminDialog.isChannelChat
                checked: rightOrDefault("can_post_messages", false)
            }
            TextSwitch {
                id: canEditMessagesSwitch
                text: qsTr("Edit messages of others", "admin privilege (channels)")
                visible: promoteAdminDialog.isChannelChat
                checked: rightOrDefault("can_edit_messages", false)
            }
            TextSwitch {
                id: canPostStoriesSwitch
                text: qsTr("Post stories", "admin privilege (channels)")
                visible: promoteAdminDialog.isChannelChat
                checked: rightOrDefault("can_post_stories", false)
            }
            TextSwitch {
                id: canEditStoriesSwitch
                text: qsTr("Edit stories", "admin privilege (channels)")
                visible: promoteAdminDialog.isChannelChat
                checked: rightOrDefault("can_edit_stories", false)
            }
            TextSwitch {
                id: canDeleteStoriesSwitch
                text: qsTr("Delete stories", "admin privilege (channels)")
                visible: promoteAdminDialog.isChannelChat
                checked: rightOrDefault("can_delete_stories", false)
            }
            TextSwitch {
                id: canPromoteMembersSwitch
                text: qsTr("Add new admins", "admin privilege")
                description: qsTr("With the rights this user already has.")
                checked: rightOrDefault("can_promote_members", false)
            }
            TextSwitch {
                id: isAnonymousSwitch
                text: qsTr("Anonymous", "admin privilege")
                description: qsTr("Send messages as the group itself.")
                visible: !promoteAdminDialog.isChannelChat
                checked: rightOrDefault("is_anonymous", false)
            }
        }

        VerticalScrollDecorator {}
    }
}
