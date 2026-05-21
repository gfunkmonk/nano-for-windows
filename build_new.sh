#!/bin/bash
set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: $0 [x86_64|i686|aarch64|armv7] [wincon|wingui|vt]"
    echo "Example: $0 i686 wincon"
    exit 1
fi

PURPLE="\x1b[1;35m"
YELLOW="\x1b[1;33m"
TEAL="\x1b[2;36m"
BWHITE="\x1b[1;37m"
GREEN="\x1b[1;32m"
RED="\x1b[1;31m"
NC="\x1b[0m"

die() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

# --- 1. Check Dependencies ---
for cmd in git curl tar patch sed perl make autoconf automake 7z; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required but not installed."
done

# Map the input to the full triplet
case "$1" in
    x86_64|amd64|x64)    TARGETS=("x86_64-w64-mingw32") ;;
    i686|i386|x86|x32)   TARGETS=("i686-w64-mingw32") ;;
    aarch64|arm64|armv8) TARGETS=("aarch64-w64-mingw32") ;;
    armv7|arm|arm32)     TARGETS=("armv7-w64-mingw32") ;;
    *) die "Invalid architecture: $1" ;;
esac

# Map PDTERM
PDTERM="$2"
case "$PDTERM" in
    vt)     export PDT_PRETTY="VT" ;;
    wincon) export PDT_PRETTY="WinCon" ;;
    wingui) export PDT_PRETTY="WinGUI" ;;
    *) die "Invalid PDTERM: $PDTERM (expected wincon, wingui, or vt)" ;;
esac
echo "Building for $1 with PDTERM=$PDTERM"

# --- 2. Configuration & Environment ---
BASE_DIR="$(pwd)"
BUILDDIR="${BASE_DIR}/build"

mkdir -p "$BUILDDIR"

# Global variables from your workflow
export CFLAGS="-O2 -fno-math-errno -flto -std=c17 -Wno-error -DCHTYPE_64 -DPDC_WIDE -DPDC_FORCE_UTF8 -D_GNU_SOURCE"
export LDFLAGS="-L${BUILDDIR}/nano/curses/$PDTERM -static -static-libgcc $BUILDDIR/nano/curses/$PDTERM/pdcurses.a"
export LIBS="-l:pdcurses.a -lwinmm -lbcrypt"
export NCURSES_CFLAGS="-I${BUILDDIR}/nano/curses/ -DNCURSES_STATIC -DENABLE_MOUSE"
export NCURSES_LIBS="-l:pdcurses.a -lwinmm -lbcrypt"
export CPPFLAGS="-D__USE_MINGW_ANSI_STDIO -DHAVE_NCURSESW_NCURSES_H -DNCURSES_STATIC"
export WT_SESSION="1"
export ConEmuANSI="ON"

if [[ "$PDTERM" == "vt" ]]; then
    export PDC_VT="RGB UNDERLINE BLINK DIM STANDOUT"
elif [[ "$PDTERM" == "wingui" ]]; then
    export LIBS="${LIBS} -lole32 -lgdi32 -lcomdlg32"
fi

setup_toolchain() {
    echo -e "${TEAL}Setting up toolchain...${NC}"
    local RELEASE="20260519"
    local URL="https://github.com/mstorsjo/llvm-mingw/releases/download/${RELEASE}/llvm-mingw-${RELEASE}-ucrt-ubuntu-22.04-x86_64.tar.xz"
    local ARCHIVE="$BASE_DIR/llvm.tar.xz"

    if [[ ! -d "$BASE_DIR/toolchain/bin" ]]; then
        if [[ ! -f "$ARCHIVE" ]]; then
            echo -e "${YELLOW}Downloading toolchain release: ${RELEASE}${NC}"
            if command -v axel >/dev/null 2>&1; then
                axel -n 6 -o "$ARCHIVE" "$URL"
            else
                curl -L -o "$ARCHIVE" "$URL"
            fi
        fi
        mkdir -p "$BASE_DIR/toolchain"
        tar -xJf "$ARCHIVE" --strip-components=1 -C "$BASE_DIR/toolchain/"
    else
        echo -e "${GREEN}Toolchain cache hit: llvm found.${NC}"
    fi
    export PATH="$BASE_DIR/toolchain/bin:$PATH"
}

