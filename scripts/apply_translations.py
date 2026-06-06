#!/usr/bin/env python3
"""Patch IT/DE .ts files con traduzioni embedded.
Per stringhe singolari: dict[src] = "traduzione".
Per plurali Qt (numerus="yes"): dict[src] = ("singolare", "plurale").
Esegue: lascia type="vanished" intatto, sostituisce solo type="unfinished".
"""
from pathlib import Path
import re
import sys


IT = {
    # 2.3: cancella per me/per tutti (#1) + popup Novità (#9)
    "Delete for everyone": "Elimina per tutti",
    "Delete for me": "Elimina solo per me",
    "Cancel": "Annulla",
    "Novità": "Novità",
    "Continua": "Continua",
    # 2.3: contatti (#7), sta scrivendo (#2/#17), video-chat/tema (#14)
    "Add to contacts": "Aggiungi ai contatti",
    "Contact": "Contatto",
    "Contact saved to address book": "Contatto salvato in rubrica",
    "Could not save the contact": "Impossibile salvare il contatto",
    "Message": "Messaggia",
    "No contacts with a phone number": "Nessun contatto con un numero di telefono",
    "Search contact": "Cerca contatto",
    "Send contact": "Invia contatto",
    "sent a contact": "ha inviato un contatto",
    "is typing…": "sta scrivendo…",
    "is recording a voice message": "sta registrando un messaggio vocale",
    "is recording a video message": "sta registrando un videomessaggio",
    "is recording a video": "sta registrando un video",
    "is sending a voice message": "sta inviando un messaggio vocale",
    "is sending a video message": "sta inviando un videomessaggio",
    "is sending a video": "sta inviando un video",
    "is sending a photo": "sta inviando una foto",
    "is sending a file": "sta inviando un file",
    "is choosing a sticker": "sta scegliendo uno sticker",
    "is choosing a location": "sta scegliendo una posizione",
    "is choosing a contact": "sta scegliendo un contatto",
    "started a video chat": "ha avviato una chiamata di gruppo",
    "ended the video chat": "ha terminato la chiamata di gruppo",
    "scheduled a video chat": "ha programmato una chiamata di gruppo",
    "invited participants to the video chat": "ha invitato partecipanti alla chiamata di gruppo",
    "changed the chat theme": "ha cambiato il tema della chat",
    "changed the chat background": "ha cambiato lo sfondo della chat",
    # Selettore tema Silica/Neon (2.2)
    "Choose RooTelegram's theme": "Scegli il tema di RooTelegram",
    "Silica (base theme)": "Silica (tema base)",
    "Neon (cyberpunk)": "Neon (cyberpunk)",
    "Cyberpunk look (requires a dark and orange theme for the perfect experience)": "Look cyberpunk (richiede un tema scuro e arancione per un'esperienza perfetta)",
    "Silica base theme (lighter, also good on light themes)": "Tema Silica base (più leggero, ottimo anche con i temi chiari)",
    "Neon theme": "Tema Neon",
    "Silica theme": "Tema Silica",
    "Cyberpunk look": "Look cyberpunk",
    "Base theme": "Tema base",
    "Apply now": "Applica ora",
    "Apply this theme now?": "Applicare questo tema adesso?",
    "Circuit background, neon glow on menus, buttons and titles, rounded avatars and glass cards. Heavier: requires a dark and orange theme for the perfect experience.": "Sfondo a circuiti, bagliore neon su menù, pulsanti e titoli, avatar arrotondati e schede di vetro. Più pesante: richiede un tema scuro e arancione per un'esperienza perfetta.",
    "Native flat menus, square avatars, no custom background, standard Silica colors. Lighter and clearly readable also on light system themes.": "Menù piatti nativi, avatar quadrati, nessuno sfondo personalizzato, colori Silica standard. Più leggero e ben leggibile anche con i temi di sistema chiari.",
    # Attribuzione librerie multimediali bundlate (compat 5.0/5.1)
    "For SailfishOS 5.0/5.1 compatibility this package also bundles FFmpeg's multimedia dependencies: libvpx, Opus, Ogg, Vorbis, Theora, Speex, WebP, libsharpyuv (BSD) and OpenJPEG (BSD-2). Copyright their respective contributors. The full license texts are shipped in /usr/share/harbour-rootelegram/licenses/.": "Per la compatibilità con SailfishOS 5.0/5.1 questo pacchetto include anche le dipendenze multimediali di FFmpeg: libvpx, Opus, Ogg, Vorbis, Theora, Speex, WebP, libsharpyuv (BSD) e OpenJPEG (BSD-2). Copyright dei rispettivi autori. I testi completi delle licenze sono in /usr/share/harbour-rootelegram/licenses/.",
    # Privacy chiamate (2.0 #1): rinominato da "Allow voice calls"
    "Allow calls": "Consenti chiamate",
    "Search...": "Cerca...",
    "Play/Pause": "Play/Pausa",
    "Transcribe": "Trascrivi",
    "Voice and video messages": "Messaggi vocali e video",
    "Who can send you voice messages and video notes (round videos). Premium feature.": "Chi può inviarti messaggi vocali e video circolari (video note). Funzione Premium.",
    "This is a Premium-only feature.": "Questa è una funzione solo per utenti Premium.",
    "Only selected": "Solo i selezionati",
    "Everybody except": "Tutti tranne",
    "Choose who can send you voice messages and video notes.": "Scegli chi può inviarti messaggi vocali e video circolari.",
    "Choose who cannot send you voice messages and video notes.": "Scegli chi NON può inviarti messaggi vocali e video circolari.",
    "Privacy updated": "Privacy aggiornata",
    "(%n selected)": ("(%n selezionato)", "(%n selezionati)"),
    "Add to folder: %1": "Aggiungi alla cartella: %1",
    "Added to folder: %1": "Aggiunto alla cartella: %1",
    "Add to folder...": "Aggiungi alla cartella...",
    "Add to folder": "Aggiungi alla cartella",
    "No folders": "Nessuna cartella",
    "Remove from folder: %1": "Rimuovi dalla cartella: %1",
    "Removed from folder: %1": "Rimosso dalla cartella: %1",
    # Settings / generali
    "Recent": "Recenti",
    "Sticker set": "Set di sticker",
    "No recent stickers": "Nessuno sticker recente",
    "No stickers in this set": "Nessuno sticker in questo set",
    "Yes": "Sì",
    "No": "No",
    "Refresh": "Aggiorna",
    "Unknown chat": "Chat sconosciuta",
    "Pull down to refresh": "Trascina giù per aggiornare",
    "(no caption)": "(nessuna didascalia)",
    "Notifications": "Notifiche",
    "Show desktop notifications for new messages. The app always stays in background; this toggle controls only notification publishing.":
        "Mostra le notifiche desktop per i nuovi messaggi. L'app resta sempre attiva in background; questa opzione regola solo la pubblicazione delle notifiche.",
    "Stories": "Storie",
    "Notify when a contact posts a new story.": "Avvisa quando un contatto pubblica una nuova storia.",
    "posted a new story": "ha pubblicato una nuova storia",
    "In reply to a story": "In risposta a una storia",
    # Reaction sui propri messaggi (Task 3)
    "Reactions": "Reazioni",
    "Notify when someone reacts to one of your messages.": "Avvisa quando qualcuno reagisce a un tuo messaggio.",
    "reacted to your message": "ha reagito al tuo messaggio",
    "reacted %1 to your message": "ha reagito %1 al tuo messaggio",
    "Someone": "Qualcuno",
    # Copia testo parziale del messaggio
    "Selected text copied to clipboard": "Testo selezionato copiato negli appunti",
    # Videochiamate (stub)
    "Video call": "Videochiamata",
    "Video calls are not available in this build yet.": "Le videochiamate non sono ancora disponibili in questa versione.",
    # Stories — tabs + lista
    "Main": "Home",
    "Archive": "Archivio",
    "Profile": "Profilo",
    "Blocklist": "Lista bloccati",
    "View": "Vedi",
    "Show the list of Telegram users you have blocked.": "Mostra l'elenco degli utenti di Telegram che hai bloccato.",
    "Blacklist": "Blacklist",
    "Blacklist is empty": "La blacklist è vuota",
    "Add to blacklist": "Aggiungi alla blacklist",
    "Remove from blacklist": "Rimuovi dalla blacklist",
    "Added to blacklist": "Aggiunto alla blacklist",
    "Removed from blacklist": "Rimosso dalla blacklist",
    "My Archive": "Il mio archivio",
    "You have no archived stories": "Non hai storie archiviate",
    "My Profile": "Il mio profilo",
    "You have no stories on your profile": "Non hai storie sul tuo profilo",
    "No stories from your contacts": "Nessuna storia dai tuoi contatti",
    # Stories — viewer / actions
    "Story": "Storia",
    "Story not available": "Storia non disponibile",
    "This story type is not supported yet": "Questo tipo di storia non è ancora supportato",
    "Delete story": "Elimina storia",
    "Deleting story": "Eliminazione storia",
    "Could not set reaction.": "Impossibile impostare la reazione.",
    "Reply sent": "Risposta inviata",
    "Send": "Invia",
    "Reply": "Rispondi",
    "Reply to %1": "Rispondi a %1",
    "Reply to story": "Rispondi alla storia",
    "Write a reply…": "Scrivi una risposta…",
    "Viewers": "Visualizzazioni",
    "No viewers yet": "Nessuna visualizzazione ancora",
    "Telegram user": "Utente Telegram",
    "Forwarded": "Inoltrato",
    "Reposted": "Ripubblicato",
    # Stories — compose / publish
    "New story": "Nuova storia",
    "Tap to change": "Tocca per cambiare",
    "Caption": "Didascalia",
    "Add a caption (optional)": "Aggiungi una didascalia (opzionale)",
    "Reading video…": "Lettura video…",
    "Video too long: %1 (max %2)": "Video troppo lungo: %1 (max %2)",
    "Duration: %1": "Durata: %1",
    "Publish": "Pubblica",
    "Cannot determine your account.": "Impossibile determinare il tuo account.",
    "Posting story…": "Pubblicazione storia…",
    "Video conversion failed.": "Conversione video fallita.",
    "Story posted": "Storia pubblicata",
    "Could not post story.": "Impossibile pubblicare la storia.",
    "Telegram stories are vertical (9:16). Your landscape video is being adapted before publishing.":
        "Le storie Telegram sono verticali (9:16). Il tuo video orizzontale verrà adattato prima della pubblicazione.",
    "Converting video": "Conversione video",
    "Uploading video": "Caricamento video",
    # Stories — audience / picker
    "Audience": "Pubblico",
    "Everyone": "Tutti",
    "Selected contacts": "Contatti selezionati",
    "Choose contacts": "Scegli contatti",
    "Custom audience": "Pubblico personalizzato",
    "Custom audience (%1)": "Pubblico personalizzato (%1)",
    "Allow screenshots": "Consenti screenshot",
    "If off, the story is marked as protected: official clients block screenshots and forwarding.":
        "Se disattivato, la storia è contrassegnata come protetta: i client ufficiali bloccano screenshot e inoltri.",
    "Post to my profile": "Pubblica sul mio profilo",
    "Keep the story visible on your profile after the 24h expiration.":
        "Mantiene la storia visibile sul tuo profilo anche dopo la scadenza delle 24 ore.",
    "Done": "Fatto",
    "Search...": "Cerca...",
    "No contacts or private chats.": "Nessun contatto o chat privata.",
    "Loading contacts...": "Caricamento contatti...",
    # Video transcoder
    "A video conversion is already in progress.": "Una conversione video è già in corso.",
    "Video converter not available.": "Convertitore video non disponibile.",
    "Source video not found.": "Video sorgente non trovato.",
    "Could not start the video converter.": "Impossibile avviare il convertitore video.",
    # Plurali (Qt numerus="yes")
    "Delete %Ln message(s)?": ("Eliminare %Ln messaggio?", "Eliminare %Ln messaggi?"),
    "%n new story(es)": ("%n nuova storia", "%n nuove storie"),
    "%n story(es)": ("%n storia", "%n storie"),
    "%n view(s)": ("%n visualizzazione", "%n visualizzazioni"),
    "%n reaction(s)": ("%n reazione", "%n reazioni"),
    "%n contact(s) selected": ("%n contatto selezionato", "%n contatti selezionati"),
    "Choose who will see your next story (%n selected).": (
        "Scegli chi vedrà la tua prossima storia (%n selezionato).",
        "Scegli chi vedrà la tua prossima storia (%n selezionati).",
    ),
    "Members of your custom audience (%n selected). Saved across stories.": (
        "Membri del tuo pubblico personalizzato (%n selezionato). Salvato tra le storie.",
        "Membri del tuo pubblico personalizzato (%n selezionati). Salvato tra le storie.",
    ),
    # Traduzione messaggi (1.8.5)
    "Translate message": "Traduci messaggio",
    "Type your message first, then tap this button to translate it to English!":
        "Scrivi prima il messaggio, poi premi questo tasto per tradurlo in inglese!",
    # Proxy anti-censura (2.1)
    "Proxy added and enabled": "Proxy aggiunto e attivato",
    "Add proxy": "Aggiungi proxy",
    "Add": "Aggiungi",
    "Paste a proxy link (optional)": "Incolla un link proxy (facoltativo)",
    "tg://proxy?server=…  or  https://t.me/proxy?…": "tg://proxy?server=…  oppure  https://t.me/proxy?…",
    "Link recognised": "Link riconosciuto",
    "Type": "Tipo",
    "MTProto (recommended)": "MTProto (consigliato)",
    "SOCKS5 (also for calls)": "SOCKS5 (anche per le chiamate)",
    "HTTP": "HTTP",
    "Server": "Server",
    "Server (host or IP)": "Server (host o IP)",
    "Port": "Porta",
    "Secret": "Secret",
    "Secret (supports dd… and ee… Fake-TLS)": "Secret (supporta dd… e ee… Fake-TLS)",
    "Username (optional)": "Nome utente (facoltativo)",
    "Username": "Nome utente",
    "Password (optional)": "Password (facoltativa)",
    "Password": "Password",
    "HTTP only": "Solo HTTP",
    "The proxy supports only HTTP requests (no HTTPS tunnelling).":
        "Il proxy supporta solo richieste HTTP (nessun tunneling HTTPS).",
    "MTProto": "MTProto",
    "SOCKS5": "SOCKS5",
    "%1 ms": "%1 ms",
    "Proxy": "Proxy",
    "Disable proxy (direct connection)": "Disattiva proxy (connessione diretta)",
    "Proxy disabled": "Proxy disattivato",
    "No proxies": "Nessun proxy",
    "Pull down to add a proxy, or paste a tg://proxy link.":
        "Trascina giù per aggiungere un proxy, o incolla un link tg://proxy.",
    "Disable": "Disattiva",
    "Enable": "Attiva",
    "Test connection": "Prova connessione",
    "Remove": "Rimuovi",
    "Removing proxy": "Rimozione proxy",
    "Connection": "Connessione",
    "Proxies route your Telegram traffic through another server to bypass censorship. MTProto proxies (especially with Fake-TLS) are the most resistant to blocking. SOCKS5 proxies also cover voice and video calls.":
        "I proxy instradano il tuo traffico Telegram attraverso un altro server per aggirare la censura. I proxy MTProto (specialmente con Fake-TLS) sono i più resistenti ai blocchi. I proxy SOCKS5 coprono anche le chiamate vocali e video.",
    "On (%n configured)": ("Attivo (%n configurato)", "Attivo (%n configurati)"),
    "Off (%n configured)": ("Disattivo (%n configurato)", "Disattivo (%n configurati)"),
    "Off": "Disattivo",
    "Add, enable and test connection proxies.":
        "Aggiungi, attiva e prova la connessione dei proxy.",
}


