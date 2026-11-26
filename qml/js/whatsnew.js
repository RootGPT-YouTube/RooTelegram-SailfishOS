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

var version = "4.0";

var changelogByLang = {
    "it": [
        "Nuovo tema Classic: l'aspetto di una classica app di messaggistica, con lista piatta, avatar tondi, cartelle come schede e fumetti compatti. Si sceglie da Impostazioni → Aspetto.",
        "Sfondi delle chat (tema Classic): RooTelegram mostra lo sfondo del tuo account Telegram, generale o della singola chat, e puoi cambiarlo da qui: lo ritrovi anche sugli altri dispositivi. Senza sfondo impostato compare un nuovo motivo disegnato per RooTelegram.",
        "Album di foto più belli in tutti i temi: le immagini sono composte a mosaico, senza spazi vuoti fra l'una e l'altra.",
        "Il pulsante di traduzione nel campo di scrittura ora funziona anche se stai ancora scrivendo l'ultima parola.",
        "Se la schermata principale del telefono si riavvia, RooTelegram riparte da solo in background e le notifiche continuano ad arrivare."
    ],
    "en": [
        "New Classic theme: the look of a classic messaging app, with a flat chat list, round avatars, folders as tabs and compact bubbles. Choose it in Settings → Appearance.",
        "Chat backgrounds (Classic theme): RooTelegram shows the background of your Telegram account, for all chats or for a single chat, and you can change it here: you will find it on your other devices too. With no background set, a new pattern drawn for RooTelegram appears.",
        "Nicer photo albums in every theme: pictures are arranged as a mosaic, with no empty gaps between them.",
        "The translate button in the message field now works even while you are still typing the last word.",
        "If the phone's home screen restarts, RooTelegram starts again by itself in the background and notifications keep arriving."
    ],
    "de": [
        "Neues Classic-Thema: der Look einer klassischen Messenger-App, mit flacher Chatliste, runden Avataren, Ordnern als Tabs und kompakten Blasen. Auswahl unter Einstellungen → Erscheinungsbild.",
        "Chat-Hintergründe (Classic-Thema): RooTelegram zeigt den Hintergrund deines Telegram-Kontos, für alle Chats oder für einen einzelnen Chat, und du kannst ihn hier ändern: Du findest ihn auch auf deinen anderen Geräten. Ohne festgelegten Hintergrund erscheint ein neues, für RooTelegram gezeichnetes Muster.",
        "Schönere Fotoalben in allen Themen: Die Bilder werden als Mosaik angeordnet, ohne leere Lücken dazwischen.",
        "Die Übersetzen-Taste im Eingabefeld funktioniert jetzt auch, während du das letzte Wort noch tippst.",
        "Wenn der Startbildschirm des Telefons neu startet, startet RooTelegram von selbst im Hintergrund neu und Benachrichtigungen kommen weiterhin an."
    ],
    "pl": [
        "Nowy motyw Classic: wygląd klasycznego komunikatora, z płaską listą czatów, okrągłymi awatarami, folderami jako kartami i zwartymi dymkami. Wybierzesz go w Ustawienia → Wygląd.",
        "Tła czatów (motyw Classic): RooTelegram pokazuje tło twojego konta Telegram, dla wszystkich czatów lub dla jednego czatu, i możesz je tu zmienić: znajdziesz je też na innych urządzeniach. Bez ustawionego tła pojawia się nowy wzór narysowany dla RooTelegram.",
        "Ładniejsze albumy zdjęć we wszystkich motywach: obrazy są ułożone w mozaikę, bez pustych odstępów między nimi.",
        "Przycisk tłumaczenia w polu wpisywania działa teraz także wtedy, gdy jeszcze piszesz ostatnie słowo.",
        "Jeśli ekran główny telefonu uruchomi się ponownie, RooTelegram sam uruchomi się w tle i powiadomienia nadal będą docierać."
    ],
    "ru": [
        "Новая тема Classic: вид классического мессенджера — плоский список чатов, круглые аватары, папки вкладками и компактные пузыри. Выбирается в Настройки → Внешний вид.",
        "Фоны чатов (тема Classic): RooTelegram показывает фон вашего аккаунта Telegram — общий или отдельного чата, и его можно изменить прямо здесь: он появится и на других ваших устройствах. Если фон не задан, показывается новый узор, нарисованный для RooTelegram.",
        "Красивее фотоальбомы во всех темах: изображения складываются мозаикой, без пустых промежутков.",
        "Кнопка перевода в поле ввода теперь работает, даже пока вы ещё набираете последнее слово.",
        "Если главный экран телефона перезапускается, RooTelegram сам снова запускается в фоне, и уведомления продолжают приходить."
    ],
    "fr": [
        "Nouveau thème Classic : l'apparence d'une messagerie classique, avec une liste de discussions plate, des avatars ronds, des dossiers en onglets et des bulles compactes. À choisir dans Paramètres → Apparence.",
        "Fonds des discussions (thème Classic) : RooTelegram affiche le fond de votre compte Telegram, pour toutes les discussions ou pour une seule, et vous pouvez le changer ici : vous le retrouverez aussi sur vos autres appareils. Sans fond défini, un nouveau motif dessiné pour RooTelegram apparaît.",
        "De plus beaux albums photo dans tous les thèmes : les images sont disposées en mosaïque, sans espaces vides entre elles.",
        "Le bouton de traduction du champ de saisie fonctionne maintenant même pendant que vous tapez encore le dernier mot.",
        "Si l'écran d'accueil du téléphone redémarre, RooTelegram redémarre tout seul en arrière-plan et les notifications continuent d'arriver."
    ],
    "sk": [
        "Nová téma Classic: vzhľad klasickej aplikácie na správy, s plochým zoznamom četov, okrúhlymi avatarmi, priečinkami ako kartami a kompaktnými bublinami. Vyberieš ju v Nastavenia → Vzhľad.",
        "Pozadia četov (téma Classic): RooTelegram zobrazuje pozadie tvojho účtu Telegram, pre všetky čety alebo pre jeden čet, a môžeš ho tu zmeniť: nájdeš ho aj na ostatných zariadeniach. Bez nastaveného pozadia sa zobrazí nový vzor nakreslený pre RooTelegram.",
        "Krajšie fotoalbumy vo všetkých témach: obrázky sú usporiadané ako mozaika, bez prázdnych medzier medzi nimi.",
        "Tlačidlo prekladu v poli na písanie teraz funguje, aj keď ešte píšeš posledné slovo.",
        "Ak sa domovská obrazovka telefónu reštartuje, RooTelegram sa sám znova spustí na pozadí a upozornenia naďalej prichádzajú."
    ]
};

// Vuoto: il messaggio del popup sta DOPO l'elenco, e la cosa da leggere per prima
// (il tema Classic, nella 4.0) e' gia' la prima voce dell'elenco (richiesta dell'utente).
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
