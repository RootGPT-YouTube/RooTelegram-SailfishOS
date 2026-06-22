# [ENGLISH] RooTelegram — A lightweight and responsive Telegram client for SailfishOS
Prerequisite: SFOS 5.0/5.1  
Telegram Group: https://t.me/+E7V-a7x4JbY1Njhk  
RooTelegram is tested on:  
- Sony Xperia 10 III (SFOS 5.0)  
- Jolla C2 (SFOS 5.1.0.10)  
    
## This application was developed using artificial intelligence technologies, specifically Warp Terminal and Claude Code Opus, but Warp Terminal has been gradually phased out in favor of Claude Code. Therefore, if the use of an application generated via a large-scale language model (LLM) is not comfortable for the user, it is recommended to avoid its installation and use. It is specified that any negative comment regarding this circumstance will not only be ignored but will result in the immediate blocking of the user.  
## I hereby disclaim any and all responsibility for the application, its functionality, and any consequences arising from its use. By choosing to use this application, the user acknowledges and accepts that they do so entirely at their own risk, and agrees that the developer shall not be held liable for any damages, losses, or adverse effects—whether direct, indirect, incidental, or consequential—resulting from the use or misuse of the application.

 

### Main features
Simple, fast interface optimized for SailfishOS  
Full support for message formatting (bold, italic, monospace, etc.)  
Reliable notifications via a dedicated daemon  
Custom Emoji support  
Message PIN management  
Stickers support  
Group join request management (for admins)  
Modern UI + daemon architecture, for instant app startup  
Calls and Videocalls  
## Project origins
RooTelegram was born as an evolution and modernization of the original Telegram client for SailfishOS:  

Fernschreiber by Sebastian J. Wolf and his collaborators: https://github.com/Wunderfitz/harbour-fernschreiber#contributions  

and draws inspiration from some technical solutions of:  

Yottagram by Michal Szczepaniak: https://github.com/Michal-Szczepaniak/Yottagram  

Both projects served as a valuable starting point, but RooTelegram introduces a fully redesigned architecture, conceived to be faster, more stable, and better suited to modern devices.  

## Project goal
The goal of RooTelegram is to offer a Telegram client that is:  

responsive → instant startup thanks to the always-on daemon  
lightweight → minimal UI, no heavy effects  
reliable → notifications always working  
consistent with SailfishOS → native integration, respect for Silica guidelines  
The design is intentionally bare and basic, because the priority is speed, not aesthetics.

## Roadmap
Current development status (ROADMAP):  

Message editing (text formatting) — ✔️ DONE  
Working notifications — ✔️ DONE  
Notifications daemon — ✔️ DONE  
Folder creation and management — ✔️ DONE  
Custom emoji — ✔️ DONE  
Message PIN — ✔️ DONE  
Partial text selection + copy — ✔️ DONE  
Group join request management (admin) — ✔️ DONE  
Statuses / Stories — ✔️ DONE  
Formatting bugfixes — ✔️ DONE  
Message translation — ✔️ DONE  
Add "Send to RooTelegram" in the SailfishOS Share menu — ✔️ DONE  
Add "Call" for Telegram voice/video calls — ✔️ DONE  
Improve image previews (portrait and landscape), improve message formatting (word wrap and mono) and link previews — ✔️ DONE  
User bio and tabs (Media, Audio, Documents, Links, Groups) — ✔️ DONE  
Settings for Groups and Channels — ✔️ DONE  
Multilanguage version — English, German, Italian, Polish, Russian, French.  
Telegram Proxy — ✔️ DONE  
Your support helps keep my projects alive! https://ko-fi.com/rootgpt  
Telegram Group.  
GitHub: https://github.com/RootGPT-YouTube/RooTelegram-SailfishOS  

## 🔧 Build your own RPM (aarch64) — step by step
These are foolproof, copy‑paste instructions to compile RooTelegram yourself from
this repository and obtain an installable `.rpm`. They target **aarch64** (Sony
Xperia 10 III, Jolla C2 — the tested devices). armv7hl/i486 work the same way but
are not covered here.

> **Why an extra download?** A couple of build dependencies are too big for git
> (TDLib and the WebRTC/voice‑call libraries, ~210 MB compressed). They live in a
> GitHub *Release* of this same repository and you download them **once**.

### 0. What you need
- A PC running **Linux** (the Sailfish SDK also runs on macOS/Windows, but this
  guide assumes Linux).
- About **3 GB** of free disk space and an internet connection.
- The tools `git`, `tar`, `curl` (preinstalled on most distributions).

### 1. Install the Sailfish SDK
1. Download the **Sailfish SDK** from the official page:
   https://sailfishos.org/develop/
