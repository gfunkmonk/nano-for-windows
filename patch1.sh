#!/bin/bash
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 PDTERM"
    echo "Example: $0 wincon"
    exit 1
fi

PURPLE="\x1b[1;35m"
YELLOW="\x1b[1;33m"
BROWN="\x1b[0;33m"
TEAL="\x1b[2;36m"
BWHITE="\x1b[1;37m"
GREEN="\x1b[1;32m"
BLUE="\x1b[1;34m"
CYAN="\x1b[1;36m"
RED="\x1b[1;31m"
ORANGE="$(tput setaf 214)"
NEONBLUE="\033[38;2;4;218;255m"
NEONGREEN="\033[38;2;57;255;20m"
NEONPINK="\033[38;2;255;19;240m"
NEONPURPLE="\033[38;2;225;8;255m"
NEONRED="\033[38;2;255;49;49m"
JUNEBUD="\033[38;2;189;218;87m"
HIGHLIGHTER="\033[38;2;248;255;15m"
NC="\x1b[0m"

for cmd in git curl tar patch sed perl; do
    command -v "$cmd" >/dev/null 2>&1 || echo -e  "${RED}$cmd is required but not installed.${NC}"
done

# Map PDTERM
PDTERM="$1"

case "$PDTERM" in
     vt)
      export _NAME="VirtTerm"
      export _PAD="######"
      export _PAD2="  "
      ;;
     wincon)
      export _NAME="WinCon"
      export _PAD="####"
      export _PAD2=""
      ;;
     wingui)
      export _NAME="WinGUI"
      export _PAD="####"
      export _PAD2=""
      ;;
    *) echo "Invalid PDTERM: $PDTERM (expected wincon, wingui, or vt)"; exit 1 ;;
esac

echo -e "${NEONGREEN}##########################################${_PAD}"
echo -e "${NEONGREEN}%%  ${BWHITE}Patching for ${CYAN}nano ${BWHITE}and PDTERM is ${HIGHLIGHTER}${_NAME}  ${NEONGREEN}%%${NC}"
echo -e "${NEONGREEN}%%        ${_PAD2} ${NEONRED}  without sed patches          ${NEONGREEN}  %%"
echo -e "${NEONGREEN}##########################################${_PAD}"
sleep 2

# --- Configuration & Environment ---
BASE_DIR="$(pwd)"
BUILDDIR="${BASE_DIR}/build"

mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"

# --- Source Setup ---
# Function to sync without redownloading the universe
sync_repo() {
    local url=$1
    local dir=$2
    if [ ! -d "$dir" ]; then
        git clone "$url" --depth=1 "$dir"
    else
        echo -e "${YELLOW}Syncing $dir...${NC}"
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
sync_repo "https://github.com/coreutils/gnulib.git" "gnulib"

# Gnulib Import (The glibc fix)
#modules="base32 base64 futimens getdelim getline getopt-gnu glob isblank iswblank lstat mbrlen mbchar mkstemps nl_langinfo regex rewinddir sigaction snprintf-posix stdarg-h strcase strcasestr-simple strnlen sys_wait-h uniwidth unitypes unictype/property-emoji vsnprintf-posix wchar-h wctype-h wcwidth"
#./gnulib/gnulib-tool --import $modules
#autopoint --force && aclocal -I m4 && autoconf && autoheader && automake --add-missing

# Patch Nano
if [ -d "$BASE_DIR/patch/nano" ]; then
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        echo -e "${BLUE}Applying $(basename "$p") to nano${NC}"
        patch -p1 < "$p" || exit 1
    done < <(find "$BASE_DIR/patch/nano" -maxdepth 1 -type f -name '*.patch' | sort -V)
fi

# Patch Curses
if [ -d "$BASE_DIR/patch/curses/common" ]; then
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        echo -e "${PURPLE}Applying $(basename "$p") to curses${NC}"
        patch -p1 < "$p" || exit 1
    done < <(find "$BASE_DIR/patch/curses/common" -maxdepth 1 -type f -name '*.patch' | sort -V)
fi
if [ -d "$BASE_DIR/patch/curses/$PDTERM" ]; then
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        echo -e "${CYAN}Applying $(basename "$p") to curses${NC}"
        patch -p1 < "$p" || exit 1
    done < <(find "$BASE_DIR/patch/curses/$PDTERM" -maxdepth 1 -type f -name '*.patch' | sort -V)
fi
