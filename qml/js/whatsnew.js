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

var version = "3.1";

var changelogByLang = {
    "it": [
        "Chiamate e volume: questa versione è dedicata a un problema segnalato da diversi utenti. Grazie a chi l'ha segnalato!",
        "Suoneria e notifiche di nuovo a volume pieno dopo una chiamata. Dopo una chiamata fatta con RooTelegram, su telefoni come Xperia e Jolla l'audio restava sulla capsula dell'orecchio: suoneria, notifiche e musica uscivano bassissime da lì, come se il volume fosse calato del 90%, fino al riavvio del telefono. Ora a fine chiamata l'audio torna sempre all'altoparlante.",
        "Il volume multimediale non viene più toccato. Prima ogni chiamata portava di nascosto il volume multimediale al 90% e a fine chiamata lo riscriveva: a qualcuno saliva, a qualcuno scendeva, e restava così anche dopo. Ora RooTelegram non cambia più nessun volume del telefono: la chiamata parte al volume che hai scelto tu.",
        "«Termina» chiude la chiamata all'istante. A volte la chiamata restava aperta fino a un minuto dopo aver premuto Termina, in attesa della conferma dei server di Telegram: audio acceso, schermo acceso e telefono convinto di essere ancora in chiamata. Ora si chiude subito, anche se la conferma arriva dopo.",
        "Due chiamate di seguito non si intralciano più. Richiamando subito dopo aver riagganciato, la nuova chiamata poteva mescolarsi con quella vecchia non ancora chiusa: non arrivava al destinatario o si chiudeva da sola. Ora ogni chiamata è separata, e una chiamata che arriva mentre ne hai già una in corso non interrompe quella in corso.",
        "Se il tuo telefono era già stato colpito, basta sistemarlo una volta: in Impostazioni → Suoni sposta il cursore della suoneria su un altro valore e poi riportalo dove vuoi; per il volume multimediale usa i tasti del volume mentre suona qualcosa. Se suoneria e notifiche escono ancora dalla capsula, riavvia il telefono.",
        "Da sapere: durante una chiamata di RooTelegram i tasti del volume regolano il volume multimediale del telefono, non un volume separato della chiamata. Se lo abbassi durante una chiamata, resta basso anche dopo: rialzalo con i tasti. Separare i due volumi è il prossimo passo."
    ],
    "en": [
        "Calls and volume: this version is about a problem reported by several users. Thanks to everyone who reported it!",
        "Ringtone and notifications are back at full volume after a call. After a RooTelegram call, on phones like Xperia and Jolla the sound stayed on the earpiece: ringtone, notifications and music came out very quietly from there, as if the volume had dropped by 90%, until the phone was restarted. Now the sound always goes back to the loudspeaker when a call ends.",
        "The media volume is no longer touched. Before, every call quietly set the media volume to 90% and rewrote it at the end of the call: for some people it went up, for others it went down, and it stayed that way afterwards. Now RooTelegram no longer changes any volume of your phone: the call starts at the volume you chose.",
        "«End call» ends the call instantly. Sometimes a call stayed open for up to a minute after pressing End, waiting for Telegram's servers to confirm: sound on, screen on and the phone still thinking it was in a call. Now it closes right away, even if the confirmation arrives later.",
        "Two calls in a row no longer get in each other's way. Calling again right after hanging up, the new call could get mixed up with the old one that was not closed yet: it did not reach the other person or ended by itself. Now every call is separate, and a call that comes in while you are already on one does not interrupt it.",
        "If your phone was already affected, fix it once: in Settings → Sounds move the ringtone slider to another value and then back where you want it; for the media volume use the volume keys while something is playing. If ringtone and notifications still come from the earpiece, restart the phone.",
        "Good to know: during a RooTelegram call the volume keys adjust the phone's media volume, not a separate call volume. If you lower it during a call, it stays low afterwards: raise it again with the keys. Separating the two volumes is the next step."
    ],
    "de": [
        "Anrufe und Lautstärke: diese Version widmet sich einem Problem, das mehrere Nutzer gemeldet haben. Danke an alle, die es gemeldet haben!",
        "Klingelton und Benachrichtigungen nach einem Anruf wieder in voller Lautstärke. Nach einem Anruf mit RooTelegram blieb der Ton auf Telefonen wie Xperia und Jolla auf der Hörmuschel: Klingelton, Benachrichtigungen und Musik kamen sehr leise von dort, als wäre die Lautstärke um 90 % gesunken, bis das Telefon neu gestartet wurde. Jetzt geht der Ton am Ende des Anrufs immer zurück auf den Lautsprecher.",
        "Die Medienlautstärke wird nicht mehr angefasst. Früher setzte jeder Anruf die Medienlautstärke heimlich auf 90 % und schrieb sie am Ende neu: bei manchen stieg sie, bei anderen sank sie, und so blieb sie danach. Jetzt ändert RooTelegram keine Lautstärke des Telefons mehr: der Anruf beginnt mit der Lautstärke, die du gewählt hast.",
        "«Beenden» beendet den Anruf sofort. Manchmal blieb ein Anruf nach dem Drücken auf Beenden bis zu einer Minute offen und wartete auf die Bestätigung der Telegram-Server: Ton an, Bildschirm an und das Telefon glaubte, noch im Gespräch zu sein. Jetzt schließt er sofort, auch wenn die Bestätigung später kommt.",
        "Zwei Anrufe hintereinander behindern sich nicht mehr. Wer gleich nach dem Auflegen wieder anrief, konnte den neuen Anruf mit dem alten, noch nicht geschlossenen vermischen: er kam beim Empfänger nicht an oder endete von selbst. Jetzt ist jeder Anruf getrennt, und ein Anruf, der während eines laufenden Gesprächs eingeht, unterbricht dieses nicht.",
        "Wenn dein Telefon schon betroffen war, genügt es, es einmal zu korrigieren: in Einstellungen → Töne den Klingelton-Regler auf einen anderen Wert schieben und dann dorthin zurück, wo du ihn willst; für die Medienlautstärke die Lautstärketasten benutzen, während etwas abgespielt wird. Wenn Klingelton und Benachrichtigungen noch aus der Hörmuschel kommen, das Telefon neu starten.",
        "Gut zu wissen: während eines RooTelegram-Anrufs regeln die Lautstärketasten die Medienlautstärke des Telefons, keine eigene Anruflautstärke. Wenn du sie während eines Anrufs senkst, bleibt sie danach niedrig: mit den Tasten wieder erhöhen. Die beiden Lautstärken zu trennen ist der nächste Schritt."
    ],
    "pl": [
        "Połączenia i głośność: ta wersja jest poświęcona problemowi zgłoszonemu przez kilku użytkowników. Dziękujemy wszystkim, którzy go zgłosili!",
        "Dzwonek i powiadomienia znów na pełnej głośności po rozmowie. Po rozmowie w RooTelegram na telefonach takich jak Xperia i Jolla dźwięk zostawał na słuchawce: dzwonek, powiadomienia i muzyka wychodziły stamtąd bardzo cicho, jakby głośność spadła o 90%, aż do ponownego uruchomienia telefonu. Teraz po zakończeniu rozmowy dźwięk zawsze wraca na głośnik.",
        "Głośność multimediów nie jest już zmieniana. Wcześniej każda rozmowa po cichu ustawiała głośność multimediów na 90% i na końcu zapisywała ją od nowa: jednym rosła, innym spadała i tak już zostawała. Teraz RooTelegram nie zmienia żadnej głośności telefonu: rozmowa zaczyna się z głośnością, którą sam wybrałeś.",
        "«Zakończ» kończy rozmowę natychmiast. Czasem po naciśnięciu Zakończ rozmowa zostawała otwarta nawet przez minutę, czekając na potwierdzenie serwerów Telegrama: dźwięk włączony, ekran włączony, a telefon przekonany, że wciąż trwa rozmowa. Teraz zamyka się od razu, nawet jeśli potwierdzenie przychodzi później.",
        "Dwie rozmowy jedna po drugiej już sobie nie przeszkadzają. Gdy dzwoniło się ponownie zaraz po rozłączeniu, nowa rozmowa mogła pomieszać się ze starą, jeszcze niezamkniętą: nie docierała do odbiorcy albo kończyła się sama. Teraz każda rozmowa jest osobna, a połączenie przychodzące w trakcie innej rozmowy jej nie przerywa.",
        "Jeśli twój telefon już został dotknięty problemem, wystarczy poprawić to raz: w Ustawienia → Dźwięki przesuń suwak dzwonka na inną wartość, a potem z powrotem tam, gdzie chcesz; głośność multimediów ustaw przyciskami głośności, gdy coś gra. Jeśli dzwonek i powiadomienia nadal wychodzą ze słuchawki, uruchom telefon ponownie.",
        "Warto wiedzieć: podczas rozmowy w RooTelegram przyciski głośności regulują głośność multimediów telefonu, a nie osobną głośność rozmowy. Jeśli ściszysz ją w trakcie rozmowy, pozostanie cicha także potem: podgłośnij ją przyciskami. Rozdzielenie tych dwóch głośności to następny krok."
    ],
    "ru": [
        "Звонки и громкость: эта версия посвящена проблеме, о которой сообщили несколько пользователей. Спасибо всем, кто о ней сообщил!",
        "Рингтон и уведомления снова на полной громкости после звонка. После звонка через RooTelegram на телефонах вроде Xperia и Jolla звук оставался на разговорном динамике: рингтон, уведомления и музыка звучали оттуда очень тихо, будто громкость упала на 90%, до перезагрузки телефона. Теперь по окончании звонка звук всегда возвращается на громкий динамик.",
        "Громкость мультимедиа больше не меняется. Раньше каждый звонок незаметно выставлял громкость мультимедиа на 90% и в конце звонка перезаписывал её: у одних она росла, у других падала, и так и оставалась. Теперь RooTelegram не меняет никакую громкость телефона: звонок начинается с той громкостью, которую выбрали вы.",
        "«Завершить» завершает звонок мгновенно. Иногда после нажатия «Завершить» звонок оставался открытым до минуты, ожидая подтверждения серверов Telegram: звук включён, экран включён, а телефон считает, что разговор ещё идёт. Теперь он закрывается сразу, даже если подтверждение приходит позже.",
        "Два звонка подряд больше не мешают друг другу. Если перезвонить сразу после завершения, новый звонок мог смешаться со старым, ещё не закрытым: не доходил до собеседника или завершался сам. Теперь каждый звонок отдельный, а входящий звонок во время разговора не прерывает текущий.",
        "Если ваш телефон уже пострадал, достаточно исправить это один раз: в Настройки → Звуки передвиньте ползунок рингтона на другое значение, а затем верните туда, где хотите; громкость мультимедиа настройте кнопками громкости, пока что-то играет. Если рингтон и уведомления всё ещё идут из разговорного динамика, перезагрузите телефон.",
        "Полезно знать: во время звонка RooTelegram кнопки громкости регулируют громкость мультимедиа телефона, а не отдельную громкость звонка. Если убавить её во время звонка, она останется низкой и после: прибавьте её кнопками. Разделить эти две громкости — следующий шаг."
    ],
    "fr": [
        "Appels et volume : cette version est consacrée à un problème signalé par plusieurs utilisateurs. Merci à tous ceux qui l'ont signalé !",
        "Sonnerie et notifications de nouveau à plein volume après un appel. Après un appel avec RooTelegram, sur des téléphones comme Xperia et Jolla le son restait sur l'écouteur : sonnerie, notifications et musique sortaient très faiblement de là, comme si le volume avait baissé de 90 %, jusqu'au redémarrage du téléphone. Désormais, à la fin d'un appel, le son revient toujours sur le haut-parleur.",
        "Le volume multimédia n'est plus modifié. Avant, chaque appel mettait discrètement le volume multimédia à 90 % et le réécrivait à la fin de l'appel : chez certains il montait, chez d'autres il baissait, et il restait ainsi ensuite. Désormais RooTelegram ne modifie plus aucun volume du téléphone : l'appel démarre au volume que vous avez choisi.",
        "« Raccrocher » termine l'appel instantanément. Parfois l'appel restait ouvert jusqu'à une minute après avoir appuyé sur Raccrocher, en attendant la confirmation des serveurs de Telegram : son actif, écran allumé et téléphone persuadé d'être encore en communication. Désormais il se ferme tout de suite, même si la confirmation arrive plus tard.",
        "Deux appels à la suite ne se gênent plus. En rappelant juste après avoir raccroché, le nouvel appel pouvait se mélanger avec l'ancien pas encore fermé : il n'arrivait pas au destinataire ou se terminait tout seul. Désormais chaque appel est séparé, et un appel qui arrive pendant une communication ne l'interrompt pas.",
        "Si votre téléphone a déjà été touché, il suffit de corriger une seule fois : dans Paramètres → Sons, déplacez le curseur de la sonnerie sur une autre valeur puis remettez-le où vous voulez ; pour le volume multimédia, utilisez les touches de volume pendant qu'un son est joué. Si la sonnerie et les notifications sortent encore de l'écouteur, redémarrez le téléphone.",
        "Bon à savoir : pendant un appel RooTelegram, les touches de volume règlent le volume multimédia du téléphone, pas un volume d'appel séparé. Si vous le baissez pendant un appel, il reste bas ensuite : remontez-le avec les touches. Séparer les deux volumes est la prochaine étape."
    ],
    "sk": [
        "Hovory a hlasitosť: táto verzia je venovaná problému, ktorý nahlásilo viacero používateľov. Ďakujeme všetkým, ktorí ho nahlásili!",
        "Zvonenie a upozornenia sú po hovore opäť na plnú hlasitosť. Po hovore cez RooTelegram na telefónoch ako Xperia a Jolla zostával zvuk na slúchadle: zvonenie, upozornenia a hudba odtiaľ zneli veľmi potichu, akoby hlasitosť klesla o 90 %, až do reštartu telefónu. Teraz sa na konci hovoru zvuk vždy vráti do reproduktora.",
        "Hlasitosť médií sa už nemení. Predtým každý hovor potichu nastavil hlasitosť médií na 90 % a na konci hovoru ju prepísal: niekomu stúpla, niekomu klesla a tak aj zostala. Teraz RooTelegram nemení žiadnu hlasitosť telefónu: hovor začne s hlasitosťou, ktorú ste si zvolili.",
        "«Ukončiť» ukončí hovor okamžite. Niekedy zostal hovor po stlačení Ukončiť otvorený až minútu a čakal na potvrdenie serverov Telegramu: zvuk zapnutý, obrazovka zapnutá a telefón presvedčený, že hovor ešte trvá. Teraz sa zavrie hneď, aj keď potvrdenie príde neskôr.",
        "Dva hovory za sebou si už neprekážajú. Keď ste zavolali znova hneď po zavesení, nový hovor sa mohol pomiešať so starým, ešte nezavretým: nedostal sa k príjemcovi alebo sa sám ukončil. Teraz je každý hovor samostatný a hovor, ktorý príde počas iného hovoru, ho nepreruší.",
        "Ak bol váš telefón už postihnutý, stačí to raz opraviť: v Nastavenia → Zvuky posuňte posúvač zvonenia na inú hodnotu a potom späť, kam chcete; hlasitosť médií nastavte tlačidlami hlasitosti, keď niečo hrá. Ak zvonenie a upozornenia stále vychádzajú zo slúchadla, reštartujte telefón.",
        "Dobré vedieť: počas hovoru RooTelegram tlačidlá hlasitosti regulujú hlasitosť médií telefónu, nie samostatnú hlasitosť hovoru. Ak ju počas hovoru stíšite, zostane nízka aj potom: zosilnite ju tlačidlami. Oddeliť tieto dve hlasitosti je ďalší krok."
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
