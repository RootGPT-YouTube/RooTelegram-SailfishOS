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

var version = "3.7.5";

var changelogByLang = {
    "it": [
        "Corretto: in alcuni gruppi certe reaction venivano rifiutate su un messaggio che ne aveva già una. Un gruppo può limitare quante reaction diverse ha ogni messaggio; ora RooTelegram propone solo quelle che Telegram accetta, come l'app ufficiale.",
        "Corretto: disattivando e poi riattivando le reaction di un gruppo dalle sue Info, il gruppo restava con una sola reaction diversa per messaggio. Ora la riattivazione rimette il limite normale di 11. Se un tuo gruppo ha il problema, spegni e riaccendi le reaction."
    ],
    "en": [
        "Fixed: in some groups certain reactions were refused on a message that already had one. A group can limit how many different reactions each message has; RooTelegram now offers only the ones Telegram accepts, like the official app.",
        "Fixed: turning a group's reactions off and on again from its Info left the group with only one different reaction per message. Turning them back on now restores the normal limit of 11. If one of your groups has the problem, turn reactions off and on again."
    ],
    "de": [
        "Behoben: In manchen Gruppen wurden bestimmte Reaktionen auf eine Nachricht abgelehnt, die schon eine hatte. Eine Gruppe kann begrenzen, wie viele verschiedene Reaktionen eine Nachricht haben darf; RooTelegram bietet jetzt nur die an, die Telegram akzeptiert, wie die offizielle App.",
        "Behoben: Wurden die Reaktionen einer Gruppe in ihren Infos aus- und wieder eingeschaltet, blieb nur eine verschiedene Reaktion pro Nachricht erlaubt. Beim Wiedereinschalten gilt jetzt wieder das normale Limit von 11. Hat eine deiner Gruppen das Problem, schalte die Reaktionen aus und wieder ein."
    ],
    "pl": [
        "Poprawiono: w niektórych grupach pewne reakcje były odrzucane na wiadomości, która już miała jedną. Grupa może ograniczyć liczbę różnych reakcji na wiadomość; RooTelegram proponuje teraz tylko te, które Telegram akceptuje, jak oficjalna aplikacja.",
        "Poprawiono: wyłączenie i ponowne włączenie reakcji grupy w jej informacjach zostawiało tylko jedną różną reakcję na wiadomość. Ponowne włączenie przywraca teraz zwykły limit 11. Jeśli twoja grupa ma ten problem, wyłącz i włącz reakcje ponownie."
    ],
    "ru": [
        "Исправлено: в некоторых группах часть реакций отклонялась на сообщении, у которого уже была одна. Группа может ограничить число разных реакций на сообщение; теперь RooTelegram предлагает только те, что принимает Telegram, как официальное приложение.",
        "Исправлено: после выключения и повторного включения реакций группы в её информации на сообщение оставалась только одна разная реакция. Теперь при включении восстанавливается обычный лимит 11. Если в вашей группе есть эта проблема, выключите и снова включите реакции."
    ],
    "fr": [
        "Corrigé : dans certains groupes, certaines réactions étaient refusées sur un message qui en avait déjà une. Un groupe peut limiter le nombre de réactions différentes par message ; RooTelegram ne propose plus que celles que Telegram accepte, comme l'application officielle.",
        "Corrigé : désactiver puis réactiver les réactions d'un groupe depuis ses infos laissait une seule réaction différente par message. La réactivation remet désormais la limite normale de 11. Si l'un de vos groupes a le problème, désactivez puis réactivez les réactions."
    ],
    "sk": [
        "Opravené: v niektorých skupinách boli niektoré reakcie odmietnuté na správe, ktorá už jednu mala. Skupina môže obmedziť počet rôznych reakcií na správu; RooTelegram teraz ponúka iba tie, ktoré Telegram prijme, ako oficiálna aplikácia.",
        "Opravené: vypnutie a opätovné zapnutie reakcií skupiny v jej informáciách nechalo iba jednu rôznu reakciu na správu. Opätovné zapnutie teraz vráti bežný limit 11. Ak má vaša skupina tento problém, vypnite a znova zapnite reakcie."
    ],
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
