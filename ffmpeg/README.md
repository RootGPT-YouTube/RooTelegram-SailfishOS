# ffmpeg minimale (bundled)

Binario `ffmpeg` statico-minimale usato per normalizzare i video landscape in
storie verticali 9:16 (720x1280 H.264) prima dell'upload (TDLib non transcodifica
e le storie Telegram sono portrait-only).

Build: ffmpeg 7.0.2 + libx264 (stable), cross-compilato nella Sailfish SDK
(`sfdk build-shell`) per ogni arch. Configure minimale (--enable-small, solo
h264/hevc/vp8/vp9 decode, libx264+aac encode, mp4 mux, crop/scale). Dipende solo
da libc/libm/libpthread. ~5.5MB.

Per rigenerare vedi scripts/build-ffmpeg.sh (TODO) o la memoria del progetto.
Installato dal .pro in /usr/share/harbour-rootelegram/bin/ffmpeg.
