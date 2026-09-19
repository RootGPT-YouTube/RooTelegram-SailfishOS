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

var version = "3.0";

var changelogByLang = {
    "it": [
        "Nuovo tema \"Barbara\": PROVATELO!",
        "Barbara è vetro freddo color ciano: righe delle chat come schede, filtri Tutte/Gruppi/Canali e cartelle a pastiglia su una riga. Ha una palette chiara e una scura e sceglie da sé quella giusta in base all'ambience. Per chi installa RooTelegram per la prima volta è il tema predefinito; gli altri lo scelgono da Impostazioni → Aspetto, con le tre pillole Silica / Neon / Barbara.",
        "I post «articolo» dei canali ora si leggono: titolo grande, foto, testo, elenchi e link, come nell'app ufficiale, invece di «messaggio non supportato».",
        "Con Telegram Premium puoi scrivere articoli: dalla graffetta si apre un editor a pagina intera con titoli, sottotitoli, grassetto e corsivo visibili mentre scrivi, elenchi puntati, link e foto. Un articolo inviato si può anche modificare.",
        "Bot: i pulsanti fissi di un bot stanno ora sopra la barra di scrittura, come nell'app ufficiale, invece di scorrere via con i messaggi. Il pulsante con la tastiera accanto alla graffetta li nasconde e li rimostra.",
        "Aggiornato il motore di Telegram: sondaggi, articoli e altri messaggi nuovi non risultano più «non supportati», e le posizioni in tempo reale seguono il formato nuovo.",
        "Link, nomi utente e ogni altro collegamento nei messaggi sono ora celeste chiaro, ben leggibili sui temi scuri.",
        "Forum: il topic «General» carica di nuovo i messaggi recenti e il suo contatore scende. Tenendo premuto su un topic lo segni come letto, e nei gruppi normali torna «segna tutto come letto».",
        "I contatori delle cartelle si aggiornano subito, il filtro «Tutte» mostra davvero tutte le chat, e il contatore dei canali che restava bloccato ora si azzera.",
        "Corretto l'invio di una parola appena scritta: il tasto restava spento, o partiva solo un pezzo della parola appena corretta. Ora parte tutto al primo tocco."
    ],
    "en": [
        "New theme \"Barbara\": TRY IT!",
        "Barbara is cold cyan glass: chat rows as cards, All/Groups/Channels filters and folder chips on one row. It has a light and a dark palette and picks the right one from your ambience. It is the default theme for new installs; everyone else can pick it in Settings → Appearance with the three Silica / Neon / Barbara pills.",
        "Channel «article» posts can now be read: big title, photo, text, lists and links, like in the official app, instead of «unsupported message».",
        "With Telegram Premium you can write articles: the paperclip opens a full-page editor with titles, subtitles, bold and italic shown while you type, bullet lists, links and photos. A sent article can be edited too.",
        "Bots: a bot's fixed buttons now sit above the input bar, like in the official app, instead of scrolling away with the messages. The keyboard button next to the paperclip hides and shows them.",
        "The Telegram engine is updated: polls, articles and other new messages no longer show up as «unsupported», and live locations follow the new format.",
        "Links, usernames and every other link in messages are now light sky blue, easy to read on dark themes.",
        "Forums: the «General» topic loads recent messages again and its counter goes down. Long-press a topic to mark it as read, and in normal groups «mark all as read» is back.",
        "Folder counters update right away, the «All» filter really shows every chat, and the channel counter that used to get stuck now clears.",
        "Fixed sending a word you had just typed: the button stayed dim, or only part of a just-corrected word was sent. Now everything goes with the first tap."
    ],
    "de": [
        "Neues Thema \"Barbara\": PROBIERT ES AUS!",
        "Barbara ist kaltes Glas in Cyan: Chat-Zeilen als Karten, Filter Alle/Gruppen/Kanäle und Ordner als Chips in einer Zeile. Es hat eine helle und eine dunkle Palette und wählt die passende selbst nach dem Ambiente. Bei Neuinstallationen ist es das Standardthema; alle anderen wählen es unter Einstellungen → Aussehen mit den drei Pillen Silica / Neon / Barbara.",
        "«Artikel»-Beiträge von Kanälen sind jetzt lesbar: großer Titel, Foto, Text, Listen und Links wie in der offiziellen App, statt «nicht unterstützte Nachricht».",
        "Mit Telegram Premium kannst du Artikel schreiben: die Büroklammer öffnet einen ganzseitigen Editor mit Titeln, Untertiteln, fett und kursiv schon beim Tippen sichtbar, Aufzählungen, Links und Fotos. Ein gesendeter Artikel lässt sich auch bearbeiten.",
        "Bots: die festen Tasten eines Bots stehen jetzt über der Eingabeleiste wie in der offiziellen App, statt mit den Nachrichten wegzuscrollen. Die Tastatur-Taste neben der Büroklammer blendet sie aus und wieder ein.",
        "Die Telegram-Engine ist aktualisiert: Umfragen, Artikel und andere neue Nachrichten erscheinen nicht mehr als «nicht unterstützt», und Live-Standorte folgen dem neuen Format.",
        "Links, Benutzernamen und alle anderen Verweise in Nachrichten sind jetzt hellblau und auf dunklen Themen gut lesbar.",
        "Foren: das Thema «General» lädt wieder neue Nachrichten und sein Zähler sinkt. Langes Drücken auf ein Thema markiert es als gelesen, und in normalen Gruppen ist «alles als gelesen markieren» zurück.",
        "Ordnerzähler aktualisieren sich sofort, der Filter «Alle» zeigt wirklich alle Chats, und der Kanalzähler, der hängen blieb, geht jetzt auf null.",
        "Senden eines gerade getippten Wortes korrigiert: die Taste blieb dunkel oder es ging nur ein Teil des eben korrigierten Wortes raus. Jetzt geht alles beim ersten Tipp."
    ],
    "pl": [
        "Nowy motyw \"Barbara\": WYPRÓBUJCIE GO!",
        "Barbara to zimne szkło w kolorze cyjan: wiersze czatów jako karty, filtry Wszystkie/Grupy/Kanały i foldery jako pastylki w jednym rzędzie. Ma jasną i ciemną paletę i sama dobiera właściwą według ambience. Przy nowych instalacjach to motyw domyślny; pozostali wybierają go w Ustawienia → Wygląd trzema pigułkami Silica / Neon / Barbara.",
        "Posty kanałów typu «artykuł» są teraz czytelne: duży tytuł, zdjęcie, tekst, listy i linki, jak w oficjalnej aplikacji, zamiast «nieobsługiwana wiadomość».",
        "Z Telegram Premium możesz pisać artykuły: spinacz otwiera edytor na całą stronę z tytułami, podtytułami, pogrubieniem i kursywą widocznymi podczas pisania, listami, linkami i zdjęciami. Wysłany artykuł można też edytować.",
        "Boty: stałe przyciski bota są teraz nad paskiem pisania, jak w oficjalnej aplikacji, zamiast przewijać się razem z wiadomościami. Przycisk klawiatury obok spinacza je ukrywa i pokazuje.",
        "Zaktualizowano silnik Telegrama: ankiety, artykuły i inne nowe wiadomości nie pokazują się już jako «nieobsługiwane», a lokalizacje na żywo korzystają z nowego formatu.",
        "Linki, nazwy użytkowników i wszystkie inne odnośniki w wiadomościach są teraz jasnobłękitne, dobrze czytelne w ciemnych motywach.",
        "Fora: temat «General» znowu wczytuje nowe wiadomości, a jego licznik spada. Długie przytrzymanie tematu oznacza go jako przeczytany, a w zwykłych grupach wraca «oznacz wszystko jako przeczytane».",
        "Liczniki folderów aktualizują się od razu, filtr «Wszystkie» naprawdę pokazuje wszystkie czaty, a licznik kanałów, który się zacinał, teraz się zeruje.",
        "Poprawione wysyłanie dopiero co napisanego słowa: przycisk pozostawał wygaszony albo wychodziła tylko część poprawionego słowa. Teraz wszystko idzie za pierwszym dotknięciem."
    ],
    "ru": [
        "Новая тема \"Barbara\": ПОПРОБУЙТЕ ЕЁ!",
        "Barbara — это холодное бирюзовое стекло: строки чатов в виде карточек, фильтры Все/Группы/Каналы и папки чипами в одну строку. У неё светлая и тёмная палитры, и она сама выбирает нужную по амбиенсу. При новой установке это тема по умолчанию; остальные могут выбрать её в Настройки → Внешний вид тремя кнопками Silica / Neon / Barbara.",
        "Посты-«статьи» каналов теперь читаются: крупный заголовок, фото, текст, списки и ссылки, как в официальном приложении, вместо «неподдерживаемого сообщения».",
        "С Telegram Premium можно писать статьи: скрепка открывает редактор на весь экран с заголовками, подзаголовками, жирным и курсивом прямо при наборе, маркированными списками, ссылками и фото. Отправленную статью можно редактировать.",
        "Боты: постоянные кнопки бота теперь находятся над строкой ввода, как в официальном приложении, а не уезжают вверх вместе с сообщениями. Кнопка с клавиатурой рядом со скрепкой скрывает и показывает их.",
        "Обновлён движок Telegram: опросы, статьи и другие новые сообщения больше не показываются как «неподдерживаемые», а трансляция геопозиции использует новый формат.",
        "Ссылки, имена пользователей и все прочие ссылки в сообщениях теперь светло-голубые и хорошо читаются в тёмных темах.",
        "Форумы: тема «General» снова загружает новые сообщения, и её счётчик уменьшается. Долгое нажатие на тему отмечает её прочитанной, а в обычных группах вернулся пункт «отметить всё как прочитанное».",
        "Счётчики папок обновляются сразу, фильтр «Все» действительно показывает все чаты, а зависавший счётчик каналов теперь обнуляется.",
        "Исправлена отправка только что набранного слова: кнопка оставалась тусклой или уходила лишь часть исправленного слова. Теперь всё уходит с первого нажатия."
    ],
    "fr": [
        "Nouveau thème \"Barbara\" : ESSAYEZ-LE !",
        "Barbara, c'est du verre froid cyan : lignes de discussion en cartes, filtres Toutes/Groupes/Canaux et dossiers en pastilles sur une ligne. Il a une palette claire et une sombre et choisit tout seul la bonne selon l'ambiance. C'est le thème par défaut des nouvelles installations ; les autres le choisissent dans Paramètres → Apparence avec les trois pilules Silica / Neon / Barbara.",
        "Les publications « article » des canaux se lisent maintenant : grand titre, photo, texte, listes et liens, comme dans l'application officielle, au lieu de « message non pris en charge ».",
        "Avec Telegram Premium vous pouvez écrire des articles : le trombone ouvre un éditeur pleine page avec titres, sous-titres, gras et italique visibles pendant la saisie, listes à puces, liens et photos. Un article envoyé peut aussi être modifié.",
        "Bots : les boutons fixes d'un bot sont désormais au-dessus de la barre de saisie, comme dans l'application officielle, au lieu de défiler avec les messages. Le bouton clavier à côté du trombone les masque et les réaffiche.",
        "Le moteur Telegram est mis à jour : sondages, articles et autres nouveaux messages n'apparaissent plus comme « non pris en charge », et les positions en direct suivent le nouveau format.",
        "Les liens, noms d'utilisateur et tous les autres liens des messages sont maintenant bleu ciel clair, bien lisibles sur les thèmes sombres.",
        "Forums : le sujet « General » charge de nouveau les messages récents et son compteur baisse. Un appui long sur un sujet le marque comme lu, et dans les groupes normaux « tout marquer comme lu » revient.",
        "Les compteurs des dossiers se mettent à jour tout de suite, le filtre « Toutes » montre vraiment toutes les discussions, et le compteur des canaux qui restait bloqué se remet à zéro.",
        "Envoi d'un mot tout juste écrit corrigé : le bouton restait éteint, ou seule une partie du mot corrigé partait. Maintenant tout part au premier appui."
    ],
    "sk": [
        "Nová téma \"Barbara\": VYSKÚŠAJTE JU!",
        "Barbara je studené sklo v azúrovej: riadky četov ako karty, filtre Všetky/Skupiny/Kanály a priečinky ako štítky v jednom riadku. Má svetlú aj tmavú paletu a správnu si vyberie sama podľa ambientu. Pri nových inštaláciách je predvolenou témou; ostatní si ju vyberú v Nastavenia → Vzhľad tromi tlačidlami Silica / Neon / Barbara.",
        "Príspevky kanálov typu «článok» sa teraz dajú čítať: veľký nadpis, fotka, text, zoznamy a odkazy ako v oficiálnej aplikácii, namiesto «nepodporovaná správa».",
        "S Telegram Premium môžete písať články: kancelárska spinka otvorí editor na celú stránku s nadpismi, podnadpismi, tučným písmom a kurzívou viditeľnými počas písania, odrážkami, odkazmi a fotkami. Odoslaný článok sa dá aj upraviť.",
        "Boty: pevné tlačidlá bota sú teraz nad riadkom na písanie ako v oficiálnej aplikácii, namiesto toho, aby odchádzali so správami. Tlačidlo klávesnice vedľa spinky ich skryje a znova zobrazí.",
        "Aktualizované jadro Telegramu: ankety, články a ďalšie nové správy sa už nezobrazujú ako «nepodporované» a polohy v reálnom čase používajú nový formát.",
        "Odkazy, používateľské mená a všetky ďalšie prepojenia v správach sú teraz svetlomodré a dobre čitateľné v tmavých témach.",
        "Fóra: téma «General» opäť načítava nové správy a jej počítadlo klesá. Dlhým podržaním témy ju označíte ako prečítanú a v bežných skupinách sa vracia «označiť všetko ako prečítané».",
        "Počítadlá priečinkov sa aktualizujú hneď, filter «Všetky» naozaj ukazuje všetky čety a počítadlo kanálov, ktoré zamŕzalo, sa teraz vynuluje.",
        "Opravené odosielanie práve napísaného slova: tlačidlo zostávalo zhasnuté alebo odišla len časť opraveného slova. Teraz všetko odíde na prvý dotyk."
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
