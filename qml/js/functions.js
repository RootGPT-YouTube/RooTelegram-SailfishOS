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

.pragma library
.import "debug.js" as Debug
.import Sailfish.Silica 1.0 as Silica

var tdLibWrapper;
var appNotification;
function setGlobals(globals) {
    tdLibWrapper = globals.tdLibWrapper;
    appNotification = globals.appNotification;
}
function formatUnreadCount(value) {
    if(value < 1000) {
        return value;
    } else if(value > 9000) {
        return '9k+';
    }
    return ''+Math.floor(value / 1000)+'k'+((value % 1000)>0 ? '+' : '');
}

function getUserName(userInformation) {
    return ((userInformation.first_name || "") + " " + (userInformation.last_name || "")).trim();
}

// Nome utente tappabile per i messaggi di servizio ("ha rimosso X", "ha aggiunto
// Y"): genera un link `userId://` che Functions.handleLink apre come chat privata.
// In contesti `simple` (anteprime lista chat, clipboard, edit) restituisce il
// nome semplice senza HTML, per non sporcare il testo plain.
function getServiceUserLink(userId, simple) {
    var name = getUserName(tdLibWrapper.getUserInformation(userId));
    if (simple) {
        return name;
    }
    return "<a style=\"font-weight: bold; color:" + messageLinkColor() + ";\" href=\"userId://" + userId + "\">" + name + "</a>";
}

// Censura plain-text degli spoiler per i preview (chat list, notifiche): sostituisce
// la sostringa coperta da textEntityTypeSpoiler con blocchi unicode U+2588 della
// stessa lunghezza, così l'utente non legge il contenuto nel preview ma percepisce
// che lì c'è uno spoiler.
function censorSpoilersPlain(formattedText) {
    if (!formattedText || !formattedText.text) {
        return formattedText ? formattedText.text || "" : "";
    }
    var entities = formattedText.entities || [];
    if (entities.length === 0) {
        return formattedText.text;
    }
    var spoilerEntities = [];
    for (var i = 0; i < entities.length; i++) {
        if (entities[i] && entities[i].type && entities[i].type['@type'] === "textEntityTypeSpoiler") {
            spoilerEntities.push(entities[i]);
        }
    }
    if (spoilerEntities.length === 0) {
        return formattedText.text;
    }
    // Process in reverse order to keep offsets stable.
    spoilerEntities.sort(function(a, b) { return b.offset - a.offset; });
    var result = formattedText.text;
    for (var k = 0; k < spoilerEntities.length; k++) {
        var sp = spoilerEntities[k];
        var blocks = "";
        for (var j = 0; j < sp.length; j++) { blocks += "█"; }
        result = result.substring(0, sp.offset) + blocks + result.substring(sp.offset + sp.length);
    }
    return result;
}

