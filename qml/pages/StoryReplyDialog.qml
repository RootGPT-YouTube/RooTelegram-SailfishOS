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

Dialog {
    id: replyDialog
    allowedOrientations: Orientation.All

    property string storyPosterChatId: ""
    property int storyId: 0
    property string posterName: ""

    canAccept: messageField.text.trim().length > 0

    onAccepted: {
        tdLibWrapper.sendStoryReply(replyDialog.storyPosterChatId,
                                    replyDialog.storyId,
                                    messageField.text.trim());
        appNotification.show(qsTr("Reply sent"));
    }

    Column {
        width: parent.width

        DialogHeader {
            acceptText: qsTr("Send")
            title: replyDialog.posterName.length > 0
                   ? qsTr("Reply to %1").arg(replyDialog.posterName)
                   : qsTr("Reply to story")
        }

        TextArea {
            id: messageField
            width: parent.width
            label: qsTr("Reply")
            placeholderText: qsTr("Write a reply…")
            focus: true
            EnterKey.iconSource: "image://theme/icon-m-enter-accept"
            EnterKey.onClicked: {
                if (replyDialog.canAccept) replyDialog.accept();
            }
        }
    }

    Component.onCompleted: messageField.forceActiveFocus()
}
