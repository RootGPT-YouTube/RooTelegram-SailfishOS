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

var version = "2.8";

var changelogByLang = {
    "it": [
        "GIF: nuova scheda GIF nel pannello allegati, con la libreria delle tue GIF salvate e la ricerca delle GIF. Tocca una GIF per inviarla subito.",
        "Cita: rispondi citando solo una porzione del testo di un messaggio, come su Telegram ufficiale.",
        "Inoltro multiplo: ora puoi inoltrare più messaggi insieme in un'unica operazione.",
        "Menzioni @ nei gruppi: i suggerimenti mostrano solo i membri del gruppo, non tutti i contatti.",
        "Gestione gruppi: rimuovere/bannare i membri ora funziona; solo il creatore del gruppo può nominare o revocare gli amministratori; nuova sezione \"Utenti rimossi/bannati\".",
        "Storie: i video si riproducono correttamente fino alla fine e la sezione Storie ora rispetta il tema Silica.",
        "Emoji: corrette le emoji con genere (es. 🤦‍♀️) che apparivano spezzate, più le emoji recenti; il pannello emoji resta aperto dopo una selezione e non apre più la tastiera.",
        "Nomi toccabili: nei messaggi di servizio (\"ha aggiunto/rimosso X\") i nomi degli utenti sono ora toccabili.",
        "Stabilità: risolto il blocco che poteva capitare aprendo l'app da una notifica."
    ],
    "en": [
        "GIFs: new GIF tab in the attachment panel, with your saved GIFs library and GIF search. Tap a GIF to send it right away.",
        "Quote: reply quoting only a portion of a message's text, like in official Telegram.",
        "Multiple forwarding: you can now forward several messages together in a single action.",
        "@ mentions in groups: suggestions now show only the group's members, not all your contacts.",
        "Group management: removing/banning members now works; only the group creator can promote or demote admins; new \"Removed/Banned Users\" section.",
        "Stories: videos now play all the way through and the Stories section follows the Silica theme.",
        "Emoji: fixed gendered emoji (e.g. 🤦‍♀️) that showed up broken, plus recent emoji; the emoji panel stays open after a pick and no longer pops up the keyboard.",
        "Tappable names: user names in service messages (\"added/removed X\") are now tappable.",
        "Stability: fixed the freeze that could happen opening the app from a notification."
    ],
    "de": [
        "GIFs: neuer GIF-Tab im Anhang-Panel, mit deiner Bibliothek gespeicherter GIFs und GIF-Suche. Tippe ein GIF an, um es sofort zu senden.",
        "Zitat: antworte und zitiere nur einen Teil des Nachrichtentexts, wie im offiziellen Telegram.",
        "Mehrfaches Weiterleiten: du kannst jetzt mehrere Nachrichten zusammen in einem Schritt weiterleiten.",
        "@-Erwähnungen in Gruppen: Vorschläge zeigen jetzt nur die Mitglieder der Gruppe, nicht alle Kontakte.",
        "Gruppenverwaltung: Entfernen/Sperren von Mitgliedern funktioniert jetzt; nur der Gruppenersteller kann Admins ernennen oder absetzen; neuer Bereich „Entfernte/Gesperrte Benutzer“.",
        "Storys: Videos werden jetzt bis zum Ende abgespielt und der Storys-Bereich folgt dem Silica-Theme.",
        "Emoji: behoben sind die geschlechtsbezogenen Emoji (z. B. 🤦‍♀️), die zerbrochen erschienen, dazu kürzlich verwendete Emoji; das Emoji-Panel bleibt nach einer Auswahl offen und öffnet die Tastatur nicht mehr.",
        "Antippbare Namen: Benutzernamen in Dienstnachrichten („hat X hinzugefügt/entfernt“) sind jetzt antippbar.",
        "Stabilität: das Einfrieren beim Öffnen der App aus einer Benachrichtigung wurde behoben."
    ],
    "pl": [
        "GIF-y: nowa karta GIF w panelu załączników, z biblioteką zapisanych GIF-ów i wyszukiwaniem GIF-ów. Dotknij GIF-a, aby od razu go wysłać.",
        "Cytowanie: odpowiadaj, cytując tylko fragment tekstu wiadomości, jak w oficjalnym Telegramie.",
        "Przekazywanie wielu wiadomości: możesz teraz przekazać kilka wiadomości naraz w jednej operacji.",
        "Wzmianki @ w grupach: podpowiedzi pokazują teraz tylko członków grupy, a nie wszystkie kontakty.",
        "Zarządzanie grupą: usuwanie/banowanie członków już działa; tylko twórca grupy może nadawać lub odbierać uprawnienia administratora; nowa sekcja „Usunięci/Zbanowani użytkownicy”.",
        "Relacje: filmy odtwarzają się teraz do końca, a sekcja Relacje uwzględnia motyw Silica.",
        "Emoji: naprawiono emoji z płcią (np. 🤦‍♀️), które wyświetlały się jako rozbite, oraz ostatnio używane emoji; panel emoji pozostaje otwarty po wyborze i nie otwiera już klawiatury.",
        "Dotykalne nazwy: nazwy użytkowników w wiadomościach systemowych („dodał/usunął X”) są teraz dotykalne.",
        "Stabilność: naprawiono zawieszanie, które mogło wystąpić przy otwieraniu aplikacji z powiadomienia."
    ],
    "ru": [
        "GIF: новая вкладка GIF в панели вложений, с библиотекой сохранённых GIF и поиском GIF. Нажмите на GIF, чтобы сразу отправить.",
        "Цитата: отвечайте, цитируя только часть текста сообщения, как в официальном Telegram.",
        "Пересылка нескольких сообщений: теперь можно переслать сразу несколько сообщений за одно действие.",
        "Упоминания @ в группах: подсказки теперь показывают только участников группы, а не все контакты.",
        "Управление группой: удаление/бан участников теперь работает; только создатель группы может назначать и снимать администраторов; новый раздел «Удалённые/Забаненные пользователи».",
        "Истории: видео теперь воспроизводятся до конца, а раздел «Истории» учитывает тему Silica.",
        "Эмодзи: исправлены гендерные эмодзи (напр. 🤦‍♀️), которые отображались разбитыми, плюс недавние эмодзи; панель эмодзи остаётся открытой после выбора и больше не открывает клавиатуру.",
        "Нажимаемые имена: имена пользователей в служебных сообщениях («добавил/удалил X») теперь нажимаемые.",
        "Стабильность: исправлено зависание, которое могло возникать при открытии приложения из уведомления."
    ],
    "fr": [
        "GIF : nouvel onglet GIF dans le panneau des pièces jointes, avec votre bibliothèque de GIF enregistrés et la recherche de GIF. Touchez un GIF pour l'envoyer aussitôt.",
        "Citer : répondez en citant seulement une partie du texte d'un message, comme dans Telegram officiel.",
        "Transfert multiple : vous pouvez désormais transférer plusieurs messages ensemble en une seule opération.",
        "Mentions @ dans les groupes : les suggestions n'affichent plus que les membres du groupe, et non tous vos contacts.",
        "Gestion des groupes : retirer/bannir des membres fonctionne désormais ; seul le créateur du groupe peut nommer ou révoquer les administrateurs ; nouvelle section « Utilisateurs supprimés/bannis ».",
        "Stories : les vidéos se lisent maintenant jusqu'au bout et la section Stories respecte le thème Silica.",
        "Émojis : correction des émojis genrés (ex. 🤦‍♀️) qui apparaissaient cassés, plus les émojis récents ; le panneau d'émojis reste ouvert après une sélection et n'ouvre plus le clavier.",
        "Noms touchables : dans les messages de service (« a ajouté/retiré X »), les noms d'utilisateurs sont désormais touchables.",
        "Stabilité : correction du blocage qui pouvait survenir en ouvrant l'application depuis une notification."
    ],
    "sk": [
        "GIF: nová karta GIF v paneli príloh, s knižnicou uložených GIF a vyhľadávaním GIF. Ťuknutím na GIF ho hneď odošlete.",
        "Citovať: odpovedajte citovaním iba časti textu správy, ako v oficiálnom Telegrame.",
        "Hromadné preposielanie: teraz môžete preposlať viacero správ naraz jedným úkonom.",
        "Zmienky @ v skupinách: návrhy teraz zobrazujú iba členov skupiny, nie všetky kontakty.",
        "Správa skupiny: odstránenie/zablokovanie členov už funguje; iba tvorca skupiny môže vymenovať alebo odvolať administrátorov; nová sekcia „Odstránení/Zablokovaní používatelia“.",
        "Príbehy: videá sa teraz prehrajú až do konca a sekcia Príbehy rešpektuje tému Silica.",
        "Emoji: opravené rodové emoji (napr. 🤦‍♀️), ktoré sa zobrazovali rozbité, plus nedávne emoji; panel emoji zostáva po výbere otvorený a už neotvára klávesnicu.",
        "Ťuknuteľné mená: mená používateľov v servisných správach („pridal/odstránil X“) sú teraz ťuknuteľné.",
        "Stabilita: opravené zamrznutie, ktoré mohlo nastať pri otvorení aplikácie z upozornenia."
    ]
};

