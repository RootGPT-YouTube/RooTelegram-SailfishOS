/*
    Copyright (C) 2026 RootGPT

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
import QtMultimedia 5.6

// Precedente / successivo per il player unico (appWindow.sharedAudio), come in
// Telegram: la "playlist" e' l'elenco dei messaggi dello STESSO tipo di quello
// che suona (brani coi brani, vocali coi vocali) nella sua chat, in ordine di
// chat (successivo = piu' recente). Vive nella finestra e chiede i vicini a
// TDLib (searchChatMessages filtrato): la ChatPage puo' non esserci piu', o non
// avere caricato quei messaggi.
Item {
    id: playlist

    property var player

    // Richiesta in volo (una alla volta: un nuovo tocco sostituisce la vecchia).
    property string requestExtra: ""
    property int requestDirection: 0
    property bool requestAutomatic: false
    property string requestContentType: ""
    // Brano scelto ma non ancora scaricato: parte all'arrivo del file.
    property int pendingFileId: 0
    property var pendingMessage: null
    // Copertina richiesta a TDLib per il brano corrente.
    property int pendingCoverFileId: 0

    readonly property bool available: !!(player && player.message)

    function cancel() {
        requestExtra = "";
        pendingFileId = 0;
        pendingMessage = null;
    }

    function isVoice(message) {
        return !!(message && message.content && message.content["@type"] === "messageVoiceNote");
    }

    function fileOf(message) {
        return isVoice(message) ? message.content.voice_note.voice : message.content.audio.audio;
    }

    function titleOf(message) {
        // Il titolo dei vocali e' il testo tradotto che MessageVoiceNote ha gia'
        // dato al player: ripeterlo qui farebbe una stringa nuova, non tradotta.
        if (isVoice(message)) {
            return player.title;
        }
        var audio = message && message.content ? message.content.audio : null;
        if (!audio) {
            return "";
        }
        var name = audio.title || audio.file_name || "";
        return audio.performer ? audio.performer + " – " + name : name;
    }

    // Copertina del brano per la cover: il file della miniatura se c'e' gia',
    // altrimenti la si chiede e intanto si usa la minimiaturina inclusa nel
    // messaggio (base64, sfocata ma subito disponibile).
    function coverArtOf(message) {
        var audio = message && message.content ? message.content.audio : null;
        if (!audio) {
            return "";
        }
        var thumbnail = audio.album_cover_thumbnail;
        if (thumbnail && thumbnail.file) {
            if (thumbnail.file.local && thumbnail.file.local.is_downloading_completed) {
                pendingCoverFileId = 0;
                return "file://" + thumbnail.file.local.path;
            }
            pendingCoverFileId = thumbnail.file.id;
            tdLibWrapper.downloadFile(thumbnail.file.id);
        } else {
            pendingCoverFileId = 0;
        }
        if (audio.album_cover_minithumbnail && audio.album_cover_minithumbnail.data) {
            return "data:image/jpeg;base64," + audio.album_cover_minithumbnail.data;
        }
        return "";
    }

    // direction: +1 successivo, -1 precedente. automatic: chiamata dalla fine del
    // brano (se non c'e' un successivo il player si ferma).
    function step(direction, automatic) {
        if (!available) {
            return;
        }
        // Come in Telegram: "indietro" a brano avviato lo riavvolge.
        if (direction < 0 && !automatic && player.position > 3000) {
            player.seek(0);
            return;
        }
        var current = player.message;
        var voice = isVoice(current);
        cancel();
        requestDirection = direction;
        requestContentType = current.content["@type"];
        requestAutomatic = !!automatic;
        requestExtra = "audioPlaylist:" + Date.now();
        // offset negativo = anche messaggi piu' recenti di from_message_id. Il
        // vicino giusto lo scegliamo noi sotto, quindi i bordi (incluso o no
        // from_message_id) non contano.
        tdLibWrapper.sendRequest({
            "@type": "searchChatMessages",
            "chat_id": current.chat_id,
            "query": "",
            "from_message_id": current.id,
            "offset": direction > 0 ? -3 : 0,
            "limit": direction > 0 ? 4 : 3,
            "filter": { "@type": voice ? "searchMessagesFilterVoiceNote" : "searchMessagesFilterAudio" },
            "@extra": requestExtra
        });
    }

    function playMessage(message) {
        var file = fileOf(message);
        if (file.local && file.local.is_downloading_completed) {
            pendingFileId = 0;
            pendingMessage = null;
            appWindow.playSharedAudio(message.chat_id + "_" + message.id, file.local.path, titleOf(message), message);
        } else {
            pendingFileId = file.id;
            pendingMessage = message;
            tdLibWrapper.downloadFile(file.id);
        }
    }

    function handleFound(messages) {
        var currentId = player.message ? player.message.id : 0;
        var best = null;
        for (var i = 0; i < messages.length; i++) {
            var m = messages[i];
            if (!m || !m.content || m.content["@type"] !== requestContentType) {
                continue;
            }
            if (requestDirection > 0 ? (m.id > currentId && (!best || m.id < best.id))
                                     : (m.id < currentId && (!best || m.id > best.id))) {
                best = m;
            }
        }
        if (best) {
            playMessage(best);
        } else if (requestAutomatic) {
            // Fine dell'ultimo brano della chat.
            appWindow.stopSharedAudio();
        }
    }

    Connections {
        target: tdLibWrapper
        onMessagesReceivedWithExtra: {
            if (playlist.requestExtra === "" || extra !== playlist.requestExtra) {
                return;
            }
            playlist.requestExtra = "";
            playlist.handleFound(messages || []);
        }
        onErrorReceived: {
            if (playlist.requestExtra !== "" && extra === playlist.requestExtra) {
                playlist.requestExtra = "";
                if (playlist.requestAutomatic) {
                    appWindow.stopSharedAudio();
                }
            }
        }
        onFileUpdated: {
            if (!fileInformation.local || !fileInformation.local.is_downloading_completed) {
                return;
            }
            if (fileId === playlist.pendingFileId && playlist.pendingMessage) {
                var message = playlist.pendingMessage;
                playlist.pendingFileId = 0;
                playlist.pendingMessage = null;
                appWindow.playSharedAudio(message.chat_id + "_" + message.id, fileInformation.local.path,
                                          playlist.titleOf(message), message);
            } else if (fileId === playlist.pendingCoverFileId) {
                playlist.pendingCoverFileId = 0;
                playlist.player.coverArt = "file://" + fileInformation.local.path;
            }
        }
    }
}
