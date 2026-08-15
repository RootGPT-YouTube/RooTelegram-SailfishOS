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

var version = "2.9.1";

var changelogByLang = {
    "it": [
        "I messaggi vocali ora vengono registrati nel formato che Telegram richiede: dovrebbero finalmente sentirsi anche sugli iPhone, che prima li ricevevano vuoti. Se ti capitava, riprova e fai sapere.",
        "Nei gruppi con i topic, il contatore dei messaggi non letti ora si azzera davvero dopo che hai letto: prima restava spesso appiccicato.",
        "L'app non si chiude più all'improvviso mentre libera memoria in background. Chi la vedeva ripartire «come al primo avvio» non dovrebbe più vederlo.",
        "Durante una chiamata lo schermo ora si spegne quando avvicini il telefono all'orecchio, come per una telefonata normale.",
        "Corrette alcune icone che non comparivano e ripulite alcune segnalazioni interne."
    ],
    "en": [
        "Voice messages are now recorded in the format Telegram requires: they should finally play on iPhones too, which used to receive them empty. If this happened to you, please try again and let us know.",
        "In groups with topics, the unread counter now really resets after you read: before, it often stayed stuck.",
        "The app no longer closes unexpectedly while freeing memory in the background. If you saw it restart \"as if it were the first launch\", that should be gone.",
        "During a call the screen now switches off when you hold the phone to your ear, like on a regular phone call.",
        "Fixed a few icons that were not showing up, and cleaned up some internal warnings."
    ],
    "de": [
        "Sprachnachrichten werden jetzt in dem Format aufgenommen, das Telegram verlangt: sie sollten endlich auch auf iPhones abspielbar sein, die sie bisher leer empfingen. Falls dir das passiert ist, versuche es erneut und melde dich.",
        "In Gruppen mit Themen wird der Zähler ungelesener Nachrichten jetzt wirklich zurückgesetzt, nachdem du gelesen hast: vorher blieb er oft hängen.",
        "Die App schließt sich nicht mehr unerwartet, während sie im Hintergrund Speicher freigibt.",
        "Während eines Anrufs schaltet sich der Bildschirm jetzt aus, wenn du das Telefon ans Ohr hältst, wie bei einem normalen Telefonat.",
        "Einige fehlende Symbole korrigiert und interne Warnungen aufgeräumt."
    ],
    "pl": [
        "Wiadomości głosowe są teraz nagrywane w formacie wymaganym przez Telegram: powinny wreszcie odtwarzać się także na iPhone'ach, które dotąd otrzymywały je puste. Jeśli ci się to zdarzało, spróbuj ponownie i daj znać.",
        "W grupach z tematami licznik nieprzeczytanych wiadomości teraz naprawdę się zeruje po przeczytaniu: wcześniej często się zacinał.",
        "Aplikacja nie zamyka się już niespodziewanie podczas zwalniania pamięci w tle.",
        "Podczas połączenia ekran wyłącza się teraz, gdy przykładasz telefon do ucha, jak przy zwykłej rozmowie.",
        "Poprawiono kilka brakujących ikon i uporządkowano wewnętrzne ostrzeżenia."
    ],
    "ru": [
        "Голосовые сообщения теперь записываются в формате, который требует Telegram: они должны наконец воспроизводиться и на iPhone, которые раньше получали их пустыми. Если с вами такое случалось, попробуйте снова и сообщите.",
        "В группах с темами счётчик непрочитанных теперь действительно обнуляется после прочтения: раньше он часто застревал.",
        "Приложение больше не закрывается неожиданно, освобождая память в фоне.",
        "Во время звонка экран теперь гаснет, когда вы подносите телефон к уху, как при обычном разговоре.",
        "Исправлены несколько не отображавшихся значков и убраны внутренние предупреждения."
    ],
    "fr": [
        "Les messages vocaux sont désormais enregistrés dans le format exigé par Telegram : ils devraient enfin s'entendre aussi sur iPhone, qui les recevait vides. Si cela vous arrivait, réessayez et dites-le nous.",
        "Dans les groupes avec sujets, le compteur de non-lus se remet vraiment à zéro après lecture : avant, il restait souvent bloqué.",
        "L'application ne se ferme plus à l'improviste pendant qu'elle libère de la mémoire en arrière-plan.",
        "Pendant un appel, l'écran s'éteint maintenant quand vous portez le téléphone à l'oreille, comme pour un appel normal.",
        "Correction de quelques icônes manquantes et nettoyage d'avertissements internes."
    ],
    "sk": [
        "Hlasové správy sa teraz nahrávajú vo formáte, ktorý Telegram vyžaduje: mali by sa konečne prehrať aj na iPhonoch, ktoré ich doteraz dostávali prázdne. Ak sa vám to stávalo, skúste to znova a dajte vedieť.",
        "V skupinách s témami sa počítadlo neprečítaných teraz naozaj vynuluje po prečítaní: predtým často zostávalo visieť.",
        "Aplikácia sa už nezatvára nečakane, keď na pozadí uvoľňuje pamäť.",
        "Počas hovoru sa obrazovka teraz vypne, keď si priložíte telefón k uchu, ako pri bežnom telefonáte.",
        "Opravených niekoľko chýbajúcich ikon a upratané interné upozornenia."
    ]
};

var messageByLang = {
    "it": "Aggiornamento di correzioni: vocali finalmente compatibili con iPhone, contatori dei topic che si azzerano, niente più chiusure improvvise.",
    "en": "Bugfix update: voice messages finally compatible with iPhone, topic counters that actually reset, no more unexpected closures.",
    "de": "Fehlerbehebungen: Sprachnachrichten endlich iPhone-kompatibel, Themen-Zähler die sich zurücksetzen, keine unerwarteten Abstürze mehr.",
    "pl": "Aktualizacja poprawek: wiadomości głosowe wreszcie zgodne z iPhone'em, działające liczniki tematów, koniec nieoczekiwanych zamknięć.",
    "ru": "Обновление с исправлениями: голосовые наконец совместимы с iPhone, счётчики тем обнуляются, больше нет внезапных закрытий.",
    "fr": "Mise à jour de corrections : messages vocaux enfin compatibles iPhone, compteurs de sujets qui se remettent à zéro, plus de fermetures inopinées.",
    "sk": "Aktualizácia opráv: hlasové správy konečne kompatibilné s iPhonom, fungujúce počítadlá tém, koniec nečakaných zatvorení."
};

// Restituisce il changelog/messaggio per la lingua data (codice a 2 lettere),
// con fallback a "en". Usati dal WhatsNewDialog.
function changelogFor(lang) {
    return changelogByLang[lang] || changelogByLang["en"];
}

function messageFor(lang) {
    return (lang in messageByLang) ? messageByLang[lang] : messageByLang["en"];
}
