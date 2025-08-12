#!/usr/bin/env bash

trap 'echo; exit 130' INT

# Check if the shell is bash
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script must be run using Bash. Try running it with: bash $0" >&2
    exit 1
fi

TOOLKIT_PATH="$(pwd)"
SOURCES_LIST="/etc/apt/sources.list"
LOG_FILE="${TOOLKIT_PATH}/logs/setup.log"

error_msg() {
    echo
    echo
    echo "Error: $1" | tee -a "${LOG_FILE}"
    echo
    read -n 1 -s -r -p "Press any key to exit..."
    echo
    exit 1
}

log_and_run() {
  echo
  echo -n "$1..."
  # Run command, redirect stdout and stderr to LOG_FILE
  if ! eval "$2" >> "${LOG_FILE}" 2>&1; then
    error_msg "Failed to $1. Check '${LOG_FILE}' for details."
  fi
}

clear

mkdir -p "${TOOLKIT_PATH}/logs" >/dev/null 2>&1

# Clean sources.list if needed
if [[ -f "$SOURCES_LIST" ]]; then
    if grep -q 'deb cdrom' "$SOURCES_LIST"; then
        echo "Removing 'deb cdrom' line from $SOURCES_LIST..."
        sudo sed -i '/deb cdrom/d' "$SOURCES_LIST" >> "${LOG_FILE}" 2>&1 || error_msg "Failed to clean $SOURCES_LIST"
        echo "'deb cdrom' line removed." >> "${LOG_FILE}"
    fi
fi

echo "Installing Dependences:"

# Detect package manager and install packages
if [ -x "$(command -v apt)" ]; then
    log_and_run "Update package lists" "sudo apt update"
    log_and_run "Install required packages (apt)" "sudo apt install -y axel imagemagick xxd python3 python3-venv python3-pip nodejs npm bc rsync curl zip wget chromium ffmpeg lvm2"
    echo
elif [ -x "$(command -v dnf)" ]; then
    log_and_run "Install required packages (dnf)" "sudo dnf install -y gcc axel ImageMagick xxd python3 python3-devel python3-pip nodejs npm bc rsync curl zip wget chromium ffmpeg lvm2"
    echo
elif [ -x "$(command -v pacman)" ]; then
    log_and_run "Update archlinux-keyring" "sudo pacman -Sy --needed archlinux-keyring"
    log_and_run "Install required packages (pacman)" "sudo pacman -S --needed axel imagemagick xxd python pyenv python-pip nodejs npm bc rsync curl zip wget chromium ffmpeg lvm2"
    echo
else
    error_msg "No supported package manager found (apt, dnf, pacman)."
fi

# Check and install exfat support if needed
if ! command -v mkfs.exfat &> /dev/null; then
    echo "mkfs.exfat not found. Installing exfat driver..."
    if [ -x "$(command -v apt)" ]; then
        log_and_run "install exfat-fuse" "sudo apt install -y exfat-fuse"
        echo
    elif [ -x "$(command -v dnf)" ]; then
        log_and_run "install exfatprogs" "sudo dnf install -y exfatprogs"
        echo
    elif [ -x "$(command -v pacman)" ]; then
        log_and_run "install exfatprogs" "sudo pacman -S exfatprogs"
        echo
    else
        error_msg "No supported package manager found for exfat driver installation."
    fi
    echo "exFAT driver installed successfully." | tee -a "${LOG_FILE}"
fi

echo

# Setup Python virtual environment and install dependencies
echo -n "Setting up Python virtual environment and installing dependencies..."
if ! python3 -m venv scripts/venv >> "${LOG_FILE}" 2>&1; then
    error_msg "Failed to create Python virtual environment."
fi
echo

# shellcheck disable=SC1091
source scripts/venv/bin/activate || error_msg "Failed to activate the Python virtual environment."

if ! pip install lz4 natsort mutagen tqdm >> "${LOG_FILE}" 2>&1; then
    error_msg "Failed to install Python dependencies."
fi
deactivate

echo "Python virtual environment and dependencies installed successfully." | tee -a "${LOG_FILE}"
echo

cd scripts || error_msg "Failed to enter scripts directory."

echo -n "Installing Puppeteer via npm..."
if ! npm install puppeteer >> "${LOG_FILE}" 2>&1; then
    error_msg "Failed to install puppeteer."
fi
echo
echo "Puppeteer installed successfully." | tee -a "${LOG_FILE}"
echo
echo "Setup completed successfully!" | tee -a "${LOG_FILE}"

