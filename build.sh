#!/bin/bash

if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script must be run with bash, not sh." >&2
    exit 1
fi

set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: $0 [x86_64|i686|aarch64|armv7] [wincon|wingui|vt]"
    echo "Example: $0 i686 wincon"
    exit 1
fi

# Load shared colors, check_deps, sync_repo
source "$(dirname "$0")/common.sh"

# --- Check Dependencies (exits on first missing tool) ---
check_deps git curl tar patch sed perl make autoconf automake 7z jq

# Map the input to the full triplet
case "$1" in
    x86_64|amd64|x64)    TARGETS=("x86_64-w64-mingw32") ;;
    i686|i386|x86|x32)   TARGETS=("i686-w64-mingw32") ;;
    aarch64|arm64|armv8) TARGETS=("aarch64-w64-mingw32") ;;
    armv7|arm|arm32)     TARGETS=("armv7-w64-mingw32") ;;
    *) echo "Invalid architecture: $1"; exit 1 ;;
esac

# Padding for banner alignment
case "$1" in
    x86_64)  PAD="###" ;;
    amd64)   PAD="##" ;;
    x64)     PAD="" ;;
    i686)    PAD="#" ;;
    i386)    PAD="#" ;;
    x86)     PAD="" ;;
    x32)     PAD="" ;;
    aarch64) PAD="####" ;;
    arm64)   PAD="##" ;;
    armv8)   PAD="##" ;;
    arm)     PAD="" ;;
    armv7)   PAD="##" ;;
    arm32)   PAD="##" ;;
esac

# Map PDTERM
PDTERM="$2"
case "$PDTERM" in
    vt)
        export PDT_PRETTY="VT"
        export BANNER_NAME="VirtTerm"
        export PAD2="##"
        ;;
    wincon)
        export PDT_PRETTY="WinCon"
        export BANNER_NAME="WinCon"
        export PAD2=""
        ;;
    wingui)
        export PDT_PRETTY="WinGUI"
        export BANNER_NAME="WinGUI"
        export PAD2=""
        ;;
    *) echo "Invalid PDTERM: $PDTERM (expected wincon, wingui, or vt)"; exit 1 ;;
esac

echo -e "${BLUE}################################################${PAD}${PAD2}"
echo -e "${BLUE}@@  ${BWHITE}Building ${JUNEBUD}nano ${BWHITE}for ${NEONPINK}$1 ${GREEN}with ${YELLOW}PDTERM ${RED}$BANNER_NAME  ${BLUE}@@${NC}"
echo -e "${BLUE}################################################${PAD}${PAD2}"
sleep 3

# --- Configuration & Environment ---
BASE_DIR="$(pwd)"
BUILDDIR="${BASE_DIR}/build"

mkdir -p "$BUILDDIR"

# Global variables
export CFLAGS="-O2 -fno-math-errno -flto -std=c17 -Wno-error -DCHTYPE_64 -DPDC_WIDE -DPDC_FORCE_UTF8 -D_GNU_SOURCE"
export LDFLAGS="-L${BUILDDIR}/nano/curses/$PDTERM -static -static-libgcc $BUILDDIR/nano/curses/$PDTERM/pdcurses.a"
export LIBS="-l:pdcurses.a -lwinmm -lbcrypt -lshlwapi"
export NCURSES_CFLAGS="-I${BUILDDIR}/nano/curses/ -DNCURSES_STATIC -DENABLE_MOUSE"
export NCURSES_LIBS="-l:pdcurses.a -lwinmm -lbcrypt -lshlwapi"
export CPPFLAGS="-D__USE_MINGW_ANSI_STDIO -DHAVE_NCURSESW_NCURSES_H -DNCURSES_STATIC"
export WT_SESSION="1"
export ConEmuANSI="ON"

if [[ "$PDTERM" == "vt" ]]; then
    export PDC_VT="RGB UNDERLINE BLINK DIM STANDOUT"
elif [[ "$PDTERM" == "wingui" ]]; then
    export LIBS="${LIBS} -lole32 -lgdi32 -lcomdlg32"
    export CFLAGS="${CFLAGS} -DPDC_GUI"
fi

