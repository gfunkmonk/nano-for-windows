#!/bin/bash
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 PDTERM"
    echo "Example: $0 wincon"
    exit 1
fi

PURPLE="\x1b[1;35m"
YELLOW="\x1b[1;33m"
TEAL="\x1b[2;36m"
BWHITE="\x1b[1;37m"
GREEN="\x1b[1;32m"
NC="\x1b[0m"

# Map the input to the full triplet
#case "$1" in
#    x86_64)  TARGETS=("x86_64-w64-mingw32") ;;
#    i686)    TARGETS=("i686-w64-mingw32") ;;
#    aarch64) TARGETS=("aarch64-w64-mingw32") ;;
#    armv7) TARGETS=("armv7-w64-mingw32") ;;
#    *) echo "Invalid architecture: $1"; exit 1 ;;
#esac

# Map PDTERM
PDTERM="$1"
echo "Building for $1 with PDTERM=$PDTERM"

# --- 2. Configuration & Environment ---
BASE_DIR="$(pwd)"
BUILDDIR="${BASE_DIR}/build"

mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"

# --- 4. Source Setup ---
# Function to sync without redownloading the universe
sync_repo() {
    local url=$1
    local dir=$2
    if [ ! -d "$dir" ]; then
        git clone "$url" --depth=1 "$dir"
    else
        echo -e "${TEAL}Syncing $dir...${NC}"
        cd "$dir"
        git fetch --depth=1
        git reset --hard origin/$(git symbolic-ref --short HEAD)
        git clean -fd # Scrub the previous sed/patch debris
        cd ..
    fi
}

sync_repo "https://github.com/GitMirroring/nano.git" "nano"
cd nano
sync_repo "https://github.com/Bill-Gray/PDCursesMod.git" "curses"
sync_repo "https://git.savannah.gnu.org/git/gnulib.git" "gnulib"

# Gnulib Import (The glibc fix)
#modules="base32 base64 futimens getdelim getline getopt-gnu glob isblank iswblank lstat mbrlen mbchar mkstemps nl_langinfo regex rewinddir sigaction snprintf-posix stdarg-h strcase strcasestr-simple strnlen sys_wait-h uniwidth unitypes unictype/property-emoji vsnprintf-posix wchar-h wctype-h wcwidth"
#./gnulib/gnulib-tool --import $modules
#autopoint --force && aclocal -I m4 && autoconf && autoheader && automake --add-missing

# Patch Nano
if [ -d "$BASE_DIR/patch/nano" ]; then
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        echo -e "${PURPLE}Applying $(basename "$p") to nano${NC}"
        patch -p1 < "$p" || exit 1
    done < <(find "$BASE_DIR/patch/nano" -maxdepth 1 -type f -name '*.patch' | sort -V)
fi

# Patch Curses
if [ -d "$BASE_DIR/patch/curses/$PDTERM" ]; then
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        echo -e "${YELLOW}Applying $(basename "$p") to curses${NC}"
        patch -p1 < "$p" || exit 1
    done < <(find "$BASE_DIR/patch/curses/$PDTERM" -maxdepth 1 -type f -name '*.patch' | sort -V)
fi

