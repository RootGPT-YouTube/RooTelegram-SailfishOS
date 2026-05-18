#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# build-rpm.sh — Build harbour-rootelegram Beta 1.5
#                per SailfishOS 5 con il Sailfish Platform SDK
#
# Prerequisiti:
#   1. Sailfish SDK installato (default: ~/SailfishOS)
#   2. Target aarch64 (SailfishOS-5.0.0-aarch64) installato nel Platform SDK
#   3. libtdjson.so per aarch64 presente in lib/aarch64/ (vedi note sotto)
#
# Uso:
#   cd harbour-rootelegram-beta-1.5
#   bash build-rpm.sh
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Configurazione ────────────────────────────────────────────────────────────
PACKAGE_NAME="harbour-rootelegram"
# Single source of truth: la variabile VERSION nel .pro. Da qui sincronizziamo
# anche rpm/*.{spec,yaml}, così basta bumpare in un solo posto (il .pro).
VERSION="$(grep -E '^VERSION[[:space:]]*=' "${PACKAGE_NAME}.pro" | head -1 | awk -F= '{print $2}' | tr -d ' "')"
if [[ -z "$VERSION" ]]; then
    echo "[ERROR] Impossibile leggere VERSION da ${PACKAGE_NAME}.pro" >&2
    exit 1
fi
RELEASE="1"

# Sincronizza rpm/*.spec e rpm/*.yaml con la VERSION del .pro
sed -i -E "s/^(Version:[[:space:]]+).*/\1${VERSION}/" "rpm/${PACKAGE_NAME}.spec" "rpm/${PACKAGE_NAME}.yaml"
# Auto-detect target dall'arch della directory corrente. Le cartelle parallele
# sono `_aarch64`, `_armv7hl`, `_i486`: cosi' lo stesso script va bene per
# tutte e tre senza override esplicito.
if [[ -z "${SFOS_TARGET:-}" ]]; then
    case "$PWD" in
        *_aarch64*) SFOS_TARGET="SailfishOS-5.0.0.62-aarch64" ;;
        *_armv7hl*) SFOS_TARGET="SailfishOS-5.0.0.62-armv7hl" ;;
        *_i486*)    SFOS_TARGET="SailfishOS-5.0.0.62-i486" ;;
        *)          SFOS_TARGET="SailfishOS-5.0.0.62-aarch64" ;;
    esac
fi
SDK_DIR="${SDK_DIR:-$HOME/SailfishOS}"
SB2_CMD="$SDK_DIR/bin/sfdk"                                 # Sailfish SDK ≥ 3.x usa sfdk

# ── Colori ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[BUILD]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN] ${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Verifica SDK ──────────────────────────────────────────────────────────────
if [[ ! -f "$SB2_CMD" ]]; then
    error "Sailfish SDK non trovato in $SDK_DIR. Installalo da https://sailfishos.org/develop/"
fi

info "Sailfish SDK trovato: $SB2_CMD"
info "Target: $SFOS_TARGET"

# ── Verifica TDLib ────────────────────────────────────────────────────────────
TDLIB_SO="tdlib/aarch64/lib/libtdjson.so"
if [[ ! -f "$TDLIB_SO" ]]; then
    warn "TDLib non trovata in $TDLIB_SO"
    warn ""
    warn "Devi fornire libtdjson.so compilata per aarch64 SailfishOS."
    warn "Opzioni:"
    warn "  A) Scarica da OBS: https://build.sailfishos.org/package/show/home:werkwolf/libtdjson"
    warn "  B) Compila con: https://github.com/Wunderfitz/harbour-rootelegram#building-tdlib"
    warn ""
    warn "Poi copiala in: $TDLIB_SO"
    warn ""
    read -rp "Vuoi continuare senza TDLib (il build fallirà al link step)? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || exit 1
fi

# ── Inizializzazione rlottie ──────────────────────────────────────────────────
SRCDIR="$(pwd)"
if [[ ! -f "$SRCDIR/rlottie/CMakeLists.txt" ]] || grep -q "zip_stream_open\|zip_entry" "$SRCDIR/rlottie/src/lottie/lottieparser.cpp" 2>/dev/null; then
    info "Clonazione rlottie v0.2 da Samsung/rlottie..."
    rm -rf "$SRCDIR/rlottie"
    git clone --depth=1 --branch v0.2 https://github.com/Samsung/rlottie.git "$SRCDIR/rlottie"
    info "rlottie clonato"
