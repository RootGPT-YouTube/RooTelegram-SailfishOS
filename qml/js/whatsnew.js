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

var version = "3.5";

var changelogByLang = {
    "it": [
        "Icona più nitida: l'aeroplanino d'acciaio è stato ridisegnato e ora si riconosce bene anche in piccolo.",
        "Le notifiche hanno finalmente la nuova icona d'acciaio: prima mostravano ancora quella blu delle versioni precedenti."
    ],
    "en": [
        "Sharper icon: the steel paper plane has been redrawn and is now easy to recognise even at small sizes.",
        "Notifications finally show the new steel icon: until now they still had the blue one from earlier versions."
    ],
    "de": [
        "Schärferes Symbol: Der Papierflieger aus Stahl wurde neu gezeichnet und ist jetzt auch in kleiner Größe gut zu erkennen.",
        "Benachrichtigungen zeigen endlich das neue Stahl-Symbol: Bisher hatten sie noch das blaue aus früheren Versionen."
    ],
    "pl": [
        "Wyraźniejsza ikona: stalowy papierowy samolocik został narysowany od nowa i teraz dobrze go widać nawet w małym rozmiarze.",
        "Powiadomienia mają wreszcie nową stalową ikonę: do tej pory pokazywały jeszcze niebieską z poprzednich wersji."
    ],
    "ru": [
        "Более чёткий значок: стальной бумажный самолётик перерисован, и теперь его легко узнать даже в маленьком размере.",
        "Уведомления наконец показывают новый стальной значок: до сих пор в них оставался синий из прежних версий."
    ],
    "fr": [
        "Icône plus nette : l'avion en papier d'acier a été redessiné et se reconnaît bien, même en petit.",
        "Les notifications affichent enfin la nouvelle icône en acier : jusqu'ici elles montraient encore l'icône bleue des versions précédentes."
    ],
    "sk": [
        "Ostrejšia ikona: oceľové papierové lietadielko bolo nakreslené nanovo a teraz je dobre rozpoznateľné aj v malej veľkosti.",
        "Upozornenia majú konečne novú oceľovú ikonu: doteraz ešte zobrazovali modrú z predchádzajúcich verzií."
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
