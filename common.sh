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
NC="\x1b[0m"

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
        git clone "$url" --depth=1 "$dir"
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


