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

var version = "3.7.2";

var changelogByLang = {
    "it": [
        "Corretto: alcune storie video, per esempio quelle di «Suggerimenti di Telegram», restavano nere. Ora si vedono.",
        "Corretto: con le notifiche UnifiedPush (Foghorn), aprendo l'app da una notifica a volte restava la scritta «In attesa della rete» anche con la connessione attiva, soprattutto dopo aver riacceso il telefono.",
        "Corretto: dopo essere saltati a un messaggio vecchio, in alcune chat dei messaggi vecchi potevano finire in fondo, sotto quelli di oggi."
    ],
    "en": [
        "Fixed: some video stories, for example the ones from «Telegram Tips», stayed black. Now they play.",
        "Fixed: with UnifiedPush notifications (Foghorn), opening the app from a notification sometimes kept showing «Waiting for network» even with a working connection, especially after restarting the phone.",
        "Fixed: after jumping to an old message, in some chats old messages could end up at the bottom, below today's ones."
    ],
    "de": [
        "Behoben: Manche Video-Storys, zum Beispiel die von «Telegram-Tipps», blieben schwarz. Jetzt werden sie abgespielt.",
        "Behoben: Mit UnifiedPush-Benachrichtigungen (Foghorn) blieb beim Öffnen der App über eine Benachrichtigung manchmal «Warte auf Netzwerk» stehen, obwohl die Verbindung funktionierte, vor allem nach einem Neustart des Telefons.",
        "Behoben: Nach dem Sprung zu einer alten Nachricht konnten in manchen Chats alte Nachrichten ganz unten landen, unter den heutigen."
    ],
    "pl": [
        "Naprawiono: niektóre relacje wideo, na przykład te z «Porad Telegrama», pozostawały czarne. Teraz się odtwarzają.",
        "Naprawiono: przy powiadomieniach UnifiedPush (Foghorn) po otwarciu aplikacji z powiadomienia czasem zostawał napis «Oczekiwanie na sieć», mimo działającego połączenia, zwłaszcza po ponownym uruchomieniu telefonu.",
        "Naprawiono: po przejściu do starej wiadomości w niektórych czatach stare wiadomości mogły trafić na sam dół, pod dzisiejsze."
    ],
    "ru": [
        "Исправлено: некоторые видеоистории, например из «Советов Telegram», оставались чёрными. Теперь они воспроизводятся.",
        "Исправлено: с уведомлениями UnifiedPush (Foghorn) при открытии приложения из уведомления иногда оставалась надпись «Ожидание сети», хотя соединение работало, особенно после перезагрузки телефона.",
        "Исправлено: после перехода к старому сообщению в некоторых чатах старые сообщения могли оказаться в самом низу, под сегодняшними."
    ],
    "fr": [
        "Corrigé : certaines stories vidéo, par exemple celles des « Astuces Telegram », restaient noires. Elles se lisent maintenant.",
        "Corrigé : avec les notifications UnifiedPush (Foghorn), en ouvrant l'application depuis une notification, « En attente du réseau » restait parfois affiché alors que la connexion fonctionnait, surtout après un redémarrage du téléphone.",
        "Corrigé : après un saut vers un ancien message, dans certaines discussions, d'anciens messages pouvaient se retrouver tout en bas, sous ceux du jour."
    ],
    "sk": [
        "Opravené: niektoré video príbehy, napríklad tie z «Tipov Telegramu», zostávali čierne. Teraz sa prehrajú.",
        "Opravené: pri upozorneniach UnifiedPush (Foghorn) po otvorení aplikácie z upozornenia niekedy zostal nápis «Čaká sa na sieť», hoci pripojenie fungovalo, najmä po reštarte telefónu.",
        "Opravené: po skoku na starú správu sa v niektorých četoch mohli staré správy dostať úplne dole, pod dnešné."
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
