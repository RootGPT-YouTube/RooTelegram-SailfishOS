.pragma library

// Contenuto del popup "Novità" mostrato una-tantum dopo ogni aggiornamento.
// >>> AGGIORNARE A OGNI RELEASE <<< (fa parte della pipeline /rilascia).
//
// - version:       deve combaciare con RT_APP_VERSION nel .pro.
// - changelogByLang: oggetto { "<codice lingua>": [ ...stringhe... ] }.
// - messageByLang:   oggetto { "<codice lingua>": "<messaggio>" }; "" = nessuno.
//
// Il testo NON passa da qsTr (i .pragma library non hanno contesto di
// traduzione): è scritto direttamente qui, una voce per lingua. Il dialog
// sceglie la lingua dell'app (codice a 2 lettere da Qt.locale()) tramite i
// getter qui sotto, con FALLBACK a "en" se quella lingua non è presente.
// Scrivi almeno "it" + "en"; le altre lingue sono opzionali (mostrano "en").

var version = "2.9.3";

var changelogByLang = {
    "it": [
        "Le citazioni ora si vedono: quando un messaggio cita un pezzo di un altro messaggio compare la barra colorata e il rientro, invece di sembrare testo scritto sul momento.",
        "Molti messaggi che prima dicevano soltanto \"messaggio non supportato\" ora si leggono: storie condivise, giveaway, pagamenti, dadi, chiamate di gruppo, vocali e videomessaggi scaduti, contatti e chat condivisi.",
        "Gli hashtag si toccano: un tocco su #qualcosa apre la ricerca nei messaggi gia' pronta con quella parola.",
        "I numeri di carta di credito si copiano con un tocco, e gli orari scritti nel testo (per esempio 1:23) saltano a quel punto del video o dell'audio del messaggio.",
        "Corretta la citazione in invio: quando citi una frase che nel messaggio originale compare piu' volte, ora viene evidenziata quella che hai scelto tu."
    ],
    "en": [
        "Quotes are visible at last: when a message quotes part of another one you now get the coloured bar and the indent, instead of text that looks freshly written.",
        "Many messages that only said \"unsupported message\" can now be read: shared stories, giveaways, payments, dice, group calls, expired voice and video notes, shared contacts and chats.",
        "Hashtags are tappable: tapping #something opens the message search already filled in with that word.",
        "Credit card numbers are copied with a tap, and timestamps written in the text (1:23, for instance) jump to that point of the message's video or audio.",
        "Fixed quoting when sending: if you quote a sentence that appears more than once in the original message, the one you picked is now the one highlighted."
    ],
    "de": [
        "Zitate sind endlich sichtbar: zitiert eine Nachricht einen Teil einer anderen, erscheinen jetzt der farbige Balken und der Einzug statt frisch geschriebenem Text.",
        "Viele Nachrichten, die nur \"nicht unterstutzte Nachricht\" anzeigten, sind jetzt lesbar: geteilte Storys, Gewinnspiele, Zahlungen, Wurfel, Gruppenanrufe, abgelaufene Sprach- und Videonachrichten, geteilte Kontakte und Chats.",
        "Hashtags sind antippbar: ein Tipp auf #etwas offnet die Nachrichtensuche bereits mit diesem Wort.",
        "Kreditkartennummern werden mit einem Tipp kopiert, und Zeitangaben im Text (etwa 1:23) springen an diese Stelle im Video oder Audio der Nachricht.",
        "Zitieren beim Senden korrigiert: kommt der zitierte Satz mehrfach in der Originalnachricht vor, wird jetzt der von dir gewahlte hervorgehoben."
    ],
    "pl": [
        "Cytaty wreszcie widac: gdy wiadomosc cytuje fragment innej, pojawia sie kolorowy pasek i wciecie, zamiast tekstu wygladajacego na nowo napisany.",
        "Wiele wiadomosci, ktore wczesniej mowily tylko \"nieobslugiwana wiadomosc\", teraz da sie przeczytac: udostepnione relacje, konkursy, platnosci, kostki, polaczenia grupowe, wygasle wiadomosci glosowe i wideo, udostepnione kontakty i czaty.",
        "Hashtagi sa klikalne: dotkniecie #czegos otwiera wyszukiwanie wiadomosci juz wypelnione tym slowem.",
        "Numery kart platniczych kopiuje sie jednym dotknieciem, a godziny zapisane w tekscie (na przyklad 1:23) przeskakuja do tego miejsca wideo lub audio wiadomosci.",
        "Poprawione cytowanie przy wysylaniu: jesli cytujesz zdanie wystepujace w oryginale kilka razy, podswietlone zostanie to wybrane przez ciebie."
    ],
    "ru": [
        "Цитаты наконец видно: когда сообщение цитирует часть другого, появляются цветная полоса и отступ, а не текст, похожий на только что написанный.",
        "Многие сообщения, которые раньше показывали лишь «сообщение не поддерживается», теперь читаются: истории, розыгрыши, платежи, кубики, групповые звонки, истёкшие голосовые и видеосообщения, пересланные контакты и чаты.",
        "Хештеги стали нажимаемыми: касание #чего-нибудь открывает поиск по сообщениям, уже заполненный этим словом.",
        "Номера банковских карт копируются одним касанием, а время, написанное в тексте (например 1:23), переносит к этому месту видео или аудио сообщения.",
        "Исправлено цитирование при отправке: если цитируемая фраза встречается в исходном сообщении несколько раз, теперь выделяется именно выбранная вами."
    ],
    "fr": [
        "Les citations se voient enfin : quand un message cite un morceau d'un autre, la barre coloree et le retrait apparaissent, au lieu d'un texte qui semble tout juste ecrit.",
        "Beaucoup de messages qui affichaient seulement \"message non pris en charge\" se lisent maintenant : stories partagees, tirages au sort, paiements, des, appels de groupe, messages vocaux et video expires, contacts et discussions partages.",
        "Les hashtags sont tactiles : toucher #quelquechose ouvre la recherche dans les messages deja remplie avec ce mot.",
        "Les numeros de carte bancaire se copient d'un toucher, et les horaires ecrits dans le texte (1:23 par exemple) sautent a cet endroit de la video ou de l'audio du message.",
        "Citation corrigee a l'envoi : si la phrase citee apparait plusieurs fois dans le message d'origine, c'est bien celle que vous avez choisie qui est mise en avant."
    ],
    "sk": [
        "Citacie je konecne vidiet: ked sprava cituje cast inej, objavi sa farebny pruh a odsadenie namiesto textu, ktory vyzera ako prave napisany.",
        "Mnohe spravy, ktore predtym hovorili len \"nepodporovana sprava\", sa teraz daju precitat: zdielane pribehy, sutaze, platby, kocky, skupinove hovory, vyprsane hlasove a videospravy, zdielane kontakty a chaty.",
        "Hashtagy sa daju tuknut: tuknutie na #nieco otvori vyhladavanie v spravach uz vyplnene tym slovom.",
        "Cisla platobnych kariet sa kopiruju jednym tuknutim a casy napisane v texte (napriklad 1:23) skocia na to miesto videa alebo zvuku spravy.",
        "Opravene citovanie pri odosielani: ak sa citovana veta v povodnej sprave vyskytuje viackrat, zvyrazni sa ta, ktoru si vybral."
    ]
};

var messageByLang = {
    "it": "Le citazioni ora si vedono davvero, e molti messaggi che dicevano \"non supportato\" finalmente si leggono.",
    "en": "Quotes are finally visible, and many messages that said \"unsupported\" can now be read.",
    "de": "Zitate sind endlich sichtbar, und viele \"nicht unterstutzte\" Nachrichten sind jetzt lesbar.",
    "pl": "Cytaty wreszcie widac, a wiele \"nieobslugiwanych\" wiadomosci da sie teraz przeczytac.",
    "ru": "Цитаты наконец видны, и многие «неподдерживаемые» сообщения теперь читаются.",
    "fr": "Les citations se voient enfin, et beaucoup de messages \"non pris en charge\" se lisent maintenant.",
    "sk": "Citacie je konecne vidiet a mnohe \"nepodporovane\" spravy sa teraz daju precitat."
};

// Restituisce il changelog/messaggio per la lingua data (codice a 2 lettere),
// con fallback a "en". Usati dal WhatsNewDialog.
function changelogFor(lang) {
    return changelogByLang[lang] || changelogByLang["en"];
}

function messageFor(lang) {
    return (lang in messageByLang) ? messageByLang[lang] : messageByLang["en"];
}
