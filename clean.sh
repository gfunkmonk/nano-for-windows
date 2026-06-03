#!/bin/bash
set -euo pipefail


PINK="$(tput setaf 219)"
PURPLE="$(tput setaf 92)"
YELLOW="$(tput setaf 226)"
TEAL="$(tput setaf 37)"
WHITE="$(tput setaf 15)"
GREEN="$(tput setaf 47)"
RED="$(tput setaf 196)"
CYAN="$(tput setaf 45)"
BLUE="$(tput setaf 33)"
ORANGE="$(tput setaf 214)"
BROWN="$(tput setaf 137)"
NEONBLUE="\033[38;2;4;218;255m"
NEONGREEN="\033[38;2;57;255;20m"
NEONPINK="\033[38;2;255;19;240m"
NEONPURPLE="\033[38;2;225;8;255m"
NEONRED="\033[38;2;255;49;49m"
JUNEBUD="\033[38;2;189;218;87m"
HIGHLIGHTER="\033[38;2;248;255;15m"
NC="\x1b[0m"

clear
echo -e ""
echo -e "${BROWN}===============================================${NC}"
echo -e "${BROWN}||            ${HIGHLIGHTER}NANO 4-WIN CLEANER             ${NC}${BROWN}||${NC}"
echo -e "${BROWN}===============================================${NC}"
echo -e ""
echo -e "\x1b[5;31mWARNING!!:${NC} ${WHITE}This will run '${ORANGE}git reset --hard${WHITE}' and"
echo -e "'${ORANGE}git clean -fd${WHITE}'. Uncommitted Frankenstein hacks"
echo -e "will be ${YELLOW}destroyed${NC}${WHITE}. It won't come back no matter"
echo -e "how ${PINK}hard${NC}${WHITE} you ${BLUE}cry${WHITE}!!!!${NC}\n"

read -r -p "Are you sure you want to nuke the build dir? [y/N] " response
if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo -e "\n${JUNEBUD}Clean aborted. Your dirty hacks are safe.${NC}"
    exit 0
fi

echo -e "\n${GREEN}Confirmed. Engaging scrub mode...${NC}"

BASE_DIR="$(pwd)"
BUILDDIR="${BASE_DIR}/build"

echo -e "${BLUE}Preparing build dir: ${WHITE}${BUILDDIR}${NC}"
mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"

sync_repo() {
    local url=$1
    local dir=$2
    if [ ! -d "$dir" ]; then
        echo -e "${PURPLE}Cloning $dir...${NC}"
        git clone "$url" --depth=1 "$dir"
    else
        echo -e "${PURPLE}Scrubbing and Syncing $dir...${NC}"
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

echo -e "\n${NEONBLUE}Clean complete. Ready for patching.${NC}"