else
    info "rlottie già presente, skip clone"
fi

# ── Preparazione archivio sorgente ────────────────────────────────────────────
TARBALL="${PACKAGE_NAME}.tar.bz2"

info "Creazione archivio sorgente $TARBALL ..."
mkdir -p "$SRCDIR/rpm/BUILD"

# Patch spec con %pre/%preun (spectacle non supporta scriptlet nel yaml).
# Idempotente: rimuove eventuali blocchi esistenti e li reinserisce, cosi'
# residui da edit manuali o run precedenti non bloccano l'iniezione.
SPEC_FILE="rpm/${PACKAGE_NAME}.spec"
info "Injecting %pre/%preun scriptlets into spec"
awk '
    # Salta righe dei blocchi %pre/%preun esistenti fino al prossimo %tag
    /^%(pre|preun)$/ { in_block = 1; next }
    in_block && /^%[a-zA-Z]/ && !/^%(pre|preun)$/ { in_block = 0 }
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
        injected = 1
    }
    { print }
' "$SPEC_FILE" > "${SPEC_FILE}.tmp" && mv "${SPEC_FILE}.tmp" "$SPEC_FILE"

# Nascondi il yaml su disco PRIMA del tar e PRIMA di sfdk build/package: senza
# il yaml, specify non puo' essere chiamato e i nostri %pre/%preun nello spec
# sopravvivono fino all'RPM finale. Restore garantito da trap EXIT.
YAML_FILE="rpm/${PACKAGE_NAME}.yaml"
if [[ -f "$YAML_FILE" ]]; then
    info "Hiding yaml on disk to prevent specify regeneration"
    trap 'if [[ -f "${YAML_FILE}.disabled" ]]; then mv "${YAML_FILE}.disabled" "${YAML_FILE}"; fi' EXIT
    mv "$YAML_FILE" "${YAML_FILE}.disabled"
fi

tar cjf "$SRCDIR/rpm/$TARBALL" \
    --exclude='.git' \
    --exclude='rpm/BUILD' \
    --exclude='rpm/*.tar.bz2' \
    --transform "s|^\.|${PACKAGE_NAME}-${VERSION}|" \
    -C "$SRCDIR" .

info "Archivio creato: rpm/$TARBALL"

# ── Risolvi il target aarch64 disponibile ─────────────────────────────────────
# Se SFOS_TARGET non è stato sovrascritto dall'utente, auto-rileva
if [[ "$SFOS_TARGET" == "SailfishOS-5.0.0.0-aarch64" ]]; then
    info "Auto-rilevamento target aarch64..."
    DETECTED=$("$SB2_CMD" tools list 2>/dev/null | grep -i "aarch64" | awk '{print $1}' | head -1)
    if [[ -n "$DETECTED" ]]; then
        SFOS_TARGET="$DETECTED"
        info "Target rilevato automaticamente: $SFOS_TARGET"
    else
        error "Nessun target aarch64 trovato. Esegui: ~/SailfishOS/bin/sfdk tools list"
    fi
fi

cd "$SRCDIR"

# Imposta il target (sintassi sfdk >= 3.x)
"$SB2_CMD" config --global target="$SFOS_TARGET"

# 1. Compila (qmake + make)
"$SB2_CMD" build

# 2. Crea il pacchetto RPM
"$SB2_CMD" package

# Ripristina yaml subito (anche il trap EXIT lo farebbe, belt-and-suspenders)
if [[ -f "${YAML_FILE}.disabled" ]]; then
    mv "${YAML_FILE}.disabled" "$YAML_FILE"
    trap - EXIT
fi

info ""
info "────────────────────────────────────────────────────────"
info "Build completato!"
info "RPM si trova in: RPMS/"
ls RPMS/aarch64/*.rpm 2>/dev/null || ls *.rpm 2>/dev/null || true
info "────────────────────────────────────────────────────────"
info ""
info "Installazione sul dispositivo:"
info "  scp RPMS/aarch64/${PACKAGE_NAME}-${VERSION}-${RELEASE}.aarch64.rpm nemo@<device-ip>:/tmp/"
info "  ssh nemo@<device-ip> 'pkcon install-local /tmp/${PACKAGE_NAME}-${VERSION}-${RELEASE}.aarch64.rpm'"