2. Run the installer and accept the default install location (`~/SailfishOS`).
3. When asked for a **build target**, install **`SailfishOS-5.0.0.62-aarch64`**
   (you can also add it later from the SDK Maintenance Tool / `sdk-assistant`).
4. Check it is available:
   ```bash
   ~/SailfishOS/bin/sfdk tools list
   ```
   You should see a line containing `SailfishOS-5.0.0.62-aarch64`.

### 2. Get the source code
```bash
git clone https://github.com/RootGPT-YouTube/RooTelegram-SailfishOS.git
cd RooTelegram-SailfishOS
```

### 3. Create your Telegram API credentials
RooTelegram needs a personal Telegram **api_id / api_hash** pair to reach
Telegram's servers. These are **not** included in the repository. Getting your own
is free and takes two minutes:
1. Open https://my.telegram.org → **API development tools** and log in with your
   phone number.
2. Create an app (any title / short name). You'll receive an **api_id** (a number)
   and an **api_hash** (a long hex string).
3. Create the file **`src/tdlibsecrets.h`** with exactly this content, replacing the
   two values with your own:
   ```c
   #ifndef TDLIBSECRETS_H
   #define TDLIBSECRETS_H
   const char TDLIB_API_ID[]   = "1234567";
   const char TDLIB_API_HASH[] = "0123456789abcdef0123456789abcdef";
   #endif // TDLIBSECRETS_H
   ```
> ⚠️ Keep this file private — never commit or share your `api_hash`.

### 4. Download the build dependencies (one‑time)
The large prebuilt dependencies are **not** in git. Download the archive from this
repo's **Releases** page and extract it **at the root of the cloned folder** (the
one that contains `build-rpm.sh`):
```bash
curl -L -o build-deps.tar.gz \
  https://github.com/RootGPT-YouTube/RooTelegram-SailfishOS/releases/download/build-deps-aarch64/rootelegram-build-deps-aarch64.tar.gz
tar xzf build-deps.tar.gz
rm build-deps.tar.gz
```
This creates two folders: `tdlib/` (TDLib 1.8.62) and `vendor/` (the voice/video
call libraries). Their licenses and exact upstream sources are documented in the
archive's `PROVENANCE.txt` and in the repository `NOTICE` file.

### 5. Build the RPM
From the project root, just run:
```bash
bash build-rpm.sh
```
The script does everything for you: it auto‑clones `rlottie`, compiles inside the
SDK and packages the RPM. The **first** build takes several minutes. When it
finishes, the package is here:
```
RPMS/harbour-rootelegram-<version>-1.aarch64.rpm
```

### 6. Install it on the phone
Replace `<device-ip>` with your phone's IP (Settings → Developer tools), with
Developer mode enabled:
```bash
scp RPMS/harbour-rootelegram-*-1.aarch64.rpm defaultuser@<device-ip>:/tmp/
ssh defaultuser@<device-ip> 'devel-su pkcon install-local -y /tmp/harbour-rootelegram-*-1.aarch64.rpm'
```

### Troubleshooting
- **`Sailfish SDK not found`** → it isn't in `~/SailfishOS`. Reinstall there, or run
  `SDK_DIR=/path/to/SailfishOS bash build-rpm.sh`.
- **`tdlibsecrets.h: No such file or directory`** → step 3 was skipped. Create
  `src/tdlibsecrets.h` with your own Telegram api_id/api_hash.
- **`TDLib not found in tdlib/...`** → step 4 was skipped or extracted in the wrong
  folder. Make sure `tdlib/aarch64/lib/libtdjson.so` exists at the project root.
- **Link errors mentioning `tg_owt` / `tgcalls`** → the `vendor/` folder is missing;
  re‑extract the dependencies archive (step 4).

---

# [ITALIANO] RooTelegram — Un client Telegram leggero e reattivo per SailfishOS
Requisiti: SFOS 5.0/5.1  
Gruppo Telegram: https://t.me/+E7V-a7x4JbY1Njhk  
RooTelegram è testato:  
- Sony Xperia 10 III (SFOS 5.0)  
- Jolla C2 (SFOS 5.1.0.8)  
## Questa applicazione è stata sviluppata utilizzando tecnologie di intelligenza artificiale, in particolare Warp Terminal e Claude Code Opus, ma Warp Terminal è stato abbandonato in favore di Claude Code. Pertanto, se l'uso di un'applicazione generata tramite un modello linguistico su larga scala (LLM) non fosse per l'utente confortevole, si raccomanda di evitarne l'installazione e l'uso. Si specifica che qualsiasi commento negativo riguardante questa circostanza non verrà solo ignorato, ma comporterà il blocco immediato dell'utente.  
## Con la presente declino ogni responsabilità relativa all’applicazione, al suo funzionamento e a qualsiasi conseguenza derivante dal suo utilizzo. L’utente, scegliendo di utilizzare l’applicazione, riconosce e accetta di farlo a proprio ed esclusivo rischio, e concorda che lo sviluppatore non potrà essere ritenuto responsabile per eventuali danni, perdite o effetti negativi — diretti, indiretti, incidentali o consequenziali — derivanti dall’uso o dall’uso improprio dell’applicazione.

