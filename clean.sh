#!/bin/bash

# Ensure this script is being run with bash
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script must be run with bash, not sh." >&2
    exit 1
fi

set -euo pipefail

# Load shared colors, check_deps, sync_repo
source "$(dirname "$0")/common.sh"

clear
echo -e ""
echo -e "${BROWN}===============================================${NC}"
echo -e "${BROWN}||            ${CORAL}NANO 4-WIN CLEANER             ${NC}${BROWN}||${NC}"
echo -e "${BROWN}===============================================${NC}"
echo -e ""
echo -e "\x1b[5;31mWARNING!!:${NC} ${WHITE}This will run '${ORANGE}git reset --hard${WHITE}' and"
echo -e "'${ORANGE}git clean -fd${WHITE}'. Uncommitted Frankenstein hacks"
echo -e "will be ${HIGHLIGHTER}destroyed${NC}${WHITE}. It won't come back no matter"
echo -e "how ${NEONPINK}hard${NC}${WHITE} you ${BLUE}cry${WHITE}!!!!${NC}\n"

read -r -p "Are you sure you want to nuke the build dir? [y/N] " response
if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo -e "\n${JUNEBUD}Clean aborted. Your dirty hacks are safe.${NC}"
    exit 0
fi

echo -e "\n${GREEN}Confirmed. Engaging scrub mode...${NC}"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDDIR="${BASE_DIR}/build"

echo -e "${BLUE}Preparing build dir: ${WHITE}${BUILDDIR}${NC}"
mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"

sync_repo "https://github.com/gfunkmonk/nano-upstream.git" "nano" "$COOLGRAY"
cd nano
sync_repo "https://github.com/Bill-Gray/PDCursesMod.git" "curses" "$COOLGRAY"
sync_repo "https://github.com/coreutils/gnulib.git" "gnulib" "$COOLGRAY"

# Also wipe dist/ so stale build artifacts don't linger
cd "${BASE_DIR}"
if [ -d "dist" ]; then
    echo -e ""
    read -r -p "Nuke the dist dir also? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo -e "${VIOLET}Removing dist/ directory...${NC}"
        rm -rf dist/
    else
        echo -e "\n${CITRON}Skipping dist. Dist dir lives another day..${NC}"
    fi
fi

# maybe want to clear toolchain dir?
cd "${BASE_DIR}"
if [ -d "toolchain" ]; then
    echo -e ""
    read -r -p "Scrub away toolchain dir as well? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo -e "${MAUVE}Removing toolchain/ directory...${NC}"
        rm -rf toolchain/
    else
        echo -e "\n${BLUE}Skipping toolchain. Toolchain dir lives another day..${NC}"
    fi
fi

echo -e "\n${NEONBLUE}Clean complete. Ready for patching.${NC}"
