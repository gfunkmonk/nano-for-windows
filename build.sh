#!/bin/bash

if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script must be run with bash, not sh." >&2
    exit 1
fi

set -euo pipefail

usage() {
echo ""
echo -e "${GREEN}$(basename "${0}") ${GREEN}[${BWHITE}ARCH${GREEN}] [${BWHITE}PDTERM${GREEN}] [${BWHITE}OPTIONS${GREEN}]${NC}"
echo ""
echo -e "${LAGOON}Where:${NC}"
echo -e "${JUNEBUD}  ARCH   ${MAUVE}-- ${BLUE}[${YELLOW}x86_64${BLUE}|${YELLOW}i686${BLUE}|${YELLOW}aarch64${BLUE}|${YELLOW}armv7${BLUE}|${YELLOW}all${BLUE}]${NC}"
echo -e "${NEONRED}  PDTERM ${MAUVE}-- ${BLUE}[${YELLOW}wincon${BLUE}|${YELLOW}wingui${BLUE}|${YELLOW}vt${BLUE}|${YELLOW}all${BLUE}]${NC}"
echo ""
echo -e "${LAGOON}Options:${NC}"
echo -e "${CARIBBEAN} --no-save-gui        ${BWHITE}= Disable SAVE_GUI (wingui only)${NC}"
echo -e "${CARIBBEAN} --no-pdterm-release  ${BWHITE}= Omit PDTERM from release version string${NC}"
echo ""
echo -e "${LAGOON}Examples:${NC}"
echo -e "${VIOLET}  Single build:   ${PEACH}./build.sh i686 wincon${NC}"
echo -e "${VIOLET}  All archs:      ${PEACH}./build.sh all wingui${NC}"
echo -e "${VIOLET}  All everything: ${PEACH}./build.sh all all${NC}"
echo -e "${VIOLET}  With options:   ${PEACH}./build.sh all wingui --no-save-gui --no-pdterm-release${NC}"
echo ""
}

if [ "${1:-}" = "--help" ] || [ $# -lt 2 ]; then
    # Load shared colors for usage(), if available
    source "$(dirname "$0")/common.sh" 2>/dev/null || true
    usage
    exit 1
fi

ARCH_ARG="$1"
PDTERM_ARG="$2"
shift 2
SAVE_GUI=1
PDTERM_RELEASE=1
while [ $# -gt 0 ]; do
    case "$1" in
        --no-save-gui)       SAVE_GUI=0 ;;
        #--save-gui)          SAVE_GUI=1 ;;
        --no-pdterm-release) PDTERM_RELEASE=0 ;;
        #--pdterm-release)    PDTERM_RELEASE=1 ;;
        *) echo "Invalid option: $1"; exit 1 ;;
    esac
    shift
done

# Load shared colors, check_deps, sync_repo
source "$(dirname "$0")/common.sh"

# --- Check Dependencies (exits on first missing tool) ---
check_deps git curl tar patch sed perl make autoconf automake 7z jq

#SAVE_GUI_FLAG=$([ "$SAVE_GUI" -eq 0 ] && echo "--no-save-gui" || echo "--save-gui")
#PDTERM_RELEASE_FLAG=$([ "$PDTERM_RELEASE" -eq 0 ] && echo "--no-pdterm-release" || echo "--pdterm-release")

# Handle 'all' for architecture
if [ "$ARCH_ARG" = "all" ]; then
    for ARCH in x86_64 i686 aarch64 armv7; do
        "$0" "$ARCH" "$PDTERM_ARG" "$SAVE_GUI_FLAG" "$PDTERM_RELEASE_FLAG"
    done
    exit 0
fi

# Handle 'all' for PDTERM
if [ "$PDTERM_ARG" = "all" ]; then
    for PDT in wincon wingui vt; do
        "$0" "$ARCH_ARG" "$PDT" "$SAVE_GUI_FLAG" "$PDTERM_RELEASE_FLAG"
    done
    exit 0
fi

# Map the input to the full triplet
case "$ARCH_ARG" in
    x86_64|amd64|x64)    TARGETS=("x86_64-w64-mingw32") ;;
    i686|i386|x86|x32)   TARGETS=("i686-w64-mingw32") ;;
    aarch64|arm64|armv8) TARGETS=("aarch64-w64-mingw32") ;;
    armv7|arm|arm32)     TARGETS=("armv7-w64-mingw32") ;;
    *) echo "Invalid architecture: $ARCH_ARG"; exit 1 ;;
esac

# Padding for banner alignment
case "$ARCH_ARG" in
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
PDTERM="$PDTERM_ARG"
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
echo -e "${BLUE}@@  ${BWHITE}Building ${JUNEBUD}nano ${BWHITE}for ${NEONPINK}$ARCH_ARG ${GREEN}with ${YELLOW}PDTERM ${RED}$BANNER_NAME  ${BLUE}@@${NC}"
echo -e "${BLUE}################################################${PAD}${PAD2}"
sleep 2

# Global variables
export CFLAGS="-Oz -fno-math-errno -flto -std=c17 -Wno-error -DPDC_WIDE -DPDC_FORCE_UTF8 -D_GNU_SOURCE -ftree-vectorize -fomit-frame-pointer -D_FORTIFY_SOURCE=3"
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
    export LIBS="${LIBS} -lole32 -lgdi32 -lcomdlg32 -lshlwapi"
    if [ "$SAVE_GUI" -eq 1 ]; then
        export CFLAGS="${CFLAGS} -DSAVE_GUI"
    fi
fi

setup_toolchain

cd "${BUILDDIR}"
sync_repo "https://github.com/gfunkmonk/nano-upstream.git" "nano" "$NEONPURPLE"
cd nano
sync_repo "https://github.com/Bill-Gray/PDCursesMod.git" "curses" "$NEONBLUE"
sync_repo "https://github.com/coreutils/gnulib.git" "gnulib" "$ORANGE"

patch_glib "$NEONBLUE"

modules="canonicalize-lgpl futimens getdelim getline getopt-gnu glob isblank iswblank lstat mbchar mbrlen mkstemps nl_langinfo regex rewinddir sigaction snprintf-posix stdarg-h strcase strcasestr-simple strnlen sys_wait-h uniwidth vsnprintf-posix wchar-h wctype-h wcwidth"
./gnulib/gnulib-tool --import $modules
autopoint --force && aclocal -I m4 && autoconf && autoheader && automake --add-missing

patch_nano "$PURPLE"

patch_curses "common" "$BROWN"
patch_curses "$PDTERM" "$YELLOW"

sed_patches "$NEONRED" "$GREEN"

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
        WIDE=Y UTF8=Y DLL=N HAVE_MOUSE=Y _${SHORT}=Y \
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
    if [[ "$PDTERM_RELEASE" == "1" ]]; then
        echo "#define REVISION \"GNU nano $NANOVER for $NAME on $PDT_PRETTY\"" > src/revision.h
    else
        echo "#define REVISION \"GNU nano $NANOVER for $NAME\"" > src/revision.h
    fi

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
    if [[ "${ARCH}" == "x86_64" || "${ARCH}" == "i686" ]]; then
        upx --lzma --best nano.exe || true
    fi
    ls -als
    7z a -mx9 -mm=Deflate64 -mmt$(nproc) "${BASE_DIR}/dist/nano-for-windows_${ARCH}_${PDT_PRETTY}_$(date +%h%d%Y_%I:%M:%S%p).zip" * .nanorc
done
