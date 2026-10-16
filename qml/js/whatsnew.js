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

var version = "3.6";

var changelogByLang = {
    "it": [
        "Musica e messaggi vocali: ora c'è un solo lettore, con una barra in alto per metterli in pausa o fermarli da qualunque schermata, anche dopo aver chiuso e riaperto l'app. Prima, chiudendo l'app, un vocale poteva continuare senza modo di fermarlo, e partirne un secondo insieme.",
        "Icona più nitida: l'aeroplanino d'acciaio è stato ridisegnato e ora si riconosce bene anche in piccolo.",
        "Le notifiche hanno finalmente la nuova icona d'acciaio: prima mostravano ancora quella blu delle versioni precedenti."
    ],
    "en": [
        "Music and voice messages: there is now a single player, with a bar at the top to pause or stop them from any screen, even after closing and reopening the app. Before, after closing the app a voice message could keep playing with no way to stop it, and a second one could start at the same time.",
        "Sharper icon: the steel paper plane has been redrawn and is now easy to recognise even at small sizes.",
        "Notifications finally show the new steel icon: until now they still had the blue one from earlier versions."
    ],
    "de": [
        "Musik und Sprachnachrichten: Es gibt jetzt einen einzigen Player, mit einer Leiste oben, um sie auf jedem Bildschirm anzuhalten oder zu stoppen, auch nach dem Schließen und erneuten Öffnen der App. Vorher konnte eine Sprachnachricht nach dem Schließen der App ohne Möglichkeit zum Anhalten weiterlaufen und eine zweite gleichzeitig starten.",
        "Schärferes Symbol: Der Papierflieger aus Stahl wurde neu gezeichnet und ist jetzt auch in kleiner Größe gut zu erkennen.",
        "Benachrichtigungen zeigen endlich das neue Stahl-Symbol: Bisher hatten sie noch das blaue aus früheren Versionen."
    ],
    "pl": [
        "Muzyka i wiadomości głosowe: teraz jest jeden odtwarzacz, z paskiem u góry, który pozwala je wstrzymać lub zatrzymać z każdego ekranu, także po zamknięciu i ponownym otwarciu aplikacji. Wcześniej po zamknięciu aplikacji wiadomość głosowa mogła grać dalej bez możliwości zatrzymania, a druga mogła zacząć grać jednocześnie.",
        "Wyraźniejsza ikona: stalowy papierowy samolocik został narysowany od nowa i teraz dobrze go widać nawet w małym rozmiarze.",
        "Powiadomienia mają wreszcie nową stalową ikonę: do tej pory pokazywały jeszcze niebieską z poprzednich wersji."
    ],
    "ru": [
        "Музыка и голосовые сообщения: теперь один проигрыватель с панелью вверху, чтобы поставить на паузу или остановить их с любого экрана, даже после закрытия и повторного открытия приложения. Раньше после закрытия приложения голосовое сообщение могло продолжать играть без возможности его остановить, а второе — запуститься одновременно.",
        "Более чёткий значок: стальной бумажный самолётик перерисован, и теперь его легко узнать даже в маленьком размере.",
        "Уведомления наконец показывают новый стальной значок: до сих пор в них оставался синий из прежних версий."
    ],
    "fr": [
        "Musique et messages vocaux : il n'y a plus qu'un seul lecteur, avec une barre en haut pour les mettre en pause ou les arrêter depuis n'importe quel écran, même après avoir fermé et rouvert l'application. Avant, après la fermeture de l'application, un message vocal pouvait continuer sans moyen de l'arrêter, et un second pouvait démarrer en même temps.",
        "Icône plus nette : l'avion en papier d'acier a été redessiné et se reconnaît bien, même en petit.",
        "Les notifications affichent enfin la nouvelle icône en acier : jusqu'ici elles montraient encore l'icône bleue des versions précédentes."
    ],
    "sk": [
        "Hudba a hlasové správy: teraz je jeden prehrávač s lištou hore, ktorou ich môžete pozastaviť alebo zastaviť z ktorejkoľvek obrazovky, aj po zatvorení a opätovnom otvorení aplikácie. Predtým mohla hlasová správa po zatvorení aplikácie hrať ďalej bez možnosti zastavenia a súčasne sa mohla spustiť druhá.",
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
