#!/bin/bash
# common.sh — shared color definitions, dependency checker, and sync_repo
# Source this file from build.sh, patch.sh, patch1.sh, and clean.sh

# --- Colors (raw ANSI only — no tput, safe in non-interactive/CI) ---
PINK="\x1b[38;5;219m"
PURPLE="\x1b[1;35m"
YELLOW="\x1b[1;33m"
BROWN="\x1b[0;33m"
TEAL="\x1b[2;36m"
WHITE="\x1b[38;5;15m"
BWHITE="\x1b[1;37m"
GREEN="\x1b[1;32m"
CYAN="\x1b[1;36m"
RED="\x1b[1;31m"
BLUE="\x1b[1;34m"
ORANGE="\x1b[38;5;214m"
NEONBLUE="\x1b[38;2;4;218;255m"
NEONGREEN="\x1b[38;2;57;255;20m"
NEONPINK="\x1b[38;2;255;19;240m"
NEONPURPLE="\x1b[38;2;225;8;255m"
NEONRED="\x1b[38;2;255;49;49m"
JUNEBUD="\x1b[38;2;189;218;87m"
HIGHLIGHTER="\x1b[38;2;248;255;15m"
VIOLET="\x1b[38;2;143;0;255m"
MAUVE="\x1b[38;2;224;175;255m"
PEACH="\x1b[38;2;246;161;146m"
CORAL="\x1b[38;2;255;127;80m"
COOLGRAY="\x1b[38;2;140;146;172m"
CITRON="\x1b[38;2;159;169;31m"
CARIBBEAN="\x1b[38;2;0;204;153m"
CHARTREUSE="\x1b[38;2;127;255;0m"
SLATE="\x1b[38;2;109;129;150m"
LAGOON="\x1b[38;2;142;235;236m"
NC="\x1b[0m"

# --- Configuration & Environment ---
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDDIR="${BASE_DIR}/build"

mkdir -p "$BUILDDIR"

# --- Dependency checker — exits on any missing tool ---
# Usage: check_deps git curl tar patch sed perl make ...
check_deps() {
    local missing=0
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo -e "${NEONRED}$cmd is required but not installed.${NC}" >&2
            missing=1
        fi
    done
    [ "$missing" -eq 0 ] || exit 1
}

# --- Sync or clone a git repo with depth=1, using pushd/popd for safety ---
# Usage: sync_repo <url> <dir> <color>
sync_repo() {
    local url=$1
    local dir=$2
    local color=$3
    if [[ ! -d "$dir" ]]; then
        echo -e "$color Cloning $dir...${NC}"
        git clone -b master "$url" --depth=1 "$dir"
    else
        echo -e "$color Syncing $dir...${NC}"
        pushd "$dir" > /dev/null
        git fetch --depth=1
        local current_branch
        current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || git ls-remote --symref origin HEAD | grep '^ref:' | sed 's|ref: refs/heads/||' | awk '{print $1}')
        git reset --hard origin/"$current_branch"
        git clean -fd
        popd > /dev/null
    fi
}

patch_nano() {
    local color=$1

    # Patch Nano
    if [ -d "$BASE_DIR/patch/nano" ]; then
        echo -e "${BWHITE}\033[0;100m Patches from nano${NC}"
        while IFS= read -r p; do
            [ -n "$p" ] || continue
            echo -e "$color Applying $(basename "$p") to nano${NC}"
            patch -p1 < "$p" || exit 1
        done < <(find "$BASE_DIR/patch/nano" -maxdepth 1 -type f -name '*.patch' | sort -V)
    fi
}

patch_curses() {
    local type=$1
    local color=$2

    # Patch Curses
    if [ -d "$BASE_DIR/patch/curses/$type" ]; then
        echo -e "${BWHITE}\033[0;100m Patches from $type${NC}"
        while IFS= read -r p; do
            [ -n "$p" ] || continue
            echo -e "$color Applying $(basename "$p") to curses${NC}"
            patch -p1 < "$p" || exit 1
        done < <(find "$BASE_DIR/patch/curses/$type" -maxdepth 1 -type f -name '*.patch' | sort -V)
    fi
}

