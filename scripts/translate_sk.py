#!/usr/bin/env python3
"""Genera translations/harbour-rootelegram-sk.ts (slovacco).

Base = la traduzione donata da okruhliak (PR #1), che è ottima per ~91% delle
stringhe. Questo script:
  - riusa le stringhe slovacche valide del contributor (chiave: contesto+source);
  - sovrascrive i residui rimasti in TEDESCO (il contributor aveva usato il file
    de.ts come base) con traduzioni slovacche corrette (vedi SK_FIX);
  - aggiunge le stringhe mancanti (feature recenti: ArchivedChatsPage,
    MessageInfoPage) tradotte in slovacco;
  - genera l'output dalla struttura di en.ts → tutti i messaggi presenti, plurali
    a 3 forme (slovacco: one / few(2-4) / many(5+)).

Uso:  python3 scripts/translate_sk.py [/percorso/sk-contributor.ts]
Default contributor: /tmp/sk.ts
"""
from pathlib import Path
import sys
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

EN = Path("translations/harbour-rootelegram-en.ts")
DE = Path("translations/harbour-rootelegram-de.ts")
OUT = Path("translations/harbour-rootelegram-sk.ts")
CONTRIB = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/tmp/sk.ts")

# --- Le mie traduzioni slovacche per i 76 residui tedeschi + le 37 mancanti ---
# chiave: (context, source) -> str  oppure  tuple (3 forme) per i plurali.
SK_FIX = {
    # 2.8: banna membri (#4) + tab GIF (#5)
    ("ChatInformationPageContent", "Removed/Banned Users"): "Odstránení/Zablokovaní používatelia",
    ("SupergroupMembersPage", "Removed/Banned Users"): "Odstránení/Zablokovaní používatelia",
    ("ChatInformationTabItemMembersGroups", "Ban from group"): "Zablokovať v skupine",
    ("ChatInformationTabItemMembersGroups", "Banning user"): "Blokovanie používateľa…",
    ("ChatPage", "No saved GIFs"): "Žiadne uložené GIF",
    ("ChatPage", "Search GIFs"): "Hľadať GIF",
    ("ChatPage", "No GIFs found"): "Nenašli sa žiadne GIF",
    ("AddProxyDialog", "Type"): "Typ",
    ("AllScheduledMessagesPage", "Document"): "Dokument",
    ("ScheduleMessageDialog", "Document"): "Dokument",
    ("MessageContact", "Contact"): "Kontakt",
    ("StoriesPage", "Profile"): "Profil",
    ("functions", "Document: %1"): "Dokument: %1",
    ("GroupTypePage", "Username can only use letters, numbers and underscores."):
        "Používateľské meno môže obsahovať iba písmená, číslice a podčiarkovníky.",
    # --- ChatPage (residui tedeschi) ---
    ("ChatPage", "Accuracy: %1m"): "Presnosť: %1 m",
    ("ChatPage", "Additional Options"): "Ďalšie možnosti",
    ("ChatPage", "Close Chat"): "Zavrieť konverzáciu",
    ("ChatPage", "Closing chat"): "Zatváranie konverzácie",
    ("ChatPage", "Copy Message to Clipboard"): "Kopírovať správu do schránky",
    ("ChatPage", "Copy Selected Text"): "Kopírovať vybraný text",
    ("ChatPage", "Delete Chat"): "Odstrániť konverzáciu",
    ("ChatPage", "Delete message"): "Odstrániť správu",
    ("ChatPage", "Deleted User"): "Odstránený používateľ",
    ("ChatPage", "Deleting \"%1\""): "Odstraňuje sa „%1“",
    ("ChatPage", "Deleting chat"): "Odstraňovanie konverzácie",
    ("ChatPage", "Deleting set"): "Odstraňovanie súpravy",
    ("ChatPage", "Do you want to delete \"%1\"?"): "Chcete odstrániť „%1“?",
    ("ChatPage", "Do you want to delete this set?"): "Chcete odstrániť túto súpravu?",
    ("ChatPage", "Double-tap on a message to choose a reaction"):
        "Dvojitým ťuknutím na správu vyberiete reakciu",
    ("ChatPage", "Edit Message"): "Upraviť správu",
    ("ChatPage", "Forward message"): "Preposlať správu",
    ("ChatPage", "Join Chat"): "Pripojiť sa ku konverzácii",
    ("ChatPage", "Leave Chat"): "Opustiť konverzáciu",
    ("ChatPage", "Leaving chat"): "Opúšťanie konverzácie",
    ("ChatPage", "Loading messages..."): "Načítavanie správ…",
    ("ChatPage", "Location (%1/%2)"): "Poloha (%1/%2)",
    ("ChatPage", "Location: Obtaining position..."): "Poloha: Zisťuje sa pozícia…",
    ("ChatPage", "Message unpinned"): "Správa odopnutá",
    ("ChatPage", "Mute Chat"): "Stlmiť konverzáciu",
    ("ChatPage", "No"): "Nie",
    ("ChatPage", "No premium emoji set available"):
        "Nie je dostupná žiadna prémiová súprava emoji",
    ("ChatPage", "No recent stickers"): "Žiadne nedávne nálepky",
    ("ChatPage", "No stickers in this set"): "V tejto súprave nie sú žiadne nálepky",
    ("ChatPage", "Only the first shared file has been prepared."):
        "Pripravený bol iba prvý zdieľaný súbor.",
    ("ChatPage", "Pin Message"): "Pripnúť správu",
    ("ChatPage", "Premium set"): "Prémiová súprava",
    ("ChatPage", "Quote Selected Text"): "Citovať vybraný text",
    ("ChatPage", "Recent"): "Nedávne",
    ("ChatPage", "RooTelegram couldn't detect the language of the text — maybe you wrote a multilingual message?"):
        "RooTelegram nedokázal rozpoznať jazyk textu — možno ste napísali viacjazyčnú správu?",
    ("ChatPage", "Scheduled for %1"): "Naplánované na %1",
    ("ChatPage", "Search in Chat"): "Hľadať v konverzácii",
    ("ChatPage", "Search in chat..."): "Hľadať v konverzácii…",
    ("ChatPage", "Select Messages"): "Vybrať správy",
    ("ChatPage", "Selected text copied to clipboard"):
        "Vybraný text skopírovaný do schránky",
    ("ChatPage", "Sponsored Message"): "Sponzorovaná správa",
    ("ChatPage", "Sticker set"): "Súprava nálepiek",
    ("ChatPage", "Telegram allows up to %1 images per album."):
        "Telegram povoľuje až %1 obrázkov v albume.",
    ("ChatPage", "This chat is empty."): "Táto konverzácia je prázdna.",
    ("ChatPage", "This secret chat is not yet ready. Your chat partner needs to go online first."):
        "Tento tajný čet ešte nie je pripravený. Váš partner v konverzácii musí najprv prejsť do režimu online.",
    ("ChatPage", "Topic is closed"): "Téma je uzavretá",
    ("ChatPage", "Type your message first, then tap this button to translate it to English!"):
        "Najprv napíšte správu, potom ťuknite na toto tlačidlo, aby ste ju preložili do angličtiny!",
    ("ChatPage", "Unable to send this sticker."): "Túto nálepku sa nepodarilo odoslať.",
    ("ChatPage", "Unknown"): "Neznáme",
    ("ChatPage", "Unknown address"): "Neznáma adresa",
    ("ChatPage", "Unmute Chat"): "Zrušiť stlmenie konverzácie",
    ("ChatPage", "Unpin Message"): "Odopnúť správu",
    ("ChatPage", "Uploading..."): "Nahrávanie…",
    ("ChatPage", "Yes"): "Áno",
    ("ChatPage", "You joined the chat %1"): "Pripojili ste sa ku konverzácii %1",
    ("ChatPage", "Your message"): "Vaša správa",
    ("ChatPage", "edited"): "upravené",
    ("ChatPage", "is choosing a contact"): "vyberá kontakt",
    ("ChatPage", "is choosing a location"): "vyberá polohu",
    ("ChatPage", "is choosing a sticker"): "vyberá nálepku",
    ("ChatPage", "is recording a video"): "nahráva video",
    ("ChatPage", "is recording a video message"): "nahráva videosprávu",
    ("ChatPage", "is recording a voice message"): "nahráva hlasovú správu",
    ("ChatPage", "is sending a file"): "odosiela súbor",
    ("ChatPage", "is sending a photo"): "odosiela fotku",
    ("ChatPage", "is sending a video"): "odosiela video",
    ("ChatPage", "is sending a video message"): "odosiela videosprávu",
    ("ChatPage", "is sending a voice message"): "odosiela hlasovú správu",
    ("ChatPage", "is typing…"): "píše…",
    # --- ArchivedChatsPage (mancanti) ---
    ("ArchivedChatsPage", "%n chat(s)"): ("%n konverzácia", "%n konverzácie", "%n konverzácií"),
    ("ArchivedChatsPage", "Archived chats"): "Archivované konverzácie",
    ("ArchivedChatsPage", "Audio"): "Zvuk",
    ("ArchivedChatsPage", "Call"): "Hovor",
    ("ArchivedChatsPage", "Contact"): "Kontakt",
    ("ArchivedChatsPage", "Document"): "Dokument",
    ("ArchivedChatsPage", "GIF"): "GIF",
    ("ArchivedChatsPage", "Location"): "Poloha",
    ("ArchivedChatsPage", "Long-press a chat in the main list and choose Archive."):
        "Podržte konverzáciu v hlavnom zozname a vyberte Archivovať.",
    ("ArchivedChatsPage", "No archived chats"): "Žiadne archivované konverzácie",
    ("ArchivedChatsPage", "Photo"): "Fotka",
    ("ArchivedChatsPage", "Poll"): "Anketa",
    ("ArchivedChatsPage", "Sticker"): "Nálepka",
    ("ArchivedChatsPage", "Unarchive"): "Zrušiť archiváciu",
    ("ArchivedChatsPage", "Unknown"): "Neznáme",
    ("ArchivedChatsPage", "Video"): "Video",
    ("ArchivedChatsPage", "Video message"): "Videospráva",
    ("ArchivedChatsPage", "Voice message"): "Hlasová správa",
    ("ChatListViewItem", "Archive chat"): "Archivovať konverzáciu",
    ("SettingsStorage", "Archived chats"): "Archivované konverzácie",
    # --- MessageInfoPage (mancanti) ---
    ("MessageInfoPage", "Album ID"): "ID albumu",
    ("MessageInfoPage", "Author signature"): "Podpis autora",
    ("MessageInfoPage", "Edited"): "Upravené",
    ("MessageInfoPage", "Forwarded from"): "Preposlané od",
    ("MessageInfoPage", "Forwards"): "Preposlania",
    ("MessageInfoPage", "Message ID"): "ID správy",
    ("MessageInfoPage", "Message info"): "Informácie o správe",
    ("MessageInfoPage", "Original date"): "Pôvodný dátum",
    ("MessageInfoPage", "Reactions"): "Reakcie",
    ("MessageInfoPage", "Scheduled"): "Naplánované",
    ("MessageInfoPage", "Sender"): "Odosielateľ",
    ("MessageInfoPage", "Sent"): "Odoslané",
    ("MessageInfoPage", "Via bot"): "Cez bota",
    ("MessageInfoPage", "Views"): "Zobrazenia",
    ("MessageInfoPage", "When the recipient comes online"):
        "Keď príjemca prejde do režimu online",
    ("MessageListViewItem", "Code copied to clipboard"): "Kód skopírovaný do schránky",
    ("MessageListViewItem", "Message info"): "Informácie o správe",
    # --- Nomi propri / protocolli: identici in slovacco (azzera gli unfinished) ---
    ("AboutPage", "Fernschreiber"): "Fernschreiber",
    ("AboutPage", "Yottagram"): "Yottagram",
    ("SettingsAbout", "Fernschreiber"): "Fernschreiber",
    ("SettingsAbout", "Yottagram"): "Yottagram",
    ("AddProxyDialog", "HTTP"): "HTTP",
    ("AddProxyDialog", "Port"): "Port",
    ("AddProxyDialog", "Server"): "Server",
    ("AllScheduledMessagesPage", "GIF"): "GIF",
    ("AllScheduledMessagesPage", "Video"): "Video",
    ("ScheduleMessageDialog", "GIF"): "GIF",
    ("ScheduleMessageDialog", "Video"): "Video",
    ("ProxyListPage", "%1 ms"): "%1 ms",
    ("ProxyListPage", "HTTP"): "HTTP",
    ("ProxyListPage", "MTProto"): "MTProto",
    ("ProxyListPage", "Proxy"): "Proxy",
    ("ProxyListPage", "SOCKS5"): "SOCKS5",
    ("SettingsConnection", "Proxy"): "Proxy",
}


