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

var version = "3.4";

var changelogByLang = {
    "it": [
        "Risolto il blocco all'apertura da una notifica. Se RooTelegram non era ancora avviato, toccare una sua notifica apriva la chat e poi l'app si bloccava, fino a chiudersi da sola. Ora la chat si apre e resta utilizzabile.",
        "Nuova icona: RooTelegram entra nella nuova famiglia RootApps, con lo stesso stile “acciaio” di tutte le app sorelle."
    ],
    "en": [
        "Fixed the freeze when opening from a notification. If RooTelegram was not running yet, tapping one of its notifications opened the chat and then the app froze, until it closed by itself. Now the chat opens and stays usable.",
        "New icon: RooTelegram joins the new RootApps family, with the same “steel” style as all its sister apps."
    ],
    "de": [
        "Einfrieren beim Öffnen über eine Benachrichtigung behoben. Lief RooTelegram noch nicht, öffnete ein Tippen auf eine seiner Benachrichtigungen den Chat, dann fror die App ein, bis sie sich von selbst schloss. Jetzt öffnet sich der Chat und bleibt bedienbar.",
        "Neues Symbol: RooTelegram gehört jetzt zur neuen RootApps-Familie, im gleichen „Stahl“-Stil wie alle Schwester-Apps."
    ],
    "pl": [
        "Naprawiono zawieszanie się po otwarciu z powiadomienia. Jeśli RooTelegram nie był jeszcze uruchomiony, dotknięcie jego powiadomienia otwierało czat, a potem aplikacja się zawieszała, aż sama się zamknęła. Teraz czat się otwiera i można z niego normalnie korzystać.",
        "Nowa ikona: RooTelegram dołącza do nowej rodziny RootApps, w tym samym „stalowym” stylu co wszystkie siostrzane aplikacje."
    ],
    "ru": [
        "Исправлено зависание при открытии из уведомления. Если RooTelegram ещё не был запущен, нажатие на его уведомление открывало чат, а затем приложение зависало, пока не закрывалось само. Теперь чат открывается и остаётся рабочим.",
        "Новый значок: RooTelegram входит в новое семейство RootApps, в том же «стальном» стиле, что и все родственные приложения."
    ],
    "fr": [
        "Correction du blocage à l'ouverture depuis une notification. Si RooTelegram n'était pas encore lancé, toucher une de ses notifications ouvrait la discussion, puis l'application se bloquait, jusqu'à se fermer d'elle-même. Désormais la discussion s'ouvre et reste utilisable.",
        "Nouvelle icône : RooTelegram rejoint la nouvelle famille RootApps, avec le même style « acier » que toutes ses applications sœurs."
    ],
    "sk": [
        "Opravené zamrznutie pri otvorení z upozornenia. Ak RooTelegram ešte nebežal, ťuknutie na jeho upozornenie otvorilo chat a potom aplikácia zamrzla, až kým sa sama nezavrela. Teraz sa chat otvorí a dá sa normálne používať.",
        "Nová ikona: RooTelegram patrí do novej rodiny RootApps, v rovnakom „oceľovom“ štýle ako všetky sesterské aplikácie."
    ]
};

// Vuoto: il messaggio del popup sta DOPO l'elenco, e la cosa da leggere per prima
// (il tema Barbara) e' gia' la prima voce dell'elenco (richiesta dell'utente).
var messageByLang = {
    "it": "",
    "en": "",
};

// Restituisce il changelog/messaggio per la lingua data (codice a 2 lettere),
// con fallback a "en". Usati dal WhatsNewDialog.
function changelogFor(lang) {
    return changelogByLang[lang] || changelogByLang["en"];
}

function messageFor(lang) {
    return (lang in messageByLang) ? messageByLang[lang] : messageByLang["en"];
}