function getMessageText(message, simple, currentUserId, ignoreEntities, revealedSpoilers) {

    var myself = false;
    if ( message['@type'] !== "sponsoredMessage" ) {
        myself = ( message.sender_id['@type'] === "messageSenderUser" && message.sender_id.user_id.toString() === currentUserId.toString() );
    }
    // Colore del testo monospace (tap-to-copy): lo stesso colore del testo del
    // messaggio — i propri messaggi usano highlightColor, gli altrui primaryColor —
    // così il blocco "code" non assume il colore-link pur essendo un <a> tappabile.
    var monoTextColor = myself ? Silica.Theme.highlightColor : Silica.Theme.primaryColor;

    switch(message.content['@type']) {
    case 'messageText':
        if (simple) {
            return censorSpoilersPlain(message.content.text);
        } else {
            return enhanceMessageText(message.content.text, ignoreEntities, revealedSpoilers, monoTextColor);
        }
    case 'messageRichMessage':
        if (!message.content.message) {
            return "";
        }
        if (simple || ignoreEntities) {
            return pageBlocksToText(message.content.message.blocks, true);
        }
        // I blocchi fino alla prima foto e la foto li disegna MessageRichMessage.qml
        // sopra il testo; qui resta il seguito (preceduto dalla didascalia della foto).
        var richLayout = getRichMessageLayout(message.content);
        var richCaption = (richLayout.photoBlock && richLayout.photoBlock.caption && richLayout.head.length + richLayout.tail.length < message.content.message.blocks.length)
                ? richTextToText(richLayout.photoBlock.caption.text, false) : "";
        var richBody = pageBlocksToText(richLayout.tail, false, richLayout.photoBlock);
        return (richCaption && richBody) ? richCaption + "<br><br>" + richBody : (richCaption || richBody);
    case 'messageSticker':
        return simple ? message.content.sticker.emoji : ""
    case 'messageAnimatedEmoji':
        return simple ? message.content.animated_emoji.sticker.emoji : ""
    case 'messagePhoto':
        if (message.content.caption.text !== "") {
            return simple ? qsTr("Picture: %1").arg(censorSpoilersPlain(message.content.caption)) : enhanceMessageText(message.content.caption, ignoreEntities, revealedSpoilers, monoTextColor)
        } else {
            return simple ? (myself ? qsTr("sent a picture", "myself") : qsTr("sent a picture")) : "";
        }
    case 'messageVideo':
        if (message.content.caption.text !== "") {
            return simple ? qsTr("Video: %1").arg(censorSpoilersPlain(message.content.caption)) : enhanceMessageText(message.content.caption, ignoreEntities, revealedSpoilers, monoTextColor)
        } else {
            return simple ? (myself ? qsTr("sent a video", "myself") : qsTr("sent a video")) : "";
        }
    case 'messageVideoNote':
        return simple ? (myself ? qsTr("sent a video note", "myself") : qsTr("sent a video note")) : "";
    case 'messageAnimation':
        if (message.content.caption.text !== "") {
            return simple ? qsTr("Animation: %1").arg(censorSpoilersPlain(message.content.caption)) : enhanceMessageText(message.content.caption, ignoreEntities, revealedSpoilers, monoTextColor)
        } else {
            return simple ? (myself ? qsTr("sent an animation", "myself") : qsTr("sent an animation")) : "";
        }
    case 'messageAudio':
        if (message.content.caption.text !== "") {
            return simple ? qsTr("Audio: %1").arg(censorSpoilersPlain(message.content.caption)) : enhanceMessageText(message.content.caption, ignoreEntities, revealedSpoilers, monoTextColor)
        } else {
            return simple ? (myself ? qsTr("sent an audio", "myself") : qsTr("sent an audio")) : "";
        }
    case 'messageVoiceNote':
        if (message.content.caption.text !== "") {
            return simple ? qsTr("Voice Note: %1").arg(censorSpoilersPlain(message.content.caption)) : enhanceMessageText(message.content.caption, ignoreEntities, revealedSpoilers, monoTextColor)
        } else {
            return simple ? (myself ? qsTr("sent a voice note", "myself") : qsTr("sent a voice note")) : "";
        }
    case 'messageDocument':
        if (message.content.document.file_name !== "") {
            return simple ? qsTr("Document: %1").arg(message.content.document.file_name) : (message.content.caption.text !== "" ? enhanceMessageText(message.content.caption, ignoreEntities, revealedSpoilers, monoTextColor) : "").trim();
        } else {
            return simple ? (myself ? qsTr("sent a document", "myself") : qsTr("sent a document")) : "";
        }
    case 'messageLocation':
    case 'messageLiveLocation':
        return simple ? (myself ? qsTr("sent a location", "myself") : qsTr("sent a location")) : "";
    case 'messageContact':
        return simple ? (myself ? qsTr("sent a contact", "myself") : qsTr("sent a contact")) : "";
    case 'messageVenue':
        return simple ? (myself ? qsTr("sent a venue", "myself") : qsTr("sent a venue")) : ( "<b>" + message.content.venue.title + "</b>, " + message.content.venue.address );
    case 'messageContactRegistered':
        return myself ? qsTr("have registered with Telegram") : qsTr("has registered with Telegram");
    case 'messageChatJoinByLink':
    case 'messageChatJoinByRequest':
        return myself ? qsTr("joined this chat", "myself") : qsTr("joined this chat");
    case 'messageChatAddMembers':
        if (message.sender_id['@type'] === "messageSenderUser" && message.sender_id.user_id === message.content.member_user_ids[0]) {
            return myself ? qsTr("were added to this chat", "myself") : qsTr("was added to this chat");
        } else {
            var addedUserNames = "";
            for (var i = 0; i < message.content.member_user_ids.length; i++) {
                if (i > 0) {
                    addedUserNames += ", ";
                }
                addedUserNames += getServiceUserLink(message.content.member_user_ids[i], simple);
            }
            return myself ? qsTr("have added %1 to the chat", "myself").arg(addedUserNames) : qsTr("has added %1 to the chat").arg(addedUserNames);
        }
    case 'messageChatDeleteMember':
        if (message.sender_id['@type'] === "messageSenderUser" && message.sender_id.user_id === message.content.user_id) {
            return myself ? qsTr("left this chat", "myself") : qsTr("left this chat");
        } else {
            return myself ? qsTr("have removed %1 from the chat", "myself").arg(getServiceUserLink(message.content.user_id, simple)) : qsTr("has removed %1 from the chat").arg(getServiceUserLink(message.content.user_id, simple));
        }
    case 'messageChatChangeTitle':
        return myself ? qsTr("changed the chat title to %1", "myself").arg(message.content.title) : qsTr("changed the chat title to %1").arg(message.content.title);
    case 'messagePoll':
        if (message.content.poll.type['@type'] === "pollTypeQuiz") {
            if (message.content.poll.is_anonymous) {
                return simple ? (myself ? qsTr("sent an anonymous quiz", "myself") : qsTr("sent an anonymous quiz")) : ("<b>" + qsTr("Anonymous Quiz") + "</b>");
            }
            return simple ? (myself ? qsTr("sent a quiz", "myself") : qsTr("sent a quiz")) : ("<b>" + qsTr("Quiz") + "</b>");
        }
        if (message.content.poll.is_anonymous) {
            return simple ? (myself ? qsTr("sent an anonymous poll", "myself") : qsTr("sent an anonymous poll")) : ("<b>" + qsTr("Anonymous Poll") + "</b>");
        }
        return simple ? (myself ? qsTr("sent a poll", "myself") : qsTr("sent a poll")) : ("<b>" + qsTr("Poll") + "</b>");
    case 'messageBasicGroupChatCreate':
    case 'messageSupergroupChatCreate':
        return myself ? qsTr("created this group", "myself") : qsTr("created this group");
    case 'messageChatChangePhoto':
        return myself ? qsTr("changed the chat photo", "myself") : qsTr("changed the chat photo");
    case 'messageChatDeletePhoto':
        return myself ? qsTr("deleted the chat photo", "myself") : qsTr("deleted the chat photo");
    case 'messageChatSetTtl':
        return myself ? qsTr("changed the secret chat TTL setting", "myself; TTL = Time To Live") : qsTr("changed the secret chat TTL setting", "TTL = Time To Live");
    case 'messageChatUpgradeFrom':
    case 'messageChatUpgradeTo':
        return myself ? qsTr("upgraded this group to a supergroup", "myself") : qsTr("upgraded this group to a supergroup");
    case 'messageCustomServiceAction':
        return message.content.text;
    case 'messagePinMessage':
        return myself ? qsTr("changed the pinned message", "myself") : qsTr("changed the pinned message");
    case 'messageExpiredPhoto':
        return myself ? qsTr("sent a self-destructing photo that is expired", "myself") : qsTr("sent a self-destructing photo that is expired");
    case 'messageExpiredVideo':
        return myself ? qsTr("sent a self-destructing video that is expired", "myself") : qsTr("sent a self-destructing video that is expired");
    case 'messageScreenshotTaken':
        return myself ? qsTr("created a screenshot in this chat", "myself") : qsTr("created a screenshot in this chat");
    case 'messageGame':
        return simple ? (myself ? qsTr("sent a game", "myself") : qsTr("sent a game")) : "";
    case 'messageGameScore':
        return myself ? qsTr("scored %Ln points", "myself", message.content.score) : qsTr("scored %Ln points", "myself", message.content.score);
    case 'messageCall':
        if (message.content.discard_reason && message.content.discard_reason['@type'] === "callDiscardReasonMissed") {
            return myself ? qsTr("cancelled a call", "myself") : qsTr("missed a call");
        }
        return myself ? qsTr("started a call", "myself") : qsTr("started a call");
    case 'messageVideoChatStarted':
        return myself ? qsTr("started a video chat", "myself") : qsTr("started a video chat");
    case 'messageVideoChatEnded':
        return myself ? qsTr("ended the video chat", "myself") : qsTr("ended the video chat");
    case 'messageVideoChatScheduled':
        return myself ? qsTr("scheduled a video chat", "myself") : qsTr("scheduled a video chat");
    case 'messageInviteVideoChatParticipants':
        return myself ? qsTr("invited participants to the video chat", "myself") : qsTr("invited participants to the video chat");
    case 'messageChatSetTheme':
        return myself ? qsTr("changed the chat theme", "myself") : qsTr("changed the chat theme");
    case 'messageChatSetBackground':
        return myself ? qsTr("changed the chat background", "myself") : qsTr("changed the chat background");
    case 'messageForumTopicCreated':
        return qsTr("created topic: %1").arg(message.content.name || "");
    case 'messageForumTopicEdited':
        var editedName = message.content.name || "";
        if (editedName) return qsTr("renamed topic to: %1").arg(editedName);
        if (message.content.edit_icon_custom_emoji !== undefined) return qsTr("edited topic icon");
        if (message.content.is_closed !== undefined) return message.content.is_closed ? qsTr("closed topic") : qsTr("reopened topic");
        return qsTr("edited topic");
    case 'messageForumTopicIsClosedToggled':
        return message.content.is_closed ? qsTr("closed topic") : qsTr("reopened topic");
    case 'messageForumTopicIsHiddenToggled':
        return message.content.is_hidden ? qsTr("hid topic") : qsTr("unhid topic");
    // --- #19(B): tipi di contenuto che un utente normale incontra davvero. Prima
    // finivano nel ramo default qui sotto, cioe' "ha inviato un messaggio non
    // supportato: <tipo>". I campi si leggono in modo difensivo: uno snapshot di
    // TDLib diverso puo' non averli, e un undefined non deve rompere l'anteprima.
    case 'messageStory':
        if (message.content.via_mention) {
            return qsTr("mentioned you in a story");
        }
        return myself ? qsTr("shared a story", "myself") : qsTr("shared a story");
    case 'messageGiveaway':
        return myself ? qsTr("sent a giveaway", "myself") : qsTr("sent a giveaway");
    case 'messageGiveawayCreated':
        return qsTr("started a giveaway");
    case 'messageGiveawayCompleted':
        return qsTr("giveaway ended");
    case 'messageGiveawayWinners':
        return qsTr("giveaway winners");
    case 'messageInvoice':
        var invoiceTitle = (message.content.product_info && message.content.product_info.title) ? message.content.product_info.title : "";
        if (invoiceTitle !== "") {
            return qsTr("Invoice: %1", "%1 is the name of the product").arg(simple ? invoiceTitle : enhanceHtmlEntities(invoiceTitle));
        }
        return myself ? qsTr("sent an invoice", "myself") : qsTr("sent an invoice");
    case 'messagePaymentSuccessful':
        return qsTr("payment completed");
    case 'messageDice':
        // Il dado non ha niente da tradurre: e' l'emoji stessa, col risultato.
        return (message.content.emoji || "\ud83c\udfb2") + ((typeof message.content.value === "number" && message.content.value > 0) ? (" (" + message.content.value + ")") : "");
    case 'messageChatShared':
        return myself ? qsTr("shared a chat", "myself") : qsTr("shared a chat");
    case 'messageUsersShared':
        return myself ? qsTr("shared a user", "myself") : qsTr("shared a user");
    case 'messageProximityAlertTriggered':
        return qsTr("is now nearby");
    case 'messageExpiredVoiceNote':
        return qsTr("expired voice note");
    case 'messageExpiredVideoNote':
        return qsTr("expired video note");
    case 'messageChatSetMessageAutoDeleteTime':
        return (message.content.message_auto_delete_time > 0) ? qsTr("enabled auto-delete of messages") : qsTr("disabled auto-delete of messages");
    case 'messageGroupCall':
        return message.content.is_video ? qsTr("video chat") : qsTr("group call");
    case 'messageUnsupported':
        return myself ? qsTr("sent an unsupported message", "myself") : qsTr("sent an unsupported message");
    default:
        return myself ? qsTr("sent an unsupported message: %1", "myself; %1 is message type").arg(message.content['@type'].substring(7)) : qsTr("sent an unsupported message: %1", "%1 is message type").arg(message.content['@type'].substring(7));
    }
}

function getChatPartnerStatusText(statusType, was_online) {
    switch(statusType) {
    case "userStatusEmpty":
        return qsTr("was never online");
    case "userStatusLastMonth":
        return qsTr("last online: last month");
    case "userStatusLastWeek":
        return qsTr("last online: last week");
    case "userStatusOffline":
        return qsTr("last online: %1").arg(getDateTimeElapsed(was_online));
    case "userStatusOnline":
        return qsTr("online");
    case "userStatusRecently":
        return qsTr("was recently online");
    }
}

function getSecretChatStatus(secretChatDetails) {
    switch (secretChatDetails.state["@type"]) {
    case "secretChatStateClosed":
        return "<b>" + qsTr("Closed!") + "</b>";
    case "secretChatStatePending":
        return qsTr("Pending acknowledgement");
    case "secretChatStateReady":
        return "";
    }
}

function getChatMemberStatusText(statusType) {
    switch(statusType) {
    case "chatMemberStatusAdministrator":
        return qsTr("Admin", "channel user role");
    case "chatMemberStatusBanned":
        return qsTr("Banned", "channel user role");
    case "chatMemberStatusCreator":
        return qsTr("Creator", "channel user role");
    case "chatMemberStatusRestricted":
        return qsTr("Restricted", "channel user role");
    case "chatMemberStatusLeft":
    case "chatMemberStatusMember":
        return ""
    }
    return statusType || "";
}

function getShortenedCount(count) {
    if (count >= 1000000) {
        return qsTr("%1M").arg((count / 1000000).toLocaleString(Qt.locale(), 'f', 0));
    } else if (count >= 1000 ) {
        return qsTr("%1K").arg((count / 1000).toLocaleString(Qt.locale(), 'f', 0));
    } else {
        return count;
    }
}

