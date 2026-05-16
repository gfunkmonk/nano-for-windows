#!/bin/bash
set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: $0 [x86_64|i686|aarch64] PDTERM"
    echo "Example: $0 i686 wincon"
    exit 1
fi

PURPLE="\x1b[1;35m"
YELLOW="\x1b[1;33m"
TEAL="\x1b[2;36m"
BWHITE="\x1b[1;37m"
GREEN="\x1b[1;32m"
NC="\x1b[0m"

# Map the input to the full triplet
case "$1" in
    x86_64)  TARGETS=("x86_64-w64-mingw32") ;;
    i686)    TARGETS=("i686-w64-mingw32") ;;
    aarch64) TARGETS=("aarch64-w64-mingw32") ;;
    *) echo "Invalid architecture: $1"; exit 1 ;;
esac

# Map PDTERM
PDTERM="$2"
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

# realpath() workaround
echo -e "${GREEN}[${BWHITE}definitions.h${GREEN}] ${BWHITE}realpath() workaround applied.${NC}"
cp -p ./src/definitions.h{,.bak}
echo " " >> ./src/definitions.h
echo "#ifdef _WIN32" >> ./src/definitions.h
echo "#include <windows.h>"  >> ./src/definitions.h
echo "#include \"uniwidth.h\""  >> ./src/definitions.h
echo "#define realpath(N,R) _fullpath((R),(N),0)" >> ./src/definitions.h
echo "#endif" >> ./src/definitions.h

# Default open() files in binary mode
echo -e "${GREEN}[${BWHITE}files.c${GREEN}] ${BWHITE}default open in binary mode${NC}"
sed -i 's/O_..ONLY/& | _O_BINARY/g' ./src/files.c
sed -i 's/O_..ONLY/& | _O_BINARY/g' ./src/text.c

# Environment and Path Fixes
echo -e "${GREEN}[${BWHITE}files.c${GREEN}] ${BWHITE}Swapping TMPDIR for TEMP${NC}"
sed -i 's|TMPDIR|TEMP|g' ./src/files.c

echo -e "${GREEN}[${BWHITE}files.c${GREEN}] ${BWHITE}Hardening invalid character check${NC}"
sed -i 's!if (thename\[i\] == "/")!if (strchr("<>\\\\:\\\"/\\\\\\\\|?*", thename[i]))!g' src/files.c

echo -e "${GREEN}[${BWHITE}files.c${GREEN}] ${BWHITE}Injecting backslash normalization loop${NC}"
perl -i -pe "s|if\(\*tilded == \"\\\\\\\\\"\)|if(*tilded == '\\\\')|g; s|\*tilded = \"/\"|*tilded = '/'|g" src/files.c

echo -e "${GREEN}[${BWHITE}files.c${GREEN}] ${BWHITE}Updating path separator comparison${NC}"
perl -i -pe 's|path\[i\] != \x27/\x27|path[i] != \x27/\x27 && path[i] != \x27\\\\\x27|g' src/files.c

echo -e "${GREEN}[${BWHITE}files.c${GREEN}] ${BWHITE}Redirecting /tmp/ to AppData Local${NC}"
sed -i 's|/tmp/|~/AppData/Local/Temp/|g' ./src/files.c

echo -e "${GREEN}[${BWHITE}utils.c${GREEN}] ${BWHITE}Mapping HOME to USERPROFILE${NC}"
sed -i 's|\"HOME\"|"USERPROFILE\"|g' ./src/utils.c

# UI and Terminal Logic
echo -e "${GREEN}[${BWHITE}rcfile.c${GREEN}] ${BWHITE}Patching 256 color support check${NC}"
sed -i "/COLORS == 256/ {s/==/>=/}" src/rcfile.c

echo -e "${GREEN}[${BWHITE}winio.c${GREEN}] ${BWHITE}Stripping halfdelay and kb_interrupt calls${NC}"
sed -i "/halfdelay(ISSET(QUICK_BLANK)/,/disable_kb_interrupt/d" src/winio.c

echo -e "${GREEN}[${BWHITE}nano.c${GREEN}] ${BWHITE}Mapping /dev/tty to CON${NC}"
sed -i "s|/dev/tty|CON|" src/nano.c

# The STDIN / Stream Handler
echo -e "${GREEN}[${BWHITE}nano.c${GREEN}] ${BWHITE}Fixing stream/fd assignment${NC}"
sed -i "s/stream, 0/stream, fd/" src/nano.c

echo -e "${GREEN}[${BWHITE}nano.c${GREEN}] ${BWHITE}Injecting Windows Console/STDIN handler block${NC}"
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