sync_repo() {
    local url=$1
    local dir=$2
    if [[ ! -d "$dir" ]]; then
        git clone "$url" --depth=1 "$dir"
    else
        echo -e "${TEAL}Syncing $dir...${NC}"
        (cd "$dir" && git fetch --depth=1 && git reset --hard origin/$(git symbolic-ref --short HEAD) && git clean -fd)
    fi
}

apply_patches() {
    local type=$1
    local patch_dir="$BASE_DIR/patch/$type"
    [[ "$type" == "curses" ]] && patch_dir="$patch_dir/$PDTERM"
    
    if [[ -d "$patch_dir" ]]; then
        echo -e "${PURPLE}Applying patches to $type...${NC}"
        find "$patch_dir" -maxdepth 1 -type f -name '*.patch' | sort -V | while read -r p; do
            echo -e "  ${YELLOW}Applying $(basename "$p")${NC}"
            patch -p1 < "$p" || die "Patch $p failed"
        done
    fi
}

apply_source_modifications() {
    # realpath() workaround
    echo -e "${GREEN}[definitions.h] realpath() workaround${NC}"
    {
        echo -e "\n#ifdef _WIN32"
        echo "#include <windows.h>"
        echo "#include \"uniwidth.h\""
        echo "#define realpath(N,R) _fullpath((R),(N),0)"
        echo "#endif"
    } >> ./src/definitions.h

    echo -e "${GREEN}Applying Windows source hacks...${NC}"
    sed -i 's/O_..ONLY/& | _O_BINARY/g' ./src/files.c ./src/text.c
    sed -i 's|TMPDIR|TEMP|g' ./src/files.c
    sed -i 's!if (thename\[i\] == "/")!if (strchr("<>\\\\:\\\"/\\\\\\\\|?*", thename[i]))!g' src/files.c
    perl -i -pe "s|if\(\*tilded == \"\\\\\\\\\"\)|if(*tilded == '\\\\')|g; s|\*tilded = \"/\"|*tilded = '/'|g" src/files.c
    perl -i -pe 's|path\[i\] != \x27/\x27|path[i] != \x27/\x27 && path[i] != \x27\\\\\x27|g' src/files.c
    sed -i 's|/tmp/|~/AppData/Local/Temp/|g' ./src/files.c
    sed -i 's|\"HOME\"|"USERPROFILE\"|g' ./src/utils.c
    sed -i "/COLORS == 256/ {s/==/>=/}" src/rcfile.c
    sed -i "/halfdelay(ISSET(QUICK_BLANK)/,/disable_kb_interrupt/d" src/winio.c
    sed -i "s|/dev/tty|CON|" src/nano.c
    sed -i "s/stream, 0/stream, fd/" src/nano.c

    # Inject STDIN handler
    sed -i "/FILE \*stream/,/stop the reading/ c\\
	 static FILE *stream;\\n\\
	 static int fd=0;\\n\\
	 if (fd==0){\\n\\
	 if (GetConsoleWindow() != NULL)\\n\\
	 fprintf(stderr, _(\"Reading data from keyboard; type a ^Z line to finish.\\\\n\"));\\n\\
	 fd = dup(0);\\n\\
	 stream = fdopen(fd, \"rb\");\\n\\
	 freopen(\"CON\", \"rb\", stdin);\\n\\
	 FreeConsole();\\n\\
	 AttachConsole(ATTACH_PARENT_PROCESS);\\n\\
	 return FALSE;}\\n\\
	 endwin();\\n\\
	 if (stream == NULL) {\\n\\
	 \t int errnumber = errno;\\n\\
	 \t if(fd > -1) close(fd);\\n\\
	 return FALSE;}" src/nano.c

    sed -i "/initscr/i\\
	 for(int optind_=optind; optind_ < argc;optind_++)\\n\\
	 if (strcmp(argv[optind_], \"-\") == 0){scoop_stdin();break;}" src/nano.c

    sed -i 's/--selected/selected=0/' src/browser.c
    sed -i 's/rewinddir(dir)/rewinddir((DIR *)dir)/' src/browser.c
    sed -i "s|Save modified buffer|& (Y/N/^C)|" src/nano.c
    sed -i 's|vt220||g; /x1B/d; /nl_langinfo(CODESET)/ c\tsetlocale(LC_ALL, "");' src/nano.c
    sed -i '/setlocale(LC_ALL, "");/a #ifdef _WIN32\n\tSetConsoleOutputCP(65001);\n\tSetConsoleCP(65001);\n#endif' src/nano.c
    sed -i 's|wcwidth(wc)|uc_width(wc, "UTF-8")|g' src/chars.c src/winio.c
    sed -i '/prototypes.h/a#include "uniwidth.h"' src/chars.c
    sed -i "/0x42[1234]/d" src/definitions.h

    # True color / 64-bit chtype updates
    sed -i "/interface_color_pair/ s/\bint\b/chtype/g" src/prototypes.h src/global.c
    sed -i "/int attributes/ s/\bint\b/chtype/g" src/definitions.h src/rcfile.c
    sed -i "/bool parse_combination/ s/\bint\b/chtype/g" src/rcfile.c
    
    sed -i 's/PDC_display_utf8 = FALSE/PDC_display_utf8 = TRUE/g' curses/wincon/*.c curses/vt/*.c curses/wingui/*.c
    sed -i 's/#if WCHAR_MAX > 65535/#if 1 \/\/ Forced for 64-bit chtype/g' curses/vt/pdckbd.c curses/wincon/pdckbd.c curses/wingui/pdckbd.c
}

setup_toolchain

mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"
sync_repo "https://github.com/GitMirroring/nano.git" "nano"
cd nano
sync_repo "https://github.com/Bill-Gray/PDCursesMod.git" "curses"
sync_repo "https://github.com/coreutils/gnulib.git" "gnulib"

echo -e "${TEAL}Importing Gnulib modules...${NC}"
modules="canonicalize-lgpl futimens getdelim getline getopt-gnu glob isblank iswblank lstat mbrlen mbchar mkstemps nl_langinfo regex rewinddir sigaction snprintf-posix stdarg-h strcase strcasestr-simple strnlen sys_wait-h uniwidth vsnprintf-posix wchar-h wctype-h wcwidth"
./gnulib/gnulib-tool --import $modules
autopoint --force && aclocal -I m4 && autoconf && autoheader && automake --add-missing

apply_patches "nano"
apply_patches "curses"
apply_source_modifications

# --- 6. Build Binaries ---
for TRIPLET in "${TARGETS[@]}"; do
    # Now ARCH is actually the arch (e.g., x86_64)
    ARCH=$(echo "$TRIPLET" | cut -d'-' -f1)
    PREFIX="$BASE_DIR/dist/$ARCH"

    # Mapping for your 'Win64/WinARM' labels
    NAME=$(echo "$ARCH" | sed 's/aarch64/ARM64/;s/armv7/ARM32/;s/x86_64/Win64/;s/i686/Win32/')
    SHORT=$(echo "$ARCH" | cut -d'-' -f1 | sed 's/aarch64/a64/;s/armv7/a32/;s/x86_64/w64/;s/i686/w32/')

    echo -e "${TEAL}Building for ${ARCH} (Target: ${TRIPLET})${NC}"
    
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
        --enable-utf8 --enable-threads=windows --disable-nls --sysconfdir="C:\\\\ProgramData" --enable-extras --enable-color --enable-nanorc --disable-dependency-tracking \
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
    7z a -mx9 -mm=Deflate64 -mmt$(nproc) "${BASE_DIR}/dist/nano-for-windows_${ARCH}_${PDT_PRETTY}_$(date +%y%m%d_%H%M%S).zip" * .nanorc
done

