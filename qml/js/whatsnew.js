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

var version = "2.7.1";

var changelogByLang = {
    "it": [
        "Consumo RAM: risolta la crescita continua della memoria quando RooTelegram resta attivo in background per ore o giorni. Nei momenti di inattività l'app ricicla automaticamente la connessione a Telegram e restituisce al sistema la memoria che prima restava occupata (poteva superare 1 GB dopo una giornata). Connessione e notifiche riprendono da soli, senza dover rifare l'accesso.",
        "Posizione in tempo reale (Live Location): condividi la tua posizione che si aggiorna automaticamente per 15 minuti, 1 ora o 8 ore. Mentre il GPS si aggancia compare l'avviso “ottengo posizione…”. Puoi anche inviare la posizione attuale una sola volta.",
        "Caricamento chat: corretto il caso in cui una conversazione si apriva mostrando solo 3-4 messaggi; ora la cronologia compare completa.",
        "Le azioni del menu \"Opzioni aggiuntive\" (tieni premuto su un messaggio in un gruppo) ora funzionano: bannare l'autore, eliminare tutti i suoi messaggi, segnalarlo come spam ed eliminare il messaggio. Prima il menu si apriva ma i comandi non avevano effetto.",
        "Tema Silica: lo sfondo del menu nella schermata principale è ora opaco e si adatta al tema chiaro o scuro, invece di restare arancione (poco leggibile sui temi chiari).",
        "Traduzioni: corretti alcuni testi che comparivano in italiano nelle schermate \"Nuovo Canale\" e \"Nuovo Gruppo\" (ora traducibili in tutte le lingue) e sistemate alcune frasi di sistema in slovacco. Grazie a okruhliak per le segnalazioni.",
        "La voce \"Copia messaggio negli appunti\" è stata accorciata in \"Copia messaggio\"."
    ],
    "en": [
        "Memory usage: fixed the steady RAM growth when RooTelegram stays active in the background for hours or days. While idle, the app now automatically recycles its connection to Telegram and returns to the system the memory that used to stay locked up (it could exceed 1 GB after a day). Connection and notifications resume on their own, with no need to sign in again.",
        "Live location sharing: share your position updating automatically for 15 minutes, 1 hour or 8 hours. While the GPS gets a fix you see an “obtaining position…” notice. You can also send your current location just once.",
        "Chat loading: fixed the case where a conversation opened showing only 3-4 messages; the full history now appears.",
        "The actions in the \"More options\" menu (long-press a message in a group) now work: ban the sender, delete all their messages, report them as spam, and delete the message. Before, the menu opened but the commands had no effect.",
        "Silica theme: the title menu background on the home screen is now opaque and adapts to the light or dark ambience, instead of staying orange (hard to read on light themes).",
        "Translations: fixed some texts that appeared in Italian on the \"New Channel\" and \"New Group\" screens (now translatable in every language) and corrected some Slovak system messages. Thanks to okruhliak for the reports.",
        "The \"Copy Message to Clipboard\" entry was shortened to \"Copy Message\"."
    ],
    "de": [
        "Speicherverbrauch: Das stetige Anwachsen des RAM behoben, wenn RooTelegram stunden- oder tagelang im Hintergrund aktiv bleibt. In Ruhephasen erneuert die App automatisch die Verbindung zu Telegram und gibt den zuvor belegten Speicher an das System zurück (er konnte nach einem Tag über 1 GB liegen). Verbindung und Benachrichtigungen laufen von selbst weiter, ohne erneute Anmeldung.",
        "Live-Standort: Teile deinen Standort, der sich 15 Minuten, 1 Stunde oder 8 Stunden lang automatisch aktualisiert. Während das GPS einen Fix sucht, erscheint der Hinweis „Position wird ermittelt…“. Du kannst deinen aktuellen Standort auch einmalig senden.",
        "Laden von Chats: Der Fall behoben, dass eine Unterhaltung nur mit 3-4 Nachrichten geöffnet wurde; der vollständige Verlauf erscheint nun.",
        "Die Aktionen im Menü „Weitere Optionen“ (langes Drücken auf eine Nachricht in einer Gruppe) funktionieren jetzt: Absender sperren, alle seine Nachrichten löschen, als Spam melden und die Nachricht löschen. Zuvor öffnete sich das Menü, aber die Befehle hatten keine Wirkung.",
        "Silica-Thema: Der Hintergrund des Titelmenüs auf dem Startbildschirm ist nun deckend und passt sich dem hellen oder dunklen Ambiente an, statt orange zu bleiben (auf hellen Themes schwer lesbar).",
        "Übersetzungen: Einige Texte korrigiert, die auf den Bildschirmen „Neuer Kanal“ und „Neue Gruppe“ auf Italienisch erschienen (jetzt in alle Sprachen übersetzbar), und einige slowakische Systemmeldungen verbessert. Danke an okruhliak für die Hinweise.",
        "Der Eintrag „Nachricht in die Zwischenablage kopieren“ wurde zu „Nachricht kopieren“ verkürzt."
    ],
    "pl": [
        "Zużycie pamięci: naprawiono ciągły wzrost RAM, gdy RooTelegram pozostaje aktywny w tle przez wiele godzin lub dni. W okresach bezczynności aplikacja automatycznie odświeża połączenie z Telegramem i zwraca systemowi zajmowaną wcześniej pamięć (po dniu mogła przekroczyć 1 GB). Połączenie i powiadomienia wznawiają się same, bez potrzeby ponownego logowania.",
        "Lokalizacja na żywo: udostępnij swoją pozycję, która aktualizuje się automatycznie przez 15 minut, 1 godzinę lub 8 godzin. Gdy GPS ustala pozycję, pojawia się komunikat „ustalanie pozycji…”. Możesz też wysłać bieżącą lokalizację jednorazowo.",
        "Wczytywanie czatów: naprawiono przypadek, w którym rozmowa otwierała się z zaledwie 3-4 wiadomościami; teraz pojawia się pełna historia.",
        "Działania w menu „Więcej opcji” (przytrzymaj wiadomość w grupie) teraz działają: zablokuj nadawcę, usuń wszystkie jego wiadomości, zgłoś jako spam i usuń wiadomość. Wcześniej menu się otwierało, ale polecenia nie miały efektu.",
        "Motyw Silica: tło menu tytułowego na ekranie głównym jest teraz nieprzezroczyste i dostosowuje się do jasnej lub ciemnej kompozycji, zamiast pozostawać pomarańczowe (słabo czytelne na jasnych motywach).",
        "Tłumaczenia: poprawiono niektóre teksty wyświetlane po włosku na ekranach „Nowy kanał” i „Nowa grupa” (teraz przetłumaczalne na każdy język) oraz poprawiono kilka słowackich komunikatów systemowych. Dziękujemy okruhliakowi za zgłoszenia.",
        "Pozycja „Kopiuj wiadomość do schowka” została skrócona do „Kopiuj wiadomość”."
    ],
    "ru": [
        "Потребление памяти: устранён постоянный рост ОЗУ, когда RooTelegram остаётся активным в фоне часами или сутками. В периоды простоя приложение автоматически обновляет подключение к Telegram и возвращает системе ранее занятую память (через сутки она могла превышать 1 ГБ). Подключение и уведомления возобновляются сами, без повторного входа.",
        "Трансляция местоположения: делитесь своей позицией, которая обновляется автоматически в течение 15 минут, 1 часа или 8 часов. Пока GPS определяет местоположение, показывается уведомление «определение местоположения…». Можно отправить и текущее местоположение один раз.",
        "Загрузка чатов: исправлен случай, когда беседа открывалась всего с 3-4 сообщениями; теперь отображается полная история.",
        "Действия в меню «Дополнительно» (долгое нажатие на сообщение в группе) теперь работают: заблокировать отправителя, удалить все его сообщения, пожаловаться на спам и удалить сообщение. Раньше меню открывалось, но команды не давали эффекта.",
        "Тема Silica: фон меню заголовка на главном экране теперь непрозрачный и подстраивается под светлое или тёмное оформление, а не остаётся оранжевым (плохо читался на светлых темах).",
        "Переводы: исправлены некоторые тексты, отображавшиеся по-итальянски на экранах «Новый канал» и «Новая группа» (теперь переводятся на любой язык), и улучшены некоторые системные сообщения на словацком. Спасибо okruhliak за сообщения.",
        "Пункт «Копировать сообщение в буфер обмена» сокращён до «Копировать сообщение»."
    ],
    "fr": [
        "Consommation de mémoire : corrigée la croissance continue de la RAM lorsque RooTelegram reste actif en arrière-plan pendant des heures ou des jours. En période d'inactivité, l'application renouvelle automatiquement sa connexion à Telegram et rend au système la mémoire auparavant occupée (elle pouvait dépasser 1 Go après une journée). La connexion et les notifications reprennent d'elles-mêmes, sans avoir à se reconnecter.",
        "Position en direct : partagez votre position qui se met à jour automatiquement pendant 15 minutes, 1 heure ou 8 heures. Pendant que le GPS se cale, l'avis « obtention de la position… » s'affiche. Vous pouvez aussi envoyer votre position actuelle une seule fois.",
        "Chargement des conversations : corrigé le cas où une conversation s'ouvrait en n'affichant que 3-4 messages ; l'historique complet apparaît désormais.",
        "Les actions du menu « Plus d'options » (appui long sur un message dans un groupe) fonctionnent désormais : bannir l'expéditeur, supprimer tous ses messages, le signaler comme spam et supprimer le message. Auparavant, le menu s'ouvrait mais les commandes restaient sans effet.",
        "Thème Silica : l'arrière-plan du menu de titre sur l'écran d'accueil est maintenant opaque et s'adapte à l'ambiance claire ou sombre, au lieu de rester orange (peu lisible sur les thèmes clairs).",
        "Traductions : corrigés certains textes qui apparaissaient en italien sur les écrans « Nouvelle chaîne » et « Nouveau groupe » (désormais traduisibles dans toutes les langues) et amélioré quelques messages système en slovaque. Merci à okruhliak pour les signalements.",
        "L'entrée « Copier le message dans le presse-papiers » a été raccourcie en « Copier le message »."
    ],
    "sk": [
        "Spotreba pamäte: opravený trvalý nárast RAM, keď RooTelegram zostáva aktívny na pozadí hodiny alebo dni. V čase nečinnosti aplikácia automaticky obnoví spojenie s Telegramom a vráti systému predtým obsadenú pamäť (po dni mohla presiahnuť 1 GB). Spojenie a upozornenia pokračujú samy, bez opätovného prihlásenia.",
        "Poloha naživo: zdieľajte svoju polohu, ktorá sa automaticky aktualizuje počas 15 minút, 1 hodiny alebo 8 hodín. Kým GPS zameriava polohu, zobrazí sa oznam „zisťujem polohu…“. Aktuálnu polohu môžete poslať aj jednorazovo.",
        "Načítavanie konverzácií: opravený prípad, keď sa konverzácia otvorila len s 3-4 správami; teraz sa zobrazí celá história.",
        "Akcie v ponuke „Ďalšie možnosti“ (podržte správu v skupine) teraz fungujú: zablokovať odosielateľa, odstrániť všetky jeho správy, nahlásiť ako spam a odstrániť správu. Predtým sa ponuka otvorila, ale príkazy nemali účinok.",
        "Téma Silica: pozadie ponuky názvu na domovskej obrazovke je teraz nepriehľadné a prispôsobuje sa svetlému alebo tmavému prostrediu namiesto toho, aby zostalo oranžové (na svetlých témach ťažko čitateľné).",
        "Preklady: opravené niektoré texty, ktoré sa zobrazovali v taliančine na obrazovkách „Nový kanál“ a „Nová skupina“ (teraz preložiteľné do každého jazyka), a vylepšené niektoré slovenské systémové správy. Ďakujeme používateľovi okruhliak za hlásenia.",
        "Položka „Kopírovať správu do schránky“ bola skrátená na „Kopírovať správu“."
    ]
};

