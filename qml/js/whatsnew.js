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

var version = "2.6";

var changelog = [
    "Accesso tramite QR code: oltre al numero + SMS, ora puoi accedere scansionando un codice QR da un dispositivo già connesso a Telegram (Impostazioni → Dispositivi → Collega dispositivo). Utile soprattutto su un secondo telefono.",
    "Nuova pagina \"Permessi dell'app\" in Impostazioni → Privacy: attiva o disattiva singolarmente l'accesso a Posizione, Fotocamera, Microfono, Contatti, Immagini, Video e File. È un controllo interno all'app, diviso per livello di rischio.",
    "Nuova opzione \"Resta nella chat alla chiusura dell'app\" in Impostazioni → Comportamento: riaprendo l'app ritrovi la chat aperta invece di tornare alla home.",
    "Traduzione completa in slovacco (Slovenčina), grazie a okruhliak. Lingue ora supportate: IT, EN, DE, PL, RU, FR, SK.",
    "Consumo RAM: la memoria liberata chiudendo le chat e mettendo l'app in background viene ora restituita al sistema, invece di restare occupata.",
    "Tema Silica: la scritta R∞Telegram nella home è di una misura più piccola.",
    "Correzione: l'allegato Posizione ora mostra subito \"ottengo posizione…\" mentre cerca il GPS (prima, al chiuso, non dava alcun riscontro).",
    "Correzione: layout della pagina di creazione sondaggi (il pulsante non si sovrappone più alla domanda).",
    "Correzione: i permessi di gruppo \"Modifica info\" e \"Fissa messaggi\" mostrano un messaggio chiaro quando Telegram non li consente per tutti i membri."
];

var message = "Due grandi novità: l'accesso tramite QR code (affianca il classico numero + SMS, comodo su un secondo dispositivo) e una nuova pagina \"Permessi dell'app\" in Impostazioni → Privacy, dove puoi negare a RooTelegram l'accesso a fotocamera, microfono, posizione, contatti e file, voce per voce. Inoltre la RAM rientra meglio quando chiudi le chat o metti l'app in background.";