def load_map(path):
    """(context, source) -> ('plain', text) | ('plural', [forms])."""
    tree = ET.parse(str(path))
    out = {}
    for ctx in tree.getroot().findall("context"):
        cname = ctx.find("name").text
        for m in ctx.findall("message"):
            src = m.find("source").text or ""
            tr = m.find("translation")
            if tr is None:
                continue
            forms = tr.findall("numerusform")
            if forms:
                out[(cname, src)] = ("plural", [f.text or "" for f in forms])
            else:
                out[(cname, src)] = ("plain", tr.text or "")
    return out


def main():
    contrib = load_map(CONTRIB)
    de = load_map(DE)
    en_map = load_map(EN)
    en_text = EN.read_text(encoding="utf-8")

    # Stringhe del contributor da considerare VALIDE: tutte tranne quelle ancora
    # identiche al tedesco (residui non tradotti) e diverse dall'inglese.
    def is_german_leftover(key, value):
        if key not in de:
            return False
        return de[key] == value and en_map.get(key) != de[key]

    sk = {}
    for key, val in contrib.items():
        if is_german_leftover(key, val):
            continue
        sk[key] = val
    # Le mie correzioni/aggiunte hanno priorità.
    for key, val in SK_FIX.items():
        if isinstance(val, tuple):
            sk[key] = ("plural", list(val))
        else:
            sk[key] = ("plain", val)

    # Genera l'output clonando la struttura di en.ts via sostituzione testuale
    # per-messaggio (mantiene formattazione e ordine identici alla sorgente).
    import re

    def esc(t):
        return escape(t)

    stats = {"plain": 0, "plural": 0, "unfinished": 0}

    def unescape(t):
        return (t.replace("&quot;", '"').replace("&lt;", "<").replace("&gt;", ">")
                 .replace("&apos;", "'").replace("&amp;", "&"))

    def process_context(cm):
        block = cm.group(0)
        nm = re.search(r"<name>(.*?)</name>", block, re.S)
        cname = nm.group(1) if nm else ""

        def repl_msg(mm):
            mblock = mm.group(0)
            sm = re.search(r"<source>(.*?)</source>", mblock, re.S)
            if not sm:
                return mblock
            src_key = unescape(sm.group(1))
            entry = sk.get((cname, src_key))
            if entry is None:
                stats["unfinished"] += 1
                return mblock
            if entry[0] == "plural":
                nf = "".join(
                    f"\n            <numerusform>{esc(x)}</numerusform>" for x in entry[1])
                new_tr = f"<translation>{nf}\n        </translation>"
                stats["plural"] += 1
            else:
                new_tr = f"<translation>{esc(entry[1])}</translation>"
                stats["plain"] += 1
            return re.sub(r"<translation[^>]*>.*?</translation>", new_tr,
                          mblock, count=1, flags=re.S)

        return re.sub(r"<message[^>]*>.*?</message>", repl_msg, block, flags=re.S)

    out_text = re.sub(r"<context>.*?</context>", process_context, en_text, flags=re.S)
    out_text = out_text.replace('language="en"', 'language="sk_SK"')

    OUT.write_text(out_text, encoding="utf-8")
    print("Scritto", OUT)
    print("Statistiche:", stats)


if __name__ == "__main__":
    main()
