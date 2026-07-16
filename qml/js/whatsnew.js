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

var version = "2.8.10";

var changelogByLang = {
    "it": [
        "Volume delle chiamate: risolto il problema per cui, dopo una chiamata, il volume di sistema restava più alto (minimo alzato, volume sempre al massimo). Ora al termine della chiamata il volume torna esattamente com'era prima.",
        "Il volume iniziale in chiamata è più equilibrato (90% anziché forzato al massimo) e resta regolabile durante la conversazione.",
        "Nuovo: durante le chiamate vengono mostrate le 4 emoji di verifica della cifratura. Se combaciano con quelle dell'interlocutore, la chiamata è cifrata end-to-end e non intercettata."
    ],
    "en": [
        "Call volume: fixed the issue where the system volume stayed higher after a call (raised minimum, volume stuck at maximum). The volume now returns to exactly what it was before the call ended.",
        "The initial in-call volume is more balanced (90% instead of forced to maximum) and stays adjustable during the conversation.",
        "New: the 4 encryption verification emoji are now shown during calls. If they match your contact's, the call is end-to-end encrypted and not intercepted."
    ],
    "de": [
        "Anruflautstärke: das Problem behoben, bei dem die Systemlautstärke nach einem Anruf höher blieb (angehobenes Minimum, Lautstärke auf Maximum hängend). Die Lautstärke kehrt jetzt am Anrufende genau zum vorherigen Wert zurück.",
        "Die anfängliche Gesprächslautstärke ist ausgewogener (90 % statt auf Maximum erzwungen) und bleibt während des Gesprächs regelbar.",
        "Neu: Während Anrufen werden die 4 Emoji zur Verschlüsselungsprüfung angezeigt. Stimmen sie mit denen des Kontakts überein, ist der Anruf Ende-zu-Ende verschlüsselt und nicht abgehört."
    ],
    "pl": [
        "Głośność połączeń: naprawiono problem, przez który po połączeniu głośność systemu pozostawała wyższa (podniesione minimum, głośność utknięta na maksimum). Po zakończeniu połączenia głośność wraca teraz dokładnie do poprzedniej wartości.",
        "Początkowa głośność w rozmowie jest bardziej wyważona (90% zamiast wymuszonego maksimum) i pozostaje regulowana podczas rozmowy.",
        "Nowość: podczas połączeń wyświetlane są 4 emoji weryfikacji szyfrowania. Jeśli zgadzają się z emoji rozmówcy, połączenie jest szyfrowane end-to-end i nieprzechwytywane."
    ],
    "ru": [
        "Громкость звонков: устранена проблема, из-за которой после звонка системная громкость оставалась выше (поднятый минимум, громкость застревала на максимуме). Теперь по завершении звонка громкость возвращается точно к прежнему значению.",
        "Начальная громкость во время звонка стала более сбалансированной (90% вместо принудительного максимума) и остаётся регулируемой во время разговора.",
        "Новое: во время звонков показываются 4 эмодзи проверки шифрования. Если они совпадают с эмодзи собеседника, звонок зашифрован сквозным шифрованием и не перехвачен."
    ],
    "fr": [
        "Volume des appels : correction du problème où le volume système restait plus élevé après un appel (minimum relevé, volume bloqué au maximum). Le volume revient désormais exactement à sa valeur d'avant à la fin de l'appel.",
        "Le volume initial en appel est plus équilibré (90 % au lieu d'être forcé au maximum) et reste réglable pendant la conversation.",
        "Nouveau : les 4 emoji de vérification du chiffrement sont désormais affichés pendant les appels. S'ils correspondent à ceux de votre contact, l'appel est chiffré de bout en bout et non intercepté."
    ],
    "sk": [
        "Hlasitosť hovorov: opravený problém, keď po hovore zostala hlasitosť systému vyššia (zdvihnuté minimum, hlasitosť zaseknutá na maxime). Po skončení hovoru sa hlasitosť teraz vráti presne na predchádzajúcu hodnotu.",
        "Počiatočná hlasitosť počas hovoru je vyváženejšia (90 % namiesto vynúteného maxima) a zostáva nastaviteľná počas rozhovoru.",
        "Novinka: počas hovorov sa zobrazujú 4 emoji na overenie šifrovania. Ak sa zhodujú s emoji druhej strany, hovor je šifrovaný end-to-end a neodpočúvaný."
    ]
};

var messageByLang = {
    "it": "Volume chiamate: dopo una chiamata il volume di sistema non resta più alto, torna com'era prima; volume iniziale più equilibrato. Nuovo: durante le chiamate compaiono le 4 emoji di verifica della cifratura.",
    "en": "Call volume: after a call the system volume no longer stays high — it returns to what it was before; more balanced initial volume. New: the 4 encryption verification emoji now appear during calls.",
    "de": "Anruflautstärke: nach einem Anruf bleibt die Systemlautstärke nicht mehr höher — sie kehrt genau zum vorherigen Wert zurück. Die anfängliche Gesprächslautstärke ist ausgewogener und regelbar.",
    "pl": "Głośność połączeń: po połączeniu głośność systemu nie pozostaje już wyższa — wraca dokładnie do poprzedniej wartości. Początkowa głośność w rozmowie jest bardziej wyważona i regulowana.",
    "ru": "Громкость звонков: после звонка системная громкость больше не остаётся выше — она возвращается точно к прежнему значению. Начальная громкость во время звонка стала сбалансированнее и регулируемой.",
    "fr": "Volume des appels : après un appel, le volume système ne reste plus élevé — il revient exactement à sa valeur d'avant. Le volume initial en appel est plus équilibré et réglable.",
    "sk": "Hlasitosť hovorov: po hovore hlasitosť systému už nezostáva vyššia — vráti sa presne na predchádzajúcu hodnotu. Počiatočná hlasitosť počas hovoru je vyváženejšia a nastaviteľná."
};

// Restituisce il changelog/messaggio per la lingua data (codice a 2 lettere),
// con fallback a "en". Usati dal WhatsNewDialog.
function changelogFor(lang) {
    return changelogByLang[lang] || changelogByLang["en"];
}

function messageFor(lang) {
    return (lang in messageByLang) ? messageByLang[lang] : messageByLang["en"];
}