var messageByLang = {
    "it": "RooTelegram 2.8 aggiunge la scheda GIF (libreria delle GIF salvate + ricerca), la Cita di una porzione di messaggio, l'inoltro di più messaggi insieme, le menzioni @ limitate ai membri del gruppo e la gestione corretta di rimozione/ban dei membri. Inoltre: storie video riprodotte fino in fondo e sezione Storie in tema Silica, emoji con genere corrette + emoji recenti, nomi toccabili nei messaggi di servizio e più stabilità all'apertura da notifica.",
    "en": "RooTelegram 2.8 adds the GIF tab (saved GIFs library + search), Quote of a portion of a message, forwarding several messages at once, @ mentions limited to group members, and proper member removal/ban management. Also: story videos that play all the way through and a Silica-themed Stories section, fixed gendered emoji + recent emoji, tappable names in service messages, and more stability when opening from a notification.",
    "de": "RooTelegram 2.8 bringt den GIF-Tab (Bibliothek gespeicherter GIFs + Suche), das Zitieren eines Nachrichtenteils, das Weiterleiten mehrerer Nachrichten auf einmal, @-Erwähnungen beschränkt auf Gruppenmitglieder und die korrekte Verwaltung von Entfernen/Sperren von Mitgliedern. Außerdem: Story-Videos, die bis zum Ende abspielen, und ein Storys-Bereich im Silica-Theme, behobene geschlechtsbezogene Emoji + kürzlich verwendete Emoji, antippbare Namen in Dienstnachrichten und mehr Stabilität beim Öffnen aus einer Benachrichtigung.",
    "pl": "RooTelegram 2.8 dodaje kartę GIF (biblioteka zapisanych GIF-ów + wyszukiwanie), cytowanie fragmentu wiadomości, przekazywanie kilku wiadomości naraz, wzmianki @ ograniczone do członków grupy oraz poprawne zarządzanie usuwaniem/banowaniem członków. Ponadto: filmy w relacjach odtwarzane do końca i sekcja Relacje w motywie Silica, naprawione emoji z płcią + ostatnio używane emoji, dotykalne nazwy w wiadomościach systemowych oraz większa stabilność przy otwieraniu z powiadomienia.",
    "ru": "RooTelegram 2.8 добавляет вкладку GIF (библиотека сохранённых GIF + поиск), цитирование части сообщения, пересылку нескольких сообщений сразу, упоминания @, ограниченные участниками группы, и правильное управление удалением/баном участников. Также: видео в историях воспроизводятся до конца и раздел «Истории» в теме Silica, исправленные гендерные эмодзи + недавние эмодзи, нажимаемые имена в служебных сообщениях и больше стабильности при открытии из уведомления.",
    "fr": "RooTelegram 2.8 ajoute l'onglet GIF (bibliothèque de GIF enregistrés + recherche), la citation d'une partie d'un message, le transfert de plusieurs messages à la fois, les mentions @ limitées aux membres du groupe et la gestion correcte du retrait/bannissement des membres. Aussi : des vidéos de stories qui se lisent jusqu'au bout et une section Stories au thème Silica, des émojis genrés corrigés + émojis récents, des noms touchables dans les messages de service et plus de stabilité à l'ouverture depuis une notification.",
    "sk": "RooTelegram 2.8 pridáva kartu GIF (knižnica uložených GIF + vyhľadávanie), citovanie časti správy, preposlanie viacerých správ naraz, zmienky @ obmedzené na členov skupiny a správne spravovanie odstránenia/zablokovania členov. Okrem toho: videá v príbehoch sa prehrajú až do konca a sekcia Príbehy v téme Silica, opravené rodové emoji + nedávne emoji, ťuknuteľné mená v servisných správach a väčšia stabilita pri otvorení z upozornenia."
};

// Restituisce il changelog/messaggio per la lingua data (codice a 2 lettere),
// con fallback a "en". Usati dal WhatsNewDialog.
function changelogFor(lang) {
    return changelogByLang[lang] || changelogByLang["en"];
}

function messageFor(lang) {
    return (lang in messageByLang) ? messageByLang[lang] : messageByLang["en"];
}