sed_patches() {
    local color1=$1
    local color2=$2
    echo -e ""
    echo -e "${SLATE}    --------------------------------${NC}"
    echo -e "${SLATE}    ||  ${LAGOON}   SED & PERL patches     ${SLATE}||${NC}"
    echo -e "${SLATE}    --------------------------------${NC}"
    echo -e ""
    # realpath() workaround
    echo -e "${color1}[${color2}definitions.h${color1}] ${BWHITE}realpath() workaround applied.${NC}"
    printf '\n#ifdef _WIN32\n#include <windows.h>\n#include "uniwidth.h"\n#define realpath(N,R) _fullpath((R),(N),0)\n#endif\n' >> ./src/definitions.h

    # Default open() files in binary mode
    echo -e "${color1}[${color2}files.c${color1}] ${BWHITE}default open in binary mode${NC}"
    sed -i 's/O_..ONLY/& | _O_BINARY/g' ./src/files.c
    sed -i 's/O_..ONLY/& | _O_BINARY/g' ./src/text.c

    # Environment and Path Fixes
    echo -e "${color1}[${color2}files.c${color1}] ${BWHITE}Swapping TMPDIR for TEMP${NC}"
    sed -i 's|TMPDIR|TEMP|g' ./src/files.c

    echo -e "${color1}[${color2}files.c${color1}] ${BWHITE}Hardening invalid character check${NC}"
    sed -i 's!if (thename\[i\] == "/")!if (strchr("<>\\\\:\\\"/\\\\\\\\|?*", thename[i]))!g' src/files.c

    echo -e "${color1}[${color2}files.c${color1}] ${BWHITE}Injecting backslash normalization loop${NC}"
    perl -i -pe "s|if\(\*tilded == \"\\\\\\\\\"\)|if(*tilded == '\\\\')|g; s|\*tilded = \"/\"|*tilded = '/'|g" src/files.c

    echo -e "${color1}[${color2}files.c${color1}] ${BWHITE}Updating path separator comparison${NC}"
    perl -i -pe 's|path\[i\] != \x27/\x27|path[i] != \x27/\x27 && path[i] != \x27\\\\\x27|g' src/files.c

    echo -e "${color1}[${color2}files.c${color1}] ${BWHITE}Redirecting /tmp/ to AppData Local${NC}"
    sed -i 's|/tmp/|~/AppData/Local/Temp/|g' ./src/files.c

    echo -e "${color1}[${color2}utils.c${color1}] ${BWHITE}Mapping HOME to USERPROFILE${NC}"
    sed -i 's|\"HOME\"|"USERPROFILE\"|g' ./src/utils.c

    # UI and Terminal Logic
    echo -e "${color1}[${color2}rcfile.c${color1}] ${BWHITE}Patching 256 color support check${NC}"
    sed -i "/COLORS == 256/ {s/==/>=/}" src/rcfile.c

    echo -e "${color1}[${color2}winio.c${color1}] ${BWHITE}Stripping halfdelay and kb_interrupt calls${NC}"
    sed -i "/halfdelay(ISSET(QUICK_BLANK)/,/disable_kb_interrupt/d" src/winio.c

    echo -e "${color1}[${color2}nano.c${color1}] ${BWHITE}Mapping /dev/tty to CON${NC}"
    sed -i "s|/dev/tty|CON|" src/nano.c

    # The STDIN / Stream Handler
    echo -e "${color1}[${color2}nano.c${color1}] ${BWHITE}Fixing stream/fd assignment${NC}"
    sed -i "s/stream, 0/stream, fd/" src/nano.c

    echo -e "${color1}[${color2}nano.c${color1}] ${BWHITE}Injecting Windows Console/STDIN handler block${NC}"
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

    echo -e "${color1}[${color2}nano.c${color1}] ${BWHITE}Adding scoop_stdin trigger${NC}"
    sed -i "/initscr/i\\
    \t for(int optind_=optind; optind_ < argc;optind_++)\\n\\
    \t if (strcmp(argv[optind_], \"-\") == 0){scoop_stdin();break;}" src/nano.c

    # Prompts and Character Handling
    echo -e "${color1}[${color2}browser.c${color1}] ${BWHITE}Zeroing selected status${NC}"
    sed -i 's/--selected/selected=0/' src/browser.c

    # GNUlib glob wraps opendir with its own gl_directory type, so dir is
    # struct gl_directory* by the time rewinddir is called. Cast it to DIR*.
    echo -e "${color1}[${color2}browser.c${color1}] ${BWHITE}fix GNUlib glob DIR* conflict${NC}"
    sed -i 's/rewinddir(dir)/rewinddir((DIR *)dir)/' src/browser.c

    echo -e "${color1}[${color2}nano.c${color1}] ${BWHITE}Updating modified buffer prompt text${NC}"
    sed -i "s|Save modified buffer|& (Y/N/^C)|" src/nano.c

    echo -e "${color1}[${color2}nano.c${color1}] ${BWHITE}Cleaning vt220 and applying setlocale${NC}"
    sed -i 's|vt220||g; /x1B/d; /nl_langinfo(CODESET)/ c\tsetlocale(LC_ALL, "");' src/nano.c

    echo -e "${color1}[${color2}nano.c${color1}] ${BWHITE}Injecting UTF-8 Code Page (65001) force${NC}"
    sed -i '/setlocale(LC_ALL, "");/a #ifdef _WIN32\n\tSetConsoleOutputCP(65001);\n\tSetConsoleCP(65001);\n#endif' src/nano.c

    echo -e "${color1}[${color2}chars.c${color1}] ${BWHITE}Including uniwidth.h${NC}"
    sed -i '/prototypes.h/a#include "uniwidth.h"' src/chars.c

    echo -e "${color1}[${color2}definitions.h${color1}] ${BWHITE}Deleting 0x42 range${NC}"
    sed -i "/0x42[1234]/d" src/definitions.h

    # Adjust winio.c to prevent PDCurses from truncating high-plane characters
    # This ensures that characters outside the BMP (Basic Multilingual Plane) aren't filtered.
    echo -e "${color1}[${color2}winio.c${color1}] ${BWHITE}fix wcwidth${NC}"
    sed -i '/if (is_extended_char(wc))/i \    if (wc > 0xFFFF) return true;' src/winio.c

    # Ensure the title bar and status bar allow for multi-column character spacing
    sed -i 's/waddnwstr(window, \&widechar, 1);/waddnwstr(window, \&widechar, wcwidth(widechar));/' src/winio.c

    # PDCurses uses 64bit (chtype) for cell attributes instead of 32bit (int)
    echo -e "${color1}[${color2}various${color1}] ${BWHITE}Improving from 256colors to true color${NC}"
    sed -i "/interface_color_pair/ s/\bint\b/chtype/g" src/prototypes.h src/global.c
    sed -i "/int attributes/ s/\bint\b/chtype/g" src/definitions.h
    sed -i "/int attributes/ s/\bint\b/chtype/g" src/rcfile.c
    sed -i "/bool parse_combination/ s/\bint\b/chtype/g" src/rcfile.c

    echo -e "${color1}[${color2}curspriv.h${color1}] ${BWHITE}Make MAX_UNICODE suck less.${NC}"
    sed -i 's|MAX_UNICODE 0x110000|MAX_UNICODE 0x10ffff|g' curses/curspriv.h

}

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
                axel -n 6 -o "$ARCHIVE" "$URL" || {
                    echo -e "${YELLOW}axel failed, retrying with curl...${NC}" >&2
                    rm -f "$ARCHIVE"
                    curl -fL -o "$ARCHIVE" "$URL"
                }
            else
                    curl -fL -o "$ARCHIVE" "$URL"
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

