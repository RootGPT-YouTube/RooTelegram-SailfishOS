# [ENGLISH] Notifications via UnifiedPush and Foghorn (BETA)

> ⚠️ **BETA.** Both this option in RooTelegram and Foghorn itself are new. If notifications stop
> arriving, turn the option off: RooTelegram goes back to its usual background service and
> nothing else changes.

## What it is, in two sentences

Normally RooTelegram stays in memory all the time (around 100 MB) so that it can receive your
messages. With UnifiedPush it closes completely instead, and a tiny separate app, **Foghorn**
(about 5 MB), wakes it up only when a new message arrives.

How a message reaches you with UnifiedPush:

1. Someone writes to you. Telegram's servers send a short, encrypted **wake-up signal** to an
   Internet address that belongs to your phone, on Mozilla's push service.
2. Foghorn, which keeps one single connection to that service for all apps, receives the signal
   and starts RooTelegram in the background, without a window.
3. RooTelegram connects to Telegram, downloads the new messages (encrypted as usual), shows the
   notifications, and closes again after 20–60 seconds.

The price: a notification can arrive a few seconds later than with the background service.

## Who it is for — and who should keep the background service

UnifiedPush is useful above all on **phones with little memory**, where keeping RooTelegram in
memory all the time weighs a lot.

On **recent phones, with 6 GB of RAM or more, the usual background service is usually the better
choice.** UnifiedPush uses fewer resources, but with this option on, tapping a notification always
starts RooTelegram **from scratch** (a "cold start"), so the chat takes a few seconds longer to
open. With the background service RooTelegram is already running and the chat opens at once.

## What you need

- SailfishOS **5.1** or newer (tested on 5.1). On 5.0 it may work, but it has not been tested.
- The **Foghorn** app, from OpenRepos: <https://openrepos.net/content/projectmoon/foghorn>
  (0.7.0 or newer; installable with Storeman).
- RooTelegram with this option (version after 3.6).
- An Internet connection.

## Step by step

### 1. Install Foghorn
Install Foghorn from OpenRepos. Open it once from its icon and check that its service is
running (Foghorn shows it on its main page).

### 2. Leave Foghorn on its default push service, **Mozilla**
You don't have to change anything: Foghorn's default service (Mozilla Push) works with Telegram.
We measured it: with all other Telegram apps closed the wake-up reaches the phone in about
**one second**.

**Don't choose ntfy.** In our tests Telegram almost never delivered its wake-ups through the public
`ntfy.sh` server: in a whole afternoon not a single one arrived, and so no notifications either.

If you had already switched Foghorn to another service, go back to Mozilla in Foghorn's settings.
Changing the service in Foghorn unregisters all apps: that's expected. RooTelegram notices it and
registers again by itself, even while it is closed (if its status stays on "Connecting", open
RooTelegram and press *Try again*).

### 3. Open RooTelegram from its icon
After installing or updating RooTelegram, open it once **by tapping its icon**. SailfishOS may ask
you to allow the app's permissions, including the new **UnifiedPush** one: accept.

Without this step Foghorn cannot start RooTelegram in the background: SailfishOS would have to ask
for the permission while no window is open, and that request fails silently.

### 4. Turn the option on
RooTelegram → **Settings → Behavior → Notifications via UnifiedPush (BETA)**.

Under the switch a status line appears. After a few seconds it should say:
*"Active: Telegram wakes RooTelegram through updates.push.services.mozilla.com."*

