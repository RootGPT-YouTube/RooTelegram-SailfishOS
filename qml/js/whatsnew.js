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

var version = "3.2";

var changelogByLang = {
    "it": [
        "Suoneria delle chiamate Telegram di nuovo a volume pieno. Dalla seconda chiamata in arrivo in poi la suoneria usciva dalla capsula dell'orecchio invece che dall'altoparlante, ed era bassissima. Ora esce dall'altoparlante, e l'audio passa alla capsula solo quando rispondi.",
        "Grazie a godogabor, che ha segnalato il problema e ha insistito anche quando sembrava non riproducibile: aveva ragione!",
        "Risolto un raro schermo nero. Ogni tanto, riaccendendo lo schermo, il telefono diventava nero per qualche secondo, tornava alla schermata iniziale e RooTelegram non rispondeva più. Succedeva quando l'app, in background, si riavviava da sola per liberare memoria proprio in quel momento. Ora lo fa solo a schermo spento, e chiudendo prima la sua finestra."
    ],
    "en": [
        "Telegram call ringtone back at full volume. From the second incoming call on, the ringtone came out of the earpiece instead of the loudspeaker, and was very quiet. Now it rings from the loudspeaker, and the sound moves to the earpiece only when you answer.",
        "Thanks to godogabor, who reported the problem and kept insisting even when it seemed impossible to reproduce: you were right!",
        "Fixed a rare black screen. Now and then, when turning the screen on, the phone went black for a few seconds, went back to the home screen and RooTelegram stopped responding. It happened when the app, in the background, restarted itself to free memory at exactly that moment. Now it only does so with the screen off, and closes its window first."
    ],
    "de": [
        "Klingelton von Telegram-Anrufen wieder in voller Lautstärke. Ab dem zweiten eingehenden Anruf kam der Klingelton aus der Hörmuschel statt aus dem Lautsprecher und war sehr leise. Jetzt klingelt es über den Lautsprecher, und der Ton wechselt erst beim Annehmen zur Hörmuschel.",
        "Danke an godogabor, der das Problem gemeldet und darauf bestanden hat, auch als es nicht reproduzierbar schien: du hattest recht!",
        "Seltener schwarzer Bildschirm behoben. Ab und zu wurde das Telefon beim Einschalten des Bildschirms für ein paar Sekunden schwarz, kehrte zum Startbildschirm zurück und RooTelegram reagierte nicht mehr. Das passierte, wenn sich die App im Hintergrund genau in diesem Moment selbst neu startete, um Speicher freizugeben. Jetzt tut sie das nur bei ausgeschaltetem Bildschirm und schließt vorher ihr Fenster."
    ],
    "pl": [
        "Dzwonek połączeń Telegram znów na pełnej głośności. Od drugiego połączenia przychodzącego dzwonek wychodził ze słuchawki zamiast z głośnika i był bardzo cichy. Teraz dzwoni z głośnika, a dźwięk przechodzi na słuchawkę dopiero po odebraniu.",
        "Dziękujemy godogabor, który zgłosił problem i nie odpuścił, nawet gdy wydawał się niemożliwy do odtworzenia: miałeś rację!",
        "Naprawiono rzadki czarny ekran. Czasami po włączeniu ekranu telefon na kilka sekund robił się czarny, wracał do ekranu głównego, a RooTelegram przestawał odpowiadać. Działo się tak, gdy aplikacja w tle uruchamiała się ponownie, aby zwolnić pamięć, akurat w tym momencie. Teraz robi to tylko przy wyłączonym ekranie i najpierw zamyka swoje okno."
    ],
    "ru": [
        "Рингтон звонков Telegram снова на полной громкости. Начиная со второго входящего звонка рингтон звучал из разговорного динамика вместо громкого и был очень тихим. Теперь он звучит из громкого динамика, а звук переходит в разговорный динамик только когда вы отвечаете.",
        "Спасибо godogabor, который сообщил о проблеме и настаивал, даже когда её не удавалось воспроизвести: ты был прав!",
        "Исправлен редкий чёрный экран. Иногда при включении экрана телефон на несколько секунд становился чёрным, возвращался на главный экран, а RooTelegram переставал отвечать. Это происходило, когда приложение в фоне перезапускалось, чтобы освободить память, как раз в этот момент. Теперь оно делает это только при выключенном экране и сначала закрывает своё окно."
    ],
    "fr": [
        "Sonnerie des appels Telegram de nouveau à plein volume. À partir du deuxième appel entrant, la sonnerie sortait de l'écouteur au lieu du haut-parleur, et elle était très faible. Désormais elle sonne sur le haut-parleur, et le son passe à l'écouteur seulement quand vous répondez.",
        "Merci à godogabor, qui a signalé le problème et a insisté même quand il semblait impossible à reproduire : tu avais raison !",
        "Correction d'un rare écran noir. De temps en temps, en rallumant l'écran, le téléphone devenait noir pendant quelques secondes, revenait à l'écran d'accueil et RooTelegram ne répondait plus. Cela arrivait quand l'application, en arrière-plan, redémarrait d'elle-même pour libérer de la mémoire précisément à ce moment. Désormais elle ne le fait qu'écran éteint, et ferme d'abord sa fenêtre."
    ],
    "sk": [
        "Zvonenie hovorov Telegram je opäť na plnú hlasitosť. Od druhého prichádzajúceho hovoru zvonenie vychádzalo zo slúchadla namiesto reproduktora a bolo veľmi tiché. Teraz zvoní z reproduktora a zvuk prejde do slúchadla až keď hovor prijmete.",
        "Ďakujeme godogabor, ktorý problém nahlásil a trval na ňom, aj keď sa zdalo, že sa nedá zopakovať: mal si pravdu!",
        "Opravená zriedkavá čierna obrazovka. Občas po zapnutí obrazovky telefón na pár sekúnd sčernel, vrátil sa na úvodnú obrazovku a RooTelegram prestal reagovať. Stávalo sa to, keď sa aplikácia na pozadí práve v tej chvíli sama reštartovala, aby uvoľnila pamäť. Teraz to robí iba pri vypnutej obrazovke a najprv zavrie svoje okno."
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
