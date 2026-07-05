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

var version = "2.8.9";

var changelogByLang = {
    "it": [
        "Sondaggi riparati: la creazione falliva e domande/risposte non venivano più visualizzate correttamente. Ora creazione (normale, anonimo, risposte multiple, quiz con spiegazione), voto, ritiro del voto, elenco dei votanti, risultati e chiusura funzionano di nuovo.",
        "La spiegazione dei quiz compare solo dopo aver risposto (o a sondaggio chiuso), non più in anticipo."
    ],
    "en": [
        "Polls fixed: creating them failed and questions/answers were no longer displayed correctly. Creation (regular, anonymous, multiple answers, quiz with explanation), voting, retracting your vote, the voter list, results and closing now work again.",
        "Quiz explanations only appear after you answer (or when the poll is closed), no longer in advance."
    ],
    "de": [
        "Umfragen repariert: das Erstellen schlug fehl und Fragen/Antworten wurden nicht mehr korrekt angezeigt. Erstellen (normal, anonym, Mehrfachantworten, Quiz mit Erklärung), Abstimmen, Stimme zurückziehen, Wählerliste, Ergebnisse und Schließen funktionieren jetzt wieder.",
        "Die Quiz-Erklärung erscheint erst nach der Antwort (oder bei geschlossener Umfrage), nicht mehr im Voraus."
    ],
    "pl": [
        "Naprawione ankiety: tworzenie kończyło się błędem, a pytania/odpowiedzi nie wyświetlały się już poprawnie. Tworzenie (zwykła, anonimowa, wielokrotny wybór, quiz z wyjaśnieniem), głosowanie, wycofanie głosu, lista głosujących, wyniki i zamykanie znów działają.",
        "Wyjaśnienie quizu pojawia się dopiero po udzieleniu odpowiedzi (lub po zamknięciu ankiety), a nie z wyprzedzeniem."
    ],
    "ru": [
        "Опросы исправлены: создание завершалось ошибкой, а вопросы и ответы отображались неправильно. Создание (обычный, анонимный, с несколькими ответами, викторина с пояснением), голосование, отзыв голоса, список проголосовавших, результаты и закрытие снова работают.",
        "Пояснение викторины появляется только после ответа (или при закрытом опросе), а не заранее."
    ],
    "fr": [
        "Sondages réparés : la création échouait et les questions/réponses ne s'affichaient plus correctement. La création (normal, anonyme, réponses multiples, quiz avec explication), le vote, le retrait du vote, la liste des votants, les résultats et la clôture fonctionnent à nouveau.",
        "L'explication des quiz n'apparaît qu'après avoir répondu (ou une fois le sondage clos), plus à l'avance."
    ],
    "sk": [
        "Ankety opravené: vytváranie zlyhávalo a otázky/odpovede sa už nezobrazovali správne. Vytváranie (bežná, anonymná, viac odpovedí, kvíz s vysvetlením), hlasovanie, stiahnutie hlasu, zoznam hlasujúcich, výsledky a zatvorenie opäť fungujú.",
        "Vysvetlenie kvízu sa zobrazí až po odpovedi (alebo pri zatvorenej ankete), už nie vopred."
    ]
};

var messageByLang = {
    "it": "Sondaggi riparati: creazione (normale, anonimo, multi-risposta, quiz), voto, ritiro del voto, risultati e chiusura ora funzionano. La spiegazione dei quiz compare solo dopo la risposta.",
    "en": "Polls fixed: creation (regular, anonymous, multiple answers, quiz), voting, retracting your vote, results and closing now work. Quiz explanations only appear after you answer.",
    "de": "Umfragen repariert: Erstellen (normal, anonym, Mehrfachantworten, Quiz), Abstimmen, Stimme zurückziehen, Ergebnisse und Schließen funktionieren jetzt. Die Quiz-Erklärung erscheint erst nach der Antwort.",
    "pl": "Naprawione ankiety: tworzenie (zwykła, anonimowa, wielokrotny wybór, quiz), głosowanie, wycofanie głosu, wyniki i zamykanie znów działają. Wyjaśnienie quizu pojawia się dopiero po odpowiedzi.",
    "ru": "Опросы исправлены: создание (обычный, анонимный, несколько ответов, викторина), голосование, отзыв голоса, результаты и закрытие теперь работают. Пояснение викторины появляется только после ответа.",
    "fr": "Sondages réparés : création (normal, anonyme, réponses multiples, quiz), vote, retrait du vote, résultats et clôture fonctionnent désormais. L'explication des quiz n'apparaît qu'après la réponse.",
    "sk": "Ankety opravené: vytváranie (bežná, anonymná, viac odpovedí, kvíz), hlasovanie, stiahnutie hlasu, výsledky a zatvorenie teraz fungujú. Vysvetlenie kvízu sa zobrazí až po odpovedi."
};

// Restituisce il changelog/messaggio per la lingua data (codice a 2 lettere),
// con fallback a "en". Usati dal WhatsNewDialog.
function changelogFor(lang) {
    return changelogByLang[lang] || changelogByLang["en"];
}

function messageFor(lang) {
    return (lang in messageByLang) ? messageByLang[lang] : messageByLang["en"];
}