The other possible statuses are explained in [Troubleshooting](#troubleshooting).

### 5. Try it
1. Close RooTelegram **completely**: close it from the home screen (on Lipstick, long-press the
   app cover and tap the ✕), don't just minimize it. About ten seconds later it is no longer in
   memory.
2. Ask someone to write to you.
3. The notification should appear within a few seconds. Tapping it opens the chat as usual.

**If Telegram is open on another device** (another phone, a computer), Telegram itself waits a
little before waking up this phone: then the notification may arrive about **half a minute** later
(measured: 31 seconds). That is normal, and the official apps behave the same way.

## How RooTelegram behaves with the option on

| Situation | What happens |
|---|---|
| App window open or minimized | Works as usual. |
| App closed | The process ends after about 10 seconds. |
| App closed, but music / a voice message is playing, or a call is in progress | It stays alive until they end. |
| A message arrives with the app closed | Started without a window for 20–60 s: notifications, then it closes. |
| Phone start-up | The background service is **not** started (Foghorn takes care of wake-ups). The "Start automatically at device boot" switch is disabled while UnifiedPush is on. |
| An incoming call with the app closed | The wake-up starts RooTelegram, which shows the call as usual. |
| You tap a notification with the app closed | RooTelegram starts **from scratch** (a "cold start"), so it takes a few seconds longer to open than usual. With the option off, the background service keeps it always ready; with the option on that service is not running, because Foghorn takes its place. |

## Troubleshooting

| Status under the switch | Meaning and what to do |
|---|---|
| *No distributor found* | Foghorn is not installed, or its service is stopped. Install/open Foghorn (step 1). |
| *Connecting to Foghorn…* (for a long time) | Open RooTelegram and press *Try again*. Check that Foghorn's service is running. |
| *It didn't work: … D-Bus …* | RooTelegram could not get the UnifiedPush permission. Open RooTelegram from its icon (step 3) and accept the permissions, then *Try again*. If you installed Foghorn **after** RooTelegram, reopening RooTelegram from the icon is required. |
| *It didn't work: (other text)* | Telegram or Foghorn refused the registration; the text says why. Try again later, or turn the option off. |
| *Active…* but no notifications | Check that Foghorn uses **Mozilla** (step 2): if the status shows `ntfy.sh`, that is the cause. In Foghorn check that **RooTelegram** is listed among the registered apps. Check the Internet connection, and that RooTelegram's own notifications are enabled in its settings. |

If nothing helps, turn the option off: RooTelegram tells Telegram to forget the address, unregisters
from Foghorn, and goes back to the background service.

### For advanced users
- Log lines are tagged `[UNIFIEDPUSH]`:
  `devel-su journalctl -f | grep -E "UNIFIEDPUSH|foghorn"`
  A wake-up shows up in Foghorn's log as `push for org.unifiedpush.Connector.rootelegram`.
- Files, in `~/.config/com.github.RootGPT_YouTube/rootelegram/`:
  `unifiedpush-enabled` (marker: option on; also read by the boot service) and
  `unifiedpush.conf` (registration token and the endpoint address — **keep it private**).
- D-Bus: RooTelegram owns `org.unifiedpush.Connector.rootelegram` (object
  `/org/unifiedpush/Connector`, interface `org.unifiedpush.Connector2`); when it is closed, D-Bus
  starts it through `/usr/share/dbus-1/services/org.unifiedpush.Connector.rootelegram.service`.
- Telegram side: the endpoint is registered with TDLib `registerDevice(deviceTokenWebPush)`, the
  same mechanism Telegram Web uses. Telegram encrypts the push with the old `aesgcm` scheme and
  puts the keys in HTTP headers, which UnifiedPush distributors drop: RooTelegram doesn't decrypt
  it, it only uses its arrival as a wake-up. On servers other than Mozilla the plain
  `deviceTokenSimplePush` is registered too; Mozilla refuses it (HTTP 406).

## Privacy

- The wake-up is encrypted and RooTelegram doesn't even read it: messages are downloaded directly
  from Telegram, encrypted as usual.
- Telegram and Mozilla learn only the address where to deliver the wake-ups (just like the
  official Android app tells Telegram its Google push address).
- Whoever learned that address could only **wake RooTelegram up**, not read anything.

## Turning it off

Turn the switch off. RooTelegram:
1. tells Telegram to forget the address;
2. unregisters from Foghorn;
3. goes back to the usual behaviour: it stays in memory in the background, and from the next phone
   start-up it is started automatically again (if "Start automatically at device boot" is on).

## Thanks

Thanks to **projectmoon**, the developer of [Foghorn](https://git.agnos.is/projectmoon/foghorn),
for the pioneering work that brought UnifiedPush to SailfishOS: without Foghorn this option would
not exist.

---

# [ITALIANO] Notifiche via UnifiedPush e Foghorn (BETA)

> ⚠️ **BETA.** Sia questa opzione di RooTelegram sia Foghorn stesso sono nuovi. Se le notifiche
> smettono di arrivare, spegni l'opzione: RooTelegram torna al solito servizio in background e
> non cambia nient'altro.

## Cos'è, in due frasi

Normalmente RooTelegram resta sempre in memoria (circa 100 MB) per poter ricevere i tuoi messaggi.
Con UnifiedPush invece si chiude del tutto, e una piccola app separata, **Foghorn** (circa 5 MB), lo
sveglia solo quando arriva un messaggio nuovo.

Come ti arriva un messaggio con UnifiedPush:

1. Qualcuno ti scrive. I server di Telegram mandano un breve **segnale di sveglia**, cifrato, a un
   indirizzo Internet che appartiene al tuo telefono, sul servizio push di Mozilla.
2. Foghorn, che tiene una sola connessione con quel servizio per tutte le app, riceve il segnale e
   avvia RooTelegram in background, senza finestra.
3. RooTelegram si collega a Telegram, scarica i messaggi nuovi (cifrati come sempre), mostra le
   notifiche e si richiude da solo dopo 20–60 secondi.

Il prezzo: una notifica può arrivare qualche secondo dopo rispetto al servizio in background.

## Per chi è — e chi farebbe meglio a tenere il servizio in background

UnifiedPush è utile soprattutto sui **telefoni con poca memoria**, dove tenere RooTelegram sempre in
memoria pesa molto.

Sui **telefoni recenti, con 6 GB di RAM o più, il solito servizio in background di solito è la scelta
migliore.** UnifiedPush consuma meno risorse, ma con questa opzione accesa toccare una notifica avvia
sempre RooTelegram **da zero** (un «avvio a freddo»), quindi la chat ci mette qualche secondo in più ad
aprirsi. Con il servizio in background RooTelegram è già in esecuzione e la chat si apre subito.

## Cosa serve

- SailfishOS **5.1** o successivo (provato sulla 5.1). Sulla 5.0 potrebbe funzionare, ma non è provato.
- L'app **Foghorn**, da OpenRepos: <https://openrepos.net/content/projectmoon/foghorn>
  (0.7.0 o successiva; si installa con Storeman).
- RooTelegram con questa opzione (versione successiva alla 3.6).
- Una connessione Internet.

## Passo per passo

### 1. Installa Foghorn
Installa Foghorn da OpenRepos. Aprilo una volta dalla sua icona e controlla che il suo servizio sia
attivo (Foghorn lo mostra nella pagina principale).

### 2. Lascia Foghorn sul suo servizio push di fabbrica, **Mozilla**
Non devi cambiare niente: il servizio di fabbrica di Foghorn (Mozilla Push) funziona con Telegram.
L'abbiamo misurato: con tutte le altre app di Telegram chiuse la sveglia arriva al telefono in circa
**un secondo**.

**Non scegliere ntfy.** Nelle nostre prove Telegram non ha quasi mai consegnato le sue sveglie
tramite il server pubblico `ntfy.sh`: in un pomeriggio intero non ne è arrivata nessuna, e quindi
nemmeno le notifiche.

Se avevi già messo Foghorn su un altro servizio, torna a Mozilla nelle impostazioni di Foghorn.
Cambiare servizio in Foghorn annulla la registrazione di tutte le app: è normale. RooTelegram se ne
accorge e si registra di nuovo da solo, anche quando è chiuso (se lo stato resta su «Collegamento»,
apri RooTelegram e premi *Riprova*).

### 3. Apri RooTelegram dalla sua icona
Dopo aver installato o aggiornato RooTelegram, aprilo una volta **toccando la sua icona**.
SailfishOS potrebbe chiederti di consentire i permessi dell'app, compreso il nuovo **UnifiedPush**:
accetta.

Senza questo passaggio Foghorn non può avviare RooTelegram in background: SailfishOS dovrebbe chiedere
il permesso senza nessuna finestra aperta, e quella richiesta fallisce senza dire niente.

### 4. Accendi l'opzione
RooTelegram → **Impostazioni → Comportamento → Notifiche via UnifiedPush (BETA)**.

Sotto l'interruttore compare una riga di stato. Dopo qualche secondo deve dire:
*«Attivo: Telegram sveglia RooTelegram tramite updates.push.services.mozilla.com.»*

Gli altri stati possibili sono spiegati in [Se non funziona](#se-non-funziona).

### 5. Provalo
1. Chiudi RooTelegram **del tutto**: chiudilo dalla schermata home (su Lipstick, pressione lunga
   sulla copertina dell'app e poi ✕), non limitarti a ridurlo. Circa dieci secondi dopo non è più
   in memoria.
2. Chiedi a qualcuno di scriverti.
3. La notifica deve comparire entro pochi secondi. Toccandola si apre la chat come sempre.

**Se Telegram è aperto su un altro dispositivo** (un altro telefono, un computer), è Telegram stesso
ad aspettare un po' prima di svegliare questo telefono: allora la notifica può arrivare circa
**mezzo minuto** più tardi (misurato: 31 secondi). È normale, e le app ufficiali fanno lo stesso.

## Come si comporta RooTelegram con l'opzione accesa

| Situazione | Cosa succede |
|---|---|
| Finestra dell'app aperta o ridotta | Funziona come sempre. |
| App chiusa | Il processo termina dopo circa 10 secondi. |
| App chiusa, ma suona musica / un vocale, o c'è una chiamata | Resta acceso finché non finiscono. |
| Arriva un messaggio ad app chiusa | Parte senza finestra per 20–60 s: notifiche, poi si chiude. |
| Accensione del telefono | Il servizio in background **non** parte (alle sveglie pensa Foghorn). L'interruttore «Avvia automaticamente all'accensione del dispositivo» è disattivato finché UnifiedPush è acceso. |
| Chiamata in arrivo ad app chiusa | La sveglia avvia RooTelegram, che mostra la chiamata come sempre. |
| Tocchi una notifica ad app chiusa | RooTelegram parte **da zero** (un «avvio a freddo»), quindi ci mette qualche secondo in più del solito ad aprirsi. Con l'opzione spenta il servizio in background lo tiene sempre pronto; con l'opzione accesa quel servizio non è in esecuzione, perché al suo posto c'è Foghorn. |

## Se non funziona

| Stato sotto l'interruttore | Significato e cosa fare |
|---|---|
| *Nessun distributore trovato* | Foghorn non è installato, o il suo servizio è fermo. Installa/apri Foghorn (passo 1). |
| *Collegamento a Foghorn…* (a lungo) | Apri RooTelegram e premi *Riprova*. Controlla che il servizio di Foghorn sia attivo. |
| *Non ha funzionato: … D-Bus …* | RooTelegram non ha ottenuto il permesso UnifiedPush. Apri RooTelegram dall'icona (passo 3) e accetta i permessi, poi *Riprova*. Se hai installato Foghorn **dopo** RooTelegram, riaprire RooTelegram dall'icona è necessario. |
| *Non ha funzionato: (altro testo)* | Telegram o Foghorn hanno rifiutato la registrazione; il testo dice perché. Riprova più tardi, o spegni l'opzione. |
| *Attivo…* ma niente notifiche | Controlla che Foghorn usi **Mozilla** (passo 2): se lo stato mostra `ntfy.sh`, la causa è quella. In Foghorn controlla che **RooTelegram** sia nell'elenco delle app registrate. Controlla la connessione Internet, e che le notifiche di RooTelegram siano accese nelle sue impostazioni. |

Se niente aiuta, spegni l'opzione: RooTelegram dice a Telegram di dimenticare l'indirizzo, annulla la
registrazione su Foghorn e torna al servizio in background.

### Per utenti esperti
- Le righe di log hanno l'etichetta `[UNIFIEDPUSH]`:
  `devel-su journalctl -f | grep -E "UNIFIEDPUSH|foghorn"`
  Una sveglia compare nel log di Foghorn come `push for org.unifiedpush.Connector.rootelegram`.
- File, in `~/.config/com.github.RootGPT_YouTube/rootelegram/`:
  `unifiedpush-enabled` (marcatore: opzione accesa; lo legge anche il servizio di avvio) e
  `unifiedpush.conf` (token di registrazione e indirizzo dell'endpoint — **tienilo privato**).
- D-Bus: RooTelegram possiede `org.unifiedpush.Connector.rootelegram` (oggetto
  `/org/unifiedpush/Connector`, interfaccia `org.unifiedpush.Connector2`); quando è chiuso, D-Bus lo
  avvia tramite `/usr/share/dbus-1/services/org.unifiedpush.Connector.rootelegram.service`.
- Lato Telegram: l'endpoint è registrato con `registerDevice(deviceTokenWebPush)` di TDLib, lo stesso
  meccanismo di Telegram Web. Telegram cifra la push con il vecchio schema `aesgcm` e mette le chiavi
  nelle intestazioni HTTP, che i distributori UnifiedPush scartano: RooTelegram non la decifra, usa
  solo il suo arrivo come sveglia. Sui server diversi da Mozilla registra anche il
  `deviceTokenSimplePush` in chiaro; Mozilla lo rifiuta (HTTP 406).

## Privacy

- La sveglia è cifrata e RooTelegram non la legge nemmeno: i messaggi si scaricano direttamente da
  Telegram, cifrati come sempre.
- Telegram e Mozilla vengono a conoscere solo l'indirizzo a cui consegnare le sveglie (come l'app
  ufficiale per Android comunica a Telegram il suo indirizzo push di Google).
- Chi scoprisse quell'indirizzo potrebbe solo **svegliare RooTelegram**, non leggere niente.

## Spegnere l'opzione

Spegni l'interruttore. RooTelegram:
1. dice a Telegram di dimenticare l'indirizzo;
2. annulla la registrazione su Foghorn;
3. torna al comportamento di sempre: resta in memoria in background e, dalla prossima accensione del
   telefono, riparte da solo (se «Avvia automaticamente all'accensione del dispositivo» è acceso).

## Ringraziamenti

Grazie a **projectmoon**, lo sviluppatore di [Foghorn](https://git.agnos.is/projectmoon/foghorn),
per il lavoro pionieristico che ha portato UnifiedPush su SailfishOS: senza Foghorn questa opzione
non esisterebbe.