// Colore di link, username e di ogni altro collegamento nei messaggi, in UN solo
// punto. 19/09/2026, richiesta dell'utente: sui temi scuri il CELESTE #80c4ff
// (prima rosso-arancio), cioe' il colore di evidenziazione della sua ambience,
// scelto da lui guardando il nome di un file allegato. E' fisso apposta: preso
// da Theme.highlightColor cambierebbe con l'ambience (rosa, salmone...). Sui temi
// chiari un blu piu' scuro, perche' li' un celeste chiaro non si leggerebbe.
function messageLinkColor() {
    return (Silica.Theme.colorScheme === Silica.Theme.DarkOnLight) ? "#1c6fb0" : "#80c4ff";
}

function getDateTimeElapsed(timestamp) {
    return Silica.Format.formatDate(new Date(timestamp * 1000), Silica.Formatter.DurationElapsed);
}

function getDateTimeTranslated(timestamp) {
    return new Date(timestamp * 1000).toLocaleString();
}

function getDateTimeTimepoint(timestamp) {
    return Silica.Format.formatDate(new Date(timestamp * 1000), Silica.Formatter.TimepointRelative);
}

function handleHtmlEntity(messageText, messageInsertions, originalString, replacementString) {
    var nextIndex = -1;
    while ((nextIndex = messageText.indexOf(originalString, nextIndex + 1)) > -1) {
        messageInsertions.push({ offset: nextIndex, insertionString: replacementString, removeLength: originalString.length });
    }
}

var rawNewLineRegExp = /\r?\n/g;
var ampRegExp = /&/g;
var ltRegExp = /</g;
var gtRegExp = />/g;

// TDLib 1.8.67: messageRichMessage. Il contenuto e' un elenco di PageBlock (gli
// stessi dell'Instant View) fatti di RichText annidati. Qui se ne da' una resa di
// SOLO testo: titoli in grassetto, paragrafi, elenchi, citazioni, codice e link;
// i media diventano un segnaposto (emoji, cosi' non servono stringhe da tradurre).
// plain = true -> testo nudo per anteprime e notifiche.
function richTextToText(richText, plain) {
    if (!richText) {
        return "";
    }
    var inner = function(t) { return richTextToText(t, plain); };
    var wrap = function(tag, t) { return plain ? inner(t) : "<" + tag + ">" + inner(t) + "</" + tag + ">"; };
    switch (richText['@type']) {
    case 'richTextPlain':
        return plain ? richText.text : enhanceHtmlEntities(richText.text).replace(rawNewLineRegExp, "<br>");
    case 'richTexts':
        var parts = [];
        for (var i = 0; i < (richText.texts || []).length; i++) {
            parts.push(richTextToText(richText.texts[i], plain));
        }
        return parts.join("");
    case 'richTextBold': return wrap("b", richText.text);
    case 'richTextItalic': return wrap("i", richText.text);
    case 'richTextUnderline': return wrap("u", richText.text);
    case 'richTextStrikethrough': return wrap("s", richText.text);
    case 'richTextSubscript': return wrap("sub", richText.text);
    case 'richTextSuperscript': return wrap("sup", richText.text);
    case 'richTextFixed': return wrap("tt", richText.text);
    case 'richTextUrl':
    case 'richTextReferenceLink':
    case 'richTextAnchorLink':
        if (plain || !richText.url) {
            return inner(richText.text);
        }
        return "<a style=\"color:" + messageLinkColor() + ";\" href=\"" + enhanceHtmlEntities(richText.url) + "\">" + inner(richText.text) + "</a>";
    case 'richTextEmailAddress':
        return plain ? inner(richText.text) : "<a style=\"color:" + messageLinkColor() + ";\" href=\"mailto:" + enhanceHtmlEntities(richText.email_address) + "\">" + inner(richText.text) + "</a>";
    case 'richTextPhoneNumber':
        return plain ? inner(richText.text) : "<a style=\"color:" + messageLinkColor() + ";\" href=\"tel:" + enhanceHtmlEntities(richText.phone_number) + "\">" + inner(richText.text) + "</a>";
    case 'richTextCustomEmoji':
        return plain ? richText.alternative_text : enhanceHtmlEntities(richText.alternative_text || "");
    case 'richTextMathematicalExpression':
        return plain ? richText.expression : "<tt>" + enhanceHtmlEntities(richText.expression || "") + "</tt>";
    case 'richTextAnchor':
    case 'richTextIcon':
    case 'richTextButton':
        return "";
    case 'richTextDiff':
        return inner(richText.text);
    default:
        // richTextSpoiler/Marked/Mention/Hashtag/... : conta il testo contenuto
        return richText.text ? inner(richText.text) : "";
    }
}

// ---- Composer degli articoli (RichMessageComposerPage.qml) -----------------------
// Ogni blocco di testo e' un campo WYSIWYG: il suo contenuto arriva da
// ComposerFormatter.toFormattedText come { text, entities } (le stesse entita' dei
// messaggi normali) e qui diventa RichText. I link con un testo proprio si scrivono
// [testo](indirizzo); quelli nudi li riconosce il server (detect_automatic_blocks).

var composerEntityRichTypes = {
    textEntityTypeBold: 'richTextBold',
    textEntityTypeItalic: 'richTextItalic',
    textEntityTypeUnderline: 'richTextUnderline',
    textEntityTypeStrikethrough: 'richTextStrikethrough',
    textEntityTypeCode: 'richTextFixed',
    textEntityTypeSpoiler: 'richTextSpoiler'
};

function composerRichTexts(nodes) {
    return nodes.length === 1 ? nodes[0] : { '@type': 'richTexts', texts: nodes };
}

// { text, entities } -> RichText. Prima si trovano i link [testo](indirizzo)
// sull'intero testo (cosi' un link col testo in grassetto resta un link), poi ogni
// tratto si taglia ai bordi delle entita': ogni pezzo prende tutti gli stili che
// lo coprono, cosi' anche gli stili sovrapposti (grassetto + corsivo) vengono giusti.
function composerStyledRange(text, entities, from, to) {
    var cuts = [from, to];
    for (var i = 0; i < entities.length; i++) {
        var a = entities[i].offset;
        var b = entities[i].offset + entities[i].length;
        if (a > from && a < to) cuts.push(a);
        if (b > from && b < to) cuts.push(b);
    }
    cuts.sort(function(x, y) { return x - y; });
    var parts = [];
    for (var c = 0; c + 1 < cuts.length; c++) {
        var start = cuts[c];
        var end = cuts[c + 1];
        if (end <= start) {
            continue;
        }
        var node = { '@type': 'richTextPlain', text: text.substring(start, end) };
        for (var e = 0; e < entities.length; e++) {
            var entity = entities[e];
            var richType = composerEntityRichTypes[entity.type ? entity.type['@type'] : ""];
            if (richType && entity.offset <= start && entity.offset + entity.length >= end) {
                node = { '@type': richType, text: node };
            }
        }
        parts.push(node);
    }
    return parts;
}

function composerFormattedToRichText(text, entities) {
    entities = entities || [];
    var nodes = [];
    var re = /\[([^\]]+)\]\(([^)\s]+)\)/g;
    var last = 0;
    var match;
    while ((match = re.exec(text)) !== null) {
        nodes = nodes.concat(composerStyledRange(text, entities, last, match.index));
        var labelStart = match.index + 1;
        var label = composerStyledRange(text, entities, labelStart, labelStart + match[1].length);
        nodes.push({ '@type': 'richTextUrl', text: composerRichTexts(label), url: match[2], is_cached: false });
        last = re.lastIndex;
    }
    nodes = nodes.concat(composerStyledRange(text, entities, last, text.length));
    return nodes.length > 0 ? composerRichTexts(nodes) : { '@type': 'richTextPlain', text: "" };
}

// Toglie spazi in testa e in coda spostando le entita' di conseguenza.
function composerTrimFormatted(text, entities) {
    var lead = text.length - text.replace(/^\s+/, "").length;
    var trimmed = text.replace(/^\s+|\s+$/g, "");
    var moved = [];
    for (var i = 0; i < (entities || []).length; i++) {
        var from = Math.max(entities[i].offset - lead, 0);
        var to = Math.min(entities[i].offset + entities[i].length - lead, trimmed.length);
        if (to > from) {
            moved.push({ '@type': 'textEntity', offset: from, length: to - from, type: entities[i].type });
        }
    }
    return { text: trimmed, entities: moved };
}

// Un elenco: una riga per voce. Le entita' di ComposerFormatter non attraversano
// mai un a capo, quindi basta assegnarle alla riga giusta.
function composerSplitLines(text, entities) {
    var lines = [];
    var start = 0;
    var pieces = text.split("\n");
    for (var i = 0; i < pieces.length; i++) {
        var end = start + pieces[i].length;
        var own = [];
        for (var e = 0; e < (entities || []).length; e++) {
            var entity = entities[e];
            if (entity.offset >= start && entity.offset + entity.length <= end) {
                own.push({ '@type': 'textEntity', offset: entity.offset - start, length: entity.length, type: entity.type });
            }
        }
        lines.push({ text: pieces[i], entities: own });
        start = end + 1;
    }
    return lines;
}

