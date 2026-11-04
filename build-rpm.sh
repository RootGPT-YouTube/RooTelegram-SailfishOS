#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# build-rpm.sh — Build harbour-rootelegram per SailfishOS 5
#
#   ALBERO UNICO + SHADOW BUILD (dal 2026-09-17)
#   ------------------------------------------------------------------------
#   Prima esistevano TRE copie dell'albero, una per architettura, e lo script
#   indovinava l'arch dal nome della cartella. Adesso l'albero e' UNO SOLO e la
#   compilazione avviene FUORI da esso, in una cartella per architettura:
#
#       RooTelegram/
#         harbour-rootelegram/    <- questo albero: SOLO sorgenti (git)
#         build/aarch64/          <- .o, binario e RPM di aarch64
#         build/armv7hl/          <- idem armv7hl
#         build/i486/             <- idem i486
#         RPMS/                   <- i 3 RPM installabili (raccoglitore)
#
#   ⭐ Perche' cosi': gli oggetti di due architetture non possono piu' finire
#   nella stessa cartella. Non e' disciplina, e' impossibilita' meccanica —
#   il 2026-08-15 il mescolamento e' costato tre rebuild (oggetti a 32 bit
#   riusati da make su aarch64: `operator new(unsigned int)` al link).
#
# Uso:
#   bash build-rpm.sh aarch64        (o armv7hl, o i486)
#   bash build-rpm.sh               -> aarch64 (default)
#
#   L'arch si puo' imporre anche con SFOS_TARGET / TDLIB_ARCH nell'ambiente.
#
# Prerequisiti:
#   1. Sailfish SDK in ~/SailfishOS (o SDK_DIR)
#   2. Target SailfishOS-5.0.0.62-<arch> installato nel Platform SDK
#   3. tdlib/<arch>/lib/libtdjson.so presente (vedi README)
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

PACKAGE_NAME="harbour-rootelegram"

# ── Dove siamo ────────────────────────────────────────────────────────────────
# SRCDIR e' la cartella DI QUESTO SCRIPT, non $PWD: cosi' lo script funziona
# anche lanciato da un'altra directory, e $PWD non decide piu' niente.
SRCDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROJROOT="$(dirname "$SRCDIR")"

# ── Architettura ──────────────────────────────────────────────────────────────
# 1) argomento esplicito; 2) variabile d'ambiente; 3) nome della cartella da cui
#    si lancia (compatibilita' con i vecchi percorsi *_aarch64 / *_armv7hl /
#    *_i486, che ora sono symlink a questo albero); 4) aarch64.
ARCH="${1:-}"
if [[ -z "$ARCH" ]]; then
    ARCH="${TDLIB_ARCH:-}"
fi
if [[ -z "$ARCH" ]]; then
    case "$PWD" in
        *_aarch64*) ARCH="aarch64" ;;
        *_armv7hl*) ARCH="armv7hl" ;;
        *_i486*)    ARCH="i486" ;;
        *)          ARCH="aarch64" ;;
    esac
fi
case "$ARCH" in
    aarch64|armv7hl|i486) ;;
    *) echo "[ERROR] Architettura sconosciuta: '$ARCH' (attese: aarch64, armv7hl, i486)" >&2; exit 1 ;;
esac

SFOS_TARGET="${SFOS_TARGET:-SailfishOS-5.0.0.62-${ARCH}}"
BUILDDIR="${BUILDDIR:-$PROJROOT/build/$ARCH}"
COLLECTDIR="${COLLECTDIR:-$PROJROOT/RPMS}"

