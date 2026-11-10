#!/bin/bash

# patch1.sh — applies only .patch files, no inline sed/perl transforms.
# Use this to test patch files in isolation.

# Ensure this script is being run with bash
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script must be run with bash, not sh." >&2
    exit 1
fi

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 PDTERM"
    echo "Example: $0 wincon"
    exit 1
fi

# Load shared colors, check_deps, sync_repo
source "$(dirname "$0")/common.sh"

# --- Check Dependencies (exits on first missing tool) ---
check_deps git patch

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

echo -e "${HIGHLIGHTER}##########################################${_PAD}"
echo -e "${HIGHLIGHTER}%%  ${BWHITE}Patching for ${CARIBBEAN}nano ${BWHITE}and ${PEACH}PDTERM${BWHITE} is ${NEONGREEN}${_NAME}  ${HIGHLIGHTER}%%${NC}"
echo -e "${HIGHLIGHTER}%%        ${_PAD2} ${NEONRED}  without sed patches          ${HIGHLIGHTER}  %%"
echo -e "${HIGHLIGHTER}##########################################${_PAD}"
sleep 2

# --- Configuration & Environment ---
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDDIR="${BASE_DIR}/build"

mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"

sync_repo "https://github.com/gfunkmonk/nano-upstream.git" "nano" "$MAUVE"
cd nano
sync_repo "https://github.com/Bill-Gray/PDCursesMod.git" "curses" "$MAUVE"
sync_repo "https://github.com/coreutils/gnulib.git" "gnulib" "$MAUVE"

# Gnulib Import (The glibc fix)
#modules="canonicalize-lgpl futimens getdelim getline getopt-gnu glob isblank iswblank lstat mbchar mbrlen mkstemps nl_langinfo regex rewinddir sigaction snprintf-posix stdarg-h strcase strcasestr-simple strnlen sys_wait-h uniwidth vsnprintf-posix wchar-h wctype-h wcwidth"
#./gnulib/gnulib-tool --import $modules
#autopoint --force && aclocal -I m4 && autoconf && autoheader && automake --add-missing

patch_nano "$BLUE"

patch_curses "common" "$PURPLE"
patch_curses "$PDTERM" "$CYAN"
