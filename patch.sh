#!/bin/bash

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
check_deps git curl tar patch sed perl

# Map PDTERM
PDTERM="$1"

case "$PDTERM" in
    vt)
        export _NAME="VirtTerm"
        export _PAD="######"
        ;;
    wincon)
        export _NAME="WinCon"
        export _PAD="####"
        ;;
    wingui)
        export _NAME="WinGUI"
        export _PAD="####"
        ;;
    *) echo "Invalid PDTERM: $PDTERM (expected wincon, wingui, or vt)"; exit 1 ;;
esac

echo -e "${NEONGREEN}##########################################${_PAD}"
echo -e "${NEONGREEN}%%  ${BWHITE}Patching for ${NEONPURPLE}nano ${BWHITE}and ${ORANGE}PDTERM${BWHITE} is ${CYAN}${_NAME}  ${NEONGREEN}%%${NC}"
echo -e "${NEONGREEN}##########################################${_PAD}"
sleep 2

cd "${BUILDDIR}"

sync_repo "https://github.com/GitMirroring/nano.git" "nano" "$CARIBBEAN"
cd nano
sync_repo "https://github.com/Bill-Gray/PDCursesMod.git" "curses" "$CARIBBEAN"
sync_repo "https://github.com/coreutils/gnulib.git" "gnulib" "$CARIBBEAN"

#modules="canonicalize-lgpl futimens getdelim getline getopt-gnu glob isblank iswblank lstat mbchar mbrlen mkstemps nl_langinfo regex rewinddir sigaction snprintf-posix stdarg-h strcase strcasestr-simple strnlen sys_wait-h uniwidth vsnprintf-posix wchar-h wctype-h wcwidth"
#./gnulib/gnulib-tool --import $modules
#autopoint --force && aclocal -I m4 && autoconf && autoheader && automake --add-missing

patch_nano "$RED"

patch_curses "common" "$TEAL"
patch_curses "$PDTERM" "$GREEN"

sed_patches "$BLUE" "$YELLOW"