DE = {
    # 2.3: löschen für mich/für alle (#1) + "Neuigkeiten"-Popup (#9)
    "Delete for everyone": "Für alle löschen",
    "Delete for me": "Nur für mich löschen",
    "Cancel": "Abbrechen",
    "Novità": "Neuigkeiten",
    "Continua": "Weiter",
    # 2.3: Kontakte (#7), schreibt (#2/#17), Gruppenanruf/Thema (#14)
    "Add to contacts": "Zu Kontakten hinzufügen",
    "Contact": "Kontakt",
    "Contact saved to address book": "Kontakt im Adressbuch gespeichert",
    "Could not save the contact": "Kontakt konnte nicht gespeichert werden",
    "Message": "Nachricht senden",
    "No contacts with a phone number": "Keine Kontakte mit Telefonnummer",
    "Search contact": "Kontakt suchen",
    "Send contact": "Kontakt senden",
    "sent a contact": "hat einen Kontakt gesendet",
    "is typing…": "schreibt…",
    "is recording a voice message": "nimmt eine Sprachnachricht auf",
    "is recording a video message": "nimmt eine Videonachricht auf",
    "is recording a video": "nimmt ein Video auf",
    "is sending a voice message": "sendet eine Sprachnachricht",
    "is sending a video message": "sendet eine Videonachricht",
    "is sending a video": "sendet ein Video",
    "is sending a photo": "sendet ein Foto",
    "is sending a file": "sendet eine Datei",
    "is choosing a sticker": "wählt einen Sticker aus",
    "is choosing a location": "wählt einen Ort aus",
    "is choosing a contact": "wählt einen Kontakt aus",
    "started a video chat": "hat einen Gruppenanruf gestartet",
    "ended the video chat": "hat den Gruppenanruf beendet",
    "scheduled a video chat": "hat einen Gruppenanruf geplant",
    "invited participants to the video chat": "hat Teilnehmer zum Gruppenanruf eingeladen",
    "changed the chat theme": "hat das Chat-Thema geändert",
    "changed the chat background": "hat den Chat-Hintergrund geändert",
    # Themenauswahl Silica/Neon (2.2)
    "Choose RooTelegram's theme": "RooTelegrams Thema wählen",
    "Silica (base theme)": "Silica (Basisthema)",
    "Neon (cyberpunk)": "Neon (Cyberpunk)",
    "Cyberpunk look (requires a dark and orange theme for the perfect experience)": "Cyberpunk-Look (erfordert ein dunkles und oranges Thema für das perfekte Erlebnis)",
    "Silica base theme (lighter, also good on light themes)": "Silica-Basisthema (leichter, auch gut bei hellen Themen)",
    "Neon theme": "Neon-Thema",
    "Silica theme": "Silica-Thema",
    "Cyberpunk look": "Cyberpunk-Look",
    "Base theme": "Basisthema",
    "Apply now": "Jetzt anwenden",
    "No": "Nein",
    "Apply this theme now?": "Dieses Thema jetzt anwenden?",
    "Circuit background, neon glow on menus, buttons and titles, rounded avatars and glass cards. Heavier: requires a dark and orange theme for the perfect experience.": "Platinen-Hintergrund, Neon-Leuchten auf Menüs, Schaltflächen und Titeln, abgerundete Avatare und Glaskarten. Schwerer: erfordert ein dunkles und oranges Thema für das perfekte Erlebnis.",
    "Native flat menus, square avatars, no custom background, standard Silica colors. Lighter and clearly readable also on light system themes.": "Native flache Menüs, quadratische Avatare, kein eigener Hintergrund, Standard-Silica-Farben. Leichter und auch bei hellen Systemthemen gut lesbar.",
    # Zuordnung der gebündelten Multimedia-Bibliotheken (Kompat. 5.0/5.1)
    "For SailfishOS 5.0/5.1 compatibility this package also bundles FFmpeg's multimedia dependencies: libvpx, Opus, Ogg, Vorbis, Theora, Speex, WebP, libsharpyuv (BSD) and OpenJPEG (BSD-2). Copyright their respective contributors. The full license texts are shipped in /usr/share/harbour-rootelegram/licenses/.": "Für die Kompatibilität mit SailfishOS 5.0/5.1 bündelt dieses Paket auch die Multimedia-Abhängigkeiten von FFmpeg: libvpx, Opus, Ogg, Vorbis, Theora, Speex, WebP, libsharpyuv (BSD) und OpenJPEG (BSD-2). Copyright der jeweiligen Autoren. Die vollständigen Lizenztexte liegen in /usr/share/harbour-rootelegram/licenses/.",
    # Anrufe-Datenschutz (2.0 #1): umbenannt von "Allow voice calls"
    "Allow calls": "Anrufe erlauben",
    "Search...": "Suchen...",
    "Play/Pause": "Wiedergabe/Pause",
    "Transcribe": "Transkribieren",
    "Voice and video messages": "Sprach- und Videonachrichten",
    "Who can send you voice messages and video notes (round videos). Premium feature.": "Wer dir Sprachnachrichten und Videonachrichten (runde Videos) senden kann. Premium-Funktion.",
    "This is a Premium-only feature.": "Dies ist eine reine Premium-Funktion.",
    "Only selected": "Nur ausgewählte",
    "Everybody except": "Alle außer",
    "Choose who can send you voice messages and video notes.": "Wähle, wer dir Sprach- und Videonachrichten senden kann.",
    "Choose who cannot send you voice messages and video notes.": "Wähle, wer dir keine Sprach- und Videonachrichten senden kann.",
    "Privacy updated": "Datenschutz aktualisiert",
    "(%n selected)": ("(%n ausgewählt)", "(%n ausgewählt)"),
    "Add to folder: %1": "Zum Ordner hinzufügen: %1",
    "Added to folder: %1": "Zum Ordner hinzugefügt: %1",
    "Add to folder...": "Zum Ordner hinzufügen...",
    "Add to folder": "Zum Ordner hinzufügen",
    "No folders": "Keine Ordner",
    "Remove from folder: %1": "Aus Ordner entfernen: %1",
    "Removed from folder: %1": "Aus Ordner entfernt: %1",
    # Settings / generali — DE ha già "Recent/Sticker set/Yes/No/..." tradotti.
    "Refresh": "Aktualisieren",
    "Unknown chat": "Unbekannter Chat",
    "Pull down to refresh": "Nach unten ziehen zum Aktualisieren",
    "(no caption)": "(keine Beschriftung)",
    "Notifications": "Benachrichtigungen",
    "Show desktop notifications for new messages. The app always stays in background; this toggle controls only notification publishing.":
        "Desktop-Benachrichtigungen für neue Nachrichten anzeigen. Die App bleibt immer im Hintergrund aktiv; dieser Schalter steuert nur die Veröffentlichung der Benachrichtigungen.",
    "Stories": "Storys",
    "Notify when a contact posts a new story.": "Benachrichtigen, wenn ein Kontakt eine neue Story postet.",
    "posted a new story": "hat eine neue Story gepostet",
    "In reply to a story": "Antwort auf eine Story",
    # Reaktionen auf eigene Nachrichten (Task 3)
    "Reactions": "Reaktionen",
    "Notify when someone reacts to one of your messages.": "Benachrichtigen, wenn jemand auf eine deiner Nachrichten reagiert.",
    "reacted to your message": "hat auf deine Nachricht reagiert",
    "reacted %1 to your message": "hat mit %1 auf deine Nachricht reagiert",
    "Someone": "Jemand",
    # Teilweises Kopieren von Nachrichtentext
    "Selected text copied to clipboard": "Markierter Text in die Zwischenablage kopiert",
    # Videoanrufe (Stub)
    "Video call": "Videoanruf",
    "Video calls are not available in this build yet.": "Videoanrufe sind in dieser Version noch nicht verfügbar.",
    # Stories — tabs + lista
    "Main": "Haupt",
    "Archive": "Archiv",
    "Profile": "Profil",
    "Blocklist": "Blockierliste",
    "View": "Anzeigen",
    "Show the list of Telegram users you have blocked.": "Zeigt die Liste der Telegram-Nutzer, die du blockiert hast.",
    "Blacklist": "Blacklist",
    "Blacklist is empty": "Blacklist ist leer",
    "Add to blacklist": "Zur Blacklist hinzufügen",
    "Remove from blacklist": "Von der Blacklist entfernen",
    "Added to blacklist": "Zur Blacklist hinzugefügt",
    "Removed from blacklist": "Von der Blacklist entfernt",
    "My Archive": "Mein Archiv",
    "You have no archived stories": "Du hast keine archivierten Storys",
    "My Profile": "Mein Profil",
    "You have no stories on your profile": "Du hast keine Storys in deinem Profil",
    "No stories from your contacts": "Keine Storys von deinen Kontakten",
    # Stories — viewer / actions
    "Story": "Story",
    "Story not available": "Story nicht verfügbar",
    "This story type is not supported yet": "Dieser Story-Typ wird noch nicht unterstützt",
    "Delete story": "Story löschen",
    "Deleting story": "Story wird gelöscht",
    "Could not set reaction.": "Reaktion konnte nicht gesetzt werden.",
    "Reply sent": "Antwort gesendet",
    "Send": "Senden",
    "Reply": "Antworten",
    "Reply to %1": "An %1 antworten",
    "Reply to story": "Auf Story antworten",
    "Write a reply…": "Antwort schreiben…",
    "Viewers": "Aufrufe",
    "No viewers yet": "Noch keine Aufrufe",
    "Telegram user": "Telegram-Nutzer",
    "Forwarded": "Weitergeleitet",
    "Reposted": "Erneut gepostet",
    # Stories — compose / publish
    "New story": "Neue Story",
    "Tap to change": "Tippen zum Ändern",
    "Caption": "Beschriftung",
    "Add a caption (optional)": "Beschriftung hinzufügen (optional)",
    "Reading video…": "Video wird gelesen…",
    "Video too long: %1 (max %2)": "Video zu lang: %1 (max %2)",
    "Duration: %1": "Dauer: %1",
    "Publish": "Veröffentlichen",
    "Cannot determine your account.": "Dein Konto konnte nicht ermittelt werden.",
    "Posting story…": "Story wird veröffentlicht…",
    "Video conversion failed.": "Videokonvertierung fehlgeschlagen.",
    "Story posted": "Story veröffentlicht",
    "Could not post story.": "Story konnte nicht veröffentlicht werden.",
    "Telegram stories are vertical (9:16). Your landscape video is being adapted before publishing.":
        "Telegram-Storys sind vertikal (9:16). Dein Querformat-Video wird vor der Veröffentlichung angepasst.",
    "Converting video": "Video wird konvertiert",
    "Uploading video": "Video wird hochgeladen",
    # Stories — audience / picker
    "Audience": "Zielgruppe",
    "Everyone": "Alle",
    "Selected contacts": "Ausgewählte Kontakte",
    "Choose contacts": "Kontakte auswählen",
    "Custom audience": "Benutzerdefinierte Zielgruppe",
    "Custom audience (%1)": "Benutzerdefinierte Zielgruppe (%1)",
    "Allow screenshots": "Screenshots erlauben",
    "If off, the story is marked as protected: official clients block screenshots and forwarding.":
        "Wenn deaktiviert, wird die Story als geschützt markiert: offizielle Clients blockieren Screenshots und Weiterleitungen.",
    "Post to my profile": "In meinem Profil veröffentlichen",
    "Keep the story visible on your profile after the 24h expiration.":
        "Story nach Ablauf der 24 Stunden in deinem Profil sichtbar lassen.",
    "Done": "Fertig",
    "Search...": "Suchen...",
    "No contacts or private chats.": "Keine Kontakte oder privaten Chats.",
    "Loading contacts...": "Kontakte werden geladen...",
    # Video transcoder
    "A video conversion is already in progress.": "Eine Videokonvertierung läuft bereits.",
    "Video converter not available.": "Video-Konverter nicht verfügbar.",
    "Source video not found.": "Quellvideo nicht gefunden.",
    "Could not start the video converter.": "Video-Konverter konnte nicht gestartet werden.",
    # Plurali
    "Delete %Ln message(s)?": ("%Ln Nachricht löschen?", "%Ln Nachrichten löschen?"),
    "%n new story(es)": ("%n neue Story", "%n neue Storys"),
    "%n story(es)": ("%n Story", "%n Storys"),
    "%n view(s)": ("%n Aufruf", "%n Aufrufe"),
    "%n reaction(s)": ("%n Reaktion", "%n Reaktionen"),
    "%n contact(s) selected": ("%n Kontakt ausgewählt", "%n Kontakte ausgewählt"),
    "Choose who will see your next story (%n selected).": (
        "Wähle, wer deine nächste Story sehen wird (%n ausgewählt).",
        "Wähle, wer deine nächste Story sehen wird (%n ausgewählt).",
    ),
    "Members of your custom audience (%n selected). Saved across stories.": (
        "Mitglieder deiner benutzerdefinierten Zielgruppe (%n ausgewählt). Wird über Storys hinweg gespeichert.",
        "Mitglieder deiner benutzerdefinierten Zielgruppe (%n ausgewählt). Wird über Storys hinweg gespeichert.",
    ),
    # Nachrichtenübersetzung (1.8.5)
    "Translate message": "Nachricht übersetzen",
    "Type your message first, then tap this button to translate it to English!":
        "Schreibe zuerst deine Nachricht, dann tippe auf diese Schaltfläche, um sie ins Englische zu übersetzen!",
    # Zensurresistenter Proxy (2.1)
    "Proxy added and enabled": "Proxy hinzugefügt und aktiviert",
    "Add proxy": "Proxy hinzufügen",
    "Add": "Hinzufügen",
    "Paste a proxy link (optional)": "Proxy-Link einfügen (optional)",
    "tg://proxy?server=…  or  https://t.me/proxy?…": "tg://proxy?server=…  oder  https://t.me/proxy?…",
    "Link recognised": "Link erkannt",
    "Type": "Typ",
    "MTProto (recommended)": "MTProto (empfohlen)",
    "SOCKS5 (also for calls)": "SOCKS5 (auch für Anrufe)",
    "HTTP": "HTTP",
    "Server": "Server",
    "Server (host or IP)": "Server (Host oder IP)",
    "Port": "Port",
    "Secret": "Secret",
    "Secret (supports dd… and ee… Fake-TLS)": "Secret (unterstützt dd… und ee… Fake-TLS)",
    "Username (optional)": "Benutzername (optional)",
    "Username": "Benutzername",
    "Password (optional)": "Passwort (optional)",
    "Password": "Passwort",
    "HTTP only": "Nur HTTP",
    "The proxy supports only HTTP requests (no HTTPS tunnelling).":
        "Der Proxy unterstützt nur HTTP-Anfragen (kein HTTPS-Tunneling).",
    "MTProto": "MTProto",
    "SOCKS5": "SOCKS5",
    "%1 ms": "%1 ms",
    "Proxy": "Proxy",
    "Disable proxy (direct connection)": "Proxy deaktivieren (direkte Verbindung)",
    "Proxy disabled": "Proxy deaktiviert",
    "No proxies": "Keine Proxys",
    "Pull down to add a proxy, or paste a tg://proxy link.":
        "Nach unten ziehen, um einen Proxy hinzuzufügen, oder einen tg://proxy-Link einfügen.",
    "Disable": "Deaktivieren",
    "Enable": "Aktivieren",
    "Test connection": "Verbindung testen",
    "Remove": "Entfernen",
    "Removing proxy": "Proxy wird entfernt",
    "Connection": "Verbindung",
    "Proxies route your Telegram traffic through another server to bypass censorship. MTProto proxies (especially with Fake-TLS) are the most resistant to blocking. SOCKS5 proxies also cover voice and video calls.":
        "Proxys leiten deinen Telegram-Datenverkehr über einen anderen Server, um Zensur zu umgehen. MTProto-Proxys (besonders mit Fake-TLS) sind am widerstandsfähigsten gegen Sperren. SOCKS5-Proxys decken auch Sprach- und Videoanrufe ab.",
    "On (%n configured)": ("An (%n konfiguriert)", "An (%n konfiguriert)"),
    "Off (%n configured)": ("Aus (%n konfiguriert)", "Aus (%n konfiguriert)"),
    "Off": "Aus",
    "Add, enable and test connection proxies.":
        "Proxys hinzufügen, aktivieren und Verbindung testen.",
}


