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

var version = "2.9.2";

var changelogByLang = {
    "it": [
        "Le chiamate ora si comportano come una telefonata normale: lo schermo si accende da solo e la schermata per rispondere compare sopra il blocco, anche se hai il codice di sicurezza. Rispondi, riaggancia, vivavoce e microfono si comandano dai controlli di sistema.",
        "Nei gruppi con i topic, aprendone uno torni dove eri rimasto invece di finire in fondo, e il contatore dei non letti scala man mano che leggi.",
        "Il numero di messaggi non letti di un gruppo con topic ora e' giusto gia' nella lista delle chat, senza dover entrare nel gruppo.",
        "I messaggi vocali ora vengono registrati nel formato richiesto da Telegram: dovrebbero sentirsi anche sugli iPhone, che prima li ricevevano vuoti.",
        "L'app non si chiude piu' all'improvviso mentre libera memoria in background, e sono state corrette alcune icone che non comparivano."
    ],
    "en": [
        "Calls now behave like a regular phone call: the screen turns on by itself and the answer screen appears above the lock screen, even with a security code set. Answer, hang up, speaker and microphone are all controlled from the system controls.",
        "In groups with topics, opening one takes you back to where you left off instead of jumping to the end, and the unread counter goes down as you read.",
        "The unread count of a group with topics is now correct already in the chat list, without having to enter the group.",
        "Voice messages are now recorded in the format Telegram requires: they should play on iPhones too, which used to receive them empty.",
        "The app no longer closes unexpectedly while freeing memory in the background, and a few missing icons have been fixed."
    ],
    "de": [
        "Anrufe verhalten sich jetzt wie ein normales Telefonat: der Bildschirm schaltet sich von selbst ein und der Annahmebildschirm erscheint uber dem Sperrbildschirm, auch mit Sicherheitscode. Annehmen, Auflegen, Lautsprecher und Mikrofon werden uber die Systemsteuerung bedient.",
        "In Gruppen mit Themen landest du beim Offnen wieder dort, wo du aufgehort hast, statt am Ende, und der Zahler ungelesener Nachrichten sinkt beim Lesen.",
        "Die Anzahl ungelesener Nachrichten einer Themengruppe stimmt jetzt schon in der Chatliste, ohne die Gruppe zu offnen.",
        "Sprachnachrichten werden jetzt in dem von Telegram verlangten Format aufgenommen: sie sollten auch auf iPhones abspielbar sein.",
        "Die App schliesst sich nicht mehr unerwartet beim Freigeben von Speicher, und einige fehlende Symbole wurden korrigiert."
    ],
    "pl": [
        "Polaczenia zachowuja sie teraz jak zwykla rozmowa telefoniczna: ekran wlacza sie sam, a ekran odbierania pojawia sie nad ekranem blokady, nawet z kodem zabezpieczajacym. Odbieranie, rozlaczanie, glosnik i mikrofon obslugujesz z panelu systemowego.",
        "W grupach z tematami po otwarciu wracasz tam, gdzie skonczyles, zamiast na koniec, a licznik nieprzeczytanych maleje w miare czytania.",
        "Liczba nieprzeczytanych wiadomosci grupy z tematami jest teraz poprawna juz na liscie czatow.",
        "Wiadomosci glosowe sa nagrywane w formacie wymaganym przez Telegram: powinny odtwarzac sie takze na iPhone'ach.",
        "Aplikacja nie zamyka sie juz niespodziewanie podczas zwalniania pamieci, poprawiono tez kilka brakujacych ikon."
    ],
    "ru": [
        "Звонки теперь ведут себя как обычный телефонный вызов: экран включается сам, а экран ответа появляется поверх блокировки, даже с кодом безопасности. Ответ, отбой, громкая связь и микрофон управляются системными кнопками.",
        "В группах с темами при открытии вы возвращаетесь туда, где остановились, а не в конец, и счётчик непрочитанных уменьшается по мере чтения.",
        "Число непрочитанных в группе с темами теперь верное уже в списке чатов, без входа в группу.",
        "Голосовые сообщения записываются в формате, который требует Telegram: они должны воспроизводиться и на iPhone.",
        "Приложение больше не закрывается неожиданно при освобождении памяти, исправлены несколько отсутствовавших значков."
    ],
    "fr": [
        "Les appels se comportent maintenant comme un vrai appel telephonique : l'ecran s'allume tout seul et l'ecran de reponse apparait par-dessus le verrouillage, meme avec un code de securite. Repondre, raccrocher, haut-parleur et micro se commandent depuis les controles du systeme.",
        "Dans les groupes avec sujets, en ouvrir un vous ramene la ou vous en etiez au lieu d'aller a la fin, et le compteur de non-lus diminue au fil de la lecture.",
        "Le nombre de non-lus d'un groupe avec sujets est desormais correct des la liste des conversations.",
        "Les messages vocaux sont enregistres dans le format exige par Telegram : ils devraient s'entendre aussi sur iPhone.",
        "L'application ne se ferme plus a l'improviste en liberant de la memoire, et quelques icones manquantes ont ete corrigees."
    ],
    "sk": [
        "Hovory sa teraz spravaju ako bezny telefonat: obrazovka sa zapne sama a obrazovka na prijatie sa zobrazi nad uzamknutou obrazovkou, aj s bezpecnostnym kodom. Prijatie, zavesenie, hlasity odposluch a mikrofon ovladate zo systemovych prvkov.",
        "V skupinach s temami sa po otvoreni vratite tam, kde ste skoncili, namiesto na koniec, a pocitadlo neprecitanych klesa pri citani.",
        "Pocet neprecitanych v skupine s temami je teraz spravny uz v zozname chatov.",
        "Hlasove spravy sa nahravaju vo formate, ktory Telegram vyzaduje: mali by sa prehrat aj na iPhonoch.",
        "Aplikacia sa uz nezatvara necakane pri uvolnovani pamate a opravenych bolo niekolko chybajucich ikon."
    ]
};

var messageByLang = {
    "it": "Le chiamate ora si comportano come vere telefonate, anche a schermo bloccato. Sistemati i topic e i loro contatori.",
    "en": "Calls now behave like real phone calls, even on the lock screen. Topics and their counters fixed.",
    "de": "Anrufe verhalten sich jetzt wie echte Telefonate, auch am Sperrbildschirm. Themen und ihre Zahler korrigiert.",
    "pl": "Polaczenia zachowuja sie jak prawdziwe rozmowy, takze na ekranie blokady. Naprawiono tematy i ich liczniki.",
    "ru": "Звонки теперь как настоящие телефонные вызовы, даже на экране блокировки. Исправлены темы и их счётчики.",
    "fr": "Les appels se comportent comme de vrais appels, meme sur l'ecran de verrouillage. Sujets et compteurs corriges.",
    "sk": "Hovory sa spravaju ako skutocne telefonaty, aj na uzamknutej obrazovke. Opravene temy a ich pocitadla."
};

// Restituisce il changelog/messaggio per la lingua data (codice a 2 lettere),
// con fallback a "en". Usati dal WhatsNewDialog.
function changelogFor(lang) {
    return changelogByLang[lang] || changelogByLang["en"];
}

function messageFor(lang) {
    return (lang in messageByLang) ? messageByLang[lang] : messageByLang["en"];
}
