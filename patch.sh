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

# --- Configuration & Environment ---
BASE_DIR="$(pwd)"
BUILDDIR="${BASE_DIR}/build"

mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"

sync_repo "https://github.com/GitMirroring/nano.git" "nano" "$CARIBBEAN"
cd nano
sync_repo "https://github.com/Bill-Gray/PDCursesMod.git" "curses" "$CARIBBEAN"
sync_repo "https://github.com/coreutils/gnulib.git" "gnulib" "$CARIBBEAN"

# Gnulib Import (The glibc fix)
#modules="canonicalize-lgpl futimens getdelim getline getopt-gnu glob isblank iswblank lstat mbchar mbrlen mkstemps nl_langinfo regex rewinddir sigaction snprintf-posix stdarg-h strcase strcasestr-simple strnlen sys_wait-h uniwidth vsnprintf-posix wchar-h wctype-h wcwidth"
#./gnulib/gnulib-tool --import $modules
#autopoint --force && aclocal -I m4 && autoconf && autoheader && automake --add-missing

# Patch Nano
if [ -d "$BASE_DIR/patch/nano" ]; then
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        echo -e "${RED}Applying $(basename "$p") to nano${NC}"
        patch -p1 < "$p" || exit 1
    done < <(find "$BASE_DIR/patch/nano" -maxdepth 1 -type f -name '*.patch' | sort -V)
fi

# Patch Curses (common)
if [ -d "$BASE_DIR/patch/curses/common" ]; then
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        echo -e "${TEAL}Applying $(basename "$p") to curses${NC}"
        patch -p1 < "$p" || exit 1
    done < <(find "$BASE_DIR/patch/curses/common" -maxdepth 1 -type f -name '*.patch' | sort -V)
fi
# Patch Curses (PDTERM-specific)
if [ -d "$BASE_DIR/patch/curses/$PDTERM" ]; then
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        echo -e "${GREEN}Applying $(basename "$p") to curses${NC}"
        patch -p1 < "$p" || exit 1
    done < <(find "$BASE_DIR/patch/curses/$PDTERM" -maxdepth 1 -type f -name '*.patch' | sort -V)
fi

# realpath() workaround — guarded so re-runs don't append duplicates
echo -e "${BLUE}[${YELLOW}definitions.h${BLUE}] ${BWHITE}realpath() workaround applied.${NC}"
if ! grep -q 'realpath(N,R)' ./src/definitions.h; then
    cp -p ./src/definitions.h{,.bak}
    printf '\n#ifdef _WIN32\n#include <windows.h>\n#include "uniwidth.h"\n#define realpath(N,R) _fullpath((R),(N),0)\n#endif\n' \
        >> ./src/definitions.h
fi

# Default open() files in binary mode
echo -e "${BLUE}[${YELLOW}files.c${BLUE}] ${BWHITE}default open in binary mode${NC}"
sed -i 's/O_..ONLY/& | _O_BINARY/g' ./src/files.c
sed -i 's/O_..ONLY/& | _O_BINARY/g' ./src/text.c

# Environment and Path Fixes
echo -e "${BLUE}[${YELLOW}files.c${BLUE}] ${BWHITE}Swapping TMPDIR for TEMP${NC}"
sed -i 's|TMPDIR|TEMP|g' ./src/files.c

echo -e "${BLUE}[${YELLOW}files.c${BLUE}] ${BWHITE}Hardening invalid character check${NC}"
sed -i 's!if (thename\[i\] == "/")!if (strchr("<>\\\\:\\\"/\\\\\\\\|?*", thename[i]))!g' src/files.c

echo -e "${BLUE}[${YELLOW}files.c${BLUE}] ${BWHITE}Injecting backslash normalization loop${NC}"
perl -i -pe "s|if\(\*tilded == \"\\\\\\\\\"\)|if(*tilded == '\\\\')|g; s|\*tilded = \"/\"|*tilded = '/'|g" src/files.c

