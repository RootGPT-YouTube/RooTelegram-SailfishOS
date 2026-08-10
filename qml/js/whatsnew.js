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

var version = "2.9";

var changelogByLang = {
    "it": [
        "L'app non si apre più da sola a tutto schermo mentre stai facendo altro: quando si riavvia in background per liberare memoria, ora resta in background.",
        "Se scarichi due file diversi con lo stesso nome, ora li apri davvero entrambi: il secondo viene salvato come «Nome (1).pdf» invece di riaprire il primo.",
        "Foto e video salvati: probabile miglioramento per le app Android che li rifiutavano dicendo «formato non supportato». Se ti capitava, riprova e fai sapere se è risolto.",
        "Corretta la dicitura del conteggio delle Storie."
    ],
    "en": [
        "The app no longer opens by itself in fullscreen while you are doing something else: when it restarts in the background to free memory, it now stays in the background.",
        "If you download two different files with the same name, you now really get both: the second one is saved as \"Name (1).pdf\" instead of reopening the first.",
        "Saved photos and videos: likely improvement for the Android apps that refused them saying \"format not supported\". If this happened to you, please try again and let us know whether it is fixed.",
        "Fixed the wording of the story counter."
    ],
    "de": [
        "Die App öffnet sich nicht mehr von selbst im Vollbild, während du etwas anderes tust: wenn sie im Hintergrund neu startet, um Speicher freizugeben, bleibt sie jetzt im Hintergrund.",
        "Wenn du zwei verschiedene Dateien mit gleichem Namen herunterlädst, erhältst du jetzt wirklich beide: die zweite wird als „Name (1).pdf“ gespeichert, statt die erste erneut zu öffnen.",
        "Gespeicherte Fotos und Videos: wahrscheinliche Verbesserung für Android-Apps, die sie mit „Format nicht unterstützt“ abgelehnt haben. Falls dir das passiert ist, versuche es erneut und melde, ob es behoben ist.",
        "Formulierung der Story-Zählung korrigiert."
    ],
    "pl": [
        "Aplikacja nie otwiera się już sama na pełnym ekranie, gdy robisz coś innego: gdy uruchamia się ponownie w tle, aby zwolnić pamięć, teraz pozostaje w tle.",
        "Jeśli pobierzesz dwa różne pliki o tej samej nazwie, otrzymasz teraz naprawdę oba: drugi zostanie zapisany jako „Nazwa (1).pdf”, zamiast otwierać ponownie pierwszy.",
        "Zapisane zdjęcia i filmy: prawdopodobna poprawa dla aplikacji Android, które odrzucały je z komunikatem „format nieobsługiwany”. Jeśli ci się to zdarzało, spróbuj ponownie i daj znać, czy problem zniknął.",
        "Poprawiono brzmienie licznika relacji."
    ],
    "ru": [
        "Приложение больше не открывается само на весь экран, пока вы заняты другим: перезапускаясь в фоне для освобождения памяти, оно теперь остаётся в фоне.",
        "Если скачать два разных файла с одинаковым именем, теперь вы действительно получите оба: второй сохраняется как «Имя (1).pdf», а не открывает первый заново.",
        "Сохранённые фото и видео: вероятное улучшение для Android-приложений, которые отклоняли их с сообщением «формат не поддерживается». Если с вами такое случалось, попробуйте снова и сообщите, помогло ли это.",
        "Исправлена формулировка счётчика историй."
    ],
    "fr": [
        "L'application ne s'ouvre plus d'elle-même en plein écran pendant que vous faites autre chose : lorsqu'elle redémarre en arrière-plan pour libérer de la mémoire, elle y reste désormais.",
        "Si vous téléchargez deux fichiers différents portant le même nom, vous obtenez maintenant vraiment les deux : le second est enregistré sous « Nom (1).pdf » au lieu de rouvrir le premier.",
        "Photos et vidéos enregistrées : amélioration probable pour les applications Android qui les refusaient en indiquant « format non pris en charge ». Si cela vous arrivait, réessayez et dites-nous si c'est réglé.",
        "Correction du libellé du compteur de stories."
    ],
    "sk": [
        "Aplikácia sa už neotvára sama na celú obrazovku, kým robíte niečo iné: keď sa na pozadí restartuje, aby uvolnila pamäť, teraz zostáva na pozadí.",
        "Ak si stiahnete dva rôzne súbory s rovnakým názvom, teraz dostanete skutočne oba: druhý sa uloží ako „Názov (1).pdf“, namiesto opätovného otvorenia prvého.",
        "Uložené fotografie a videá: pravdepodobné zlepšenie pre aplikácie Android, ktoré ich odmietali s hlásením „nepodporovaný formát“. Ak sa vám to stávalo, skúste to znova a dajte vedieť, či je to vyriešené.",
        "Opravená formulácia počítadla príbehov."
    ]
};

var messageByLang = {
    "it": "Aggiornamento medio: l'app non salta più in primo piano da sola, e i file con lo stesso nome non si sovrappongono più.",
    "en": "Medium update: the app no longer jumps to the foreground by itself, and files with the same name no longer overwrite each other.",
    "de": "Mittleres Update: die App springt nicht mehr von selbst in den Vordergrund, und Dateien mit gleichem Namen überdecken sich nicht mehr.",
    "pl": "Średnia aktualizacja: aplikacja nie wyskakuje już sama na pierwszy plan, a pliki o tej samej nazwie nie nadpisują się wzajemnie.",
    "ru": "Среднее обновление: приложение больше не выходит на передний план само, а файлы с одинаковым именем больше не перекрывают друг друга.",
    "fr": "Mise à jour intermédiaire : l'application ne passe plus au premier plan d'elle-même, et les fichiers de même nom ne se recouvrent plus.",
    "sk": "Stredná aktualizácia: aplikácia už sama neskočí do popredia a súbory s rovnakým názvom sa už neprekrývajú."
};

// Restituisce il changelog/messaggio per la lingua data (codice a 2 lettere),
// con fallback a "en". Usati dal WhatsNewDialog.
function changelogFor(lang) {
    return changelogByLang[lang] || changelogByLang["en"];
}

function messageFor(lang) {
    return (lang in messageByLang) ? messageByLang[lang] : messageByLang["en"];
}