// Blocchi del composer -> InputPageBlock di TDLib. Un blocco di testo e'
// { type, text, entities }, una foto { type: "photo", path | photoJson, caption }.
// Restituisce anche lunghezza del testo e numero di media, per i limiti del server.
function composerBlocksToInputPageBlocks(composerBlocks) {
    var blocks = [];
    var textLength = 0;
    var mediaCount = 0;
    var plain = function(t) { return { '@type': 'richTextPlain', text: t }; };
    for (var i = 0; i < composerBlocks.length; i++) {
        var b = composerBlocks[i];
        if (b.type === "photo") {
            // foto nuova = file locale; foto gia' inviata (modifica) = il suo file TDLib
            var inputFile = null;
            if (b.path) {
                inputFile = { '@type': 'inputFileLocal', path: b.path };
            } else if (b.photoJson) {
                var sentPhoto = JSON.parse(b.photoJson);
                var biggest = sentPhoto.sizes[sentPhoto.sizes.length - 1];
                inputFile = { '@type': 'inputFileId', id: biggest.photo.id };
            }
            if (!inputFile) {
                continue;
            }
            var captionText = (b.caption || "").replace(/^\s+|\s+$/g, "");
            textLength += captionText.length;
            mediaCount++;
            blocks.push({
                '@type': 'inputPageBlockPhoto',
                photo: { '@type': 'inputPhoto', photo: inputFile },
                caption: { '@type': 'pageBlockCaption', text: plain(captionText), credit: plain("") },
                has_spoiler: false
            });
            continue;
        }
        var formatted = composerTrimFormatted(b.text || "", b.entities || []);
        if (formatted.text === "") {
            continue;
        }
        textLength += formatted.text.length;
        if (b.type === "title" || b.type === "subtitle") {
            blocks.push({ '@type': 'inputPageBlockSectionHeading', text: composerFormattedToRichText(formatted.text, formatted.entities), size: b.type === "title" ? 1 : 3 });
        } else if (b.type === "list") {
            var items = [];
            var lines = composerSplitLines(formatted.text, formatted.entities);
            for (var j = 0; j < lines.length; j++) {
                var line = composerTrimFormatted(lines[j].text, lines[j].entities);
                if (line.text !== "") {
                    items.push({ '@type': 'inputPageBlockListItem',
                                 blocks: [{ '@type': 'inputPageBlockParagraph', text: composerFormattedToRichText(line.text, line.entities) }],
                                 has_checkbox: false, is_checked: false, value: 0, type: "" });
                }
            }
            if (items.length > 0) {
                blocks.push({ '@type': 'inputPageBlockList', items: items });
            }
        } else {
            blocks.push({ '@type': 'inputPageBlockParagraph', text: composerFormattedToRichText(formatted.text, formatted.entities) });
        }
    }
    return { blocks: blocks, textLength: textLength, mediaCount: mediaCount };
}

// Il contrario, per modificare un articolo inviato: RichText -> { text, entities }
// accumulati in `acc`. Grassetto, corsivo, sottolineato, barrato, monospazio,
// spoiler e link sopravvivono; il resto (emoji personalizzate, evidenziato,
// apice...) diventa testo e `state.lossy` lo segnala.
var composerRichEntityTypes = {
    richTextBold: 'textEntityTypeBold',
    richTextItalic: 'textEntityTypeItalic',
    richTextUnderline: 'textEntityTypeUnderline',
    richTextStrikethrough: 'textEntityTypeStrikethrough',
    richTextFixed: 'textEntityTypeCode',
    richTextSpoiler: 'textEntityTypeSpoiler'
};

function composerAppendRichText(richText, acc, state) {
    if (!richText) {
        return;
    }
    var type = richText['@type'];
    if (type === 'richTextPlain') {
        acc.text += richText.text;
    } else if (type === 'richTexts') {
        for (var i = 0; i < (richText.texts || []).length; i++) {
            composerAppendRichText(richText.texts[i], acc, state);
        }
    } else if (composerRichEntityTypes[type]) {
        var start = acc.text.length;
        composerAppendRichText(richText.text, acc, state);
        if (acc.text.length > start) {
            acc.entities.push({ '@type': 'textEntity', offset: start, length: acc.text.length - start,
                                type: { '@type': composerRichEntityTypes[type] } });
        }
    } else if (type === 'richTextUrl') {
        var label = { text: "", entities: [] };
        composerAppendRichText(richText.text, label, state);
        var linked = richText.url && label.text !== richText.url;
        if (linked) {
            acc.text += "[";
        }
        for (var l = 0; l < label.entities.length; l++) {
            var moved = label.entities[l];
            acc.entities.push({ '@type': 'textEntity', offset: moved.offset + acc.text.length, length: moved.length, type: moved.type });
        }
        acc.text += label.text;
        if (linked) {
            acc.text += "](" + richText.url + ")";
        }
    } else if (['richTextEmailAddress', 'richTextPhoneNumber', 'richTextHashtag', 'richTextCashtag',
                'richTextMention', 'richTextBotCommand'].indexOf(type) !== -1) {
        // questi li ritrova il server da solo (detect_automatic_blocks)
        composerAppendRichText(richText.text, acc, state);
    } else if (type === 'richTextCustomEmoji') {
        state.lossy = true;
        acc.text += richText.alternative_text || "";
    } else {
        state.lossy = true;
        if (richText.text) {
            composerAppendRichText(richText.text, acc, state);
        }
    }
}

// Articolo inviato -> blocchi del composer. `unsupported` elenca i blocchi che
// l'editor non sa ancora rifare: con quelli la modifica non si apre, perche'
// reinviando l'articolo andrebbero persi.
function richMessageToComposerBlocks(content) {
    var state = { lossy: false };
    var blocks = [];
    var unsupported = [];
    var source = (content && content.message && content.message.blocks) ? content.message.blocks : [];
    var add = function(type, richText) {
        var acc = { text: "", entities: [] };
        composerAppendRichText(richText, acc, state);
        blocks.push({ type: type, text: acc.text, entitiesJson: JSON.stringify(acc.entities), path: "", caption: "", photoJson: "" });
    };
    for (var i = 0; i < source.length; i++) {
        var b = source[i];
        switch (b['@type']) {
        case 'pageBlockTitle': add("title", b.title); break;
        case 'pageBlockHeader': add("title", b.header); break;
        case 'pageBlockSubtitle': add("subtitle", b.subtitle); break;
        case 'pageBlockSubheader': add("subtitle", b.subheader); break;
        case 'pageBlockSectionHeading': add((b.size || 1) <= 1 ? "title" : "subtitle", b.text); break;
        case 'pageBlockParagraph': add("paragraph", b.text); break;
        case 'pageBlockList':
            var list = { text: "", entities: [] };
            for (var j = 0; j < (b.items || []).length; j++) {
                var item = b.items[j];
                if (j > 0) {
                    list.text += "\n";
                }
                for (var k = 0; k < (item.blocks || []).length; k++) {
                    var ib = item.blocks[k];
                    if (ib['@type'] !== 'pageBlockParagraph') {
                        state.lossy = true;
                    }
                    if (k > 0) {
                        list.text += " ";
                    }
                    // gli a capo dentro una voce diventerebbero voci nuove
                    var itemAcc = { text: "", entities: [] };
                    composerAppendRichText(ib.text, itemAcc, state);
                    for (var m = 0; m < itemAcc.entities.length; m++) {
                        var ent = itemAcc.entities[m];
                        list.entities.push({ '@type': 'textEntity', offset: ent.offset + list.text.length, length: ent.length, type: ent.type });
                    }
                    list.text += itemAcc.text.replace(/\n/g, " ");
                }
                if (item.has_checkbox) {
                    state.lossy = true;
                }
            }
            blocks.push({ type: "list", text: list.text, entitiesJson: JSON.stringify(list.entities), path: "", caption: "", photoJson: "" });
            break;
        case 'pageBlockPhoto':
            if (b.photo && b.photo.sizes && b.photo.sizes.length > 0) {
                var captionAcc = { text: "", entities: [] };
                if (b.caption) {
                    composerAppendRichText(b.caption.text, captionAcc, state);
                }
                if (captionAcc.entities.length > 0) {
                    state.lossy = true;   // la didascalia e' un campo semplice
                }
                blocks.push({ type: "photo", text: "", entitiesJson: "[]", path: "", caption: captionAcc.text, photoJson: JSON.stringify(b.photo) });
            }
            break;
        case 'pageBlockDivider':
        case 'pageBlockAnchor':
            state.lossy = true;
            break;
        default:
            var name = b['@type'].replace(/^pageBlock/, "");
            if (unsupported.indexOf(name) === -1) {
                unsupported.push(name);
            }
        }
    }
    return { blocks: blocks, unsupported: unsupported, lossy: state.lossy };
}

// Il primo pageBlockPhoto di un messageRichMessage (anche dentro copertine,
// collage, citazioni...), in ordine di lettura; null se il post non ha foto.
function getRichMessageFirstPhotoBlock(content) {
    var search = function(blocks) {
        for (var i = 0; i < (blocks || []).length; i++) {
            var block = blocks[i];
            if (!block) {
                continue;
            }
            if (block['@type'] === 'pageBlockPhoto' && block.photo && block.photo.sizes && block.photo.sizes.length > 0) {
                return block;
            }
            var inner = search(block.cover ? [block.cover] : block.blocks);
            if (inner) {
                return inner;
            }
        }
        return null;
    };
    return (content && content.message) ? search(content.message.blocks) : null;
}