echo -e "${BLUE}[${YELLOW}files.c${BLUE}] ${BWHITE}Updating path separator comparison${NC}"
perl -i -pe 's|path\[i\] != \x27/\x27|path[i] != \x27/\x27 && path[i] != \x27\\\\\x27|g' src/files.c

echo -e "${BLUE}[${YELLOW}files.c${BLUE}] ${BWHITE}Redirecting /tmp/ to AppData Local${NC}"
sed -i 's|/tmp/|~/AppData/Local/Temp/|g' ./src/files.c

echo -e "${BLUE}[${YELLOW}utils.c${BLUE}] ${BWHITE}Mapping HOME to USERPROFILE${NC}"
sed -i 's|\"HOME\"|"USERPROFILE\"|g' ./src/utils.c

# UI and Terminal Logic
echo -e "${BLUE}[${YELLOW}rcfile.c${BLUE}] ${BWHITE}Patching 256 color support check${NC}"
sed -i "/COLORS == 256/ {s/==/>=/}" src/rcfile.c

echo -e "${BLUE}[${YELLOW}winio.c${BLUE}] ${BWHITE}Stripping halfdelay and kb_interrupt calls${NC}"
sed -i "/halfdelay(ISSET(QUICK_BLANK)/,/disable_kb_interrupt/d" src/winio.c

echo -e "${BLUE}[${YELLOW}nano.c${BLUE}] ${BWHITE}Mapping /dev/tty to CON${NC}"
sed -i "s|/dev/tty|CON|" src/nano.c

# The STDIN / Stream Handler
echo -e "${BLUE}[${YELLOW}nano.c${BLUE}] ${BWHITE}Fixing stream/fd assignment${NC}"
sed -i "s/stream, 0/stream, fd/" src/nano.c