# Single source of truth: RT_APP_VERSION nel .pro. Da qui sincronizziamo
# anche rpm/*.{spec,yaml}, così basta bumpare in un solo posto (il .pro).
# Non usiamo VERSION perché qmake la tratta come variabile riservata e su
# template app la riduce a major.minor quando espansa con $$VERSION.
VERSION="$(grep -E '^RT_APP_VERSION[[:space:]]*=' "$SRCDIR/${PACKAGE_NAME}.pro" | head -1 | awk -F= '{print $2}' | tr -d ' "')"
if [[ -z "$VERSION" ]]; then
    echo "[ERROR] Impossibile leggere RT_APP_VERSION da ${PACKAGE_NAME}.pro" >&2
    exit 1
fi
RELEASE="1"

SDK_DIR="${SDK_DIR:-$HOME/SailfishOS}"
SB2_CMD="$SDK_DIR/bin/sfdk"                                 # Sailfish SDK ≥ 3.x usa sfdk

# ── Colori ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[BUILD]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN] ${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

cd "$SRCDIR"

# Sincronizza rpm/*.spec e rpm/*.yaml con la VERSION del .pro
sed -i -E "s/^(Version:[[:space:]]+).*/\1${VERSION}/" "rpm/${PACKAGE_NAME}.spec" "rpm/${PACKAGE_NAME}.yaml"

# ── Verifica SDK ──────────────────────────────────────────────────────────────
if [[ ! -f "$SB2_CMD" ]]; then
    error "Sailfish SDK non trovato in $SDK_DIR. Installalo da https://sailfishos.org/develop/"
fi

info "Sailfish SDK trovato: $SB2_CMD"
info "Architettura: $ARCH    target: $SFOS_TARGET"
info "Sorgenti:  $SRCDIR"
info "Build dir: $BUILDDIR"

# ── Verifica TDLib ────────────────────────────────────────────────────────────
# ⚠️ Ogni arch ha la SUA libtdjson e non sono intercambiabili: stesso numero di
# versione non vuol dire stessa libreria (misurato il 2026-09-17).
TDLIB_SO="tdlib/${ARCH}/lib/libtdjson.so"
if [[ ! -f "$TDLIB_SO" ]]; then
    warn "TDLib non trovata in $TDLIB_SO"
    warn ""
    warn "Devi fornire libtdjson.so compilata per ${ARCH} SailfishOS."
    warn "Opzioni:"
    warn "  A) Scarica il pacchetto build-deps (vedi README)"
    warn "  B) Compilala dal sorgente in ../build-deps/tdlib-src"
    warn ""
    warn "Poi copiala in: $SRCDIR/$TDLIB_SO"
    warn ""
    read -rp "Vuoi continuare senza TDLib (il build fallirà al link step)? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || exit 1
fi

# ── Inizializzazione rlottie ──────────────────────────────────────────────────
if [[ ! -f "$SRCDIR/rlottie/CMakeLists.txt" ]] || grep -q "zip_stream_open\|zip_entry" "$SRCDIR/rlottie/src/lottie/lottieparser.cpp" 2>/dev/null; then
    info "Clonazione rlottie v0.2 da Samsung/rlottie..."
    rm -rf "$SRCDIR/rlottie"
    git clone --depth=1 --branch v0.2 https://github.com/Samsung/rlottie.git "$SRCDIR/rlottie"
    info "rlottie clonato"
else
    info "rlottie già presente, skip clone"
fi

# ── Guardia anti-contaminazione ───────────────────────────────────────────────
# L'albero deve contenere SOLO sorgenti: con la shadow build gli oggetti stanno
# in build/<arch>/. Se qui dentro ricompare un .o (per esempio dopo una build
# lanciata a mano dentro l'albero), verrebbe visto da TUTTE le architetture ⇒ e'
# esattamente il mescolamento che questa struttura esiste per rendere
# impossibile. Meglio fermarsi e dirlo che costruire qualcosa di sbagliato.
STRAY="$(ls "$SRCDIR"/*.o 2>/dev/null | head -5 || true)"
if [[ -n "$STRAY" ]]; then
    warn "Trovati oggetti compilati DENTRO l'albero sorgente:"
    echo "$STRAY" | sed 's/^/        /'
    warn "Non appartengono a nessuna architettura in particolare e la build li"
    warn "riuserebbe. Rimuovili con:  rm -f $SRCDIR/*.o $SRCDIR/moc_* $SRCDIR/Makefile"
    error "Albero sorgente contaminato: mi fermo."
