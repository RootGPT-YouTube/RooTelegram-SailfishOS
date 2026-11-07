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

var version = "3.8";

var changelogByLang = {
    "it": [
        "Articoli: se un articolo contiene un video o una GIF, ora lo vedi direttamente nel messaggio, come le foto, e puoi avviarlo con un tocco. Prima compariva solo un'icona."
    ],
    "en": [
        "Articles: if an article contains a video or a GIF, you now see it right in the message, just like photos, and can play it with a tap. Before, only an icon was shown."
    ],
    "de": [
        "Artikel: Enthält ein Artikel ein Video oder ein GIF, siehst du es jetzt direkt in der Nachricht, genau wie Fotos, und kannst es mit einem Tippen abspielen. Bisher wurde nur ein Symbol angezeigt."
    ],
    "pl": [
        "Artykuły: jeśli artykuł zawiera film lub GIF, widzisz go teraz bezpośrednio w wiadomości, tak jak zdjęcia, i możesz go odtworzyć jednym dotknięciem. Wcześniej pokazywana była tylko ikona."
    ],
    "ru": [
        "Статьи: если в статье есть видео или GIF, теперь оно видно прямо в сообщении, как фотографии, и запускается одним касанием. Раньше показывался только значок."
    ],
    "fr": [
        "Articles : si un article contient une vidéo ou un GIF, vous le voyez maintenant directement dans le message, comme les photos, et vous pouvez le lancer d'un simple toucher. Avant, seule une icône s'affichait."
    ],
    "sk": [
        "Články: ak článok obsahuje video alebo GIF, teraz ho vidíš priamo v správe, rovnako ako fotky, a spustíš ho jedným ťuknutím. Predtým sa zobrazovala iba ikona."
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
