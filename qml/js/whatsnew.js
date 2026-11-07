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

var version = "3.7.9";

var changelogByLang = {
    "it": [
        "Notifiche: aprendo un messaggio dalla notifica, ora risulta letto davvero, anche sugli altri dispositivi e nel contatore sulla copertina dell'app.",
        "Richieste di iscrizione: la richiesta di un account eliminato non resta più bloccata. Al posto di «Approva» e «Rifiuta» compare «Rimuovi», che la toglie."
    ],
    "en": [
        "Notifications: opening a message from a notification now really marks it as read, on your other devices too and in the counter on the app cover.",
        "Join requests: a request from a deleted account no longer stays stuck. Instead of «Approve» and «Reject» there is now «Remove», which clears it."
    ],
    "de": [
        "Benachrichtigungen: Wird eine Nachricht aus der Benachrichtigung geöffnet, gilt sie jetzt wirklich als gelesen, auch auf deinen anderen Geräten und im Zähler auf der App-Kachel.",
        "Beitrittsanfragen: Die Anfrage eines gelöschten Kontos bleibt nicht mehr hängen. Statt «Genehmigen» und «Ablehnen» gibt es jetzt «Entfernen», das sie wegräumt."
    ],
    "pl": [
        "Powiadomienia: wiadomość otwarta z powiadomienia jest teraz naprawdę oznaczona jako przeczytana, także na innych urządzeniach i w liczniku na okładce aplikacji.",
        "Prośby o dołączenie: prośba usuniętego konta już się nie zawiesza. Zamiast «Zatwierdź» i «Odrzuć» pojawia się «Usuń», które ją usuwa."
    ],
    "ru": [
        "Уведомления: сообщение, открытое из уведомления, теперь действительно отмечается прочитанным — и на других устройствах, и в счётчике на обложке приложения.",
        "Заявки на вступление: заявка удалённого аккаунта больше не зависает. Вместо «Одобрить» и «Отклонить» теперь есть «Удалить», которое её убирает."
    ],
    "fr": [
        "Notifications : un message ouvert depuis une notification est maintenant vraiment marqué comme lu, aussi sur vos autres appareils et dans le compteur de la vignette de l'application.",
        "Demandes d'adhésion : la demande d'un compte supprimé ne reste plus bloquée. À la place de « Approuver » et « Refuser », un bouton « Supprimer » la retire."
    ],
    "sk": [
        "Upozornenia: správa otvorená z upozornenia je teraz naozaj označená ako prečítaná, aj na tvojich ďalších zariadeniach a v počítadle na obálke aplikácie.",
        "Žiadosti o pripojenie: žiadosť odstráneného účtu už nezostane zaseknutá. Namiesto «Schváliť» a «Odmietnuť» je teraz «Odstrániť», ktoré ju odstráni."
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
