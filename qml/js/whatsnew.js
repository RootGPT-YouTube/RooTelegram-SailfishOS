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

var version = "3.7.3";

var changelogByLang = {
    "it": [
        "Nuovo: nelle storie c'è un tasto per salvarle sul telefono. Le foto vanno in Immagini/RooTelegram, i video in Download/RooTelegram. Le tue storie si possono salvare sempre, quelle degli altri solo se chi le ha pubblicate lo consente.",
        "Nuovo: puoi mettere i gruppi di emoji speciali nell'ordine che preferisci. Tieni premuto un gruppo per spostarlo all'inizio, a sinistra, a destra o in fondo, oppure per rimetterli tutti in ordine alfabetico. L'ordine è lo stesso anche nelle altre app di Telegram.",
        "Più chiaro: quando pubblichi una storia, la spiegazione di «Consenti screenshot» ora dice cosa fa davvero. Chi guarda la storia non può salvarla né inoltrarla; gli screenshot invece si possono bloccare solo dove il sistema del telefono lo permette alle app, e Sailfish OS non lo fa."
    ],
    "en": [
        "New: stories have a button to save them to your phone. Photos go to Pictures/RooTelegram, videos to Downloads/RooTelegram. Your own stories can always be saved, other people's only if whoever posted them allows it.",
        "New: you can put the groups of special emoji in the order you like. Press and hold a group to move it to the start, left, right or end, or to put them all back in alphabetical order. The order is the same in your other Telegram apps too.",
        "Clearer: when you post a story, the explanation of «Allow screenshots» now says what it really does. Viewers cannot save or forward the story; screenshots, instead, can only be blocked where the phone's system lets apps do it, and Sailfish OS does not."
    ],
    "de": [
        "Neu: Storys haben eine Taste, um sie auf dem Telefon zu speichern. Fotos landen in Bilder/RooTelegram, Videos in Downloads/RooTelegram. Eigene Storys lassen sich immer speichern, die von anderen nur, wenn die Person es erlaubt.",
        "Neu: Die Gruppen der Spezial-Emojis lassen sich beliebig anordnen. Halte eine Gruppe gedrückt, um sie an den Anfang, nach links, nach rechts oder ans Ende zu verschieben oder alle wieder alphabetisch zu sortieren. Die Reihenfolge gilt auch in deinen anderen Telegram-Apps.",
        "Klarer: Beim Veröffentlichen einer Story erklärt «Screenshots erlauben» jetzt, was es wirklich bewirkt. Betrachter können die Story weder speichern noch weiterleiten; Screenshots lassen sich dagegen nur blockieren, wo das System des Telefons es Apps erlaubt, und Sailfish OS tut das nicht."
    ],
    "pl": [
        "Nowość: relacje mają przycisk do zapisania ich w telefonie. Zdjęcia trafiają do Obrazy/RooTelegram, filmy do Pobrane/RooTelegram. Własne relacje można zapisać zawsze, cudze tylko wtedy, gdy autor na to pozwala.",
        "Nowość: grupy specjalnych emoji możesz ułożyć w dowolnej kolejności. Przytrzymaj grupę, aby przenieść ją na początek, w lewo, w prawo lub na koniec albo ułożyć wszystkie alfabetycznie. Kolejność jest taka sama w innych aplikacjach Telegrama.",
        "Jaśniej: przy publikowaniu relacji opis opcji «Zezwalaj na zrzuty ekranu» mówi teraz, co naprawdę robi. Oglądający nie mogą zapisać ani przekazać relacji; zrzuty ekranu można natomiast blokować tylko tam, gdzie system telefonu pozwala na to aplikacjom, a Sailfish OS tego nie robi."
    ],
    "ru": [
        "Новое: у историй появилась кнопка сохранения на телефон. Фото попадают в Изображения/RooTelegram, видео — в Загрузки/RooTelegram. Свои истории можно сохранять всегда, чужие — только если автор это разрешает.",
        "Новое: группы особых эмодзи можно расставить в любом порядке. Удерживайте группу, чтобы переместить её в начало, влево, вправо или в конец, или снова отсортировать все по алфавиту. Порядок тот же и в других приложениях Telegram.",
        "Понятнее: при публикации истории описание «Разрешить снимки экрана» теперь объясняет, что оно делает на самом деле. Зрители не могут сохранить или переслать историю; снимки экрана же можно заблокировать только там, где система телефона позволяет это приложениям, а Sailfish OS этого не делает."
    ],
    "fr": [
        "Nouveau : les stories ont un bouton pour les enregistrer sur le téléphone. Les photos vont dans Images/RooTelegram, les vidéos dans Téléchargements/RooTelegram. Vos stories peuvent toujours être enregistrées, celles des autres seulement si leur auteur l'autorise.",
        "Nouveau : vous pouvez ranger les groupes d'emoji spéciaux dans l'ordre que vous voulez. Appuyez longuement sur un groupe pour le déplacer au début, à gauche, à droite ou à la fin, ou pour tous les remettre par ordre alphabétique. L'ordre est le même dans vos autres applications Telegram.",
        "Plus clair : en publiant une story, l'explication de « Autoriser les captures d'écran » dit maintenant ce qu'elle fait vraiment. Ceux qui la regardent ne peuvent ni l'enregistrer ni la transférer ; les captures d'écran, elles, ne peuvent être bloquées que là où le système du téléphone le permet aux applications, et Sailfish OS ne le fait pas."
    ],
    "sk": [
        "Nové: príbehy majú tlačidlo na uloženie do telefónu. Fotky idú do Obrázky/RooTelegram, videá do Stiahnuté/RooTelegram. Vlastné príbehy sa dajú uložiť vždy, cudzie len vtedy, ak to autor dovolí.",
        "Nové: skupiny špeciálnych emoji si môžete usporiadať podľa seba. Podržte skupinu a presuňte ju na začiatok, doľava, doprava alebo na koniec, alebo ich všetky zoraďte abecedne. Poradie je rovnaké aj v ostatných aplikáciách Telegramu.",
        "Jasnejšie: pri zverejnení príbehu teraz popis «Povoliť snímku obrazovky» hovorí, čo naozaj robí. Diváci príbeh nemôžu uložiť ani preposlať; snímky obrazovky sa však dajú blokovať len tam, kde to systém telefónu aplikáciám umožňuje, a Sailfish OS to nerobí."
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
