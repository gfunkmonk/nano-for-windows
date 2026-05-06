#!/bin/bash
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 [x86_64|i686|aarch64]"
    echo "Example: $0 i686"
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
PDTERM="wincon"
echo "Building for $1 with PDTERM=$PDTERM"

# --- 2. Configuration & Environment ---
BASE_DIR="$(pwd)"
BUILDDIR="${BASE_DIR}/build"

if [ ! -d "$BUILDDIR" ]; then
  mkdir -p "${BUILDDIR}" && cd "${BUILDDIR}"
else
  cd "${BUILDDIR}"
fi

# Global variables from your workflow
export PDC_WINCON="TRUE"
export PDC_ANSI="TRUE"
export PDC_FORCE_UTF8="1"
export UNICODE="1"
export HAVE_WCWIDTH="TRUE"
export ENABLE_UTF8="TRUE"
export CFLAGS="-O2 -fno-math-errno -flto -std=c17 -Wno-error -DCHTYPE_64 -DPDC_WIDE -DPDC_WINCON -DPDC_FORCE_UTF8 -DPDC_SYMBOL_VERSIONING=0 -D_GNU_SOURCE"

# --- 3. Toolchain Setup (gfunkmonk/win-cross) ---
echo -e "${TEAL}Setting up toolchain...${NC}"
TOOLCHAIN_RELEASE="BillsBastards" # Plug in release name here

# Define a persistent toolchain directory outside the BUILDDIR if you want true persistence, 
# or just check if it's already in the BUILDDIR.
if [ ! -d "$BASE_DIR/toolchains/$1-mingw" ]; then
    echo -e "${YELLOW}Downloading toolchain release: ${TOOLCHAIN_RELEASE}${NC}"
    mkdir -p "$BASE_DIR/toolchains"
    curl -L -o "$BASE_DIR/toolchains/toolchain.tar.xz" "https://github.com/gfunkmonk/win-cross/releases/download/${TOOLCHAIN_RELEASE}/${1}-w64-mingw32.tar.xz"
    cd "$BASE_DIR/toolchains"
    tar -xJf toolchain.tar.xz && mv "$1"-* "$1"-mingw && rm toolchain.tar.xz
    cd "$BASE_DIR"
else
    echo -e "${GREEN}Toolchain cache hit: $1-mingw found.${NC}"
fi

export PATH="$BASE_DIR/toolchains/$1-mingw/bin:$PATH"

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
modules="base32 base64 futimens getdelim getline getopt-gnu glob isblank iswblank lstat mbrlen mbchar mkstemps nl_langinfo regex rewinddir sigaction snprintf-posix stdarg-h strcase strcasestr-simple strnlen sys_wait-h uniwidth unitypes unictype/property-emoji vsnprintf-posix wchar-h wctype-h wcwidth"
./gnulib/gnulib-tool --import $modules
autopoint --force && aclocal -I m4 && autoconf && autoheader && automake --add-missing