var messageByLang = {
    "it": "Due novità principali in questa versione. La prima è sotto il cofano: il consumo di memoria non cresce più senza sosta quando tieni RooTelegram attivo in background — a riposo l'app ricicla la connessione a Telegram e restituisce la RAM al sistema, in modo trasparente. La seconda è la condivisione della Posizione in tempo reale (Live Location), per 15 minuti, 1 ora o 8 ore. Sistemati inoltre i comandi da amministratore nel menu a pressione prolungata sui messaggi.",
    "en": "Two main changes in this version. The first is under the hood: memory usage no longer grows without bound when you keep RooTelegram active in the background — while idle, the app recycles its connection to Telegram and returns the RAM to the system, transparently. The second is live location sharing, for 15 minutes, 1 hour or 8 hours. The administrator commands in the long-press message menu have also been fixed.",
    "de": "Zwei wichtige Neuerungen in dieser Version. Die erste steckt unter der Haube: Der Speicherverbrauch wächst nicht mehr unbegrenzt, wenn du RooTelegram im Hintergrund aktiv hältst — in Ruhephasen erneuert die App die Verbindung zu Telegram und gibt den RAM transparent an das System zurück. Die zweite ist das Teilen des Live-Standorts, für 15 Minuten, 1 Stunde oder 8 Stunden. Außerdem wurden die Administrator-Befehle im Menü beim langen Drücken auf Nachrichten korrigiert.",
    "pl": "Dwie główne nowości w tej wersji. Pierwsza jest pod maską: zużycie pamięci nie rośnie już bez końca, gdy RooTelegram pozostaje aktywny w tle — w bezczynności aplikacja odświeża połączenie z Telegramem i zwraca RAM systemowi w sposób przezroczysty. Druga to udostępnianie lokalizacji na żywo, na 15 minut, 1 godzinę lub 8 godzin. Poprawiono również polecenia administratora w menu po przytrzymaniu wiadomości.",
    "ru": "Два главных новшества в этой версии. Первое — под капотом: потребление памяти больше не растёт без предела, когда RooTelegram активен в фоне — в простое приложение обновляет подключение к Telegram и прозрачно возвращает ОЗУ системе. Второе — трансляция местоположения, на 15 минут, 1 час или 8 часов. Кроме того, исправлены команды администратора в меню при долгом нажатии на сообщение.",
    "fr": "Deux nouveautés principales dans cette version. La première est sous le capot : la consommation de mémoire ne croît plus sans limite lorsque vous gardez RooTelegram actif en arrière-plan — au repos, l'application renouvelle sa connexion à Telegram et rend la RAM au système, de façon transparente. La seconde est le partage de la position en direct, pour 15 minutes, 1 heure ou 8 heures. Les commandes d'administrateur du menu par appui long sur les messages ont aussi été corrigées.",
    "sk": "Dve hlavné novinky v tejto verzii. Prvá je pod kapotou: spotreba pamäte už nerastie bez obmedzenia, keď necháte RooTelegram aktívny na pozadí — v nečinnosti aplikácia obnoví spojenie s Telegramom a transparentne vráti RAM systému. Druhou je zdieľanie polohy naživo, na 15 minút, 1 hodinu alebo 8 hodín. Opravené boli aj príkazy administrátora v ponuke po podržaní správy."
};

// Restituisce il changelog/messaggio per la lingua data (codice a 2 lettere),
// con fallback a "en". Usati dal WhatsNewDialog.
function changelogFor(lang) {
    return changelogByLang[lang] || changelogByLang["en"];
}

function messageFor(lang) {
    return (lang in messageByLang) ? messageByLang[lang] : messageByLang["en"];
}
