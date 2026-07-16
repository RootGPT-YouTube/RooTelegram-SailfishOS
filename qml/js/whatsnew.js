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

var version = "2.8.11";

var changelogByLang = {
    "it": [
        "Notifiche fantasma: risolto il problema per cui le notifiche di canali e gruppi già letti ricomparivano da sole dopo un po'. Quando chiudi o apri una notifica, ora resta chiusa.",
        "Menzioni e reazioni ora vengono segnate come lette in modo affidabile, così non arrivano più notifiche ripetute per messaggi già visti."
    ],
    "en": [
        "Ghost notifications: fixed the issue where notifications from channels and groups you had already read came back on their own after a while. When you dismiss or open a notification, it now stays closed.",
        "Mentions and reactions are now reliably marked as read, so you no longer get repeated notifications for messages you have already seen."
    ],
    "de": [
        "Geister-Benachrichtigungen: das Problem behoben, bei dem Benachrichtigungen bereits gelesener Kanäle und Gruppen nach einer Weile von selbst wieder auftauchten. Wenn du eine Benachrichtigung schließt oder öffnest, bleibt sie jetzt geschlossen.",
        "Erwähnungen und Reaktionen werden jetzt zuverlässig als gelesen markiert, sodass du keine wiederholten Benachrichtigungen für bereits gesehene Nachrichten mehr erhältst."
    ],
    "pl": [
        "Duchy powiadomień: naprawiono problem, przez który powiadomienia z już przeczytanych kanałów i grup po pewnym czasie same wracały. Gdy zamkniesz lub otworzysz powiadomienie, teraz pozostaje zamknięte.",
        "Wzmianki i reakcje są teraz niezawodnie oznaczane jako przeczytane, więc nie otrzymujesz już powtarzających się powiadomień o wiadomościach, które już widziałeś."
    ],
    "ru": [
        "Призрачные уведомления: устранена проблема, из-за которой уведомления из уже прочитанных каналов и групп через некоторое время снова появлялись сами по себе. Теперь, когда вы закрываете или открываете уведомление, оно остаётся закрытым.",
        "Упоминания и реакции теперь надёжно отмечаются как прочитанные, поэтому вы больше не получаете повторные уведомления о сообщениях, которые уже видели."
    ],
    "fr": [
        "Notifications fantômes : correction du problème où les notifications de canaux et groupes déjà lus réapparaissaient d'elles-mêmes après un moment. Lorsque vous fermez ou ouvrez une notification, elle reste désormais fermée.",
        "Les mentions et les réactions sont maintenant marquées comme lues de manière fiable, vous ne recevez donc plus de notifications répétées pour des messages déjà vus."
    ],
    "sk": [
        "Duchovné oznámenia: opravený problém, keď sa oznámenia z už prečítaných kanálov a skupín po chvíli samy znova objavovali. Keď oznámenie zavriete alebo otvoríte, teraz zostane zatvorené.",
        "Zmienky a reakcie sa teraz spoľahlivo označujú ako prečítané, takže už nedostávate opakované oznámenia pre správy, ktoré ste už videli."
    ]
};

var messageByLang = {
    "it": "Notifiche fantasma risolte: le notifiche di canali e gruppi già letti non ricompaiono più da sole. Menzioni e reazioni ora vengono segnate come lette in modo affidabile, senza notifiche ripetute.",
    "en": "Ghost notifications fixed: notifications from channels and groups you already read no longer come back on their own. Mentions and reactions are now reliably marked as read, with no repeated notifications.",
    "de": "Geister-Benachrichtigungen behoben: Benachrichtigungen bereits gelesener Kanäle und Gruppen tauchen nicht mehr von selbst wieder auf. Erwähnungen und Reaktionen werden jetzt zuverlässig als gelesen markiert, ohne wiederholte Benachrichtigungen.",
    "pl": "Naprawiono duchy powiadomień: powiadomienia z już przeczytanych kanałów i grup nie wracają już same. Wzmianki i reakcje są teraz niezawodnie oznaczane jako przeczytane, bez powtarzających się powiadomień.",
    "ru": "Призрачные уведомления исправлены: уведомления из уже прочитанных каналов и групп больше не возвращаются сами по себе. Упоминания и реакции теперь надёжно отмечаются как прочитанные, без повторных уведомлений.",
    "fr": "Notifications fantômes corrigées : les notifications de canaux et groupes déjà lus ne reviennent plus d'elles-mêmes. Les mentions et réactions sont désormais marquées comme lues de manière fiable, sans notifications répétées.",
    "sk": "Duchovné oznámenia opravené: oznámenia z už prečítaných kanálov a skupín sa už samy nevracajú. Zmienky a reakcie sa teraz spoľahlivo označujú ako prečítané, bez opakovaných oznámení."
};

// Restituisce il changelog/messaggio per la lingua data (codice a 2 lettere),
// con fallback a "en". Usati dal WhatsNewDialog.
function changelogFor(lang) {
    return changelogByLang[lang] || changelogByLang["en"];
}

function messageFor(lang) {
    return (lang in messageByLang) ? messageByLang[lang] : messageByLang["en"];
}
