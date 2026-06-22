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

var version = "2.8.5";

var changelogByLang = {
    "it": [
        "Emoji: ora si vedono anche le emoji più recenti (Unicode 16/17) che prima restavano come testo.",
        "Foto profilo: l'avatar nella pagina del profilo non risulta più vuoto per alcuni contatti.",
        "Anteprime: i messaggi non sbalzano più mentre scorri quando carica l'anteprima di una foto."
    ],
    "en": [
        "Emoji: the most recent emoji (Unicode 16/17) that used to show up as plain text now display correctly.",
        "Profile photo: the avatar on the profile page is no longer blank for some contacts.",
        "Previews: messages no longer jump around while scrolling when a photo preview loads."
    ],
    "de": [
        "Emoji: die aktuellsten Emoji (Unicode 16/17), die zuvor als reiner Text erschienen, werden jetzt korrekt angezeigt.",
        "Profilbild: der Avatar auf der Profilseite ist bei manchen Kontakten nicht mehr leer.",
        "Vorschauen: Nachrichten springen beim Scrollen nicht mehr, wenn eine Foto-Vorschau lädt."
    ],
    "pl": [
        "Emoji: najnowsze emoji (Unicode 16/17), które wcześniej wyświetlały się jako zwykły tekst, są teraz poprawnie pokazywane.",
        "Zdjęcie profilowe: awatar na stronie profilu nie jest już pusty dla niektórych kontaktów.",
        "Podglądy: wiadomości nie przeskakują już podczas przewijania, gdy ładuje się podgląd zdjęcia."
    ],
    "ru": [
        "Эмодзи: самые новые эмодзи (Unicode 16/17), которые раньше отображались обычным текстом, теперь показываются правильно.",
        "Фото профиля: аватар на странице профиля больше не пустой у некоторых контактов.",
        "Превью: сообщения больше не скачут при прокрутке, когда загружается превью фото."
    ],
    "fr": [
        "Émojis : les émojis les plus récents (Unicode 16/17) qui s'affichaient en texte brut sont désormais affichés correctement.",
        "Photo de profil : l'avatar sur la page de profil n'est plus vide pour certains contacts.",
        "Aperçus : les messages ne sautent plus pendant le défilement lorsqu'un aperçu de photo se charge."
    ],
    "sk": [
        "Emoji: najnovšie emoji (Unicode 16/17), ktoré sa predtým zobrazovali ako obyčajný text, sa teraz zobrazujú správne.",
        "Profilová fotka: avatar na stránke profilu už nie je prázdny pri niektorých kontaktoch.",
        "Náhľady: správy už pri posúvaní neposkakujú, keď sa načítava náhľad fotky."
    ]
};

var messageByLang = {
    "it": "RooTelegram 2.8.5 è un aggiornamento di rifinitura: rende visibili le emoji più recenti, corregge l'avatar vuoto nella pagina profilo di alcuni contatti ed elimina lo sbalzo dei messaggi quando carica l'anteprima di una foto.",
    "en": "RooTelegram 2.8.5 is a polish update: it makes the most recent emoji visible, fixes the blank avatar on some contacts' profile page, and stops messages from jumping when a photo preview loads.",
    "de": "RooTelegram 2.8.5 ist ein Feinschliff-Update: es macht die neuesten Emoji sichtbar, behebt den leeren Avatar auf der Profilseite mancher Kontakte und verhindert das Springen der Nachrichten beim Laden einer Foto-Vorschau.",
    "pl": "RooTelegram 2.8.5 to aktualizacja dopracowująca: pokazuje najnowsze emoji, naprawia pusty awatar na stronie profilu niektórych kontaktów i eliminuje przeskakiwanie wiadomości podczas ładowania podglądu zdjęcia.",
    "ru": "RooTelegram 2.8.5 — обновление-доработка: делает видимыми самые новые эмодзи, исправляет пустой аватар на странице профиля у некоторых контактов и устраняет скачки сообщений при загрузке превью фото.",
    "fr": "RooTelegram 2.8.5 est une mise à jour de finition : elle rend visibles les émojis les plus récents, corrige l'avatar vide sur la page de profil de certains contacts et empêche les messages de sauter lorsqu'un aperçu de photo se charge.",
    "sk": "RooTelegram 2.8.5 je dolaďovacia aktualizácia: sprístupní najnovšie emoji, opraví prázdny avatar na stránke profilu niektorých kontaktov a odstráni poskakovanie správ pri načítaní náhľadu fotky."
};

// Restituisce il changelog/messaggio per la lingua data (codice a 2 lettere),
// con fallback a "en". Usati dal WhatsNewDialog.
function changelogFor(lang) {
    return changelogByLang[lang] || changelogByLang["en"];
}

function messageFor(lang) {
    return (lang in messageByLang) ? messageByLang[lang] : messageByLang["en"];
}