fi

# ── Preparazione archivio sorgente ────────────────────────────────────────────
TARBALL="${PACKAGE_NAME}.tar.bz2"

mkdir -p "$SRCDIR/rpm/BUILD" "$BUILDDIR" "$COLLECTDIR"

# Patch spec con %pre/%preun (spectacle non supporta scriptlet nel yaml).
# Idempotente: rimuove eventuali blocchi esistenti e li reinserisce, cosi'
# residui da edit manuali o run precedenti non bloccano l'iniezione.
SPEC_FILE="rpm/${PACKAGE_NAME}.spec"
info "Injecting %pre/%preun scriptlets into spec"
awk '
    # Salta righe dei blocchi %pre/%preun/%posttrans/%postun esistenti fino al prossimo %tag
    /^%(pre|preun|posttrans|postun)$/ { in_block = 1; next }
    in_block && /^%[a-zA-Z]/ && !/^%(pre|preun|posttrans|postun)$/ { in_block = 0 }
    in_block { next }
    # Inietta i nostri scriptlet prima di %prep
    /^%prep$/ && !injected {
        print "%pre"
        print "pkill -9 harbour-rootelegram >/dev/null 2>&1 || true"
        print "exit 0"
        print ""
        print "%preun"
        print "pkill -9 harbour-rootelegram >/dev/null 2>&1 || true"
        print "exit 0"
        print ""
        # Post-install: pulisci la cache QML di Qt e riavvia sailjaild.
        # - qmlcache: i .qmlc/.jsc possono riferire a simboli del binario vecchio.
        # - sailjaild: mantiene cache stale dei permessi sandbox dopo un rpm -U,
        #   causando search rotta + crash al primo avvio post-update. Riavviarlo
        #   resetta lo stato (verificato 2026-05-19).
        print "%posttrans"
        print "for d in /home/*/.cache/QtProject/qmlcache; do"
        print "  [ -d \"$d\" ] && rm -f \"$d\"/*.qmlc \"$d\"/*.jsc 2>/dev/null || true"
        print "done"
        print "systemctl try-restart sailjaild >/dev/null 2>&1 || true"
        # Registra lo schema handler tg:/t.me appena installato e ripulisce i
        # residui per-utente delle vecchie versioni (open-url scritto a runtime
        # e bus name ibrido stale de.ygriega.rootelegram).
        print "update-desktop-database /usr/share/applications >/dev/null 2>&1 || true"
        print "for u in /home/*; do"
        print "  rm -f \"$u\"/.local/share/applications/harbour-rootelegram-open-url.desktop 2>/dev/null || true"
        print "  rm -f \"$u\"/.local/share/dbus-1/services/de.ygriega.rootelegram.service 2>/dev/null || true"
        print "  [ -d \"$u\"/.local/share/applications ] && update-desktop-database \"$u\"/.local/share/applications >/dev/null 2>&1 || true"
        print "done"
        # [2.8.8] Abilita autostart al boot per tutte le sessioni utente (systemctl --global,
        # gira da root, no sandbox). Il servizio controlla poi il marker per-utente.
        print "systemctl --global enable harbour-rootelegram.service >/dev/null 2>&1 || true"
        # Il plugin voicecall viene caricato da voicecall-manager SOLO al suo
        # avvio: senza un riavvio del servizio resterebbe inerte fino al reboot.
        # La logica sta in uno script a parte, e NON va messa qui dentro: questo
        # e un programma awk racchiuso tra apici singoli, quindi un apostrofo o
        # una sottoshell lo spezzano (successo il 2026-08-15).
        # ATTENZIONE: niente apostrofi nei commenti di questo blocco.
        print "sh /usr/share/harbour-rootelegram/bin/restart-voicecall.sh >/dev/null 2>&1 || true"
        print "exit 0"
        print ""
        # Alla rimozione definitiva del pacchetto (arg 0) disabilita il servizio utente.
        print "%postun"
        print "if [ \"$1\" = 0 ]; then"
        print "  systemctl --global disable harbour-rootelegram.service >/dev/null 2>&1 || true"
        print "fi"
        print "exit 0"
        print ""
        injected = 1
    }
    { print }