## Caratteristiche principali
Interfaccia semplice, veloce e ottimizzata per SailfishOS  
Supporto completo alla formattazione dei messaggi (grassetto, corsivo, monospazio, ecc.)  
Notifiche affidabili tramite daemon dedicato  
Supporto alle Custom Emoji  
Gestione dei PIN dei messaggi  
Supporto agli stickers  
Gestione delle richieste di accesso ai gruppi (per admin)  
Architettura moderna basata su UI + daemon, per apertura istantanea dell’app  
Chiamate vocali e chiamate video.  
## Origini del progetto
RooTelegram nasce come evoluzione e modernizzazione del primordiale client Telegram per SailfishOS:  

Fernschreiber di Sebastian J. Wolf e compagni d'opera: https://github.com/Wunderfitz/harbour-fernschreiber#contributions  

e trae ispirazione da alcune soluzioni tecniche di:  

Yottagram di Michal Szczepaniak: https://github.com/Michal-Szczepaniak/Yottagram  

Entrambi i progetti hanno rappresentato un punto di partenza prezioso, ma RooTelegram introduce un’architettura completamente rinnovata, pensata per essere più veloce, più stabile e più adatta ai dispositivi moderni.  

## Obiettivo del progetto
L’obiettivo di RooTelegram è offrire un client Telegram:  

reattivo → apertura istantanea grazie al daemon sempre attivo  
leggero → UI minimale, nessun effetto pesante  
affidabile → notifiche sempre funzionanti  
coerente con SailfishOS → integrazione nativa, rispetto delle linee guida Silica  
Il design è volutamente scarno e basilare, perché la priorità è la velocità, non l’estetica.  

## Roadmap
Stato attuale dello sviluppo (ROADMAP):  

Modifiche dei messaggi (formattazione testo) — ✔️ FATTO  
Notifiche funzionanti — ✔️ FATTO  
Demone per le notifiche — ✔️ FATTO  
Creazione e gestione delle cartelle — ✔️ FATTO  
Emoji custom — ✔️ FATTO  
PIN dei messaggi — ✔️ FATTO  
Selezione parziale del testo + copia — ✔️ FATTO  
Gestione richieste accesso ai gruppi (admin) — ✔️ FATTO  
Stati / Stories — ✔️ FATTO  
Bugfix formattazione — ✔️ FATTO  
Traduzione dei messaggi — ✔️ FATTO  
Aggiungere “Invia a RooTelegram” nel menù Condividi di SailfishOS — ✔️ FATTO  
Aggiungere "Chiama" per le telefonate/videochaimate via Telegram — ✔️ FATTO  
Migliorare preview immagini (portrait e landscape), migliorare formattazione messaggi (wordwrap e mono) e preview link — ✔️ FATTO  
Bio utente e tabulazione (Media, Audio, Documenti, Link, Gruppi) — ✔️ FATTO  
Impostazioni per Gruppi e Canali — ✔️ FATTO  
Versione multilingua — Inglese, Tedesco, Italiano, Polacco, Russo, Francese.  
Telegram Proxy — ✔️ FATTO  
Aiutami a mantenere attivi i miei progetti! https://ko-fi.com/rootgpt  
Telegram Group.  
GitHub: https://github.com/RootGPT-YouTube/RooTelegram-SailfishOS  

## 🔧 Compila il tuo RPM (aarch64) — passo per passo
Istruzioni "a prova di scimmia", da copia‑incolla, per compilare RooTelegram da
solo a partire da questo repository e ottenere un `.rpm` installabile. Valgono per
**aarch64** (Sony Xperia 10 III, Jolla C2 — i dispositivi testati). armv7hl/i486
funzionano allo stesso modo ma non sono trattati qui.

> **Perché un download extra?** Un paio di dipendenze di build sono troppo grandi
> per git (TDLib e le librerie WebRTC/chiamate, ~210 MB compressi). Stanno in una
> *Release* GitHub di questo stesso repository e le scarichi **una volta sola**.

### 0. Cosa ti serve
- Un PC con **Linux** (la Sailfish SDK gira anche su macOS/Windows, ma questa guida
  assume Linux).