# --- Toolchain Setup ---
setup_toolchain() {
    echo -e "${CYAN}Setting up toolchain...${NC}"
    # Fetch the latest llvm-mingw release tag dynamically so this doesn't go stale
    local API_RESPONSE
    API_RESPONSE=$(curl -fsSL https://api.github.com/repos/mstorsjo/llvm-mingw/releases/latest 2>&1)
    local CURL_EXIT=$?
    if [ $CURL_EXIT -ne 0 ]; then
        echo -e "${NEONRED}Failed to fetch llvm-mingw release (curl exit code: $CURL_EXIT).${NC}" >&2
        echo -e "${NEONRED}API response: $API_RESPONSE${NC}" >&2
        exit 1
    fi
    RELEASE=$(echo "$API_RESPONSE" | jq -r '.tag_name')
    if [[ -z "$RELEASE" ]]; then
        echo -e "${NEONRED}Failed to parse llvm-mingw release tag from API response.${NC}" >&2
        echo -e "${NEONRED}API response: $API_RESPONSE${NC}" >&2
        exit 1
    fi
    local URL="https://github.com/mstorsjo/llvm-mingw/releases/download/${RELEASE}/llvm-mingw-${RELEASE}-ucrt-ubuntu-22.04-x86_64.tar.xz"
    local ARCHIVE="$BASE_DIR/llvm.tar.xz"
    if [[ ! -d "$BASE_DIR/toolchain/bin" ]]; then
        if [[ ! -f "$ARCHIVE" ]]; then
            echo -e "${CYAN}Downloading toolchain release: ${YELLOW}${RELEASE}${NC}"
            if command -v axel >/dev/null 2>&1; then
                axel -n 6 -o "$ARCHIVE" "$URL"
            else
                curl -L -o "$ARCHIVE" "$URL"
            fi
            if [ $? -ne 0 ]; then
                echo -e "${NEONRED}Failed to download toolchain archive.${NC}" >&2
                exit 1
            fi
        fi
        mkdir -p "$BASE_DIR/toolchain"
        echo -e "${PEACH}Extracting toolchain...${NC}"
        tar -xJf "$ARCHIVE" --strip-components=1 -C "$BASE_DIR/toolchain/"
        if [ $? -ne 0 ]; then
            echo -e "${NEONRED}Failed to extract toolchain archive.${NC}" >&2
            exit 1
        fi
        rm -f "$ARCHIVE"
    else
        echo -e "${GREEN}Toolchain cache hit: llvm found.${NC}"
    fi
    export PATH="$BASE_DIR/toolchain/bin:$PATH"
}

setup_toolchain

cd "${BUILDDIR}"
sync_repo "https://github.com/GitMirroring/nano.git" "nano" "$NEONPURPLE"
cd nano
sync_repo "https://github.com/Bill-Gray/PDCursesMod.git" "curses" "$NEONBLUE"
sync_repo "https://github.com/coreutils/gnulib.git" "gnulib" "$ORANGE"

modules="canonicalize-lgpl futimens getdelim getline getopt-gnu glob isblank iswblank lstat mbchar mbrlen mkstemps nl_langinfo regex rewinddir sigaction snprintf-posix stdarg-h strcase strcasestr-simple strnlen sys_wait-h uniwidth vsnprintf-posix wchar-h wctype-h wcwidth"

./gnulib/gnulib-tool --import $modules
autopoint --force && aclocal -I m4 && autoconf && autoheader && automake --add-missing

# Patch Nano
if [ -d "$BASE_DIR/patch/nano" ]; then
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        echo -e "${PURPLE}Applying $(basename "$p") to nano${NC}"
        patch -p1 < "$p" || exit 1
    done < <(find "$BASE_DIR/patch/nano" -maxdepth 1 -type f -name '*.patch' | sort -V)
fi

# Patch Curses (common)
if [ -d "$BASE_DIR/patch/curses/common" ]; then
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        echo -e "${BROWN}Applying $(basename "$p") to curses${NC}"
        patch -p1 < "$p" || exit 1
    done < <(find "$BASE_DIR/patch/curses/common" -maxdepth 1 -type f -name '*.patch' | sort -V)
fi
# Patch Curses (PDTERM-specific)
if [ -d "$BASE_DIR/patch/curses/$PDTERM" ]; then
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        echo -e "${YELLOW}Applying $(basename "$p") to curses${NC}"
        patch -p1 < "$p" || exit 1
    done < <(find "$BASE_DIR/patch/curses/$PDTERM" -maxdepth 1 -type f -name '*.patch' | sort -V)
fi

# realpath() workaround
echo -e "${NEONRED}[${GREEN}definitions.h${NEONRED}] ${BWHITE}realpath() workaround applied.${NC}"
if ! grep -q 'realpath(N,R)' ./src/definitions.h; then
    cp -p ./src/definitions.h{,.bak}
    printf '\n#ifdef _WIN32\n#include <windows.h>\n#include "uniwidth.h"\n#define realpath(N,R) _fullpath((R),(N),0)\n#endif\n' \
        >> ./src/definitions.h
fi

# Default open() files in binary mode
echo -e "${NEONRED}[${GREEN}files.c${NEONRED}] ${BWHITE}default open in binary mode${NC}"
sed -i 's/O_..ONLY/& | _O_BINARY/g' ./src/files.c
sed -i 's/O_..ONLY/& | _O_BINARY/g' ./src/text.c

# Environment and Path Fixes
echo -e "${NEONRED}[${GREEN}files.c${NEONRED}] ${BWHITE}Swapping TMPDIR for TEMP${NC}"
sed -i 's|TMPDIR|TEMP|g' ./src/files.c

echo -e "${NEONRED}[${GREEN}files.c${NEONRED}] ${BWHITE}Hardening invalid character check${NC}"
sed -i 's!if (thename\[i\] == "/")!if (strchr("<>\\\\:\\\"/\\\\\\\\|?*", thename[i]))!g' src/files.c

echo -e "${NEONRED}[${GREEN}files.c${NEONRED}] ${BWHITE}Injecting backslash normalization loop${NC}"
perl -i -pe "s|if\(\*tilded == \"\\\\\\\\\"\)|if(*tilded == '\\\\')|g; s|\*tilded = \"/\"|*tilded = '/'|g" src/files.c

echo -e "${NEONRED}[${GREEN}files.c${NEONRED}] ${BWHITE}Updating path separator comparison${NC}"
perl -i -pe 's|path\[i\] != \x27/\x27|path[i] != \x27/\x27 && path[i] != \x27\\\\\x27|g' src/files.c

echo -e "${NEONRED}[${GREEN}files.c${NEONRED}] ${BWHITE}Redirecting /tmp/ to AppData Local${NC}"
sed -i 's|/tmp/|~/AppData/Local/Temp/|g' ./src/files.c

echo -e "${NEONRED}[${GREEN}utils.c${NEONRED}] ${BWHITE}Mapping HOME to USERPROFILE${NC}"
sed -i 's|\"HOME\"|"USERPROFILE\"|g' ./src/utils.c

# UI and Terminal Logic
echo -e "${NEONRED}[${GREEN}rcfile.c${NEONRED}] ${BWHITE}Patching 256 color support check${NC}"
sed -i "/COLORS == 256/ {s/==/>=/}" src/rcfile.c

echo -e "${NEONRED}[${GREEN}winio.c${NEONRED}] ${BWHITE}Stripping halfdelay and kb_interrupt calls${NC}"
sed -i "/halfdelay(ISSET(QUICK_BLANK)/,/disable_kb_interrupt/d" src/winio.c

echo -e "${NEONRED}[${GREEN}nano.c${NEONRED}] ${BWHITE}Mapping /dev/tty to CON${NC}"
sed -i "s|/dev/tty|CON|" src/nano.c

# The STDIN / Stream Handler
echo -e "${NEONRED}[${GREEN}nano.c${NEONRED}] ${BWHITE}Fixing stream/fd assignment${NC}"
sed -i "s/stream, 0/stream, fd/" src/nano.c

echo -e "${NEONRED}[${GREEN}nano.c${NEONRED}] ${BWHITE}Injecting Windows Console/STDIN handler block${NC}"
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

echo -e "${NEONRED}[${GREEN}nano.c${NEONRED}] ${BWHITE}Adding scoop_stdin trigger${NC}"
sed -i "/initscr/i\\
\t for(int optind_=optind; optind_ < argc;optind_++)\\n\\
\t if (strcmp(argv[optind_], \"-\") == 0){scoop_stdin();break;}" src/nano.c

# Prompts and Character Handling
echo -e "${NEONRED}[${GREEN}browser.c${NEONRED}] ${BWHITE}Zeroing selected status${NC}"
sed -i 's/--selected/selected=0/' src/browser.c

# GNUlib glob wraps opendir with its own gl_directory type, so dir is
# struct gl_directory* by the time rewinddir is called. Cast it to DIR*.
echo -e "${NEONRED}[${GREEN}browser.c${NEONRED}] ${BWHITE}fix GNUlib glob DIR* conflict${NC}"
sed -i 's/rewinddir(dir)/rewinddir((DIR *)dir)/' src/browser.c

echo -e "${NEONRED}[${GREEN}nano.c${NEONRED}] ${BWHITE}Updating modified buffer prompt text${NC}"
sed -i "s|Save modified buffer|& (Y/N/^C)|" src/nano.c

echo -e "${NEONRED}[${GREEN}nano.c${NEONRED}] ${BWHITE}Cleaning vt220 and applying setlocale${NC}"
sed -i 's|vt220||g; /x1B/d; /nl_langinfo(CODESET)/ c\tsetlocale(LC_ALL, "");' src/nano.c

echo -e "${NEONRED}[${GREEN}nano.c${NEONRED}] ${BWHITE}Injecting UTF-8 Code Page (65001) force${NC}"
sed -i '/setlocale(LC_ALL, "");/a #ifdef _WIN32\n\tSetConsoleOutputCP(65001);\n\tSetConsoleCP(65001);\n#endif' src/nano.c

echo -e "${NEONRED}[${GREEN}chars.c${NEONRED}] ${BWHITE}Including uniwidth.h${NC}"
sed -i '/prototypes.h/a#include "uniwidth.h"' src/chars.c

echo -e "${NEONRED}[${GREEN}definitions.h${NEONRED}] ${BWHITE}Deleting 0x42 range${NC}"
sed -i "/0x42[1234]/d" src/definitions.h

# Adjust winio.c to prevent PDCurses from truncating high-plane characters
# This ensures that characters outside the BMP (Basic Multilingual Plane) aren't filtered.
echo -e "${NEONRED}[${GREEN}winio.c${NEONRED}] ${BWHITE}fix wcwidth${NC}"
sed -i '/if (is_extended_char(wc))/i \    if (wc > 0xFFFF) return true;' src/winio.c

# Ensure the title bar and status bar allow for multi-column character spacing
sed -i 's/waddnwstr(window, \&widechar, 1);/waddnwstr(window, \&widechar, wcwidth(widechar));/' src/winio.c

# PDCurses uses 64bit (chtype) for cell attributes instead of 32bit (int)
echo -e "${NEONRED}[${GREEN}various${NEONRED}] ${BWHITE}Improving from 256colors to true color${NC}"
sed -i "/interface_color_pair/ s/\bint\b/chtype/g" src/prototypes.h src/global.c
sed -i "/int attributes/ s/\bint\b/chtype/g" src/definitions.h
sed -i "/int attributes/ s/\bint\b/chtype/g" src/rcfile.c
sed -i "/bool parse_combination/ s/\bint\b/chtype/g" src/rcfile.c

echo -e "${NEONRED}[${GREEN}wincon & vt${NEONRED}] ${BWHITE}PDC_display_utf8 = TRUE${NC}"
sed -i 's/PDC_display_utf8 = FALSE/PDC_display_utf8 = TRUE/g' curses/wincon/*.c
sed -i 's/PDC_display_utf8 = FALSE/PDC_display_utf8 = TRUE/g' curses/vt/*.c
sed -i 's/PDC_display_utf8 = FALSE/PDC_display_utf8 = TRUE/g' curses/wingui/*.c

echo -e "${NEONRED}[${GREEN}pdckbd.c${NEONRED}] ${BWHITE}Forced for 64-bit chtype${NC}"
sed -i 's/#if WCHAR_MAX > 65535/#if 1 \/\/ Forced for 64-bit chtype/g' curses/vt/pdckbd.c
sed -i 's/#if WCHAR_MAX > 65535/#if 1 \/\/ Forced for 64-bit chtype/g' curses/wincon/pdckbd.c
sed -i 's/#if WCHAR_MAX > 65535/#if 1 \/\/ Forced for 64-bit chtype/g' curses/wingui/pdckbd.c

echo -e "${NEONRED}[${GREEN}curspriv.h${NEONRED}] ${BWHITE}Make MAX_UNICODE suck less.${NC}"
sed -i 's|MAX_UNICODE 0x110000|MAX_UNICODE 0x10ffff|g' curses/curspriv.h

# --- Build Binaries ---
for TRIPLET in "${TARGETS[@]}"; do
    ARCH=$(echo "$TRIPLET" | cut -d'-' -f1)
    PREFIX="$BASE_DIR/dist/$ARCH"

    NAME=$(echo "$ARCH" | sed 's/aarch64/ARM64/;s/armv7/ARM32/;s/x86_64/Win64/;s/i686/Win32/')
    SHORT=$(echo "$ARCH" | sed 's/aarch64/a64/;s/armv7/a32/;s/x86_64/w64/;s/i686/w32/')

    echo -e "${NEONPURPLE}Building for ${ARCH} (Target: ${TRIPLET})${NC}"

    # Build PDCurses
    cd "$BUILDDIR/nano/curses/$PDTERM"
    make clean || true
    unset NCURSESW_CFLAGS
    make -j$(nproc) CC="$TRIPLET-gcc" AR="$TRIPLET-ar" STRIP="$TRIPLET-strip" \
        WIDE=Y UTF8=Y DLL=N CHTYPE_64=Y HAVE_MOUSE=Y _${SHORT}=Y \
        CFLAGS="${CFLAGS} -I.." \
        CXXFLAGS="${CFLAGS}"

    # Nano Build
    cd "$BUILDDIR/nano"
    [ -d "build" ] && rm -rf build
    mkdir build && cd build
    ../configure --host="$TRIPLET" --prefix="$PREFIX" \
        --enable-utf8 --enable-threads=windows --disable-nls \
        --sysconfdir="C:\\ProgramData" --enable-extras --enable-color \
	--enable-nanorc --disable-dependency-tracking \
        CFLAGS="${CFLAGS} -DPDC_NCMOUSE" \
        CXXFLAGS="${CFLAGS}" \
        LDFLAGS="${LDFLAGS}" \
        LIBS="${LIBS}" \
        NCURSESW_CFLAGS="${NCURSES_CFLAGS}" \
        NCURSESW_LIBS="${NCURSES_LIBS}"

cat << EOF >> config.h
#define HAVE_FREXP_IN_LIBC 1
#define HAVE_FREXPL_IN_LIBC 1
#define HAVE_SNPRINTF_RETVAL_C99 1
#define HAVE_SNPRINTF_TRUNCATION_C99 1
#define MBRTOWC_EMPTY_INPUT_BUG 1
EOF

    sed -i "/#define NEED_PRINTF_DIRECTIVE_A 1/d" config.h
    sed -i "/#define NEED_PRINTF_DIRECTIVE_F 1/d" config.h
    sed -i "/#define NEED_PRINTF_FLAG_GROUPING 1/d" config.h
    sed -i "/#define NEED_PRINTF_FLAG_ZERO 1/d" config.h
    sed -i "/#define NEED_PRINTF_INFINITE_DOUBLE 1/d" config.h
    sed -i "/#define NEED_PRINTF_UNBOUNDED_PRECISION 1/d" config.h

    NANOVER=$(grep -m1 "PACKAGE_VERSION =" Makefile | cut -d'=' -f2 | xargs)
    echo "#define REVISION \"GNU nano $NANOVER for $NAME\"" > src/revision.h

    make -j$(nproc) && make install
    "$TRIPLET-strip" -s "$PREFIX/bin/nano.exe"
    cd "${PREFIX}"
    cp "${BASE_DIR}/LICENSE" .
    cp "${BASE_DIR}/README.md" .
    mv bin/nano.exe share/doc/nano/* "${BUILDDIR}/nano/doc/sample.nanorc.in" .
    # Sync nanorc instead of re-cloning on every run
    if [ -d "syntax/.git" ]; then
        pushd syntax > /dev/null
        git fetch --depth=1
        git reset --hard origin/$(git symbolic-ref --short HEAD)
        popd > /dev/null
    else
        [ -d "syntax" ] && rm -rf syntax
        git clone https://github.com/gfunkmonk/nanorc syntax
    fi
    rm -rf syntax/.git
    cp "${BASE_DIR}/.nanorc" .
    rm -rf bin share rnano*
    file nano.exe
    upx --lzma --best nano.exe || true
    ls -als
    7z a -mx9 -mm=Deflate64 -mmt$(nproc) "${BASE_DIR}/dist/nano-for-windows_${ARCH}_${PDT_PRETTY}_$(date +%y%m%d_%H%M%S).zip" * .nanorc
done