# Patch Nano
if [ -d "$BASE_DIR/patch/nano" ]; then
    for p in "$BASE_DIR/patch/nano"/*.patch; do
        if [ -f "$p" ]; then
            echo -e "${PURPLE}Applying $(basename "$p") to nano${NC}"
            patch -p1 --fuzz=3 < "$p" || exit 1
        fi
    done
fi

# Curses Build
if [ -d "$BASE_DIR/patch/curses" ]; then
    for p in "$BASE_DIR/patch/curses"/*.patch; do
        if [ -f "$p" ]; then
            echo -e "${YELLOW}Applying $(basename "$p") to curses${NC}"
            patch -p1 --fuzz=3 < "$p" || exit 1
        fi
    done
fi

# --- 5. A.I. Killer - Slayer of Giants ---
echo -e "\n" >> src/definitions.h
echo '#define PDC_WINCON 1' >> src/definitions.h
echo '#define PDC_WIDE 1' >> src/definitions.h
echo '#define CHTYPE_64 1' >> src/definitions.h
echo '#define PDC_ANSI 1' >> src/definitions.h
echo '#define PDC_FORCE_UTF8 1' >> src/definitions.h
echo '#define UNICODE 1' >> src/definitions.h

# realpath() workaround
echo -e "${TEAL}PATCH: ${BWHITE}realpath() workaround applied.${NC}"
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

echo -e "${GREEN}[${BWHITE}nano.c${GREEN}] ${BWHITE}Removing vt220 string${NC}"
sed -i 's|vt220||g' ./src/nano.c

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

echo -e "${GREEN}[${BWHITE}browser.c${GREEN}] ${BWHITE}fix GNUlib glob DIR* conflict in browser.c.${NC}"
sed -i "s/rewinddir(dir)/rewinddir((DIR *)dir)/" src/browser.c

# PDCurses uses 64bit (chtype) for cell attributes instead of 32bit (int)
echo -e "\n\nPATCH: Improving from 256colors to true color."
sed -i "/interface_color_pair/ s/\bint\b/chtype/g" src/prototypes.h src/global.c
sed -i "/int attributes/ s/\bint\b/chtype/g" src/definitions.h
sed -i "/int attributes/ s/\bint\b/chtype/g" src/rcfile.c
sed -i "/bool parse_combination/ s/\bint\b/chtype/g" src/rcfile.c

echo -e "\n\nPATCH: PDC_display_utf8 = TRUE"
sed -i 's/PDC_display_utf8 = FALSE/PDC_display_utf8 = TRUE/g' curses/wincon/*.c
sed -i 's/PDC_display_utf8 = FALSE/PDC_display_utf8 = TRUE/g' curses/vt/*.c

echo -e "\n\nPATCH: Make MAX_UNICODE suck less."
sed -i 's|MAX_UNICODE 0xffff|MAX_UNICODE 0x10ffff|g' curses/curspriv.h

# Fix folder access test
echo -e "\n\nPATCH: Porting folder accessibility from executable to read access."
sed -i "s/X_OK/R_OK/" src/files.c

# GNUlib glob wraps opendir with its own gl_directory type, so dir is
# struct gl_directory* by the time rewinddir is called. Cast it to DIR*.
echo -e "\n\nPATCH: fix GNUlib glob DIR* conflict in browser.c."
sed -i 's/rewinddir(dir)/rewinddir((DIR *)dir)/' src/browser.c

# --- 6. Build Binaries ---
for TRIPLET in "${TARGETS[@]}"; do
    # Now ARCH is actually the arch (e.g., x86_64)
    ARCH=$(echo "$TRIPLET" | cut -d'-' -f1)
    PREFIX="$BASE_DIR/dist/$ARCH"

    # Mapping for your 'Win64/WinARM64' labels
    NAME=$(echo "$ARCH" | sed 's/aarch64/WinARM64/;s/x86_64/Win64/;s/i686/Win32/')
    SHORT=$(echo "$ARCH" | cut -d'-' -f1 | sed 's/aarch64/a64/;s/x86_64/w64/;s/i686/w32/')

    echo -e "${TEAL}Building for ${ARCH} (Target: ${TRIPLET})${NC}"
done

    # Build PDCurses
    cd "$BUILDDIR/nano/curses/$PDTERM"
    make clean || true
    unset NCURSESW_CFLAGS
    make -j$(nproc) CC="$TRIPLET-gcc" AR="$TRIPLET-ar" STRIP="$TRIPLET-strip" \
        WIDE=Y UTF8=Y DLL=N CHTYPE_64=Y _${SHORT}=Y PDC_SYMBOL_VERSIONING=0 \
        CFLAGS="${CFLAGS} -I.." \
        CXXFLAGS="${CFLAGS}"

    # Nano Build
    cd "$BUILDDIR/nano"

    [ -d "build" ] && rm -rf build
    mkdir build && cd build
    ../configure --host="$TRIPLET" --prefix="$PREFIX" \
        --enable-utf8 --enable-threads=windows --disable-nls --sysconfdir="C:\\\\ProgramData" --enable-extras --enable-color --enable-nanorc \
        CFLAGS="${CFLAGS} -DPDC_NCMOUSE" \
        CXXFLAGS="${CFLAGS}" \
        LDFLAGS="-L${BUILDDIR}/nano/curses/$PDTERM -static -static-libgcc $BUILDDIR/nano/curses/$PDTERM/pdcurses.a" \
        LIBS="-l:pdcurses.a -lwinmm -lbcrypt" \
        NCURSESW_CFLAGS="-I${BUILDDIR}/nano/curses/ -DNCURSES_STATIC  -DENABLE_MOUSE" \
        NCURSESW_LIBS="-l:pdcurses.a -lwinmm -lbcrypt"

echo "
#define HAVE_FREXP_IN_LIBC 1
#define HAVE_FREXPL_IN_LIBC 1
#define HAVE_SNPRINTF_RETVAL_C99 1
#define HAVE_SNPRINTF_TRUNCATION_C99 1
#define MBRTOWC_EMPTY_INPUT_BUG 1
" >> config.h

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
    cd ${PREFIX}
    cp ${BASE_DIR}/LICENSE .
    cp ${BASE_DIR}/README.md .
    mv bin/nano.exe share/doc/nano/* "${BUILDDIR}/nano/doc/sample.nanorc.in" .
    if [ -d "syntax" ]; then
        rm -fr syntax/
    fi
    git clone https://github.com/gfunkmonk/nanorc syntax
    cd syntax
    rm -fr .git/
    cd ..
    cp ${BASE_DIR}/.nanorc .
    rm -rf bin share rnano*
    upx --lzma --best nano.exe || true
    ls -als
    7z a -mx9 -mm=Deflate64 -mmt$(nproc) "${BASE_DIR}/dist/nano-for-windows_${ARCH}_$(date +%y%m%d_%H%M%S).zip" * .nanorc
done