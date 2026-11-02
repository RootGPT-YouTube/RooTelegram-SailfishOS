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

var version = "3.7.7";

var changelogByLang = {
    "it": [
        "Corretto: restando più di mezzo minuto su un'altra pagina, per esempio il profilo di una chat, al ritorno nella chat mancavano dei messaggi e le date sembravano scombinate. Ora la chat resta integra.",
        "Articoli: i pulsanti ora si vedono al loro posto nel testo, con i loro colori, e funzionano anche quelli che copiano un testo o aprono un utente.",
        "Articoli (con Telegram Premium): nell'editor puoi aggiungere pulsanti, sceglierne il colore e modificare gli articoli che ne contengono."
    ],
    "en": [
        "Fixed: after staying on another page for more than half a minute, such as a chat's profile, messages were missing when you returned to the chat and the dates looked mixed up. The chat now stays complete.",
        "Articles: buttons now appear in their place in the text, with their colours, and those that copy a text or open a user now work too.",
        "Articles (with Telegram Premium): in the editor you can add buttons, choose their colour and edit articles that contain them."
    ],
    "de": [
        "Behoben: Wenn du länger als eine halbe Minute auf einer anderen Seite warst, etwa im Profil eines Chats, fehlten bei der Rückkehr Nachrichten und die Daten wirkten durcheinander. Der Chat bleibt jetzt vollständig.",
        "Artikel: Schaltflächen erscheinen jetzt an ihrer Stelle im Text und in ihren Farben, und auch solche, die einen Text kopieren oder einen Benutzer öffnen, funktionieren.",
        "Artikel (mit Telegram Premium): Im Editor kannst du Schaltflächen hinzufügen, ihre Farbe wählen und Artikel bearbeiten, die welche enthalten."
    ],
    "pl": [
        "Naprawiono: po ponad pół minuty na innej stronie, na przykład w profilu czatu, po powrocie do czatu brakowało wiadomości, a daty wydawały się pomieszane. Teraz czat pozostaje kompletny.",
        "Artykuły: przyciski są teraz widoczne na swoim miejscu w tekście, w swoich kolorach, i działają też te, które kopiują tekst lub otwierają użytkownika.",
        "Artykuły (z Telegram Premium): w edytorze możesz dodawać przyciski, wybierać ich kolor i edytować artykuły, które je zawierają."
    ],
    "ru": [
        "Исправлено: если пробыть больше полуминуты на другой странице, например в профиле чата, то после возвращения в чат не хватало сообщений, а даты казались перепутанными. Теперь чат остаётся полным.",
        "Статьи: кнопки теперь отображаются на своём месте в тексте и в своих цветах, а ещё работают те, что копируют текст или открывают пользователя.",
        "Статьи (с Telegram Premium): в редакторе можно добавлять кнопки, выбирать их цвет и изменять статьи, в которых они есть."
    ],
    "fr": [
        "Corrigé : après plus d'une demi-minute sur une autre page, par exemple le profil d'une discussion, des messages manquaient au retour et les dates semblaient mélangées. La discussion reste désormais complète.",
        "Articles : les boutons s'affichent maintenant à leur place dans le texte, avec leurs couleurs, et ceux qui copient un texte ou ouvrent un utilisateur fonctionnent aussi.",
        "Articles (avec Telegram Premium) : dans l'éditeur, vous pouvez ajouter des boutons, choisir leur couleur et modifier les articles qui en contiennent."
    ],
    "sk": [
        "Opravené: po viac ako pol minúte na inej stránke, napríklad v profile četu, po návrate do četu chýbali správy a dátumy vyzerali pomiešané. Čet teraz zostáva úplný.",
        "Články: tlačidlá sa teraz zobrazujú na svojom mieste v texte a vo svojich farbách a fungujú aj tie, ktoré kopírujú text alebo otvárajú používateľa.",
        "Články (s Telegram Premium): v editore môžete pridávať tlačidlá, vybrať ich farbu a upravovať články, ktoré ich obsahujú."
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
