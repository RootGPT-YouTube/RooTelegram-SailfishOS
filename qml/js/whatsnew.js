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

var version = "2.8.8";

var changelogByLang = {
    "it": [
        "Canali molto grandi (es. Durov's Channel): scorrere indietro nel tempo è ora molto più fluido e regge molto più a lungo prima di rallentare. I lunghi blocchi che congelavano l'app per decine di secondi sono spariti nell'uso normale; spingendosi molto indietro di mesi può ancora impuntarsi, ma il miglioramento è netto.",
        "Avvio più sicuro: una schermata di caricamento con barra di avanzamento blocca l'interazione finché l'app non è pronta, evitando i blocchi e i crash che potevano capitare toccando subito ricerche o chat pesanti nei primi secondi dopo l'apertura.",
        "Avvio automatico all'accensione: nelle Impostazioni puoi far partire RooTelegram in background quando accendi il telefono, così le notifiche arrivano senza doverlo aprire. Attivo di default; chiudere o terminare l'app non la riavvia, l'avvio automatico agisce solo al boot del dispositivo."
    ],
    "en": [
        "Very large channels (e.g. Durov's Channel): scrolling far back in time is now much smoother and holds up much longer before slowing down. The long freezes that used to lock the app for tens of seconds are gone in normal use; going very far back through many months can still stutter, but it's a big improvement.",
        "Safer startup: a loading screen with a progress bar blocks interaction until the app is ready, preventing the freezes and crashes that could happen when tapping searches or heavy chats in the first seconds after opening.",
        "Start at device boot: in Settings you can have RooTelegram launch in the background when the phone powers on, so notifications arrive without opening it first. On by default; closing or killing the app does not relaunch it, autostart only happens at device boot."
    ],
    "de": [
        "Sehr große Kanäle (z. B. Durov's Channel): das Zurückscrollen in der Zeit ist jetzt deutlich flüssiger und hält viel länger durch, bevor es langsamer wird. Die langen Hänger, die die App zehn Sekunden und länger blockierten, sind im normalen Gebrauch verschwunden; sehr weit zurück über viele Monate kann es noch stocken, aber die Verbesserung ist deutlich.",
        "Sichererer Start: ein Ladebildschirm mit Fortschrittsbalken sperrt die Bedienung, bis die App bereit ist, und verhindert so die Hänger und Abstürze, die auftreten konnten, wenn man in den ersten Sekunden nach dem Öffnen sofort auf Suchen oder schwere Chats tippte.",
        "Automatischer Start beim Hochfahren: in den Einstellungen kannst du RooTelegram beim Einschalten des Telefons im Hintergrund starten lassen, damit Benachrichtigungen ankommen, ohne die App erst zu öffnen. Standardmäßig aktiv; die App zu schließen oder zu beenden startet sie nicht neu, der automatische Start erfolgt nur beim Gerätestart."
    ],
    "pl": [
        "Bardzo duże kanały (np. Durov's Channel): przewijanie wstecz w czasie jest teraz dużo płynniejsze i wytrzymuje znacznie dłużej, zanim zwolni. Długie zawieszenia, które blokowały aplikację na dziesiątki sekund, zniknęły w normalnym użytkowaniu; przy bardzo głębokim cofaniu o wiele miesięcy może jeszcze się zacinać, ale poprawa jest wyraźna.",
        "Bezpieczniejszy start: ekran ładowania z paskiem postępu blokuje interakcję, dopóki aplikacja nie jest gotowa, zapobiegając zawieszeniom i awariom, które mogły wystąpić po dotknięciu wyszukiwania lub ciężkich czatów w pierwszych sekundach po otwarciu.",
        "Automatyczny start przy włączeniu telefonu: w Ustawieniach możesz sprawić, że RooTelegram uruchomi się w tle po włączeniu telefonu, aby powiadomienia przychodziły bez otwierania go. Domyślnie włączone; zamknięcie lub zakończenie aplikacji nie uruchamia jej ponownie, autostart następuje tylko przy starcie urządzenia."
    ],
    "ru": [
        "Очень большие каналы (напр. Durov's Channel): прокрутка назад во времени теперь намного плавнее и держится гораздо дольше, прежде чем начать тормозить. Длинные подвисания, которые блокировали приложение на десятки секунд, исчезли при обычном использовании; при прокрутке очень далеко назад на много месяцев всё ещё возможны рывки, но улучшение значительное.",
        "Более безопасный запуск: экран загрузки с индикатором прогресса блокирует взаимодействие, пока приложение не готово, предотвращая подвисания и сбои, которые могли возникать при нажатии на поиск или тяжёлые чаты в первые секунды после открытия.",
        "Автозапуск при включении устройства: в Настройках можно сделать так, чтобы RooTelegram запускался в фоне при включении телефона, и уведомления приходили без его открытия. Включено по умолчанию; закрытие или завершение приложения не перезапускает его, автозапуск происходит только при загрузке устройства."
    ],
    "fr": [
        "Très grands canaux (p. ex. Durov's Channel) : faire défiler loin en arrière dans le temps est désormais bien plus fluide et tient beaucoup plus longtemps avant de ralentir. Les longs blocages qui figeaient l'application pendant des dizaines de secondes ont disparu à l'usage normal ; en remontant très loin sur de nombreux mois, des à-coups restent possibles, mais l'amélioration est nette.",
        "Démarrage plus sûr : un écran de chargement avec barre de progression bloque l'interaction jusqu'à ce que l'application soit prête, évitant les blocages et plantages qui pouvaient survenir en touchant des recherches ou des discussions lourdes dans les premières secondes après l'ouverture.",
        "Démarrage automatique à l'allumage : dans les Réglages, vous pouvez faire démarrer RooTelegram en arrière-plan à l'allumage du téléphone, afin que les notifications arrivent sans l'ouvrir. Activé par défaut ; fermer ou forcer l'arrêt de l'application ne la relance pas, le démarrage automatique n'a lieu qu'au démarrage de l'appareil."
    ],
    "sk": [
        "Veľmi veľké kanály (napr. Durov's Channel): posúvanie späť v čase je teraz oveľa plynulejšie a vydrží oveľa dlhšie, kým sa spomalí. Dlhé zaseknutia, ktoré blokovali aplikáciu na desiatky sekúnd, v bežnom používaní zmizli; pri veľmi hlbokom posúvaní o mnoho mesiacov sa ešte môže zasekávať, ale zlepšenie je výrazné.",
        "Bezpečnejší štart: načítavacia obrazovka s indikátorom priebehu blokuje ovládanie, kým nie je aplikácia pripravená, čím predchádza zaseknutiam a pádom, ktoré mohli nastať po klepnutí na vyhľadávanie alebo ťažké konverzácie v prvých sekundách po otvorení.",
        "Automatický štart pri zapnutí zariadenia: v Nastaveniach môžete nechať RooTelegram spustiť sa na pozadí pri zapnutí telefónu, aby upozornenia prichádzali bez jeho otvorenia. Predvolene zapnuté; zatvorenie alebo ukončenie aplikácie ju nereštartuje, automatický štart sa deje len pri štarte zariadenia."
    ]
};