- Circa **3 GB** di spazio libero su disco e una connessione internet.
- Gli strumenti `git`, `tar`, `curl` (preinstallati nella maggior parte delle
  distribuzioni).

### 1. Installa la Sailfish SDK
1. Scarica la **Sailfish SDK** dalla pagina ufficiale:
   https://sailfishos.org/develop/
2. Avvia l'installer e accetta il percorso predefinito (`~/SailfishOS`).
3. Quando ti chiede un **build target**, installa **`SailfishOS-5.0.0.62-aarch64`**
   (puoi anche aggiungerlo dopo dalla Maintenance Tool della SDK / `sdk-assistant`).
4. Verifica che ci sia:
   ```bash
   ~/SailfishOS/bin/sfdk tools list
   ```
   Dovresti vedere una riga che contiene `SailfishOS-5.0.0.62-aarch64`.

### 2. Scarica il codice sorgente
```bash
git clone https://github.com/RootGPT-YouTube/RooTelegram-SailfishOS.git
cd RooTelegram-SailfishOS
```

### 3. Crea le tue credenziali API Telegram
RooTelegram ha bisogno di una coppia personale **api_id / api_hash** di Telegram
per raggiungere i server. Queste **non** sono incluse nel repository. Ottenere le
tue è gratis e richiede due minuti:
1. Apri https://my.telegram.org → **API development tools** e accedi col tuo numero
   di telefono.
2. Crea un'app (titolo / nome breve a piacere). Riceverai un **api_id** (un numero)
   e un **api_hash** (una lunga stringa esadecimale).
3. Crea il file **`src/tdlibsecrets.h`** con esattamente questo contenuto,
   sostituendo i due valori con i tuoi:
   ```c
   #ifndef TDLIBSECRETS_H
   #define TDLIBSECRETS_H
   const char TDLIB_API_ID[]   = "1234567";
   const char TDLIB_API_HASH[] = "0123456789abcdef0123456789abcdef";
   #endif // TDLIBSECRETS_H
   ```
> ⚠️ Tieni questo file privato — non committare e non condividere mai il tuo `api_hash`.

### 4. Scarica le dipendenze di build (una tantum)
Le dipendenze precompilate pesanti **non** sono in git. Scarica l'archivio dalla
sezione **Releases** del repo ed estrailo **nella radice della cartella clonata**
(quella che contiene `build-rpm.sh`):
```bash
curl -L -o build-deps.tar.gz \
  https://github.com/RootGPT-YouTube/RooTelegram-SailfishOS/releases/download/build-deps-aarch64/rootelegram-build-deps-aarch64.tar.gz
tar xzf build-deps.tar.gz
rm build-deps.tar.gz
```
Vengono create due cartelle: `tdlib/` (TDLib 1.8.62) e `vendor/` (le librerie per
le chiamate audio/video). Licenze e sorgenti upstream esatti sono documentati nel
`PROVENANCE.txt` dentro l'archivio e nel file `NOTICE` del repository.

### 5. Compila l'RPM
Dalla radice del progetto, lancia semplicemente:
```bash
bash build-rpm.sh
```
Lo script fa tutto da sé: clona `rlottie` in automatico, compila dentro la SDK e
pacchettizza l'RPM. La **prima** build richiede qualche minuto. Al termine il
pacchetto è qui:
```
RPMS/harbour-rootelegram-<versione>-1.aarch64.rpm
```

### 6. Installalo sul telefono
Sostituisci `<ip-dispositivo>` con l'IP del telefono (Impostazioni → Strumenti per
sviluppatori), con la Modalità sviluppatore attiva:
```bash
scp RPMS/harbour-rootelegram-*-1.aarch64.rpm defaultuser@<ip-dispositivo>:/tmp/
ssh defaultuser@<ip-dispositivo> 'devel-su pkcon install-local -y /tmp/harbour-rootelegram-*-1.aarch64.rpm'
```

### Risoluzione problemi
- **`Sailfish SDK non trovato`** → non è in `~/SailfishOS`. Reinstallala lì, oppure
  lancia `SDK_DIR=/percorso/SailfishOS bash build-rpm.sh`.
- **`tdlibsecrets.h: No such file or directory`** → hai saltato il passo 3. Crea
  `src/tdlibsecrets.h` con i tuoi api_id/api_hash di Telegram.
- **`TDLib non trovata in tdlib/...`** → hai saltato il passo 4 o l'hai estratto
  nella cartella sbagliata. Assicurati che esista `tdlib/aarch64/lib/libtdjson.so`
  nella radice del progetto.
- **Errori di link con `tg_owt` / `tgcalls`** → manca la cartella `vendor/`;
  riestrai l'archivio delle dipendenze (passo 4).
