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

var version = "3.7.8";

var changelogByLang = {
    "it": [
        "Avvio: su alcuni telefoni, come il Jolla Phone, toccando l'icona l'app non si apriva, oppure si apriva dopo quasi un minuto. Ora dovrebbe aprirsi subito.",
        "Articoli: i pulsanti scritti con Telegram Desktop su una riga propria ora appaiono come veri pulsanti, non più come semplici link.",
        "Richieste di iscrizione: se una persona è iscritta a troppi canali e gruppi, ora lo spiega un messaggio chiaro invece di un codice d'errore."
    ],
    "en": [
        "Startup: on some phones, such as the Jolla Phone, tapping the icon did not open the app, or opened it only after almost a minute. It should now open right away.",
        "Articles: buttons written with Telegram Desktop on a line of their own now appear as real buttons instead of plain links.",
        "Join requests: if someone has joined too many channels and groups, a clear message now explains it instead of an error code."
    ],
    "de": [
        "Start: Auf manchen Telefonen, etwa dem Jolla Phone, öffnete ein Tipp auf das Symbol die App nicht oder erst nach fast einer Minute. Jetzt sollte sie sofort aufgehen.",
        "Artikel: Schaltflächen, die mit Telegram Desktop in einer eigenen Zeile geschrieben wurden, erscheinen jetzt als echte Schaltflächen statt als einfache Links.",
        "Beitrittsanfragen: Ist jemand Mitglied zu vieler Kanäle und Gruppen, erklärt das jetzt eine verständliche Meldung statt eines Fehlercodes."
    ],
    "pl": [
        "Uruchamianie: na niektórych telefonach, na przykład Jolla Phone, dotknięcie ikony nie otwierało aplikacji albo otwierało ją dopiero po prawie minucie. Teraz powinna otwierać się od razu.",
        "Artykuły: przyciski napisane w Telegram Desktop w osobnym wierszu są teraz prawdziwymi przyciskami, a nie zwykłymi linkami.",
        "Prośby o dołączenie: jeśli ktoś należy do zbyt wielu kanałów i grup, wyjaśnia to teraz zrozumiały komunikat zamiast kodu błędu."
    ],
    "ru": [
        "Запуск: на некоторых телефонах, например Jolla Phone, нажатие на значок не открывало приложение или открывало его почти через минуту. Теперь оно должно открываться сразу.",
        "Статьи: кнопки, написанные в Telegram Desktop на отдельной строке, теперь отображаются как настоящие кнопки, а не как обычные ссылки.",
        "Заявки на вступление: если человек состоит в слишком большом количестве каналов и групп, теперь это объясняет понятное сообщение, а не код ошибки."
    ],
    "fr": [
        "Démarrage : sur certains téléphones, comme le Jolla Phone, toucher l'icône n'ouvrait pas l'application, ou seulement après presque une minute. Elle devrait maintenant s'ouvrir tout de suite.",
        "Articles : les boutons écrits avec Telegram Desktop sur leur propre ligne apparaissent maintenant comme de vrais boutons, et non plus comme de simples liens.",
        "Demandes d'adhésion : si une personne a rejoint trop de canaux et de groupes, un message clair l'explique désormais à la place d'un code d'erreur."
    ],
    "sk": [
        "Spustenie: na niektorých telefónoch, napríklad Jolla Phone, ťuknutie na ikonu aplikáciu neotvorilo alebo ju otvorilo až takmer po minúte. Teraz by sa mala otvoriť hneď.",
        "Články: tlačidlá napísané v Telegram Desktop na samostatnom riadku sa teraz zobrazujú ako skutočné tlačidlá, nie ako obyčajné odkazy.",
        "Žiadosti o pripojenie: ak je niekto členom príliš mnohých kanálov a skupín, teraz to vysvetlí zrozumiteľná správa namiesto chybového kódu."
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
