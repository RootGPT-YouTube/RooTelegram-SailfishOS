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

var version = "2.8.13";

var changelogByLang = {
    "it": [
        "Notifiche fantasma: risolto il caso rimasto in alcuni canali e gruppi, in cui la notifica restava visibile anche dopo aver letto i messaggi e riappariva dopo un riavvio. Ora, una volta letti, questi avvisi si chiudono da soli poco dopo."
    ],
    "en": [
        "Ghost notifications: fixed the remaining case in some channels and groups where the notification stayed even after you had read the messages, and came back after a restart. Once read, these alerts now clear on their own shortly after."
    ],
    "de": [
        "Geister-Benachrichtigungen: der verbleibende Fall in manchen Kanälen und Gruppen behoben, bei dem die Benachrichtigung auch nach dem Lesen der Nachrichten bestehen blieb und nach einem Neustart wiederkam. Nach dem Lesen verschwinden diese Hinweise nun kurz darauf von selbst."
    ],
    "pl": [
        "Duchy powiadomień: naprawiono pozostały przypadek w niektórych kanałach i grupach, gdy powiadomienie pozostawało nawet po przeczytaniu wiadomości i wracało po ponownym uruchomieniu. Po przeczytaniu te powiadomienia teraz same wkrótce znikają."
    ],
    "ru": [
        "Призрачные уведомления: устранён оставшийся случай в некоторых каналах и группах, когда уведомление оставалось даже после прочтения сообщений и снова появлялось после перезапуска. Теперь после прочтения эти уведомления вскоре исчезают сами."
    ],
    "fr": [
        "Notifications fantômes : correction du cas restant, dans certains canaux et groupes, où la notification demeurait même après avoir lu les messages et réapparaissait après un redémarrage. Une fois lus, ces avis disparaissent maintenant d'eux-mêmes peu après."
    ],
    "sk": [
        "Duchovné oznámenia: opravený zostávajúci prípad v niektorých kanáloch a skupinách, keď oznámenie zostávalo aj po prečítaní správ a po reštarte sa znova objavilo. Po prečítaní tieto oznámenia teraz čoskoro samy zmiznú."
    ]
};

var messageByLang = {
    "it": "Altre notifiche fantasma risolte: i canali e i gruppi in cui l'avviso restava anche dopo la lettura ora si chiudono correttamente.",
    "en": "More ghost notifications fixed: channels and groups where the alert stayed even after reading now clear properly.",
    "de": "Weitere Geister-Benachrichtigungen behoben: Kanäle und Gruppen, in denen der Hinweis auch nach dem Lesen blieb, werden jetzt korrekt geschlossen.",
    "pl": "Naprawiono kolejne duchy powiadomień: kanały i grupy, w których powiadomienie pozostawało nawet po przeczytaniu, teraz zamykają się poprawnie.",
    "ru": "Исправлены ещё призрачные уведомления: каналы и группы, где уведомление оставалось даже после прочтения, теперь закрываются правильно.",
    "fr": "D'autres notifications fantômes corrigées : les canaux et groupes où l'avis restait même après lecture se ferment désormais correctement.",
    "sk": "Opravené ďalšie duchovné oznámenia: kanály a skupiny, kde oznámenie zostávalo aj po prečítaní, sa teraz správne zatvárajú."
};

// Restituisce il changelog/messaggio per la lingua data (codice a 2 lettere),
// con fallback a "en". Usati dal WhatsNewDialog.
function changelogFor(lang) {
    return changelogByLang[lang] || changelogByLang["en"];
}

function messageFor(lang) {
    return (lang in messageByLang) ? messageByLang[lang] : messageByLang["en"];
}
