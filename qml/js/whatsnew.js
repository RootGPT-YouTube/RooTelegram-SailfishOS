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

var version = "2.5";

var changelog = [
    "Traduzioni complete in polacco (Polski), russo (Русский) e francese (Français). Lingue ora supportate: IT, EN, DE, PL, RU, FR.",
    "Tema Silica: nuovo brand R∞Telegram, menu del titolo allineato a destra in stile ContextMenu nativo, e nuovo indicatore di connessione nella home — icona antenna + pallino tri-stato (verde = connesso, solo pallino senza descrizione; ambra lampeggiante = connessione in corso/instabile; rosso = nessuna rete). Per gli stati ambra e rosso la descrizione compare accanto al pallino. Icona e testi seguono il colore dell'ambiance.",
    "Tap-to-copy sul testo mono: toccando un blocco mono lo si copia negli appunti, come su Telegram.",
    "Consumo RAM: impostato il parametro TDLib message_unload_delay (60 s) — i messaggi delle chat chiuse vengono scaricati dalla memoria e ricaricati dal database su disco alla riapertura.",
    "Fix bozze fantasma: le ChatPage non in primo piano non salvano più la propria bozza alla chiusura/swipe-close dell'app (guard su onActiveChanged e onDestruction), evitando bozze che comparivano in una chat diversa.",
    "Soppresso il messaggio d'errore \"Need administrator rights in the channel chat\" che a volte compariva all'avvio per azioni in background su canali dove non si è amministratori."
];

var message = "La RAM che cresceva di continuo durante l'uso (fino a superare 1 GB) era causata da TDLib: teneva in memoria i messaggi di tutte le chat aperte nella sessione, senza liberarli mai. Da questa versione viene impostato message_unload_delay — 60 secondi dopo aver chiuso una chat, i suoi messaggi vengono scaricati dalla RAM (e ricaricati al volo dal database su disco se la riapri). Così il consumo non sale più senza fermarsi.";
