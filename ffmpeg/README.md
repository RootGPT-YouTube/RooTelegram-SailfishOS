# ffmpeg minimale (bundled)

Binario `ffmpeg` statico-minimale usato per normalizzare i video landscape in
storie verticali 9:16 (720x1280 H.264) prima dell'upload (TDLib non transcodifica
e le storie Telegram sono portrait-only).

Build: ffmpeg 7.0.2 + libx264 (stable), cross-compilato nella Sailfish SDK
(`sfdk build-shell`) per ogni arch. Configure minimale (--enable-small, solo
h264/hevc/vp8/vp9 decode, libx264+aac encode, mp4 mux, crop/scale). Dipende solo
da libc/libm/libpthread. ~5.5MB.

Per rigenerare il binario: `bash scripts/build-ffmpeg.sh [aarch64|armv7hl]`
(da eseguire con la Sailfish SDK installata; lo script scarica ffmpeg 7.0.2 e
libx264 stable, li cross-compila via `sfdk build-shell` e copia il binario qui).
Installato dal .pro in /usr/share/harbour-rootelegram/bin/ffmpeg.

## Licenza

Il binario è LGPL v2.1+ (core FFmpeg) ma effettivamente GPL v2+ perché compilato
con `--enable-gpl` e linkato a libx264 (GPL v2+). Testo completo delle licenze e
riferimenti al corresponding source: vedi `ffmpeg/LICENSE`. Elenco di tutte le
dipendenze del progetto: file `NOTICE` nella root.
