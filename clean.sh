#!/bin/bash
set -euo pipefail

PURPLE="\x1b[1;35m"
YELLOW="\x1b[1;33m"
TEAL="\x1b[2;36m"
BWHITE="\x1b[1;37m"
GREEN="\x1b[1;32m"
NC="\x1b[0m"

# Map PDTERM
PDTERM="wincon"
echo "Preparing clean build dir"

# --- 2. Configuration & Environment ---
BASE_DIR="$(pwd)"
BUILDDIR="${BASE_DIR}/build"

mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"

# Global variables from your workflow
export CFLAGS="-O2 -fno-math-errno -flto -std=c17 -Wno-error -DCHTYPE_64 -DPDC_WIDE -DPDC_WINCON -DPDC_FORCE_UTF8 -D_GNU_SOURCE"
export WT_SESSION="1"
export ConEmuANSI="ON"

# --- 3. Toolchain Setup (gfunkmonk/win-cross) ---
#echo -e "${TEAL}Setting up toolchain...${NC}"
#TOOLCHAIN_RELEASE="BillsBastards" # Plug in release name here

# Define a persistent toolchain directory outside the BUILDDIR if you want true persistence,
# or just check if it's already in the BUILDDIR.
#if [ ! -d "$BASE_DIR/toolchains/x86_64-mingw" ]; then
#    echo -e "${YELLOW}Downloading toolchain release: ${TOOLCHAIN_RELEASE}${NC}"
#    mkdir -p "$BASE_DIR/toolchains"
#    curl -L -o "$BASE_DIR/toolchains/toolchain.tar.xz" "https://github.com/gfunkmonk/win-cross/releases/download/${TOOLCHAIN_RELEASE}/${1}-w64-mingw32.tar.xz"
#    cd "$BASE_DIR/toolchains"
#    tar -xJf toolchain.tar.xz && mv "x86_64"-* "x86_64"-mingw && rm toolchain.tar.xz
#    cd "$BASE_DIR"
#else
#    echo -e "${GREEN}Toolchain cache hit: x86_64-mingw found.${NC}"
#fi

#export PATH="$BASE_DIR/toolchains/x86_64-mingw/bin:$PATH"

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
sync_repo "https://github.com/coreutils/gnulib.git" "gnulib"

# Gnulib Import (The glibc fix)
#modules="base32 base64 futimens getdelim getline getopt-gnu glob isblank iswblank lstat mbrlen mbchar mkstemps nl_langinfo regex rewinddir sigaction snprintf-posix stdarg-h strcase strcasestr-simple strnlen sys_wait-h uniwidth unitypes unictype/property-emoji vsnprintf-posix wchar-h wctype-h wcwidth"
#./gnulib/gnulib-tool --import $modules
#autopoint --force && aclocal -I m4 && autoconf && autoheader && automake --add-missing

