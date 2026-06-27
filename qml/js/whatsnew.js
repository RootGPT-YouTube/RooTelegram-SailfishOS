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

var version = "2.8.7";

var changelogByLang = {
    "it": [
        "Canali e gruppi: i messaggi non letti ora vengono segnati come letti solo man mano che li scorri, non più tutti insieme appena apri la chat. Il contatore dei non letti rispecchia ciò che hai davvero visto.",
        "Installazione più leggera: rimossa una copia duplicata della libreria TDLib, circa 32 MB in meno occupati sul dispositivo."
    ],
    "en": [
        "Channels and groups: unread messages are now marked as read only as you scroll through them, no longer all at once when you open the chat. The unread counter reflects what you actually saw.",
        "Lighter install: removed a duplicate copy of the TDLib library, about 32 MB less used on the device."
    ],
    "de": [
        "Kanäle und Gruppen: ungelesene Nachrichten werden jetzt erst beim Durchscrollen als gelesen markiert, nicht mehr alle auf einmal beim Öffnen des Chats. Der Ungelesen-Zähler spiegelt wider, was du tatsächlich gesehen hast.",
        "Schlankere Installation: eine doppelte Kopie der TDLib-Bibliothek entfernt, rund 32 MB weniger Speicherbelegung auf dem Gerät."
    ],
    "pl": [
        "Kanały i grupy: nieprzeczytane wiadomości są teraz oznaczane jako przeczytane dopiero w miarę ich przewijania, a nie wszystkie naraz po otwarciu czatu. Licznik nieprzeczytanych odzwierciedla to, co faktycznie zobaczyłeś.",
        "Lżejsza instalacja: usunięto zduplikowaną kopię biblioteki TDLib, około 32 MB mniej zajętego miejsca na urządzeniu."
    ],
    "ru": [
        "Каналы и группы: непрочитанные сообщения теперь отмечаются как прочитанные только по мере прокрутки, а не все сразу при открытии чата. Счётчик непрочитанных отражает то, что вы действительно видели.",
        "Более лёгкая установка: удалена дублирующая копия библиотеки TDLib, примерно на 32 МБ меньше занимаемого места на устройстве."
    ],
    "fr": [
        "Canaux et groupes : les messages non lus ne sont désormais marqués comme lus qu'au fur et à mesure que vous les faites défiler, et non plus tous d'un coup à l'ouverture de la discussion. Le compteur de non-lus reflète ce que vous avez réellement vu.",
        "Installation plus légère : suppression d'une copie en double de la bibliothèque TDLib, environ 32 Mo de moins occupés sur l'appareil."
    ],
    "sk": [
        "Kanály a skupiny: neprečítané správy sa teraz označujú ako prečítané až počas ich posúvania, nie všetky naraz pri otvorení konverzácie. Počítadlo neprečítaných odráža to, čo ste skutočne videli.",
        "Ľahšia inštalácia: odstránená duplicitná kópia knižnice TDLib, približne o 32 MB menej zabraného miesta v zariadení."
    ]
};

var messageByLang = {
    "it": "RooTelegram 2.8.7 sistema il conteggio dei messaggi letti in canali e gruppi: prima, aprendo una chat, tutti i post venivano segnati come letti anche senza scorrerli; ora si segnano letti solo i messaggi che scorri davvero. In più l'app occupa circa 32 MB in meno grazie alla rimozione di una libreria duplicata.",
    "en": "RooTelegram 2.8.7 fixes the read-message count in channels and groups: previously, opening a chat marked every post as read even without scrolling; now only the messages you actually scroll through are marked as read. The app also takes about 32 MB less space thanks to removing a duplicated library.",
    "de": "RooTelegram 2.8.7 korrigiert die Zählung gelesener Nachrichten in Kanälen und Gruppen: Bisher wurden beim Öffnen eines Chats alle Beiträge als gelesen markiert, auch ohne Scrollen; jetzt werden nur die Nachrichten als gelesen markiert, die du tatsächlich durchscrollst. Außerdem belegt die App dank Entfernung einer doppelten Bibliothek rund 32 MB weniger.",
    "pl": "RooTelegram 2.8.7 naprawia licznik przeczytanych wiadomości w kanałach i grupach: wcześniej otwarcie czatu oznaczało wszystkie posty jako przeczytane nawet bez przewijania; teraz jako przeczytane oznaczane są tylko wiadomości, które faktycznie przewiniesz. Aplikacja zajmuje też około 32 MB mniej dzięki usunięciu zduplikowanej biblioteki.",
    "ru": "RooTelegram 2.8.7 исправляет счётчик прочитанных сообщений в каналах и группах: раньше при открытии чата все посты отмечались как прочитанные даже без прокрутки; теперь прочитанными отмечаются только те сообщения, которые вы действительно прокручиваете. Приложение также занимает примерно на 32 МБ меньше благодаря удалению дублирующей библиотеки.",
    "fr": "RooTelegram 2.8.7 corrige le comptage des messages lus dans les canaux et les groupes : auparavant, ouvrir une discussion marquait tous les messages comme lus même sans les faire défiler ; désormais, seuls les messages que vous faites réellement défiler sont marqués comme lus. L'application occupe aussi environ 32 Mo de moins grâce à la suppression d'une bibliothèque en double.",
    "sk": "RooTelegram 2.8.7 opravuje počítanie prečítaných správ v kanáloch a skupinách: predtým sa pri otvorení konverzácie všetky príspevky označili ako prečítané aj bez posúvania; teraz sa ako prečítané označia iba správy, ktoré skutočne posuniete. Aplikácia tiež zaberá približne o 32 MB menej vďaka odstráneniu duplicitnej knižnice."
};

// Restituisce il changelog/messaggio per la lingua data (codice a 2 lettere),
// con fallback a "en". Usati dal WhatsNewDialog.
function changelogFor(lang) {
    return changelogByLang[lang] || changelogByLang["en"];
}

function messageFor(lang) {
    return (lang in messageByLang) ? messageByLang[lang] : messageByLang["en"];
}
