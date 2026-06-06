.pragma library

// Contenuto del popup "Novità" mostrato una-tantum dopo ogni aggiornamento.
// >>> AGGIORNARE A OGNI RELEASE <<< (fa parte della pipeline /rilascia).
//
// - version:   deve combaciare con RT_APP_VERSION nel .pro.
// - changelog: array di stringhe, mostrate come elenco puntato.
// - message:   messaggio libero opzionale dello sviluppatore; "" = nessuno.
//
// Testo libero (non passa da qsTr: i .pragma library non hanno contesto di
// traduzione). Scrivilo nella lingua che preferisci.

var version = "2.3";

var changelog = [
    "I link di invito ai gruppi (t.me/+…, tg://) ora si aprono in RooTelegram dal browser di Sailfish.",
    "Cancellazione messaggi: scelta «per tutti» o «solo per me», dove Telegram lo consente.",
    "Tema Silica: nomi delle chat in grassetto e menù long-press nativo.",
    "Popup “Novità” una-tantum dopo ogni aggiornamento (questo!)."
];

var message = "Se i link di invito non si aprono in RooTelegram, riavvia una volta il dispositivo. Probabilmente è un problema di memoria cache.";
