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
import "./messageContent"
import "../js/functions.js" as Functions
import "../js/twemoji.js" as Emoji
import "../js/debug.js" as Debug

Flickable {
    id: messageOverlayFlickable
    anchors.fill: parent
    boundsBehavior: Flickable.StopAtBounds
    contentHeight: messageContentColumn.height
    clip: true

    property var overlayMessage;
    property bool showHeader: true
    readonly property var userInformation: tdLibWrapper.getUserInformation(overlayMessage.sender_id.user_id);
    readonly property bool isOwnMessage: tdLibWrapper.getUserInformation().id === overlayMessage.sender_id.user_id;
    readonly property bool isAnonymous: overlayMessage.sender_id["@type"] === "messageSenderChat"
    property bool hasContentComponent: overlayMessage.content && chatView.delegateMessagesContent.indexOf(overlayMessage.content['@type']) > -1
    readonly property var overlayWebPageData: resolveOverlayWebPageData()
    signal requestClose;

    function getOriginalAuthor(forwardInformation, fontSize) {
        switch (forwardInformation.origin["@type"]) {
            case "messageOriginChannel":
            case "messageForwardOriginChannel":
                var otherChatInformation = tdLibWrapper.getChat(forwardInformation.origin.chat_id);
                return Emoji.emojify(otherChatInformation.title, fontSize);
            case "messageOriginUser":
            case "messageForwardOriginUser":
                var otherUserInformation = tdLibWrapper.getUserInformation(forwardInformation.origin.sender_id.user_id);
                return Emoji.emojify(Functions.getUserName(otherUserInformation), fontSize);
            default:
                return Emoji.emojify(forwardInformation.origin.sender_name, fontSize);
        }
    }
    function resolveOverlayWebPageData() {
        if (!overlayMessage || !overlayMessage.content) {
            return undefined;
        }
        var content = overlayMessage.content;
        if (typeof content.web_page !== "undefined" && content.web_page !== null) {
            return content.web_page;
        }
        if (content.text && typeof content.text.web_page !== "undefined" && content.text.web_page !== null) {
            return content.text.web_page;
        }
        if (typeof content.link_preview !== "undefined" && content.link_preview !== null) {
            if (content.link_preview.web_page) {
                return content.link_preview.web_page;
            }
            return content.link_preview;
        }
        if (content.text && typeof content.text.link_preview !== "undefined" && content.text.link_preview !== null) {
            if (content.text.link_preview.web_page) {
                return content.text.link_preview.web_page;
            }
            return content.text.link_preview;
        }
        return undefined;
    }

    Component.onCompleted: {
        delegateComponentLoadingTimer.start();
    }

    Timer {
        id: delegateComponentLoadingTimer
        interval: 500
        repeat: false
        running: false
        onTriggered: {
            if (messageOverlayFlickable.hasContentComponent) {
                var type = overlayMessage.content["@type"];
                overlayExtraContentLoader.setSource(
                            "../components/messageContent/" + type.charAt(0).toUpperCase() + type.substring(1) + ".qml",
                            {
                                overlayFlickable: messageOverlayFlickable
                            })
            } else if (typeof messageOverlayFlickable.overlayWebPageData !== "undefined" && messageOverlayFlickable.overlayWebPageData !== null) {
                overlayWebPagePreviewLoader.active = true;
            }
        }
    }

    Rectangle {
        id: messageContentBackground
        color: Theme.overlayBackgroundColor
        opacity: 0.7
        width: parent.width
        height: messageContentColumn.height >= messageOverlayFlickable.height ? messageContentColumn.height : messageOverlayFlickable.height
        MouseArea {
            anchors.fill: parent
            onClicked: {
                messageOverlayFlickable.requestClose();
            }
        }
    }

    Column {
        id: messageContentColumn
        spacing: Theme.paddingMedium
        anchors.top: parent.top
        anchors.topMargin: Theme.paddingMedium
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - ( 2 * Theme.horizontalPageMargin )

        Row {
            visible: messageOverlayFlickable.showHeader
            width: parent.width
            spacing: Theme.paddingMedium
            ProfileThumbnail {
                id: overlayMessagePictureThumbnail
                photoData: messageOverlayFlickable.isAnonymous ? ((typeof chatPage.chatInformation.photo !== "undefined") ? chatPage.chatInformation.photo.small : {}) : ((typeof messageOverlayFlickable.userInformation.profile_photo !== "undefined") ? messageOverlayFlickable.userInformation.profile_photo.small : ({}))
                replacementStringHint: overlayMessageUserText.text
                width: Theme.itemSizeLarge
                height: Theme.itemSizeLarge
            }
            Label {
                id: overlayMessageUserText

                width: parent.width - overlayMessagePictureThumbnail.width
                anchors.verticalCenter: parent.verticalCenter
                text: messageOverlayFlickable.isOwnMessage ? qsTr("You") : Emoji.emojify(messageOverlayFlickable.isAnonymous ? chatPage.chatInformation.title : Functions.getUserName(messageOverlayFlickable.userInformation), font.pixelSize)
                font.pixelSize: Theme.fontSizeExtraLarge
                font.weight: Font.ExtraBold
                maximumLineCount: 1
                truncationMode: TruncationMode.Fade
                textFormat: Text.StyledText
            }
        }

        MessageViaLabel {
            message: overlayMessage
        }

        Text {
            id: overlayForwardedInfoText
            width: parent.width
            visible: typeof overlayMessage.forward_info !== "undefined"
            font.pixelSize: Theme.fontSizeSmall
            font.italic: true
            textFormat: Text.StyledText
            color: Theme.secondaryColor
            wrapMode: Text.Wrap
            text: visible ? qsTr("This message was forwarded. Original author: %1").arg(getOriginalAuthor(overlayMessage.forward_info, font.pixelSize)) : ""
        }

        Text {
            id: overlayMessageText
            width: parent.width
            text: Emoji.emojify(Functions.getMessageText(overlayMessage, false, tdLibWrapper.getUserInformation().id, false), font.pixelSize)
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.primaryColor
            wrapMode: Text.Wrap
            textFormat: Text.RichText
            onLinkActivated: {
                Functions.handleLink(link);
            }
            linkColor: Theme.highlightColor
            visible: (text !== "")
        }

        Loader {
            id: overlayWebPagePreviewLoader
            active: false
            asynchronous: true
            width: parent.width

            sourceComponent: Component {
                id: webPagePreviewComponent
                WebPagePreview {
                    id: webPagePreview

                    onImplicitHeightChanged: {
                        overlayWebPagePreviewLoader.height = webPagePreview.implicitHeight;
                    }
                    webPageData: messageOverlayFlickable.overlayWebPageData
                    largerFontSize: true
                    width: parent.width
                }
            }
        }

        Loader {
            id: overlayExtraContentLoader
            width: parent.width
            asynchronous: true
        }

        Loader {
            id: replyMarkupLoader
            property var myMessage: overlayMessage
            width: parent.width
            height: active ? (overlayMessage.reply_markup.rows.length * (Theme.itemSizeSmall + Theme.paddingSmall) - Theme.paddingSmall) : 0
            asynchronous: true
            active: !!overlayMessage.reply_markup && myMessage.reply_markup.rows
            source: Qt.resolvedUrl("ReplyMarkupButtons.qml")
        }

        Timer {
            id: messageDateUpdater
            interval: 60000
            running: true
            repeat: true
            onTriggered: {
                overlayMessageDateText.text = ( overlayMessageDateText.useElapsed ? Functions.getDateTimeElapsed(overlayMessage.date) : Functions.getDateTimeTranslated(overlayMessage.date) );
            }
        }

        Text {
            width: parent.width

            property bool useElapsed: true

            id: overlayMessageDateText
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
            text: ( useElapsed ? Functions.getDateTimeElapsed(overlayMessage.date) : Functions.getDateTimeTranslated(overlayMessage.date) )
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    overlayMessageDateText.useElapsed = !overlayMessageDateText.useElapsed;
                    overlayMessageDateText.text = ( useElapsed ? Functions.getDateTimeElapsed(overlayMessage.date) : Functions.getDateTimeTranslated(overlayMessage.date) );
                }
            }
        }

        Label {
            id: separatorLabel
            width: parent.width
            font.pixelSize: Theme.fontSizeSmall
        }

    }

    VerticalScrollDecorator {}
}
