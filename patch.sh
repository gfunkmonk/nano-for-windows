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
NC="\x1b[0m"

# Map PDTERM
PDTERM="$1"

case "$PDTERM" in
     vt)      export _NAME="VT    " ;;
     wincon)  export _NAME="WinCon" ;;
     wingui)  export _NAME="WinGUI" ;;
    *) echo "Invalid PDTERM: $PDTERM (expected wincon, wingui, or vt)"; exit 1 ;;
esac

echo -e "${YELLOW}##############################################"
echo -e "${YELLOW}%%  ${BWHITE}Patching for ${PURPLE}nano ${BWHITE}and PDTERM is ${CYAN}${_NAME}  ${YELLOW}%%${NC}"
echo -e "${YELLOW}##############################################"
sleep 3

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
        echo -e "${GREEN}Syncing $dir...${NC}"
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
        echo -e "${PURPLE}Applying $(basename "$p") to nano${NC}"
        patch -p1 < "$p" || exit 1
    done < <(find "$BASE_DIR/patch/nano" -maxdepth 1 -type f -name '*.patch' | sort -V)
fi

# Patch Curses
if [ "$PDTERM" != "wingui" ]; then
  if [ -d "$BASE_DIR/patch/curses/common" ]; then
      while IFS= read -r p; do
          [ -n "$p" ] || continue
          echo -e "${BROWN}Applying $(basename "$p") to curses${NC}"
          patch -p1 < "$p" || exit 1
      done < <(find "$BASE_DIR/patch/curses/common" -maxdepth 1 -type f -name '*.patch' | sort -V)
  fi
fi
if [ -d "$BASE_DIR/patch/curses/$PDTERM" ]; then
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        echo -e "${YELLOW}Applying $(basename "$p") to curses${NC}"
        patch -p1 < "$p" || exit 1
    done < <(find "$BASE_DIR/patch/curses/$PDTERM" -maxdepth 1 -type f -name '*.patch' | sort -V)
fi

# realpath() workaround
echo -e "${BLUE}[${BWHITE}definitions.h${BLUE}] ${BWHITE}realpath() workaround applied.${NC}"
cp -p ./src/definitions.h{,.bak}
echo " " >> ./src/definitions.h
echo "#ifdef _WIN32" >> ./src/definitions.h
echo "#include <windows.h>"  >> ./src/definitions.h
echo "#include \"uniwidth.h\""  >> ./src/definitions.h
echo "#define realpath(N,R) _fullpath((R),(N),0)" >> ./src/definitions.h
echo "#endif" >> ./src/definitions.h

# Default open() files in binary mode
echo -e "${BLUE}[${BWHITE}files.c${BLUE}] ${BWHITE}default open in binary mode${NC}"
sed -i 's/O_..ONLY/& | _O_BINARY/g' ./src/files.c
sed -i 's/O_..ONLY/& | _O_BINARY/g' ./src/text.c

# Environment and Path Fixes
echo -e "${BLUE}[${BWHITE}files.c${BLUE}] ${BWHITE}Swapping TMPDIR for TEMP${NC}"
sed -i 's|TMPDIR|TEMP|g' ./src/files.c

echo -e "${BLUE}[${BWHITE}files.c${BLUE}] ${BWHITE}Hardening invalid character check${NC}"
sed -i 's!if (thename\[i\] == "/")!if (strchr("<>\\\\:\\\"/\\\\\\\\|?*", thename[i]))!g' src/files.c

echo -e "${BLUE}[${BWHITE}files.c${BLUE}] ${BWHITE}Injecting backslash normalization loop${NC}"
perl -i -pe "s|if\(\*tilded == \"\\\\\\\\\"\)|if(*tilded == '\\\\')|g; s|\*tilded = \"/\"|*tilded = '/'|g" src/files.c

echo -e "${BLUE}[${BWHITE}files.c${BLUE}] ${BWHITE}Updating path separator comparison${NC}"
perl -i -pe 's|path\[i\] != \x27/\x27|path[i] != \x27/\x27 && path[i] != \x27\\\\\x27|g' src/files.c

echo -e "${BLUE}[${BWHITE}files.c${BLUE}] ${BWHITE}Redirecting /tmp/ to AppData Local${NC}"
sed -i 's|/tmp/|~/AppData/Local/Temp/|g' ./src/files.c

echo -e "${BLUE}[${BWHITE}utils.c${BLUE}] ${BWHITE}Mapping HOME to USERPROFILE${NC}"
sed -i 's|\"HOME\"|"USERPROFILE\"|g' ./src/utils.c

# UI and Terminal Logic
echo -e "${BLUE}[${BWHITE}rcfile.c${BLUE}] ${BWHITE}Patching 256 color support check${NC}"
sed -i "/COLORS == 256/ {s/==/>=/}" src/rcfile.c

echo -e "${BLUE}[${BWHITE}winio.c${BLUE}] ${BWHITE}Stripping halfdelay and kb_interrupt calls${NC}"
sed -i "/halfdelay(ISSET(QUICK_BLANK)/,/disable_kb_interrupt/d" src/winio.c

echo -e "${BLUE}[${BWHITE}nano.c${BLUE}] ${BWHITE}Mapping /dev/tty to CON${NC}"
sed -i "s|/dev/tty|CON|" src/nano.c

# The STDIN / Stream Handler
echo -e "${BLUE}[${BWHITE}nano.c${BLUE}] ${BWHITE}Fixing stream/fd assignment${NC}"
sed -i "s/stream, 0/stream, fd/" src/nano.c

echo -e "${BLUE}[${BWHITE}nano.c${BLUE}] ${BWHITE}Injecting Windows Console/STDIN handler block${NC}"
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