MESSAGE_RE = re.compile(r'<message( numerus="yes")?>(.+?)</message>', re.DOTALL)
SOURCE_RE = re.compile(r'<source>(.*?)</source>', re.DOTALL)
UNFINISHED_RE = re.compile(r'<translation type="unfinished">.*?</translation>', re.DOTALL)


def xml_escape(s):
    return (s.replace("&", "&amp;")
             .replace("<", "&lt;")
             .replace(">", "&gt;")
             .replace("'", "&apos;")
             .replace('"', "&quot;"))


def xml_unescape(s):
    return (s.replace("&apos;", "'")
             .replace("&quot;", '"')
             .replace("&lt;", "<")
             .replace("&gt;", ">")
             .replace("&amp;", "&"))


def patch_ts(path: Path, translations: dict):
    text = path.read_text(encoding="utf-8")
    applied = 0
    skipped = 0

    def repl(match):
        nonlocal applied, skipped
        is_num_attr, body = match.group(1), match.group(0)
        is_num = bool(is_num_attr)
        src_m = SOURCE_RE.search(body)
        if not src_m:
            return body
        src = xml_unescape(src_m.group(1))
        if 'type="unfinished"' not in body:
            return body
        if src not in translations:
            skipped += 1
            return body
        tr = translations[src]
        if is_num:
            if not isinstance(tr, tuple):
                print(f"  [warn] plural source has non-tuple translation: {src!r}", file=sys.stderr)
                return body
            forms = "".join(
                f"\n            <numerusform>{xml_escape(form)}</numerusform>"
                for form in tr
            )
            new_trans = f"<translation>{forms}\n        </translation>"
        else:
            if not isinstance(tr, str):
                print(f"  [warn] singular source has non-str translation: {src!r}", file=sys.stderr)
                return body
            new_trans = f"<translation>{xml_escape(tr)}</translation>"
        new_body = UNFINISHED_RE.sub(new_trans, body, count=1)
        applied += 1
        return new_body

    new_text = MESSAGE_RE.sub(repl, text)
    path.write_text(new_text, encoding="utf-8")
    return applied, skipped


def main():
    root = Path(__file__).resolve().parent.parent
    it_path = root / "translations" / "harbour-rootelegram-it.ts"
    de_path = root / "translations" / "harbour-rootelegram-de.ts"

    it_applied, it_skipped = patch_ts(it_path, IT)
    de_applied, de_skipped = patch_ts(de_path, DE)

    print(f"IT: applied {it_applied}, untouched-unfinished {it_skipped}")
    print(f"DE: applied {de_applied}, untouched-unfinished {de_skipped}")

    # Sanity: report sources presenti nei dict ma NON trovati nei .ts
    for lang, d, path in [("IT", IT, it_path), ("DE", DE, de_path)]:
        text = path.read_text(encoding="utf-8")
        missing = [s for s in d if f"<source>{xml_escape(s)}</source>" not in text]
        if missing:
            print(f"{lang} sources non trovati nei .ts ({len(missing)}):")
            for s in missing:
                print(f"  - {s!r}")


if __name__ == "__main__":
    main()
