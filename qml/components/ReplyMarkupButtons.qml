/*
    Copyright (C) 2020 Sebastian J. Wolf and other contributors

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
import "../js/twemoji.js" as Emoji
import "../js/functions.js" as Functions
import "../js/debug.js" as Debug

Column {
    id: replyMarkupButtons
    width: parent.width
    height: childrenRect.height
    spacing: Theme.paddingSmall

    // di norma i pulsanti del messaggio; un articolo passa qui le sue file di pulsanti
    property var rows: (myMessage && myMessage.reply_markup && myMessage.reply_markup.rows) ? myMessage.reply_markup.rows : []
    // pageBlockButtonRow.align: "" = a tutta larghezza, se no larghi quanto il nome
    property string align: ""

    Repeater {
        model: replyMarkupButtons.rows
        delegate: Row {
            x: replyMarkupButtons.align === "right" ? replyMarkupButtons.width - implicitWidth
             : (replyMarkupButtons.align === "center" ? (replyMarkupButtons.width - implicitWidth) / 2 : 0)
            height: Theme.itemSizeSmall
            spacing: Theme.paddingSmall
            Repeater {
                id: buttonsRepeater
                model: modelData
                property int itemWidth: replyMarkupButtons.width / count
                delegate: MouseArea {
                    /*
                    Unimplemented callback types:
                        inlineKeyboardButtonTypeBuy
                        inlineKeyboardButtonTypeCallbackGame
                        inlineKeyboardButtonTypeCallbackWithPassword
                        inlineKeyboardButtonTypeLoginUrl
                        inlineKeyboardButtonTypeSwitchInline
                    */
                    property var callbacks: ({
                        inlineKeyboardButtonTypeCallback: function(){
                            tdLibWrapper.getCallbackQueryAnswer(myMessage.chat_id, myMessage.id, {data: modelData.type.data, "@type": "callbackQueryPayloadData"})
                        },

                         inlineKeyboardButtonTypeCallbackGame: function(){
                             tdLibWrapper.getCallbackQueryAnswer(myMessage.chat_id, myMessage.id, {game_short_name: myMessage.content.game.short_name, "@type": "callbackQueryPayloadGame"})
                         },
                        inlineKeyboardButtonTypeUrl: function() {
                            Functions.handleLink(modelData.type.url);
                        },
                        inlineKeyboardButtonTypeCopyText: function() {
                            Clipboard.text = modelData.type.text;
                            appNotification.show(qsTr("Text copied to clipboard"));
                        },
                        inlineKeyboardButtonTypeUser: function() {
                            Functions.handleLink("userId://" + modelData.type.user_id);
                        },
                        inlineKeyboardButtonTypeSwitchInline: function() {
                            if(modelData.type.in_current_chat) {
                                chatPage.setMessageText("@" + userInformation.usernames.editable_username + " "+(modelData.type.query || ""))
                            } else {

                                pageStack.push(Qt.resolvedUrl("../pages/ChatSelectionPage.qml"), {
                                    myUserId: chatPage.myUserId,
                                    payload: { neededPermissions: ["can_send_other_messages"], text:"@" + userInformation.usernames.editable_username + " "+(modelData.type.query || "")},
                                    state: "fillTextArea"
                                })
                            }
                        },

                        keyboardButtonTypeText: function() {
                            chatPage.setMessageText(modelData.text, true);
                        }
                    })
                    enabled: !!callbacks[modelData.type["@type"]]
                    id: buttonItem
                    // ButtonStyle: i tre colori dello schema; «Link» e' senza sfondo
                    readonly property string styleType: modelData.style ? modelData.style["@type"] : ""
                    readonly property color styleColor: styleType === "buttonStylePrimary" ? "#2481cc"
                                                      : (styleType === "buttonStyleDanger" ? "#d9464a"
                                                      : (styleType === "buttonStyleSuccess" ? "#2ea64f" : "transparent"))
                    readonly property bool hasStyleColor: styleColor.a > 0
                    readonly property real rowShare: (replyMarkupButtons.width + Theme.paddingSmall) / buttonsRepeater.count - (Theme.paddingSmall)
                    height: Theme.itemSizeSmall
                    width: replyMarkupButtons.align !== ""
                           ? Math.min(rowShare, buttonLabel.implicitWidth + 2 * Theme.paddingLarge)
                           : rowShare
                    onClicked: {
                        callbacks[modelData.type["@type"]]();
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.paddingSmall
                        color: parent.pressed ? Theme.rgba(Theme.highlightBackgroundColor, Theme.highlightBackgroundOpacity)
                                          : (buttonItem.hasStyleColor ? buttonItem.styleColor
                                          : (buttonItem.styleType === "buttonStyleLink" ? "transparent"
                                          : Theme.rgba(Theme.primaryColor, Theme.opacityFaint)))
                        opacity: parent.enabled ? 1.0 : Theme.opacityLow

                        Label {
                            id: buttonLabel
                            width: Math.min(parent.width - Theme.paddingSmall*2, contentWidth)
                            truncationMode: TruncationMode.Fade
                            text: Emoji.emojify(modelData.text, Theme.fontSizeSmall)
                            color: parent.parent.pressed ? Theme.highlightColor
                                 : (buttonItem.hasStyleColor ? "white"
                                 : (buttonItem.styleType === "buttonStyleLink" ? Functions.messageLinkColor() : Theme.primaryColor))
                            anchors.centerIn: parent
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        Icon {
                            property var sources: ({
                                                   inlineKeyboardButtonTypeUrl: "../../images/icon-s-link.svg",
                                                   inlineKeyboardButtonTypeCopyText: "image://theme/icon-s-clipboard",
                                                   inlineKeyboardButtonTypeSwitchInline: !modelData.type.in_current_chat ? "image://theme/icon-s-repost" : "image://theme/icon-s-edit",
                                                   inlineKeyboardButtonTypeCallbackWithPassword: "image://theme/icon-s-asterisk"
                                                   })
                            visible: !!sources[modelData.type["@type"]]
                            opacity: 0.6
                            source: sources[modelData.type["@type"]] || ""
                            sourceSize: Qt.size(Theme.iconSizeSmall, Theme.iconSizeSmall)
                            highlighted: parent.pressed
                            anchors {
                                right: parent.right
                                top: parent.top
                            }
                        }
                    }

                }
            }
        }
    }
}
