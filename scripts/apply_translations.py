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
    # Stories — tabs + lista
    "Main": "Home",
    "Archive": "Archivio",
    "Profile": "Profilo",
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
}


DE = {
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
    # Stories — tabs + lista
    "Main": "Haupt",
    "Archive": "Archiv",
    "Profile": "Profil",
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
}


MESSAGE_RE = re.compile(r'<message( numerus="yes")?>(.+?)</message>', re.DOTALL)
SOURCE_RE = re.compile(r'<source>(.*?)</source>', re.DOTALL)
UNFINISHED_RE = re.compile(r'<translation type="unfinished">.*?</translation>', re.DOTALL)


def xml_escape(s):
    return (s.replace("&", "&amp;")
             .replace("<", "&lt;")
             .replace(">", "&gt;"))


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
        src = src_m.group(1)
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