var messageByLang = {
    "it": "RooTelegram 2.8.8 rende molto più fluido lo scorrimento indietro nei canali grandi: i lunghi blocchi che congelavano l'app sono spariti nell'uso normale (scorrendo molto indietro di mesi può ancora rallentare, ma molto meno di prima). Aggiunge una schermata di avvio con barra di progresso che evita crash nei primi secondi, e l'avvio automatico in background all'accensione del telefono (attivabile e disattivabile nelle Impostazioni).",
    "en": "RooTelegram 2.8.8 makes scrolling back through large channels much smoother: the long freezes that used to lock the app are gone in normal use (going very far back through many months can still slow down, but far less than before). It adds a startup screen with a progress bar that prevents crashes in the first seconds, and automatic background launch when the phone powers on (toggle on or off in Settings).",
    "de": "RooTelegram 2.8.8 macht das Zurückscrollen in großen Kanälen viel flüssiger: die langen Hänger, die die App blockierten, sind im normalen Gebrauch verschwunden (sehr weit zurück über viele Monate kann es noch langsamer werden, aber deutlich weniger als zuvor). Hinzu kommen ein Startbildschirm mit Fortschrittsbalken, der Abstürze in den ersten Sekunden verhindert, und der automatische Start im Hintergrund beim Einschalten des Telefons (in den Einstellungen ein- und ausschaltbar).",
    "pl": "RooTelegram 2.8.8 znacznie usprawnia przewijanie wstecz w dużych kanałach: długie zawieszenia, które blokowały aplikację, zniknęły w normalnym użytkowaniu (przy bardzo głębokim cofaniu o wiele miesięcy może jeszcze zwalniać, ale dużo mniej niż wcześniej). Dodaje ekran startowy z paskiem postępu, który zapobiega awariom w pierwszych sekundach, oraz automatyczne uruchamianie w tle po włączeniu telefonu (włączane i wyłączane w Ustawieniach).",
    "ru": "RooTelegram 2.8.8 делает прокрутку назад в больших каналах намного плавнее: длинные подвисания, которые блокировали приложение, исчезли при обычном использовании (при прокрутке очень далеко назад на много месяцев всё ещё может тормозить, но гораздо меньше, чем раньше). Добавлены экран запуска с индикатором прогресса, предотвращающий сбои в первые секунды, и автоматический запуск в фоне при включении телефона (включается и отключается в Настройках).",
    "fr": "RooTelegram 2.8.8 rend le défilement vers l'arrière dans les grands canaux bien plus fluide : les longs blocages qui figeaient l'application ont disparu à l'usage normal (en remontant très loin sur de nombreux mois, cela peut encore ralentir, mais bien moins qu'avant). Il ajoute un écran de démarrage avec barre de progression qui évite les plantages dans les premières secondes, et le lancement automatique en arrière-plan à l'allumage du téléphone (activable et désactivable dans les Réglages).",
    "sk": "RooTelegram 2.8.8 robí posúvanie späť vo veľkých kanáloch oveľa plynulejším: dlhé zaseknutia, ktoré blokovali aplikáciu, v bežnom používaní zmizli (pri veľmi hlbokom posúvaní o mnoho mesiacov sa ešte môže spomaliť, ale oveľa menej než predtým). Pridáva štartovaciu obrazovku s indikátorom priebehu, ktorá predchádza pádom v prvých sekundách, a automatické spustenie na pozadí pri zapnutí telefónu (zapnuteľné a vypnuteľné v Nastaveniach)."
};

// Restituisce il changelog/messaggio per la lingua data (codice a 2 lettere),
// con fallback a "en". Usati dal WhatsNewDialog.
function changelogFor(lang) {
    return changelogByLang[lang] || changelogByLang["en"];
}

function messageFor(lang) {
    return (lang in messageByLang) ? messageByLang[lang] : messageByLang["en"];
}
