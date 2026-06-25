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

var version = "2.8.6";

var changelogByLang = {
    "it": [
        "Album video: più video inviati insieme ora si aprono e si salvano correttamente come video, non più come immagini.",
        "Gruppi: un gruppo eliminato che resta nella lista ora mostra un avviso \"Gruppo non più disponibile\" con i pulsanti Riprova e Rimuovi, invece di girare all'infinito."
    ],
    "en": [
        "Video albums: multiple videos sent together now open and save correctly as videos, no longer as images.",
        "Groups: a deleted group still lingering in the list now shows a \"Group no longer available\" notice with Retry and Remove buttons, instead of spinning forever."
    ],
    "de": [
        "Video-Alben: mehrere zusammen gesendete Videos öffnen und speichern jetzt korrekt als Videos, nicht mehr als Bilder.",
        "Gruppen: eine gelöschte Gruppe, die noch in der Liste verbleibt, zeigt jetzt den Hinweis \"Gruppe nicht mehr verfügbar\" mit den Schaltflächen Erneut versuchen und Entfernen, statt endlos zu laden."
    ],
    "pl": [
        "Albumy wideo: kilka filmów wysłanych razem otwiera się i zapisuje teraz poprawnie jako wideo, a nie jako obrazy.",
        "Grupy: usunięta grupa pozostająca na liście pokazuje teraz komunikat \"Grupa już niedostępna\" z przyciskami Spróbuj ponownie i Usuń, zamiast kręcić się w nieskończoność."
    ],
    "ru": [
        "Видеоальбомы: несколько видео, отправленных вместе, теперь открываются и сохраняются правильно как видео, а не как изображения.",
        "Группы: удалённая группа, оставшаяся в списке, теперь показывает уведомление \"Группа больше недоступна\" с кнопками Повторить и Удалить вместо бесконечной загрузки."
    ],
    "fr": [
        "Albums vidéo : plusieurs vidéos envoyées ensemble s'ouvrent et s'enregistrent désormais correctement comme des vidéos, et non plus comme des images.",
        "Groupes : un groupe supprimé qui reste dans la liste affiche maintenant un message \"Groupe non disponible\" avec les boutons Réessayer et Retirer, au lieu de tourner indéfiniment."
    ],
    "sk": [
        "Video albumy: viacero videí odoslaných spolu sa teraz správne otvára a ukladá ako videá, už nie ako obrázky.",
        "Skupiny: odstránená skupina, ktorá zostáva v zozname, teraz zobrazuje upozornenie \"Skupina už nie je dostupná\" s tlačidlami Skúsiť znova a Odstrániť namiesto nekonečného načítavania."
    ]
};

var messageByLang = {
    "it": "RooTelegram 2.8.6 corregge gli album video (più video insieme si aprivano e salvavano come immagini) e aggiunge un avviso per i gruppi eliminati che restano nella lista, con i pulsanti Riprova e Rimuovi al posto del caricamento infinito.",
    "en": "RooTelegram 2.8.6 fixes video albums (multiple videos sent together used to open and save as images) and adds a notice for deleted groups still lingering in the list, with Retry and Remove buttons instead of an endless spinner.",
    "de": "RooTelegram 2.8.6 behebt Video-Alben (mehrere zusammen gesendete Videos öffneten und speicherten als Bilder) und fügt einen Hinweis für gelöschte Gruppen hinzu, die in der Liste verbleiben, mit den Schaltflächen Erneut versuchen und Entfernen statt endlosem Laden.",
    "pl": "RooTelegram 2.8.6 naprawia albumy wideo (kilka filmów wysłanych razem otwierało się i zapisywało jako obrazy) oraz dodaje komunikat dla usuniętych grup pozostających na liście, z przyciskami Spróbuj ponownie i Usuń zamiast nieskończonego ładowania.",
    "ru": "RooTelegram 2.8.6 исправляет видеоальбомы (несколько видео, отправленных вместе, открывались и сохранялись как изображения) и добавляет уведомление для удалённых групп, оставшихся в списке, с кнопками Повторить и Удалить вместо бесконечной загрузки.",
    "fr": "RooTelegram 2.8.6 corrige les albums vidéo (plusieurs vidéos envoyées ensemble s'ouvraient et s'enregistraient comme des images) et ajoute un message pour les groupes supprimés restant dans la liste, avec les boutons Réessayer et Retirer au lieu d'un chargement sans fin.",
    "sk": "RooTelegram 2.8.6 opravuje video albumy (viacero videí odoslaných spolu sa otváralo a ukladalo ako obrázky) a pridáva upozornenie pre odstránené skupiny zostávajúce v zozname, s tlačidlami Skúsiť znova a Odstrániť namiesto nekonečného načítavania."
};

// Restituisce il changelog/messaggio per la lingua data (codice a 2 lettere),
// con fallback a "en". Usati dal WhatsNewDialog.
function changelogFor(lang) {
    return changelogByLang[lang] || changelogByLang["en"];
}

function messageFor(lang) {
    return (lang in messageByLang) ? messageByLang[lang] : messageByLang["en"];
}