echo -e "${BLUE}[${BWHITE}nano.c${BLUE}] ${BWHITE}Adding scoop_stdin trigger${NC}"
sed -i "/initscr/i\\
\t for(int optind_=optind; optind_ < argc;optind_++)\\n\\
\t if (strcmp(argv[optind_], \"-\") == 0){scoop_stdin();break;}" src/nano.c

# 6. Prompts and Character Handling
echo -e "${BLUE}[${BWHITE}browser.c${BLUE}] ${BWHITE}Zeroing selected status${NC}"
sed -i 's/--selected/selected=0/' src/browser.c

# GNUlib glob wraps opendir with its own gl_directory type, so dir is
# struct gl_directory* by the time rewinddir is called. Cast it to DIR*.
echo -e "${BLUE}[${BWHITE}browser.c${BLUE}] ${BWHITE}fix GNUlib glob DIR* conflict${NC}"
sed -i 's/rewinddir(dir)/rewinddir((DIR *)dir)/' src/browser.c

echo -e "${BLUE}[${BWHITE}nano.c${BLUE}] ${BWHITE}Updating modified buffer prompt text${NC}"
sed -i "s|Save modified buffer|& (Y/N/^C)|" src/nano.c

echo -e "${BLUE}[${BWHITE}nano.c${BLUE}] ${BWHITE}Cleaning vt220 and applying setlocale${NC}"
sed -i 's|vt220||g; /x1B/d; /nl_langinfo(CODESET)/ c\tsetlocale(LC_ALL, "");' src/nano.c

echo -e "${BLUE}[${BWHITE}nano.c${BLUE}] ${BWHITE}Injecting UTF-8 Code Page (65001) force${NC}"
sed -i '/setlocale(LC_ALL, "");/a #ifdef _WIN32\n\tSetConsoleOutputCP(65001);\n\tSetConsoleCP(65001);\n#endif' src/nano.c

echo -e "${BLUE}[${BWHITE}chars.c/winio.c${BLUE}] ${BWHITE}Swapping wcwidth for uc_width${NC}"
sed -i 's|wcwidth(wc)|uc_width(wc, "UTF-8")|g' src/chars.c src/winio.c

echo -e "${BLUE}[${BWHITE}chars.c${BLUE}] ${BWHITE}Including uniwidth.h${NC}"
sed -i '/prototypes.h/a#include "uniwidth.h"' src/chars.c

echo -e "${BLUE}[${BWHITE}definitions.h${BLUE}] ${BWHITE}IDeleting 0x42 range${NC}"
sed -i "/0x42[1234]/d" src/definitions.h

# 1. Force nano to treat the character range for Emojis as double-width (2 columns)
# This patches the wide-character width detection logic.
##echo -e "${BLUE}[${BWHITE}chars.c${BLUE}] ${BWHITE}fix wcwidth${NC}"
##sed -i 's/return wcwidth(wc);/if (wc >= 0x1F300 \&\& wc <= 0x1F9FF) return 2; return wcwidth(wc);/' src/chars.c
# 2. Adjust winio.c to prevent PDCurses from truncating high-plane characters
# This ensures that characters outside the BMP (Basic Multilingual Plane) aren't filtered.
##echo -e "${BLUE}[${BWHITE}winio.c${BLUE}] ${BWHITE}fix wcwidth${NC}"
##sed -i '/if (is_extended_char(wc))/i \    if (wc > 0xFFFF) return true;' src/winio.c
# 3. Ensure the title bar and status bar allow for multi-column character spacing
##sed -i 's/waddnwstr(window, \&widechar, 1);/waddnwstr(window, \&widechar, wcwidth(widechar));/' src/winio.c

# PDCurses uses 64bit (chtype) for cell attributes instead of 32bit (int)
echo -e "${BLUE}[${BWHITE}various${BLUE}] ${BWHITE}Improving from 256colors to true color${NC}"
sed -i "/interface_color_pair/ s/\bint\b/chtype/g" src/prototypes.h src/global.c
sed -i "/int attributes/ s/\bint\b/chtype/g" src/definitions.h
sed -i "/int attributes/ s/\bint\b/chtype/g" src/rcfile.c
sed -i "/bool parse_combination/ s/\bint\b/chtype/g" src/rcfile.c

echo -e "${BLUE}[${BWHITE}wincon & vt${BLUE}] ${BWHITE}PDC_display_utf8 = TRUE${NC}"
sed -i 's/PDC_display_utf8 = FALSE/PDC_display_utf8 = TRUE/g' curses/wincon/*.c
sed -i 's/PDC_display_utf8 = FALSE/PDC_display_utf8 = TRUE/g' curses/vt/*.c
sed -i 's/PDC_display_utf8 = FALSE/PDC_display_utf8 = TRUE/g' curses/wingui/*.c

echo -e "${BLUE}[${BWHITE}pdckbd.c${BLUE}] ${BWHITE}Forced for 64-bit chtype${NC}"
sed -i 's/#if WCHAR_MAX > 65535/#if 1 \/\/ Forced for 64-bit chtype/g' curses/vt/pdckbd.c
sed -i 's/#if WCHAR_MAX > 65535/#if 1 \/\/ Forced for 64-bit chtype/g' curses/wincon/pdckbd.c
sed -i 's/#if WCHAR_MAX > 65535/#if 1 \/\/ Forced for 64-bit chtype/g' curses/wingui/pdckbd.c

echo -e "${BLUE}[${BWHITE}curspriv.h${BLUE}] ${BWHITE}Make MAX_UNICODE suck less.${NC}"
sed -i 's|MAX_UNICODE 0x110000|MAX_UNICODE 0x10ffff|g' curses/curspriv.h