' "$SPEC_FILE" > "${SPEC_FILE}.tmp" && mv "${SPEC_FILE}.tmp" "$SPEC_FILE"

# Nascondi il yaml su disco PRIMA del tar e PRIMA di sfdk build/package: senza
# il yaml, specify non puo' essere chiamato e i nostri %pre/%preun nello spec
# sopravvivono fino all'RPM finale. Restore garantito da trap EXIT.
YAML_FILE="$SRCDIR/rpm/${PACKAGE_NAME}.yaml"
if [[ -f "$YAML_FILE" ]]; then
    info "Hiding yaml on disk to prevent specify regeneration"
    trap 'if [[ -f "${YAML_FILE}.disabled" ]]; then mv "${YAML_FILE}.disabled" "${YAML_FILE}"; fi' EXIT
    mv "$YAML_FILE" "${YAML_FILE}.disabled"
fi

# Compressore dell'archivio sorgente. `bzip2` e' SINGLE-THREAD e da solo si
# prendeva decine di minuti con 32 core fermi a guardare. `lbzip2` produce un
# .bz2 identico come formato (rpmbuild non nota la differenza) ma comprime su
# tutti i core. Se non c'e', si ricade sul bzip2 classico: nessuna build si
# rompe per la sua assenza.
if command -v lbzip2 >/dev/null 2>&1; then
    TAR_COMPRESS=(-I lbzip2)
    info "Compressione archivio con lbzip2 (parallelo, $(nproc) core)"
else
    TAR_COMPRESS=(-j)
    info "lbzip2 non trovato: compressione con bzip2 (single-thread, lenta)"
fi

# ⭐ Esclusioni: nell'archivio va SOLO cio' che serve a compilare. Prima ci
# finivano dentro anche _ffmpeg_build/ (446 MB di scarti), RPMS/ (gli RPM gia'
# fatti), il binario e i .o: erano loro i "2,1 GB" che rendevano il tar il passo
# piu' lento dell'intera build. I .list sono residui di rpmbuild.
# SKIP_TAR=1 riusa l'archivio esistente: utile quando si ripete la build dopo aver
# toccato SOLO lo spec (l'archivio non c'entra) — ⛔ da NON usare dopo aver
# modificato dei sorgenti, perche' l'RPM conterrebbe i file vecchi.
if [[ "${SKIP_TAR:-0}" == "1" && -f "$SRCDIR/rpm/$TARBALL" ]]; then
    warn "SKIP_TAR=1: riuso l'archivio esistente rpm/$TARBALL ($(du -h "$SRCDIR/rpm/$TARBALL" | cut -f1))"
else
info "Creazione archivio sorgente rpm/$TARBALL ..."
tar "${TAR_COMPRESS[@]}" -cf "$SRCDIR/rpm/$TARBALL" \
    --exclude='./.git' \
    --exclude='./rpm/BUILD' \
    --exclude='./rpm/*.tar.bz2' \
    --exclude='./_ffmpeg_build' \
    --exclude='./RPMS' \
    --exclude='./log.txt' \
    --exclude='./.sfdk' \
    --exclude='*.list' \
    --exclude='*.o' \
    --exclude='moc_*' \
    --exclude='./Makefile' \
    --exclude='./voicecallplugin/Makefile' \
    --exclude='./voicecallplugin/*.so' \
    --transform "s|^\.|${PACKAGE_NAME}-${VERSION}|" \
    -C "$SRCDIR" .