echo -e "${GREEN}[${BWHITE}nano.c${GREEN}] ${BWHITE}Adding scoop_stdin trigger${NC}"
sed -i "/initscr/i\\
\t for(int optind_=optind; optind_ < argc;optind_++)\\n\\
\t if (strcmp(argv[optind_], \"-\") == 0){scoop_stdin();break;}" src/nano.c

# 6. Prompts and Character Handling
echo -e "${GREEN}[${BWHITE}browser.c${GREEN}] ${BWHITE}Zeroing selected status${NC}"
sed -i 's/--selected/selected=0/' src/browser.c

# GNUlib glob wraps opendir with its own gl_directory type, so dir is
# struct gl_directory* by the time rewinddir is called. Cast it to DIR*.
echo -e "${GREEN}[${BWHITE}browser.c${GREEN}] ${BWHITE}fix GNUlib glob DIR* conflict${NC}"
sed -i 's/rewinddir(dir)/rewinddir((DIR *)dir)/' src/browser.c

echo -e "${GREEN}[${BWHITE}nano.c${GREEN}] ${BWHITE}Updating modified buffer prompt text${NC}"
sed -i "s|Save modified buffer|& (Y/N/^C)|" src/nano.c

echo -e "${GREEN}[${BWHITE}nano.c${GREEN}] ${BWHITE}Cleaning vt220 and applying setlocale${NC}"
sed -i 's|vt220||g; /x1B/d; /nl_langinfo(CODESET)/ c\tsetlocale(LC_ALL, "");' src/nano.c

echo -e "${GREEN}[${BWHITE}nano.c${GREEN}] ${BWHITE}Injecting UTF-8 Code Page (65001) force${NC}"
sed -i '/setlocale(LC_ALL, "");/a #ifdef _WIN32\n\tSetConsoleOutputCP(65001);\n\tSetConsoleCP(65001);\n#endif' src/nano.c

echo -e "${GREEN}[${BWHITE}chars.c/winio.c${GREEN}] ${BWHITE}Swapping wcwidth for uc_width${NC}"
sed -i 's|wcwidth(wc)|uc_width(wc, "UTF-8")|g' src/chars.c src/winio.c

echo -e "${GREEN}[${BWHITE}chars.c${GREEN}] ${BWHITE}Including uniwidth.h${NC}"
sed -i '/prototypes.h/a#include "uniwidth.h"' src/chars.c

echo -e "${GREEN}[${BWHITE}definitions.h${GREEN}] ${BWHITE}IDeleting 0x42 range${NC}"
sed -i "/0x42[1234]/d" src/definitions.h

# 1. Force nano to treat the character range for Emojis as double-width (2 columns)
# This patches the wide-character width detection logic.
##echo -e "${GREEN}[${BWHITE}chars.c${GREEN}] ${BWHITE}fix wcwidth${NC}"
##sed -i 's/return wcwidth(wc);/if (wc >= 0x1F300 \&\& wc <= 0x1F9FF) return 2; return wcwidth(wc);/' src/chars.c
# 2. Adjust winio.c to prevent PDCurses from truncating high-plane characters
# This ensures that characters outside the BMP (Basic Multilingual Plane) aren't filtered.
##echo -e "${GREEN}[${BWHITE}winio.c${GREEN}] ${BWHITE}fix wcwidth${NC}"
##sed -i '/if (is_extended_char(wc))/i \    if (wc > 0xFFFF) return true;' src/winio.c
# 3. Ensure the title bar and status bar allow for multi-column character spacing
##sed -i 's/waddnwstr(window, \&widechar, 1);/waddnwstr(window, \&widechar, wcwidth(widechar));/' src/winio.c

# PDCurses uses 64bit (chtype) for cell attributes instead of 32bit (int)
#echo -e "\n\nPATCH: Improving from 256colors to true color."
#sed -i "/interface_color_pair/ s/\bint\b/chtype/g" src/prototypes.h src/global.c
#sed -i "/int attributes/ s/\bint\b/chtype/g" src/definitions.h
#sed -i "/int attributes/ s/\bint\b/chtype/g" src/rcfile.c
#sed -i "/bool parse_combination/ s/\bint\b/chtype/g" src/rcfile.c

#echo -e "\n\nPATCH: PDC_display_utf8 = TRUE"
#sed -i 's/PDC_display_utf8 = FALSE/PDC_display_utf8 = TRUE/g' curses/wincon/*.c
#sed -i 's/PDC_display_utf8 = FALSE/PDC_display_utf8 = TRUE/g' curses/vt/*.c

#echo -e "\n\nPATCH: Make MAX_UNICODE suck less."
#sed -i 's|MAX_UNICODE 0xffff|MAX_UNICODE 0x10ffff|g' curses/curspriv.h

echo -e "${GREEN}[${BWHITE}pdckbd.c${GREEN}] ${BWHITE}Forced for 64-bit chtype${NC}"
sed -i 's/#if WCHAR_MAX > 65535/#if 1 \/\/ Forced for 64-bit chtype/g' curses/vt/pdckbd.c
sed -i 's/#if WCHAR_MAX > 65535/#if 1 \/\/ Forced for 64-bit chtype/g' curses/wincon/pdckbd.c

