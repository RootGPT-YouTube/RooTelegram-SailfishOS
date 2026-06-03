#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# build-ffmpeg.sh — costruisce il binario ffmpeg minimale-statico bundlato, usato
# per: (1) normalizzare i video landscape in storie verticali 9:16 720x1280
# (TDLib non transcodifica, le storie Telegram sono portrait-only); (2) estrarre
# la thumbnail JPEG dei video all'invio (encoder mjpeg + muxer image2), perché il
# server Telegram non genera l'anteprima per i video caricati senza.
#
# Output: ffmpeg/<arch>/bin/ffmpeg (vendorizzato nel repo, ~5.5MB, dipende solo
#         da libc/libm/libpthread). Build nella Sailfish SDK via `sfdk build-shell`.
#
# Uso:  bash scripts/build-ffmpeg.sh [aarch64|armv7hl|i486]   (default: aarch64)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

ARCH="${1:-aarch64}"
# Su x86 (i486) libx264 userebbe asm che richiede nasm/yasm: lo disabilitiamo
# (impatto trascurabile, qui ffmpeg serve solo per crop storie + thumbnail).
X264_EXTRA=""
FFMPEG_EXTRA=""
case "$ARCH" in
    aarch64) SFOS_TARGET="SailfishOS-5.0.0.62-aarch64" ;;
    armv7hl) SFOS_TARGET="SailfishOS-5.0.0.62-armv7hl" ;;
    # i486: niente nasm/yasm nel target -> disabilita l'asm x86 sia in x264 sia in ffmpeg.
    i486)    SFOS_TARGET="SailfishOS-5.0.0.62-i486"; X264_EXTRA="--disable-asm"; FFMPEG_EXTRA="--disable-x86asm" ;;
    *) echo "arch non supportata: $ARCH (usa aarch64|armv7hl|i486)"; exit 1 ;;
esac

SFDK="${SFDK:-$HOME/SailfishOS/bin/sfdk}"
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
B="$PROJ/_ffmpeg_build/$ARCH"
X264_URL='https://code.videolan.org/videolan/x264/-/archive/stable/x264-stable.tar.bz2'
FFMPEG_VER="7.0.2"
FFMPEG_URL="https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VER}.tar.xz"

mkdir -p "$B"
cd "$B"
[ -f x264.tar.bz2 ]  || curl -fsSL -o x264.tar.bz2  "$X264_URL"
[ -f ffmpeg.tar.xz ] || curl -fsSL -o ffmpeg.tar.xz "$FFMPEG_URL"
rm -rf x264-stable "ffmpeg-${FFMPEG_VER}" x264-install
tar xf x264.tar.bz2
tar xf ffmpeg.tar.xz

# NB: sfdk va invocato dalla ROOT del build tree (dove sta il .pro), non da $B
# (sotto _ffmpeg_build/): altrimenti "needs to be used from the top of the build
# tree". La compilazione interna usa path assoluti a $B, quindi il cwd non conta.
(cd "$PROJ" && "$SFDK" config --global target="$SFOS_TARGET")

# 1) libx264 statica (asm NEON via gas: niente nasm/yasm su ARM/aarch64)
(cd "$PROJ" && "$SFDK" build-shell bash -c "
set -e
cd '$B/x264-stable'
./configure --enable-static --enable-pic --disable-cli --disable-opencl $X264_EXTRA --prefix='$B/x264-install'
make -j\$(nproc) && make install
")

# 2) ffmpeg minimale statico con x264
(cd "$PROJ" && "$SFDK" build-shell bash -c "
set -e
cd '$B/ffmpeg-${FFMPEG_VER}'
export PKG_CONFIG_PATH='$B/x264-install/lib/pkgconfig'
./configure \
  --pkg-config-flags=--static \
  --enable-gpl --enable-version3 --enable-small \
  --enable-static --disable-shared \
  --disable-debug --disable-doc --disable-htmlpages --disable-manpages --disable-txtpages \
  --disable-ffplay --disable-ffprobe --disable-autodetect --disable-network \
  --disable-everything \
  --enable-protocol=file,pipe \
  --enable-demuxer=mov,matroska,avi,h264,hevc,aac,mpegts \
  --enable-muxer=mp4,image2 \
  --enable-decoder=h264,hevc,mpeg4,vp8,vp9,aac,mp3,ac3,vorbis,opus,pcm_s16le,pcm_u8 \
  --enable-parser=h264,hevc,mpeg4video,vp8,vp9,aac,ac3,opus \
  --enable-bsf=h264_mp4toannexb,hevc_mp4toannexb,aac_adtstoasc \
  --enable-encoder=libx264,aac,mjpeg \
  --enable-libx264 \
  --enable-filter=crop,scale,format,setsar,fps,aresample,aformat,anull,null,settb,copy,setpts,asetpts \
  --enable-swscale --enable-swresample \
  $FFMPEG_EXTRA \
  --extra-cflags=-I'$B/x264-install/include' \
  --extra-ldflags=-L'$B/x264-install/lib' \
  --extra-libs='-lpthread -lm -ldl'
make -j\$(nproc)
strip ffmpeg
")

mkdir -p "$PROJ/ffmpeg/$ARCH/bin"
cp "$B/ffmpeg-${FFMPEG_VER}/ffmpeg" "$PROJ/ffmpeg/$ARCH/bin/ffmpeg"
chmod 755 "$PROJ/ffmpeg/$ARCH/bin/ffmpeg"
echo "OK -> ffmpeg/$ARCH/bin/ffmpeg ($(du -h "$PROJ/ffmpeg/$ARCH/bin/ffmpeg" | cut -f1))"
