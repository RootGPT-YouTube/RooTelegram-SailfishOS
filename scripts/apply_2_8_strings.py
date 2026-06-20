#!/usr/bin/env python3
"""Applica le traduzioni delle NUOVE stringhe della 2.8 ai .ts (it/de/pl/ru/fr/sk).

Patcha SOLO i <translation type="unfinished"> il cui <source> è nella tabella,
sostituendoli con la traduzione e togliendo type="unfinished".
Stesso meccanismo (formatting-preserving) di apply_2_6_strings.py.

Stringhe 2.8:
  - #4 (banna membri): "Removed/Banned Users", "Ban from group", "Banning user"
  - #5 (tab GIF): "No saved GIFs", "Search GIFs", "No GIFs found"
"""
from pathlib import Path
import re
from xml.sax.saxutils import escape, unescape

ORDER = ["it", "de", "pl", "ru", "fr", "sk"]

# source -> (it, de, pl, ru, fr, sk)
T = {
"Removed/Banned Users": ("Utenti rimossi/bannati","Entfernte/Gesperrte Benutzer","Usunięci/Zbanowani użytkownicy","Удалённые/Забаненные пользователи","Utilisateurs supprimés/bannis","Odstránení/Zablokovaní používatelia"),
"Ban from group": ("Banna dal gruppo","Aus Gruppe verbannen","Zbanuj z grupy","Забанить в группе","Bannir du groupe","Zablokovať v skupine"),
"Banning user": ("Ban dell'utente…","Benutzer wird gesperrt …","Banowanie użytkownika…","Бан пользователя…","Bannissement de l'utilisateur…","Blokovanie používateľa…"),
"No saved GIFs": ("Nessuna GIF salvata","Keine gespeicherten GIFs","Brak zapisanych GIF-ów","Нет сохранённых GIF","Aucun GIF enregistré","Žiadne uložené GIF"),
"Search GIFs": ("Cerca GIF","GIFs suchen","Szukaj GIF-ów","Поиск GIF","Rechercher des GIF","Hľadať GIF"),
"No GIFs found": ("Nessuna GIF trovata","Keine GIFs gefunden","Nie znaleziono GIF-ów","GIF не найдены","Aucun GIF trouvé","Nenašli sa žiadne GIF"),
}

MSG_RE = re.compile(r"<message[^>]*>.*?</message>", re.S)
SRC_RE = re.compile(r"<source>(.*?)</source>", re.S)


def patch(path, lang_index):
    text = path.read_text(encoding="utf-8")
    stats = {"applied": 0, "left": 0}
    def repl(mm):
        block = mm.group(0)
        if 'type="unfinished"' not in block:
            return block
        sm = SRC_RE.search(block)
        if not sm:
            return block
        src = unescape(sm.group(1), {"&quot;": '"', "&apos;": "'"})
        entry = T.get(src)
        if entry is None:
            stats["left"] += 1
            return block
        tr = entry[lang_index]
        new = "<translation>%s</translation>" % escape(tr, {'"': "&quot;", "'": "&apos;"})
        stats["applied"] += 1
        return re.sub(r'<translation[^>]*>.*?</translation>', new, block, count=1, flags=re.S)
    out = MSG_RE.sub(repl, text)
    path.write_text(out, encoding="utf-8")
    return stats


if __name__ == "__main__":
    root = Path("translations")
    for lang in ORDER:
        st = patch(root / ("harbour-rootelegram-%s.ts" % lang), ORDER.index(lang))
        print(lang, st)
