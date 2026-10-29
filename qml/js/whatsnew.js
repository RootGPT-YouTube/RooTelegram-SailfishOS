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

var version = "3.7.6";

var changelogByLang = {
    "it": [
        "Nuovo: toccando un link in un messaggio compare un menu con «Apri link» e «Copia link». «Copia link» lo mette negli appunti, così puoi incollarlo dove vuoi. «Apri link» lo apre in RooTitanium se è installato, altrimenti nel browser del telefono.",
        "Dopo l'aggiornamento, al primo avvio dall'icona Sailfish OS ti chiede di nuovo di confermare i permessi: ce n'è uno nuovo, «RooTitanium», che serve per aprire i link in RooTitanium."
    ],
    "en": [
        "New: tapping a link in a message shows a menu with «Open link» and «Copy link». «Copy link» puts it on the clipboard, so you can paste it wherever you like. «Open link» opens it in RooTitanium if it is installed, otherwise in the phone's browser.",
        "After the update, the first time you open the app from its icon Sailfish OS asks you to confirm the permissions again: there is a new one, «RooTitanium», used to open links in RooTitanium."
    ],
    "de": [
        "Neu: Tippst du auf einen Link in einer Nachricht, erscheint ein Menü mit «Link öffnen» und «Link kopieren». «Link kopieren» legt ihn in die Zwischenablage, damit du ihn überall einfügen kannst. «Link öffnen» öffnet ihn in RooTitanium, wenn es installiert ist, sonst im Browser des Telefons.",
        "Nach dem Update fragt Sailfish OS beim ersten Start über das Symbol erneut nach den Berechtigungen: Es gibt eine neue, «RooTitanium», um Links in RooTitanium zu öffnen."
    ],
    "pl": [
        "Nowość: po dotknięciu linku w wiadomości pojawia się menu z opcjami «Otwórz link» i «Kopiuj link». «Kopiuj link» umieszcza go w schowku, więc możesz go wkleić, gdzie chcesz. «Otwórz link» otwiera go w RooTitanium, jeśli jest zainstalowany, a w przeciwnym razie w przeglądarce telefonu.",
        "Po aktualizacji, przy pierwszym uruchomieniu z ikony, Sailfish OS ponownie poprosi o potwierdzenie uprawnień: jest nowe, «RooTitanium», służące do otwierania linków w RooTitanium."
    ],
    "ru": [
        "Новое: при нажатии на ссылку в сообщении появляется меню «Открыть ссылку» и «Копировать ссылку». «Копировать ссылку» помещает её в буфер обмена, чтобы вставить куда угодно. «Открыть ссылку» открывает её в RooTitanium, если он установлен, иначе в браузере телефона.",
        "После обновления при первом запуске с иконки Sailfish OS снова попросит подтвердить разрешения: появилось новое, «RooTitanium», для открытия ссылок в RooTitanium."
    ],
    "fr": [
        "Nouveau : toucher un lien dans un message affiche un menu avec « Ouvrir le lien » et « Copier le lien ». « Copier le lien » le place dans le presse-papiers pour le coller où vous voulez. « Ouvrir le lien » l'ouvre dans RooTitanium s'il est installé, sinon dans le navigateur du téléphone.",
        "Après la mise à jour, au premier lancement depuis l'icône, Sailfish OS vous demande à nouveau de confirmer les autorisations : il y en a une nouvelle, « RooTitanium », qui sert à ouvrir les liens dans RooTitanium."
    ],
    "sk": [
        "Nové: po ťuknutí na odkaz v správe sa zobrazí ponuka «Otvoriť odkaz» a «Kopírovať odkaz». «Kopírovať odkaz» ho vloží do schránky, aby ste ho mohli vložiť kamkoľvek. «Otvoriť odkaz» ho otvorí v RooTitanium, ak je nainštalovaný, inak v prehliadači telefónu.",
        "Po aktualizácii pri prvom spustení z ikony vás Sailfish OS znova požiada o potvrdenie povolení: pribudlo nové, «RooTitanium», ktoré slúži na otváranie odkazov v RooTitanium."
    ],
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