// Come si divide un post ricco per disegnarlo nell'ordine di Telegram (titolo,
// foto, testo): `head` sono i blocchi PRIMA della prima foto di primo livello (di
// solito solo il titolo), che MessageRichMessage.qml disegna sopra la foto; `tail`
// il seguito, che va nel testo del messaggio. Se la foto e' solo annidata
// (copertina, collage...) la si mostra comunque in cima e il testo resta intero.
function getRichMessageLayout(content) {
    var blocks = (content && content.message && content.message.blocks) ? content.message.blocks : [];
    for (var i = 0; i < blocks.length; i++) {
        var block = blocks[i];
        if (block && block['@type'] === 'pageBlockPhoto' && block.photo && block.photo.sizes && block.photo.sizes.length > 0) {
            return { head: blocks.slice(0, i), photoBlock: block, tail: blocks.slice(i + 1) };
        }
    }
    return { head: [], photoBlock: getRichMessageFirstPhotoBlock(content), tail: blocks };
}

// La foto di un messageRichMessage presentata come un messagePhoto: cosi' la
// disegnano MessagePhoto.qml e la pagina a tutto schermo senza codice nuovo.
function richMessageAsPhotoMessage(message) {
    var block = message ? getRichMessageLayout(message.content).photoBlock : null;
    if (!block) {
        return message;
    }
    var photoMessage = {};
    for (var key in message) {
        photoMessage[key] = message[key];
    }
    photoMessage.content = {
        '@type': 'messagePhoto',
        photo: block.photo,
        caption: { '@type': 'formattedText', text: '', entities: [] },
        show_caption_above_media: false,
        has_spoiler: !!block.has_spoiler
    };
    return photoMessage;
}

function pageBlocksToText(blocks, plain, skipBlock) {
    var out = [];
    var rt = function(t) { return richTextToText(t, plain); };
    var bold = function(t) { var x = rt(t); return plain || !x ? x : "<b>" + x + "</b>"; };
    // Titoli piu' grandi del testo (che e' fontSizeSmall), come nei client ufficiali.
    var heading = function(t, pixelSize) {
        var x = rt(t);
        return plain || !x ? x : "<span style=\"font-size:" + Math.round(pixelSize) + "px\"><b>" + x + "</b></span>";
    };
    var theme = Silica.Theme;
    // pageBlockSectionHeading.size: 1 = il piu' grande ... 6 = il piu' piccolo
    var sectionSize = function(size) {
        if (size <= 1) return theme.fontSizeLarge;
        if (size === 2) return (theme.fontSizeLarge + theme.fontSizeMedium) / 2;
        if (size === 3) return theme.fontSizeMedium;
        return theme.fontSizeSmall;
    };
    var caption = function(c) { return c ? rt(c.text) : ""; };
    var media = function(icon, c) { var x = caption(c); return x ? icon + " " + x : icon; };
    for (var i = 0; i < (blocks || []).length; i++) {
        var block = blocks[i];
        var text = "";
        switch (block['@type']) {
        case 'pageBlockTitle': text = heading(block.title, theme.fontSizeLarge); break;
        case 'pageBlockSubtitle': text = heading(block.subtitle, theme.fontSizeMedium); break;
        case 'pageBlockHeader': text = heading(block.header, theme.fontSizeLarge); break;
        case 'pageBlockSubheader': text = heading(block.subheader, theme.fontSizeMedium); break;
        case 'pageBlockSectionHeading': text = heading(block.text, sectionSize(block.size || 1)); break;
        case 'pageBlockKicker': text = rt(block.kicker); break;
        case 'pageBlockAuthorDate': text = rt(block.author); break;
        case 'pageBlockParagraph':
        case 'pageBlockThinking':
            text = rt(block.text); break;
        case 'pageBlockFooter': text = rt(block.footer); break;
        case 'pageBlockPreformatted':
            text = plain ? rt(block.text) : "<tt>" + rt(block.text) + "</tt>"; break;
        case 'pageBlockMathematicalExpression':
            text = plain ? block.expression : "<tt>" + enhanceHtmlEntities(block.expression || "") + "</tt>"; break;
        case 'pageBlockDivider': text = plain ? "" : "―――"; break;
        case 'pageBlockList':
            var items = [];
            var bulleted = true;
            for (var j = 0; j < (block.items || []).length; j++) {
                var item = block.items[j];
                var label = item.has_checkbox ? (item.is_checked ? "☑ " : "☐ ") : "";
                if (!item.has_checkbox && item.label && item.label !== "•") {
                    bulleted = false;
                }
                if (plain) {
                    items.push((label || ((item.label || "•") + " ")) + pageBlocksToText(item.blocks, true, skipBlock));
                } else {
                    // dentro la voce i blocchi vanno a capo semplice: titoletto e testo
                    // restano insieme, rientrati sotto il pallino come nei client ufficiali
                    items.push("<li>" + label + pageBlocksToText(item.blocks, false, skipBlock).replace(/<br><br>/g, "<br>") + "</li>");
                }
            }
            text = plain ? items.join(" ") : (bulleted ? "<ul>" + items.join("") + "</ul>" : "<ol>" + items.join("") + "</ol>");
            break;
        case 'pageBlockBlockQuote':
            text = "“" + pageBlocksToText(block.blocks, plain, skipBlock) + "”";
            if (block.credit) { text += " — " + rt(block.credit); }
            break;
        case 'pageBlockExpandableBlockQuote':
        case 'pageBlockPullQuote':
            text = "“" + rt(block.text) + "”";
            if (block.credit) { text += " — " + rt(block.credit); }
            break;
        case 'pageBlockDetails':
            text = bold(block.header) + (plain ? " " : "<br>") + pageBlocksToText(block.blocks, plain, skipBlock);
            break;
        case 'pageBlockCover': text = pageBlocksToText([block.cover], plain, skipBlock); break;
        case 'pageBlockEmbeddedPost':
        case 'pageBlockCollage':
        case 'pageBlockSlideshow':
            text = pageBlocksToText(block.blocks, plain, skipBlock);
            if (block.caption) { text += (text ? " " : "") + caption(block.caption); }
            break;
        case 'pageBlockPhoto':
            // la foto gia' disegnata sopra il testo lascia solo la sua didascalia
            text = (block === skipBlock) ? caption(block.caption) : media("🖼", block.caption);
            break;
        case 'pageBlockVideo': text = media("🎬", block.caption); break;
        case 'pageBlockAnimation': text = media("🎞", block.caption); break;
        case 'pageBlockAudio': text = media("🎵", block.caption); break;
        case 'pageBlockVoiceNote': text = media("🎤", block.caption); break;
        case 'pageBlockDocument': text = media("📄", block.caption); break;
        case 'pageBlockMap': text = media("📍", block.caption); break;
        case 'pageBlockEmbedded':
            text = block.url ? (plain ? block.url : "<a style=\"color:" + messageLinkColor() + ";\" href=\"" + enhanceHtmlEntities(block.url) + "\">" + enhanceHtmlEntities(block.url) + "</a>") : "";
            break;
        case 'pageBlockTable':
            var rows = [];
            for (var r = 0; r < (block.cells || []).length; r++) {
                var cells = [];
                for (var c = 0; c < block.cells[r].length; c++) {
                    cells.push(rt(block.cells[r][c].text));
                }
                rows.push(cells.join(" | "));
            }
            text = (block.caption ? bold(block.caption) + (plain ? " " : "<br>") : "") + rows.join(plain ? " " : "<br>");
            break;
        case 'pageBlockRelatedArticles':
            var articles = [];
            for (var k = 0; k < (block.articles || []).length; k++) {
                var a = block.articles[k];
                articles.push(plain ? (a.title || a.url) : "<a style=\"color:" + messageLinkColor() + ";\" href=\"" + enhanceHtmlEntities(a.url) + "\">" + enhanceHtmlEntities(a.title || a.url) + "</a>");
            }
            text = rt(block.header) + (plain ? " " : "<br>") + articles.join(plain ? " " : "<br>");
            break;
        case 'pageBlockChatLink':
            text = plain ? block.title : "<a style=\"color:" + messageLinkColor() + ";\" href=\"https://t.me/" + enhanceHtmlEntities(block.username) + "\">" + enhanceHtmlEntities(block.title) + "</a>";
            break;
        default:
            // pageBlockAnchor, pageBlockButtonRow, pageBlockUnsupported: niente testo
            break;
        }
        // gli a capo in testa/coda a un blocco e i blocchi vuoti non devono
        // aggiungere righe bianche oltre alla separazione fra blocchi
        text = plain ? text.trim() : text.replace(/^(\s|<br>)+|(\s|<br>)+$/g, "");
        if (text) {
            out.push(text);
        }
    }
    return out.join(plain ? "\n" : "<br><br>");
}

function enhanceHtmlEntities(simpleText) {
    return simpleText.replace(ampRegExp, "&amp;").replace(ltRegExp, "&lt;").replace(gtRegExp, "&gt;");//.replace(rawNewLineRegExp, "<br>");
}

function messageInsertionSorter(a, b) {
    if ((b.offset + b.removeLength) > (a.offset + a.removeLength)) {
        return 1;
    }
    if ((b.offset + b.removeLength) < (a.offset + a.removeLength)) {
        return -1;
    }
    return b.offset - a.offset;
}

