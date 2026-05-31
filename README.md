# [ITALIANO] RooTelegram — Un client Telegram leggero e reattivo per SailfishOS

### Questa applicazione è stata sviluppata utilizzando tecnologie di intelligenza artificiale, in particolare Warp Terminal e Claude Code Ophus 4.7. Pertanto, se l'uso di un'applicazione generata tramite un modello linguistico su larga scala (LLM) non fosse per l'utente confortevole, si raccomanda di evitarne l'installazione e l'uso. Si specifica che qualsiasi commento negativo riguardante questa circostanza non verrà solo ignorato, ma comporterà il blocco immediato dell'utente.

## Caratteristiche principali
1. Interfaccia semplice, veloce e ottimizzata per SailfishOS
2. Supporto completo alla formattazione dei messaggi (grassetto, corsivo, monospazio, ecc.)
3. Notifiche affidabili tramite daemon dedicato
4. Supporto alle Custom Emoji
5. Gestione dei PIN dei messaggi
6. Selezione e copia parziale del testo
7. Gestione delle richieste di accesso ai gruppi (per admin)
8. Architettura moderna basata su UI + daemon, per apertura istantanea dell’app

## Origini del progetto
RooTelegram nasce come evoluzione e modernizzazione del primordiale client Telegram per SailfishOS:

Fernschreiber di Sebastian J. Wolf e compagni d'opera:
https://github.com/Wunderfitz/harbour-fernschreiber#contributions

e trae ispirazione da alcune soluzioni tecniche di:

Yottagram di Michal Szczepaniak:
https://github.com/Michal-Szczepaniak/Yottagram

Entrambi i progetti hanno rappresentato un punto di partenza prezioso, ma RooTelegram introduce un’architettura completamente rinnovata, pensata per essere più veloce, più stabile e più adatta ai dispositivi moderni.

## Obiettivo del progetto
L’obiettivo di RooTelegram è offrire un client Telegram:
- reattivo → apertura istantanea grazie al daemon sempre attivo
- leggero → UI minimale, nessun effetto pesante
- affidabile → notifiche sempre funzionanti
- coerente con SailfishOS → integrazione nativa, rispetto delle linee guida Silica

Il design è volutamente scarno e basilare, perché la priorità è la velocità, non l’estetica.

## Roadmap
Stato attuale dello sviluppo (ROADMAP):

0. Modifiche dei messaggi (formattazione testo) — ✔️ FATTO
1. Notifiche funzionanti — ✔️ FATTO
2. Demone per le notifiche — ✔️ FATTO
3. Creazione e gestione delle cartelle — ✔️ FATTO
4. Emoji custom — ✔️ FATTO
5. PIN dei messaggi — ✔️ FATTO
6. Selezione parziale del testo + copia — ✔️ FATTO
7. Gestione richieste accesso ai gruppi (admin) — ✔️ FATTO
8. Stati / Stories — ⏳ DA FARE
9. Bugfix formattazione — ✔️ FATTO
10. Traduzione dei messaggi (possibile supporto IA) — ⏳ DA FARE
11. Aggiungere “Invia a RooTelegram” nel menù Condividi di SailfishOS — ✔️ FATTO
12. Aggiungere "Chiama" per le telefonate/videochaimate via Telegram — ⏳ DA FARE
13. Migliorare preview immagini (portrait e landscape), migliorare formattazione messaggi (wordwrap e mono) e preview link — ✔️ FATTO
14. Bio utente e tabulazione (Media, Audio, Documenti, Link, Gruppi) — ✔️ FATTO
15. Impostazioni per Gruppi e Canali - ✔️ FATTO
16. Versione multilingua — ⏳ DA FARE

Telegram: RooTest Apps Group
Aiutami a mantenere attivi i miei progetti! https://ko-fi.com/rootgpt

---

# [ENGLISH] RooTelegram — A lightweight and responsive Telegram client for SailfishOS

### This application was developed using artificial intelligence technologies, specifically Warp Terminal and Claude Code Ophus 4.7. Therefore, if the use of an application generated via a large-scale language model (LLM) is not comfortable for the user, it is recommended to avoid its installation and use. It is specified that any negative comment regarding this circumstance will not only be ignored but will result in the immediate blocking of the user.

## Main features
1. Simple, fast interface optimized for SailfishOS
2. Full support for message formatting (bold, italic, monospace, etc.)
3. Reliable notifications via a dedicated daemon
4. Custom Emoji support
5. Message PIN management
6. Partial text selection and copy
7. Group join request management (for admins)
8. Modern UI + daemon architecture, for instant app startup

## Project origins
RooTelegram was born as an evolution and modernization of the original Telegram client for SailfishOS:

Fernschreiber by Sebastian J. Wolf and his collaborators:
https://github.com/Wunderfitz/harbour-fernschreiber#contributions

and draws inspiration from some technical solutions of:

Yottagram by Michal Szczepaniak:
https://github.com/Michal-Szczepaniak/Yottagram

Both projects served as a valuable starting point, but RooTelegram introduces a fully redesigned architecture, conceived to be faster, more stable, and better suited to modern devices.

## Project goal
The goal of RooTelegram is to offer a Telegram client that is:
- responsive → instant startup thanks to the always-on daemon
- lightweight → minimal UI, no heavy effects
- reliable → notifications always working
- consistent with SailfishOS → native integration, respect for Silica guidelines

The design is intentionally bare and basic, because the priority is speed, not aesthetics.

## Roadmap
Current development status (ROADMAP):

0. Message editing (text formatting) — ✔️ DONE
1. Working notifications — ✔️ DONE
2. Notifications daemon — ✔️ DONE
3. Folder creation and management — ✔️ DONE
4. Custom emoji — ✔️ DONE
5. Message PIN — ✔️ DONE
6. Partial text selection + copy — ✔️ DONE
7. Group join request management (admin) — ✔️ DONE
8. Statuses / Stories — ⏳ TO DO
9. Formatting bugfixes — ✔️ DONE
10. Message translation (possible AI support) — ⏳ TO DO
11. Add "Send to RooTelegram" in the SailfishOS Share menu — ✔️ DONE
12. Add "Call" for Telegram voice/video calls — ⏳ TO DO
13. Improve image previews (portrait and landscape), improve message formatting (word wrap and mono) and link previews — ✔️ DONE
14. User bio and tabs (Media, Audio, Documents, Links, Groups) — ✔️ DONE
15. Settings for Groups and Channels — ✔️ DONE
16. Multilanguage version — ⏳ TO DO

Telegram Group: RooTest Apps Group
Your support helps keep my projects alive! https://ko-fi.com/rootgpt
