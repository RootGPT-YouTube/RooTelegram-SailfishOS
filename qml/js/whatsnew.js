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

var version = "2.7.5";

var changelogByLang = {
    "it": [
        "Cerca nei messaggi: nuova ricerca globale per testo. Dal menu del titolo nella schermata principale tocca \"Cerca nei messaggi\", digita una parola e RooTelegram la cerca tra i messaggi di tutte le tue chat. Tocca un risultato per aprire la chat direttamente su quel messaggio.",
        "Traduzione slovacca: completata e migliorata: tradotte tutte le stringhe rimaste, incluse quelle della posizione in tempo reale. Grazie al traduttore."
    ],
    "en": [
        "Search in messages: new global text search. From the title menu on the home screen tap \"Search in messages\", type a word and RooTelegram looks for it across the messages of all your chats. Tap a result to open the chat right at that message.",
        "Slovak translation: completed and improved: all remaining strings translated, including the live location ones. Thanks to the translator."
    ],
    "de": [
        "In Nachrichten suchen: neue globale Textsuche. Tippe im Titelmenü des Startbildschirms auf „In Nachrichten suchen“, gib ein Wort ein und RooTelegram sucht es in den Nachrichten all deiner Chats. Tippe auf ein Ergebnis, um den Chat direkt bei dieser Nachricht zu öffnen.",
        "Slowakische Übersetzung: vervollständigt und verbessert: alle verbliebenen Texte übersetzt, auch die zum Live-Standort. Danke an den Übersetzer."
    ],
    "pl": [
        "Szukaj w wiadomościach: nowe globalne wyszukiwanie tekstu. W menu tytułowym na ekranie głównym dotknij „Szukaj w wiadomościach”, wpisz słowo, a RooTelegram wyszuka je w wiadomościach wszystkich Twoich czatów. Dotknij wyniku, aby otworzyć czat bezpośrednio przy tej wiadomości.",
        "Tłumaczenie słowackie: ukończone i ulepszone: przetłumaczono wszystkie pozostałe teksty, w tym te dotyczące lokalizacji na żywo. Dziękujemy tłumaczowi."
    ],
    "ru": [
        "Поиск по сообщениям: новый глобальный поиск по тексту. В меню заголовка на главном экране нажмите «Поиск по сообщениям», введите слово, и RooTelegram найдёт его в сообщениях всех ваших чатов. Нажмите на результат, чтобы открыть чат сразу на этом сообщении.",
        "Словацкий перевод: завершён и улучшен: переведены все оставшиеся строки, включая трансляцию местоположения. Спасибо переводчику."
    ],
    "fr": [
        "Rechercher dans les messages : nouvelle recherche textuelle globale. Dans le menu de titre de l'écran d'accueil, touchez « Rechercher dans les messages », saisissez un mot et RooTelegram le recherche dans les messages de toutes vos conversations. Touchez un résultat pour ouvrir la conversation directement sur ce message.",
        "Traduction slovaque : complétée et améliorée : toutes les chaînes restantes traduites, y compris celles de la position en direct. Merci au traducteur."
    ],
    "sk": [
        "Hľadať v správach: nové globálne textové vyhľadávanie. V ponuke názvu na domovskej obrazovke ťuknite na „Hľadať v správach“, zadajte slovo a RooTelegram ho vyhľadá v správach všetkých vašich konverzácií. Ťuknutím na výsledok otvoríte konverzáciu priamo pri danej správe.",
        "Slovenský preklad: dokončený a vylepšený: preložené všetky zostávajúce texty vrátane zdieľania polohy naživo. Ďakujeme prekladateľovi."
    ]
};

var messageByLang = {
    "it": "Questa versione introduce la ricerca globale nei messaggi: dal menu del titolo nella schermata principale trovi la nuova voce \"Cerca nei messaggi\", per cercare una parola tra i messaggi di tutte le tue chat e saltare direttamente al messaggio trovato. Completata inoltre la traduzione slovacca.",
    "en": "This version introduces global message search: from the title menu on the home screen you'll find the new \"Search in messages\" entry, to look for a word across the messages of all your chats and jump straight to the matching message. The Slovak translation has also been completed.",
    "de": "Diese Version führt die globale Nachrichtensuche ein: Im Titelmenü des Startbildschirms findest du den neuen Eintrag „In Nachrichten suchen“, um ein Wort in den Nachrichten all deiner Chats zu suchen und direkt zur gefundenen Nachricht zu springen. Außerdem wurde die slowakische Übersetzung vervollständigt.",
    "pl": "Ta wersja wprowadza globalne wyszukiwanie wiadomości: w menu tytułowym na ekranie głównym znajdziesz nową pozycję „Szukaj w wiadomościach”, aby wyszukać słowo w wiadomościach wszystkich czatów i przejść bezpośrednio do znalezionej wiadomości. Ukończono również tłumaczenie słowackie.",
    "ru": "В этой версии появился глобальный поиск по сообщениям: в меню заголовка на главном экране есть новый пункт «Поиск по сообщениям», чтобы найти слово в сообщениях всех ваших чатов и сразу перейти к найденному сообщению. Кроме того, завершён словацкий перевод.",
    "fr": "Cette version introduit la recherche globale dans les messages : dans le menu de titre de l'écran d'accueil, vous trouverez la nouvelle entrée « Rechercher dans les messages », pour chercher un mot dans les messages de toutes vos conversations et sauter directement au message trouvé. La traduction slovaque a également été complétée.",
    "sk": "Táto verzia prináša globálne vyhľadávanie v správach: v ponuke názvu na domovskej obrazovke nájdete novú položku „Hľadať v správach“, ktorá vyhľadá slovo v správach všetkých vašich konverzácií a hneď prejde na nájdenú správu. Okrem toho bol dokončený slovenský preklad."
};

// Restituisce il changelog/messaggio per la lingua data (codice a 2 lettere),
// con fallback a "en". Usati dal WhatsNewDialog.
function changelogFor(lang) {
    return changelogByLang[lang] || changelogByLang["en"];
}

function messageFor(lang) {
    return (lang in messageByLang) ? messageByLang[lang] : messageByLang["en"];
}
