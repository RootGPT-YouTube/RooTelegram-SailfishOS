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

var version = "2.4";

var changelog = [
    "Ripristinata la voce «Modifica» sui propri messaggi: era sparita per molti utenti (anche nei gruppi dove non sei amministratore).",
    "Nuova voce «Info messaggio» nel menù del messaggio: data completa, mittente, inoltro, visualizzazioni e altri dettagli. Rimosso il vecchio tap sulla data/ora.",
    "Risolti i messaggi che a volte ricomparivano come «bozze» dopo una modifica, soprattutto nei gruppi.",
    "Storie: dalla lista di chi ha messo «Mi piace»/visualizzato ora puoi aprire il profilo dell’utente.",
    "Nuova sezione «Chat archiviate» (Impostazioni → Memoria): archivia o disarchivia una chat con la pressione prolungata.",
    "Tema Silica: titoli e testi (come l’intestazione delle info chat/gruppo/canale) seguono ora i colori dell’ambiance scelta, niente più arancione fisso.",
    "Tema Silica: titolo «RooTelegram» in alto in grassetto corsivo e più grande; nomi delle chat leggermente più compatti.",
    "Pulsante Play su GIF e video più visibile: ora si adatta ai temi chiari e scuri.",
    "Link e nomi utente colorati in base al tema: rossi sui temi scuri, blu sui temi chiari.",
    "Storie: toccando la notifica di una storia si apre direttamente la pagina Storie.",
    "Storie: un pallino verde accanto a «Storie» segnala quando ci sono storie non ancora viste."
];

var message = "Novità: tocca la notifica di una storia per aprire subito le Storie, e quando ci sono storie non viste compare un pallino verde accanto a «Storie» nel menu. Trovi inoltre le Chat archiviate in Impostazioni → Memoria: per archiviare o disarchiviare una chat tienila premuta e scegli «Archivia»/«Disarchivia».";