function getCustomEmojiRenderSize() {
    var baseSize = (Silica.Theme && Silica.Theme.fontSizeMedium) ? Silica.Theme.fontSizeMedium : 18;
    return Math.max(18, Math.round(baseSize * 1.15));
}
function enhanceMessageText(formattedText, ignoreEntities, revealedSpoilers, monoTextColor) {

    var messageInsertions = [];
    var messageText = formattedText.text;
    var entities = formattedText.entities ? formattedText.entities : [];
    var entity;
    if (ignoreEntities) {
        return messageText;
    }
    if (entities.length === 0) {
        return messageText.replace(ampRegExp, "&amp;").replace(ltRegExp, "&lt;").replace(gtRegExp, "&gt;").replace(rawNewLineRegExp, "<br>");
    }
    var revealed = revealedSpoilers || {};
    for (var i = 0; i < entities.length; i++) {
        entity = entities[i];
        if (entity['@type'] !== "textEntity") {
            continue;
        }
        switch(entity.type['@type']) {
            case "textEntityTypeCustomEmoji":
                var customEmojiId = entity.type.custom_emoji_id ? entity.type.custom_emoji_id.toString() : "";
                if (customEmojiId === "") {
                    break;
                }
                var customEmojiPath = tdLibWrapper.getCustomEmojiPath(customEmojiId);
                if (!customEmojiPath || customEmojiPath === "") {
                    tdLibWrapper.ensureCustomEmoji(customEmojiId);
                    break;
                }
                if (customEmojiPath.indexOf("file://") !== 0) {
                    customEmojiPath = "file://" + customEmojiPath;
                }
                customEmojiPath = customEmojiPath.replace(ampRegExp, "&amp;").replace(/"/g, "&quot;");
                var customEmojiSize = getCustomEmojiRenderSize();
                messageInsertions.push(
                    { offset: entity.offset, insertionString: "<img src=\"" + customEmojiPath + "\" align=\"middle\" width=\"" + customEmojiSize + "\" height=\"" + customEmojiSize + "\"/>", removeLength: entity.length }
                );
            break;
            case "textEntityTypeBold":
                messageInsertions.push(
                    { offset: entity.offset, insertionString: "<b>", removeLength: 0 },
                    { offset: (entity.offset + entity.length), insertionString: "</b>", removeLength: 0 }
                );
            break;
            case "textEntityTypeUrl":
                messageInsertions.push(
                    { offset: entity.offset, insertionString: "<a style=\"color:" + messageLinkColor() + ";\" href=\"" + messageText.substring(entity.offset, ( entity.offset + entity.length )) + "\">", removeLength: 0 },
                    { offset: (entity.offset + entity.length), insertionString: "</a>", removeLength: 0 }
                );
            break;
            case "textEntityTypeCode":
                // Tap-to-copy (come Telegram): il blocco monospace è un link
                // `rtcopy://OFFSET/LENGTH`; al tap MessageListViewItem copia in
                // clipboard la sottostringa. text-decoration:none + colore esplicito
                // del testo del messaggio così NON assume l'aspetto di un link.
                messageInsertions.push(
                    { offset: entity.offset, insertionString: "<a href=\"rtcopy://" + entity.offset + "/" + entity.length + "\" style=\"text-decoration:none;\"><span style=\"font-family: monospace; color:" + monoTextColor + ";\">", removeLength: 0 },
                    { offset: (entity.offset + entity.length), insertionString: "</span></a>", removeLength: 0 }
                );
            break;
            case "textEntityTypeEmailAddress":
                messageInsertions.push(
                    { offset: entity.offset, insertionString: "<a style=\"color:" + messageLinkColor() + ";\" href=\"mailto:" + messageText.substring(entity.offset, ( entity.offset + entity.length )) + "\">", removeLength: 0 },
                    { offset: (entity.offset + entity.length), insertionString: "</a>", removeLength: 0 }
                );
            break;
            case "textEntityTypeItalic":
                messageInsertions.push(
                    { offset: entity.offset, insertionString: "<i>", removeLength: 0 },
                    { offset: (entity.offset + entity.length), insertionString: "</i>", removeLength: 0 }
                );
            break;
            case "textEntityTypeStrikethrough":
                messageInsertions.push(
                    { offset: entity.offset, insertionString: "<span style=\"text-decoration: line-through;\">", removeLength: 0 },
                    { offset: (entity.offset + entity.length), insertionString: "</span>", removeLength: 0 }
                );
            break;
            case "textEntityTypeSpoiler":
                // Tap-to-reveal: ogni spoiler è un link `rtspoiler://OFFSET/LENGTH`.
                // Quando MessageListViewItem riceve onLinkActivated con prefisso
                // `rtspoiler://` aggiunge la chiave a revealedSpoilers e rinnova
                // il binding del testo. Se rivelato, render senza l'hide.
                var spoilerKey = entity.offset + "-" + entity.length;
                if (revealed[spoilerKey]) {
                    // Niente da fare: render normale del testo originario.
                    break;
                }
                messageInsertions.push(
                    { offset: entity.offset, insertionString: "<a href=\"rtspoiler://" + entity.offset + "/" + entity.length + "\"><span style=\"background-color: #888888; color: #888888;\">", removeLength: 0 },
                    { offset: (entity.offset + entity.length), insertionString: "</span></a>", removeLength: 0 }
                );
            break;
            case "textEntityTypeMention":
                messageInsertions.push(
                    { offset: entity.offset, insertionString: "<a style=\"color:" + messageLinkColor() + ";\" href=\"user://" + messageText.substring(entity.offset, ( entity.offset + entity.length )) + "\">", removeLength: 0 },
                    { offset: (entity.offset + entity.length), insertionString: "</a>", removeLength: 0 }
                );
            break;
            case "textEntityTypeMentionName":
                messageInsertions.push(
                    { offset: entity.offset, insertionString: "<a style=\"color:" + messageLinkColor() + ";\" href=\"userId://" + entity.type.user_id + "\">", removeLength: 0 },
                    { offset: (entity.offset + entity.length), insertionString: "</a>", removeLength: 0 }
                );
            break;
            case "textEntityTypePhoneNumber":
                messageInsertions.push(
                    { offset: entity.offset, insertionString: "<a style=\"color:" + messageLinkColor() + ";\" href=\"tel:" + messageText.substring(entity.offset, ( entity.offset + entity.length )) + "\">", removeLength: 0 },
                    { offset: (entity.offset + entity.length), insertionString: "</a>", removeLength: 0 }
                );
            break;
            case "textEntityTypePre":
                messageInsertions.push(
                    { offset: entity.offset, insertionString: "<a href=\"rtcopy://" + entity.offset + "/" + entity.length + "\" style=\"text-decoration:none;\"><span style=\"font-family: monospace; white-space: pre-wrap; color:" + monoTextColor + ";\">", removeLength: 0 },
                    { offset: (entity.offset + entity.length), insertionString: "</span></a>", removeLength: 0 }
                );
            break;
            case "textEntityTypePreCode":
                messageInsertions.push(
                    { offset: entity.offset, insertionString: "<a href=\"rtcopy://" + entity.offset + "/" + entity.length + "\" style=\"text-decoration:none;\"><span style=\"font-family: monospace; white-space: pre-wrap; color:" + monoTextColor + ";\">", removeLength: 0 },
                    { offset: (entity.offset + entity.length), insertionString: "</span></a>", removeLength: 0 }
                );
            break;
            case "textEntityTypeTextUrl":
                messageInsertions.push(
                    { offset: entity.offset, insertionString: "<a style=\"color:" + messageLinkColor() + ";\" href=\"" + entity.type.url + "\">", removeLength: 0 },
                    { offset: (entity.offset + entity.length), insertionString: "</a>", removeLength: 0 }
                );
            break;
            case "textEntityTypeUnderline":
                messageInsertions.push(
                    { offset: entity.offset, insertionString: "<u>", removeLength: 0 },
                    { offset: (entity.offset + entity.length), insertionString: "</u>", removeLength: 0 }
                );
            break;
            case "textEntityTypeBotCommand":
                var command = messageText.substring(entity.offset, entity.offset + entity.length);
                messageInsertions.push(
                    { offset: entity.offset, insertionString: "<a style=\"color:" + messageLinkColor() + ";\" href=\"botCommand://" + command + "\">", removeLength: 0 },
                    { offset: (entity.offset + entity.length), insertionString: "</a>", removeLength: 0 }
                );
            break;
            case "textEntityTypeHashtag":
            case "textEntityTypeCashtag":
                // #hashtag e $cashtag (#19): tappabili come in Telegram — il tap apre la
                // ricerca GLOBALE nei messaggi (MessageSearchPage) gia' compilata con quel
                // testo. Il testo viaggia dentro l'href codificato, altrimenti "#" e "&"
                // spezzerebbero il link; a intercettare "rtsearch://" e' il componente che
                // disegna la bolla, come per rtcopy:// e rtspoiler://.
                messageInsertions.push(
                    { offset: entity.offset, insertionString: "<a style=\"color:" + messageLinkColor() + ";\" href=\"rtsearch://" + encodeURIComponent(messageText.substring(entity.offset, ( entity.offset + entity.length ))) + "\">", removeLength: 0 },
                    { offset: (entity.offset + entity.length), insertionString: "</a>", removeLength: 0 }
                );
            break;
            case "textEntityTypeBankCardNumber":
                // Numero di carta: tap-to-copy con lo stesso meccanismo dei blocchi
                // monospace. Il TERZO campo del link ("num") serve solo a scegliere la
                // notifica giusta: "rtcopy://OFFSET/LENGTH" senza terzo campo resta il
                // codice, quindi i link gia' in giro continuano a funzionare.
                messageInsertions.push(
                    { offset: entity.offset, insertionString: "<a style=\"color:" + messageLinkColor() + ";\" href=\"rtcopy://" + entity.offset + "/" + entity.length + "/num\">", removeLength: 0 },
                    { offset: (entity.offset + entity.length), insertionString: "</a>", removeLength: 0 }
                );
            break;
            case "textEntityTypeMediaTimestamp":
                // "1:23" scritto nel testo: il tap salta a quell'istante nel media DI
                // QUESTO messaggio (video, audio, vocale). ATTENZIONE: la variante che apre il media
                // del messaggio CITATO non e' implementata: li' il tap non fa nulla.
                var mediaTimestampSeconds = (typeof entity.type.media_timestamp === "number") ? entity.type.media_timestamp : -1;
                if (mediaTimestampSeconds < 0) {
                    break;
                }
                messageInsertions.push(
                    { offset: entity.offset, insertionString: "<a style=\"color:" + messageLinkColor() + ";\" href=\"rtseek://" + mediaTimestampSeconds + "\">", removeLength: 0 },
                    { offset: (entity.offset + entity.length), insertionString: "</a>", removeLength: 0 }
                );
            break;
            case "textEntityTypeBlockQuote":
            case "textEntityTypeExpandableBlockQuote":
                // Citazione (#19). Qt 5.6 non sa disegnare un bordo sul lato di un BLOCCO
                // (border-left per lato arriva molto dopo, e blockquote e' un blocco, non un
                // frame) => la barra verticale e' uno spazio con background-color, che non
                // dipende da nessun glifo, ripetuta su OGNI riga della citazione; il
                // <blockquote> mette il rientro e stacca il blocco dal testo nuovo.
                // Le newline dentro la citazione vanno convertite qui, perche' ognuna deve
                // riportare la barra; quelle che confinano col blocco si mangiano, altrimenti
                // il <blockquote> aggiunge una riga vuota di troppo sopra o sotto.
                // ⚠️ La variante "expandable" si vede per intero: il collasso con "espandi"
                // non e' implementato.
                var quoteBar = "<span style=\"background-color:" + messageLinkColor() + ";\">&#160;</span>&#160;";
                var quoteEnd = entity.offset + entity.length;
                messageInsertions.push(
                    { offset: entity.offset, insertionString: "<blockquote>" + quoteBar, removeLength: 0 },
                    { offset: quoteEnd, insertionString: "</blockquote>", removeLength: (messageText.charAt(quoteEnd) === "\n") ? 1 : 0 }
                );
                if (entity.offset > 0 && messageText.charAt(entity.offset - 1) === "\n") {
                    messageInsertions.push(
                        { offset: (entity.offset - 1), insertionString: "", removeLength: 1 }
                    );
                }
                for (var quoteNewLine = messageText.indexOf("\n", entity.offset);
                     quoteNewLine !== -1 && quoteNewLine < quoteEnd;
                     quoteNewLine = messageText.indexOf("\n", quoteNewLine + 1)) {
                    messageInsertions.push(
                        { offset: quoteNewLine, insertionString: "<br>" + quoteBar, removeLength: 1 }
                    );
                }
            break;
        }
    }

    if(messageInsertions.length === 0) {
        return messageText.replace(ampRegExp, "&amp;").replace(ltRegExp, "&lt;").replace(gtRegExp, "&gt;").replace(rawNewLineRegExp, "<br>");
    }

    handleHtmlEntity(messageText, messageInsertions, "&", "&amp;");
    handleHtmlEntity(messageText, messageInsertions, "<", "&lt;");
    handleHtmlEntity(messageText, messageInsertions, ">", "&gt;");
    messageInsertions.sort(messageInsertionSorter);

    for (var z = 0; z < messageInsertions.length; z++) {
        messageText = messageText.substring(0, messageInsertions[z].offset)
         + messageInsertions[z].insertionString
         + messageText.substring(messageInsertions[z].offset + messageInsertions[z].removeLength);
    }

    messageText = messageText.replace(rawNewLineRegExp, "<br>");

    return messageText;
}

function handleTMeLink(link, usedPrefix) {
    if (link.indexOf("joinchat") !== -1) {
        Debug.log("Joining Chat: ", link);
        tdLibWrapper.joinChatByInviteLink(link);
        // Do the necessary stuff to open the chat if successful
        // Fail with nice error message if it doesn't work
    } else if (link.indexOf("/+") !== -1) {
        // Can't handle t.me/+... links directly, try to parse the Telegram page...
        tdLibWrapper.getPageSource(link);
    } else {
        Debug.log("Search public chat: ", link.substring(usedPrefix.length));
        tdLibWrapper.searchPublicChat(link.substring(usedPrefix.length), true);
        // Check responses for updateBasicGroup or updateSupergroup
        // Fire createBasicGroupChat or createSupergroupChat
        // Do the necessary stuff to open the chat
        // Fail with nice error message if chat can't be found
    }
}

function handleLink(link) {
    var tMePrefix = tdLibWrapper.getOptionString("t_me_url");
    var tMePrefixHttp = tMePrefix.replace('https', 'http');

    // Checking if we have a direct message link...
    Debug.log("URL open requested: " + link);

    // Schemi INTERNI alla bolla (rtcopy/rtspoiler/rtsearch): li intercetta il componente
    // che disegna il messaggio. Qui arrivano solo dai contesti che non li intercettano
    // (risposta citata, messaggio fissato, anteprima di un link) e non vanno MAI passati
    // a Qt.openUrlExternally, che proverebbe ad aprirli nel browser.
    if (link.indexOf("rtcopy://") === 0 || link.indexOf("rtspoiler://") === 0 || link.indexOf("rtsearch://") === 0 || link.indexOf("rtseek://") === 0) {
        Debug.log("Internal bubble link, nothing to do here: " + link);
        return;
    }
    if ( (link.indexOf(tMePrefix) === 0 && link.substring(tMePrefix.length).indexOf("/") > 0) ||
         (link.indexOf(tMePrefixHttp) === 0 && link.substring(tMePrefixHttp.length).indexOf("/") > 0) ||
          link.indexOf("tg://privatepost") === 0 ||
          ( link.indexOf("tg://resolve") === 0 && link.indexOf("post") > 0 ) ) {
        Debug.log("Using message link info for: " + link);
        tdLibWrapper.getMessageLinkInfo(link, "openDirectly");
        return;
    }

    Debug.log("Trying to parse link ourselves: " + link);
    if (link.indexOf("user://") === 0) {
        var userName = link.substring(8);
        var userInformation = tdLibWrapper.getUserInformationByName(userName);
        if (typeof userInformation.id === "undefined") {
            // getUserInformationByName legge solo la cache locale usersByName, che
            // contiene i soli utenti gia' noti al client: una menzione a un canale,
            // a un gruppo o a un bot non ci sara' MAI. Prima di arrenderci chiediamo
            // al server, cioe' facciamo quel che handleTMeLink fa da sempre per i
            // link t.me/<nome> qui sopra: stessa destinazione, stessa strada.
            Debug.log("User not in local cache, resolving on the server: " + userName);
            tdLibWrapper.searchPublicChat(userName, true);
        } else {
            tdLibWrapper.createPrivateChat(userInformation.id, "openDirectly");
        }
    } else if (link.indexOf("userId://") === 0) {
        tdLibWrapper.createPrivateChat(link.substring(9), "openDirectly");
    } else if (link.indexOf("tg://") === 0) {
        Debug.log("Special TG link: ", link);
        if (link.indexOf("tg://join?invite=") === 0) {
            tdLibWrapper.joinChatByInviteLink(tMePrefix + "joinchat/" + link.substring(17));
        } else if (link.indexOf("tg://resolve?domain=") === 0) {
            tdLibWrapper.searchPublicChat(link.substring(20), true);
        }
    } else if (link.indexOf("botCommand://") === 0) { // this gets returned to send on ChatPage
        return link.substring(13);
    } else {
        if (link.indexOf(tMePrefix) === 0) {
            handleTMeLink(link, tMePrefix);
        } else if (link.indexOf(tMePrefixHttp) === 0) {
            handleTMeLink(link, tMePrefixHttp);
        } else {
            Debug.log("Trying to open URL externally: " + link)
            if (link.indexOf("://") === -1) {
                Qt.openUrlExternally("https://" + link)
            } else {
                Qt.openUrlExternally(link);
            }
        }
    }
}

function getVideoHeight(videoWidth, videoData) {
    if (typeof videoData !== "undefined") {
        if (videoData.height === 0) {
            return videoWidth;
        } else {
            var aspectRatio = videoData.height / videoData.width;
            return Math.round(videoWidth * aspectRatio);
        }
    } else {
        return 1;
    }
}

function replaceUrlsWithLinks(string) {
    return string.replace(/((\w+):\/\/[\w?=&.\/-;#~%-]+(?![\w\s?&.\/;#~%"=-]*>))/g, "<a style=\"color:" + messageLinkColor() + ";\" href=\"$1\">$1</a>");
}

function sortMessagesArrayByDate(messages) {
    messages.sort(function(a, b) {
      return a.date - b.date;
    });
}

function getMessagesArrayIds(messages) {
    sortMessagesArrayByDate(messages);
    return messages.map(function(message){return message.id.toString()});
}

function getMessagesArrayText(messages) {
    sortMessagesArrayByDate(messages);
    var lastSenderName = "";
    var lines = [];
    for(var i = 0; i < messages.length; i += 1) {
        var senderName = getUserName(tdLibWrapper.getUserInformation(messages[i].sender_id.user_id));
        if(senderName !== lastSenderName) {
            lines.push(senderName);
        }
        lastSenderName = senderName;
        lines.push(getMessageText(messages[i], true, tdLibWrapper.getUserInformation().id, false));
        lines.push("");
    }
    return lines.join("\n");
}

// Vero se il messaggio ha entità di formattazione "markdown-izzabili" (grassetto,
// corsivo, ecc.). Usato in modifica per decidere se ricostruire i marcatori.
function formattedTextHasFormatting(formattedText) {
    if (!formattedText || !formattedText.entities) {
        return false;
    }
    var fmt = ["textEntityTypeBold", "textEntityTypeItalic", "textEntityTypeUnderline",
               "textEntityTypeStrikethrough", "textEntityTypeCode", "textEntityTypePre",
               "textEntityTypePreCode", "textEntityTypeSpoiler"];
    for (var i = 0; i < formattedText.entities.length; i++) {
        var e = formattedText.entities[i];
        if (e['@type'] === "textEntity" && fmt.indexOf(e.type['@type']) !== -1) {
            return true;
        }
    }
    return false;
}

// Converte un formattedText TDLib nei MARCATORI markdown del composer (** __ ++
// ~~ ` ||), così la modifica di un messaggio ne PRESERVA la formattazione (il
// parser markdown all'invio li riconverte in entità). NB: i custom emoji non
// vengono marcati (restano il loro carattere); per i messaggi formattati gli
// eventuali custom emoji degradano a emoji normali (caso raro).
function formattedTextToComposerMarkdown(formattedText) {
    if (!formattedText) {
        return "";
    }
    var text = formattedText.text || "";
    var entities = formattedText.entities ? formattedText.entities : [];
    var markerFor = {
        "textEntityTypeBold": "**",
        "textEntityTypeItalic": "__",
        "textEntityTypeUnderline": "++",
        "textEntityTypeStrikethrough": "~~",
        "textEntityTypeCode": "`",
        "textEntityTypePre": "`",
        "textEntityTypePreCode": "`",
        "textEntityTypeSpoiler": "||"
    };
    var inserts = [];
    for (var i = 0; i < entities.length; i++) {
        var e = entities[i];
        if (e['@type'] !== "textEntity") {
            continue;
        }
        var m = markerFor[e.type['@type']];
        if (!m) {
            continue;
        }
        inserts.push({ offset: e.offset, str: m });
        inserts.push({ offset: e.offset + e.length, str: m });
    }
    if (inserts.length === 0) {
        return text;
    }
    // Inserisco dalle posizioni più alte alle più basse per non sfasare gli offset.
    inserts.sort(function(a, b) { return b.offset - a.offset; });
    for (var j = 0; j < inserts.length; j++) {
        var p = inserts[j].offset;
        if (p < 0) p = 0;
        if (p > text.length) p = text.length;
        text = text.substring(0, p) + inserts[j].str + text.substring(p);
    }
    return text;
}

function handleErrorMessage(code, message) {
    if (code === 404 || (code === 400 && message === "USERNAME_INVALID")) {
        // Silently ignore
        // - 404 Not Found messages (occur sometimes, without clear context...)
        // - searchPublicChat messages for "invalid" inline queries
        return;
    }
    // Silently ignore local file cache misses (TDLib tries to access files
    // from a previous session that are no longer in cache)
    if (message === "Message not found" || message === "File not found" || message === "FILE_DOWNLOAD_ID_INVALID"
            || message === "Wrong file id or the file is temporarily unavailable"
            || message === "Threads can't be used in General topic"
            || message === "Invalid forum topic identifier specified"
            || message === "Chat is not a forum"
            || message === "There are no message threads in the chat"
            || message === "Invalid value of parameter from_message_id specified"
            || message === "MSG_ID_INVALID"
            || message === "BROADCAST_FORBIDDEN"
            || message === "Can't get viewers of incoming messages"
            || message === "Message has no viewers"
            || message === "Chat is too big"
            || message === "Not enough rights to get scheduled messages"
            || message === "Need administrator rights in the channel chat") {
        // "Can't get viewers of incoming messages" / "Message has no viewers":
        // errori benigni di getMessageViewers (feature 👁) dove i "visti" non
        // esistono (chat private, messaggi non idonei). Nessun toast (#12).
        // MSG_ID_INVALID / BROADCAST_FORBIDDEN: errori benigni quando si
        // interrogano i reattori (getMessageAddedReactions) su messaggi che non
        // lo supportano — es. gruppi grandi (MSG_ID_INVALID) e canali, dove chi
        // ha messo la reaction è anonimo/non elencabile (BROADCAST_FORBIDDEN).
        // Le reaction funzionano comunque; qui evitiamo solo il toast grezzo.
        // "Need administrator rights in the channel chat": errore benigno che TDLib
        // emette a volte all'avvio per azioni di background (es. mark-as-read / fetch)
        // su canali dove l'utente non è amministratore; l'app funziona regolarmente,
        // niente toast all'apertura.
        // "Message not found": benigno, capita p.es. quando si cancella un messaggio
        // di live location mentre il LiveLocationManager sta ancora editandolo (l'edit
        // in volo fallisce). Il manager smette comunque agli aggiornamenti successivi.
        return;
    }
    if (message === "USER_ALREADY_PARTICIPANT") {
        appNotification.show(qsTr("You are already a member of this chat."));
    } else {
        appNotification.show(message);
    }
}

function getMessagesNeededForwardPermissions(messages) {
    var neededPermissions = ["can_send_basic_messages"]

    var mediaMessageTypes = ["messageAudio", "messageDocument", "messagePhoto", "messageVideo", "messageVideoNote", "messageVoiceNote"]
    var otherMessageTypes = ["messageAnimation", "messageGame", "messageSticker"]
    for(var i = 0; i < messages.length && neededPermissions.length < 3; i += 1) {
        var type = messages[i]["content"]["@type"]
        var permission = ""
        if(type === "messageText") {
            continue
        } else if(type === "messagePoll") {
            permission = "can_send_polls"
        } else if(mediaMessageTypes.indexOf(type) > -1) {
            permission = "can_send_media_messages"
        } else if(otherMessageTypes.indexOf(type) > -1) {
            permission = "can_send_other_messages"
        }

        if(permission !== "" && neededPermissions.indexOf(permission) === -1) {
            neededPermissions.push(permission)
        }
    }
    return neededPermissions
}

function isWidescreen(appWindow) {
    return (appWindow.deviceOrientation & Silica.Orientation.LandscapeMask) || Silica.Screen.sizeCategory === Silica.Screen.Large || Silica.Screen.sizeCategory === Silica.Screen.ExtraLarge
}

// --- Auto-download override helpers ---------------------------------------
//
// Telegram's per-network-type auto-download settings. We use these to turn
// off video preload (max_video_file_size=0, preload_large_videos=false)
// across all network types when the user enables the "Disabilita
// precaricamento video" toggle, and to restore sensible defaults when they
// turn it back off. Photos/audio are left active so previews still work.

function _autoDownloadNoVideoSettings() {
    return {
        "@type": "autoDownloadSettings",
        "is_auto_download_enabled": true,
        "max_photo_file_size": 10 * 1024 * 1024,
        "max_video_file_size": 0,
        "max_other_file_size": 3 * 1024 * 1024,
        "video_upload_bitrate": 0,
        "preload_large_videos": false,
        "preload_next_audio": true,
        "use_less_data_for_calls": false
    };
}

function _autoDownloadDefaultSettings(maxVideoSize, preloadLargeVideos) {
    return {
        "@type": "autoDownloadSettings",
        "is_auto_download_enabled": true,
        "max_photo_file_size": 10 * 1024 * 1024,
        "max_video_file_size": maxVideoSize,
        "max_other_file_size": 3 * 1024 * 1024,
        "video_upload_bitrate": 0,
        "preload_large_videos": preloadLargeVideos,
        "preload_next_audio": true,
        "use_less_data_for_calls": false
    };
}

function _sendAutoDownloadFor(typeTag, settings) {
    tdLibWrapper.sendRequest({
        "@type": "setAutoDownloadSettings",
        "settings": settings,
        "type": { "@type": typeTag }
    });
}

function applyVideoPreloadOverride() {
    var s = _autoDownloadNoVideoSettings();
    _sendAutoDownloadFor("networkTypeMobile", s);
    _sendAutoDownloadFor("networkTypeMobileRoaming", s);
    _sendAutoDownloadFor("networkTypeWiFi", s);
    _sendAutoDownloadFor("networkTypeOther", s);
}

function restoreAutoDownloadDefaults() {
    // Approximation of Telegram's "low" preset for cellular and "high" preset
    // for wifi. The user can fine-tune later from the official client.
    var low = _autoDownloadDefaultSettings(10 * 1024 * 1024, false);
    var high = _autoDownloadDefaultSettings(15 * 1024 * 1024, true);
    _sendAutoDownloadFor("networkTypeMobile", low);
    _sendAutoDownloadFor("networkTypeMobileRoaming", low);
    _sendAutoDownloadFor("networkTypeWiFi", high);
    _sendAutoDownloadFor("networkTypeOther", high);
}