echo -e "${BLUE}[${YELLOW}nano.c${BLUE}] ${BWHITE}Injecting Windows Console/STDIN handler block${NC}"
sed -i "/FILE \*stream/,/stop the reading/ c\\
\t static FILE *stream;\\n\\
\t static int fd=0;\\n\\
\t if (fd==0){\\n\\
\t if (GetConsoleWindow() != NULL)\\n\\
\t fprintf(stderr, _(\"Reading data from keyboard; type a ^Z line to finish.\\\\n\"));\\n\\
\t fd = dup(0);\\n\\
\t stream = fdopen(fd, \"rb\");\\n\\
\t freopen(\"CON\", \"rb\", stdin);\\n\\
\t FreeConsole();\\n\\
\t AttachConsole(ATTACH_PARENT_PROCESS);\\n\\
\t return FALSE;}\\n\\
\t endwin();\\n\\
\t if (stream == NULL) {\\n\\
\t \t int errnumber = errno;\\n\\
\t \t if(fd > -1) close(fd);\\n\\
\t return FALSE;}" src/nano.c

echo -e "${BLUE}[${YELLOW}nano.c${BLUE}] ${BWHITE}Adding scoop_stdin trigger${NC}"
sed -i "/initscr/i\\
\t for(int optind_=optind; optind_ < argc;optind_++)\\n\\
\t if (strcmp(argv[optind_], \"-\") == 0){scoop_stdin();break;}" src/nano.c

# Prompts and Character Handling
echo -e "${BLUE}[${YELLOW}browser.c${BLUE}] ${BWHITE}Zeroing selected status${NC}"
sed -i 's/--selected/selected=0/' src/browser.c

# GNUlib glob wraps opendir with its own gl_directory type, so dir is
# struct gl_directory* by the time rewinddir is called. Cast it to DIR*.
echo -e "${BLUE}[${YELLOW}browser.c${BLUE}] ${BWHITE}fix GNUlib glob DIR* conflict${NC}"
sed -i 's/rewinddir(dir)/rewinddir((DIR *)dir)/' src/browser.c

echo -e "${BLUE}[${YELLOW}nano.c${BLUE}] ${BWHITE}Updating modified buffer prompt text${NC}"
sed -i "s|Save modified buffer|& (Y/N/^C)|" src/nano.c

echo -e "${BLUE}[${YELLOW}nano.c${BLUE}] ${BWHITE}Cleaning vt220 and applying setlocale${NC}"
sed -i 's|vt220||g; /x1B/d; /nl_langinfo(CODESET)/ c\tsetlocale(LC_ALL, "");' src/nano.c

echo -e "${BLUE}[${YELLOW}nano.c${BLUE}] ${BWHITE}Injecting UTF-8 Code Page (65001) force${NC}"
sed -i '/setlocale(LC_ALL, "");/a #ifdef _WIN32\n\tSetConsoleOutputCP(65001);\n\tSetConsoleCP(65001);\n#endif' src/nano.c

echo -e "${BLUE}[${YELLOW}chars.c${BLUE}] ${BWHITE}Including uniwidth.h${NC}"
sed -i '/prototypes.h/a#include "uniwidth.h"' src/chars.c

echo -e "${BLUE}[${YELLOW}definitions.h${BLUE}] ${BWHITE}Deleting 0x42 range${NC}"
sed -i "/0x42[1234]/d" src/definitions.h

# Adjust winio.c to prevent PDCurses from truncating high-plane characters
echo -e "${BLUE}[${YELLOW}winio.c${BLUE}] ${BWHITE}fix wcwidth${NC}"
sed -i '/if (is_extended_char(wc))/i \    if (wc > 0xFFFF) return true;' src/winio.c

# Ensure the title bar and status bar allow for multi-column character spacing
sed -i 's/waddnwstr(window, \&widechar, 1);/waddnwstr(window, \&widechar, wcwidth(widechar));/' src/winio.c

# PDCurses uses 64bit (chtype) for cell attributes instead of 32bit (int)
echo -e "${BLUE}[${YELLOW}various${BLUE}] ${BWHITE}Improving from 256colors to true color${NC}"
sed -i "/interface_color_pair/ s/\bint\b/chtype/g" src/prototypes.h src/global.c
sed -i "/int attributes/ s/\bint\b/chtype/g" src/definitions.h
sed -i "/int attributes/ s/\bint\b/chtype/g" src/rcfile.c
sed -i "/bool parse_combination/ s/\bint\b/chtype/g" src/rcfile.c

echo -e "${BLUE}[${YELLOW}wincon & vt${BLUE}] ${BWHITE}PDC_display_utf8 = TRUE${NC}"
sed -i 's/PDC_display_utf8 = FALSE/PDC_display_utf8 = TRUE/g' curses/wincon/*.c
sed -i 's/PDC_display_utf8 = FALSE/PDC_display_utf8 = TRUE/g' curses/vt/*.c
sed -i 's/PDC_display_utf8 = FALSE/PDC_display_utf8 = TRUE/g' curses/wingui/*.c

echo -e "${BLUE}[${YELLOW}pdckbd.c${BLUE}] ${BWHITE}Forced for 64-bit chtype${NC}"
sed -i 's/#if WCHAR_MAX > 65535/#if 1 \/\/ Forced for 64-bit chtype/g' curses/vt/pdckbd.c
sed -i 's/#if WCHAR_MAX > 65535/#if 1 \/\/ Forced for 64-bit chtype/g' curses/wincon/pdckbd.c
sed -i 's/#if WCHAR_MAX > 65535/#if 1 \/\/ Forced for 64-bit chtype/g' curses/wingui/pdckbd.c

echo -e "${BLUE}[${YELLOW}curspriv.h${BLUE}] ${BWHITE}Make MAX_UNICODE suck less.${NC}"
sed -i 's|MAX_UNICODE 0x110000|MAX_UNICODE 0x10ffff|g' curses/curspriv.h
