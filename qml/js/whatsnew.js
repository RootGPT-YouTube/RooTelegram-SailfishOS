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

var version = "3.7.1";

var changelogByLang = {
    "it": [
        "Corretto: con le notifiche UnifiedPush attive, l'app aperta da una notifica si chiudeva da sola poco dopo essere passati a un'altra app.",
        "Corretto: a volte, all'avvio dalla notifica, l'app restava ferma in attesa della rete anche con la connessione attiva.",
        "Lettore audio come in Telegram: tasti per passare al brano o al vocale precedente e successivo, passaggio automatico al successivo, anche a schermo spento, e la copertina dell'app mostra cosa suona con i comandi. Rientrando nell'app torni alla chat che sta suonando.",
        "Novità in prova (BETA): notifiche tramite UnifiedPush con l'app Foghorn, al posto del servizio in background. È pensata per i telefoni con poca memoria: RooTelegram si chiude del tutto e Foghorn lo sveglia quando arriva un messaggio. Si attiva in Impostazioni → Comportamento; leggi prima le Istruzioni. Sui telefoni con 6 GB di RAM o più conviene il solito servizio in background.",
        "Corretto: in alcune chat i messaggi a volte si mescolavano fuori ordine dopo aver aperto la scheda Media o ascoltato degli audio."
    ],
    "en": [
        "Fixed: with UnifiedPush notifications on, the app opened from a notification closed by itself shortly after switching to another app.",
        "Fixed: sometimes, when started from a notification, the app stayed stuck waiting for network even with a working connection.",
        "Audio player like in Telegram: buttons to go to the previous and next track or voice message, automatic playback of the next one, even with the screen off, and the app cover shows what is playing with its controls. Coming back to the app takes you to the chat that is playing.",
        "New, in testing (BETA): notifications through UnifiedPush with the Foghorn app, instead of the background service. It is meant for phones with little memory: RooTelegram closes completely and Foghorn wakes it up when a message arrives. Turn it on in Settings → Behavior; read the Instructions first. On phones with 6 GB of RAM or more the usual background service is the better choice.",
        "Fixed: in some chats messages sometimes got mixed up out of order after opening the Media tab or listening to audio."
    ],
    "de": [
        "Behoben: Bei aktiven UnifiedPush-Benachrichtigungen schloss sich die über eine Benachrichtigung geöffnete App kurz nach dem Wechsel zu einer anderen App von selbst.",
        "Behoben: Beim Start über eine Benachrichtigung blieb die App manchmal beim Warten auf das Netzwerk hängen, obwohl die Verbindung funktionierte.",
        "Audioplayer wie in Telegram: Tasten für den vorherigen und nächsten Titel oder die vorherige und nächste Sprachnachricht, automatische Wiedergabe der nächsten, auch bei ausgeschaltetem Bildschirm, und das App-Cover zeigt, was gerade läuft, mit den Bedienelementen. Wenn du zur App zurückkehrst, landest du im Chat, der gerade abgespielt wird.",
        "Neu, im Test (BETA): Benachrichtigungen über UnifiedPush mit der App Foghorn, statt des Hintergrunddienstes. Gedacht für Telefone mit wenig Speicher: RooTelegram beendet sich vollständig und Foghorn weckt es, wenn eine Nachricht eintrifft. Einschalten unter Einstellungen → Verhalten; lies zuerst die Anleitung. Auf Telefonen mit 6 GB RAM oder mehr ist der gewohnte Hintergrunddienst die bessere Wahl.",
        "Behoben: In manchen Chats gerieten Nachrichten manchmal durcheinander, nachdem der Reiter Medien geöffnet oder Audio angehört wurde."
    ],
    "pl": [
        "Naprawiono: przy włączonych powiadomieniach UnifiedPush aplikacja otwarta z powiadomienia zamykała się sama wkrótce po przejściu do innej aplikacji.",
        "Naprawiono: czasem po uruchomieniu z powiadomienia aplikacja zatrzymywała się na oczekiwaniu na sieć, mimo działającego połączenia.",
        "Odtwarzacz audio jak w Telegramie: przyciski do poprzedniego i następnego utworu lub wiadomości głosowej, automatyczne odtwarzanie następnej, także przy wyłączonym ekranie, a okładka aplikacji pokazuje, co gra, wraz z przyciskami. Po powrocie do aplikacji trafiasz do czatu, który gra.",
        "Nowość w fazie testów (BETA): powiadomienia przez UnifiedPush z aplikacją Foghorn zamiast usługi w tle. Przeznaczone dla telefonów z małą ilością pamięci: RooTelegram zamyka się całkowicie, a Foghorn budzi go, gdy przychodzi wiadomość. Włącz w Ustawienia → Zachowanie; najpierw przeczytaj Instrukcję. Na telefonach z 6 GB RAM lub więcej lepszym wyborem jest zwykła usługa w tle.",
        "Naprawiono: w niektórych czatach wiadomości czasem mieszały się w złej kolejności po otwarciu zakładki Media lub odsłuchaniu audio."
    ],
    "ru": [
        "Исправлено: при включённых уведомлениях UnifiedPush приложение, открытое из уведомления, само закрывалось вскоре после перехода в другое приложение.",
        "Исправлено: иногда при запуске из уведомления приложение зависало в ожидании сети, хотя соединение работало.",
        "Аудиоплеер как в Telegram: кнопки для перехода к предыдущему и следующему треку или голосовому сообщению, автоматическое воспроизведение следующего, даже при выключенном экране, а обложка приложения показывает, что играет, вместе с кнопками управления. Вернувшись в приложение, вы попадёте в чат, который сейчас играет.",
        "Новое, в тестировании (БЕТА): уведомления через UnifiedPush с приложением Foghorn вместо фоновой службы. Предназначено для телефонов с небольшим объёмом памяти: RooTelegram полностью закрывается, а Foghorn будит его, когда приходит сообщение. Включается в Настройки → Поведение; сначала прочитайте Инструкцию. На телефонах с 6 ГБ ОЗУ и больше лучше обычная фоновая служба.",
        "Исправлено: в некоторых чатах сообщения иногда перемешивались не по порядку после открытия вкладки Медиа или прослушивания аудио."
    ],
    "fr": [
        "Corrigé : avec les notifications UnifiedPush activées, l'application ouverte depuis une notification se fermait toute seule peu après le passage à une autre application.",
        "Corrigé : parfois, au démarrage depuis une notification, l'application restait bloquée en attente du réseau alors que la connexion fonctionnait.",
        "Lecteur audio comme dans Telegram : des boutons pour passer au morceau ou au message vocal précédent et suivant, la lecture automatique du suivant, même écran éteint, et la vignette de l'application montre ce qui joue avec ses commandes. En revenant dans l'application, vous retrouvez la discussion en cours de lecture.",
        "Nouveau, en test (BÊTA) : des notifications via UnifiedPush avec l'application Foghorn, à la place du service d'arrière-plan. C'est pensé pour les téléphones avec peu de mémoire : RooTelegram se ferme complètement et Foghorn le réveille quand un message arrive. À activer dans Paramètres → Comportement ; lisez d'abord les Instructions. Sur les téléphones avec 6 Go de RAM ou plus, le service d'arrière-plan habituel reste le meilleur choix.",
        "Corrigé : dans certaines discussions, les messages se mélangeaient parfois dans le désordre après l'ouverture de l'onglet Médias ou l'écoute d'audio."
    ],
    "sk": [
        "Opravené: pri zapnutých upozorneniach UnifiedPush sa aplikácia otvorená z upozornenia sama zavrela krátko po prepnutí do inej aplikácie.",
        "Opravené: pri spustení z upozornenia aplikácia niekedy zostala čakať na sieť, hoci pripojenie fungovalo.",
        "Prehrávač zvuku ako v Telegrame: tlačidlá na predchádzajúcu a nasledujúcu skladbu či hlasovú správu, automatické prehratie nasledujúcej, aj pri vypnutej obrazovke, a obálka aplikácie ukazuje, čo hrá, aj s ovládaním. Po návrate do aplikácie sa dostanete do četu, ktorý práve hrá.",
        "Novinka v testovaní (BETA): upozornenia cez UnifiedPush s aplikáciou Foghorn namiesto služby na pozadí. Je určená pre telefóny s malou pamäťou: RooTelegram sa úplne zavrie a Foghorn ho zobudí, keď príde správa. Zapína sa v Nastavenia → Správanie; najprv si prečítajte Návod. Na telefónoch so 6 GB RAM alebo viac je lepšou voľbou bežná služba na pozadí.",
        "Opravené: v niektorých četoch sa správy niekedy pomiešali v nesprávnom poradí po otvorení karty Médiá alebo vypočutí zvuku."
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