info "Archivio creato: rpm/$TARBALL ($(du -h "$SRCDIR/rpm/$TARBALL" | cut -f1))"
fi

# --- Guard anti-stale APP_VERSION (idempotente) -------------------------------
# La macro APP_VERSION (-> AboutPage "RooTelegram X.Y", application_version TDLib)
# viene CEMENTATA negli oggetti compilati (harbour-rootelegram.o, tdlibwrapper.o).
# Se RT_APP_VERSION cambia ma i .o NON vengono ricompilati, il binario riporta la
# VECCHIA versione pur essendo l'RPM quella nuova (bug ricorrente). Lo stamp vive
# nella cartella di build DI QUESTA ARCH, cosi' ogni arch ha la sua contabilita'.
VERSION_STAMP="$BUILDDIR/.last_built_app_version"
if [[ ! -f "$VERSION_STAMP" || "$(cat "$VERSION_STAMP" 2>/dev/null)" != "$VERSION" ]]; then
    info "RT_APP_VERSION=${VERSION} diversa dall'ultimo build di $ARCH ($(cat "$VERSION_STAMP" 2>/dev/null || echo 'nessuno')): rimuovo i .o stale"
    find "$BUILDDIR" -maxdepth 2 -name '*.o' -delete 2>/dev/null || true
fi
# ------------------------------------------------------------------------------

# ── Compilazione, FUORI dall'albero ───────────────────────────────────────────
# `sfdk build <project-dir>` fa una SHADOW BUILD: la directory corrente diventa
# la cartella di build e l'albero passato come argomento resta intatto.
cd "$BUILDDIR"
"$SB2_CMD" config --global target="$SFOS_TARGET"

info "Compilazione (shadow build) in $BUILDDIR ..."
"$SB2_CMD" build "$SRCDIR"

info "Creazione pacchetto RPM ..."
"$SB2_CMD" package

# Build andato a buon fine: registra la versione compilata.
echo "$VERSION" > "$VERSION_STAMP"

# Ripristina yaml subito (anche il trap EXIT lo farebbe, belt-and-suspenders)
if [[ -f "${YAML_FILE}.disabled" ]]; then
    mv "${YAML_FILE}.disabled" "$YAML_FILE"
    trap - EXIT
fi

# ── Raccolta dell'RPM installabile ────────────────────────────────────────────
# Nel raccoglitore va SOLO il pacchetto installabile: debuginfo e debugsource
# restano nella cartella di build dell'arch (servono a leggere i crash, non al
# telefono).
MAIN_RPM="$(ls -t "$BUILDDIR"/RPMS/${PACKAGE_NAME}-${VERSION}-${RELEASE}.${ARCH}.rpm 2>/dev/null | head -1 || true)"
if [[ -n "$MAIN_RPM" ]]; then
    cp -f "$MAIN_RPM" "$COLLECTDIR/"
    info "RPM copiato nel raccoglitore: $COLLECTDIR/$(basename "$MAIN_RPM")"
else
    warn "RPM principale non trovato in $BUILDDIR/RPMS — controlla l'output qui sopra"
fi

info ""
info "────────────────────────────────────────────────────────"
info "Build completato — architettura: $ARCH"
ls -la "$BUILDDIR"/RPMS/*.rpm 2>/dev/null || true
info "────────────────────────────────────────────────────────"
info ""
info "Installazione sul dispositivo:"
info "  scp $COLLECTDIR/${PACKAGE_NAME}-${VERSION}-${RELEASE}.${ARCH}.rpm defaultuser@<device-ip>:/tmp/"
info "  ssh defaultuser@<device-ip> 'devel-su rpm -Uvh /tmp/${PACKAGE_NAME}-${VERSION}-${RELEASE}.${ARCH}.rpm'"
