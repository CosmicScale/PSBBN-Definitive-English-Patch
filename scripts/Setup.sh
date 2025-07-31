#!/usr/bin/env bash

# Check if the shell is bash
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script must be run using Bash. Try running it with: bash $0" >&2
    exit 1
fi

echo -e "\e[8;30;100t"

TOOLKIT_PATH="$(pwd)"

clear

if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "Error: This script requires an x86-64 CPU architecture. Detected: $(uname -m)"
  read -n 1 -s -r -p "Press any key to exit."
  echo
  exit 1
fi

cd "${TOOLKIT_PATH}"

# Check if the helper files exists
if [[ ! -f "${TOOLKIT_PATH}/helper/PFS Shell.elf" || ! -f "${TOOLKIT_PATH}/helper/HDL Dump.elf" ]]; then
    echo "Required helper files not found. Please make sure you are in the 'PSBBN-Definitive-English-Patch'"
    echo "directory and try again."
    exit 1
fi

# Check if the current directory is a Git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "This is not a Git repository. Skipping update check."
else
  # Fetch updates from the remote
  git fetch > /dev/null 2>&1

  # Check the current status of the repository
  LOCAL=$(git rev-parse @)
  REMOTE=$(git rev-parse @{u})
  BASE=$(git merge-base @ @{u})

  if [ "$LOCAL" = "$REMOTE" ]; then
    echo "The repository is up to date."
  else
    echo "Downloading updates..."
    # Get a list of files that have changed remotely
    UPDATED_FILES=$(git diff --name-only "$LOCAL" "$REMOTE")

    if [ -n "$UPDATED_FILES" ]; then
      echo "Files updated in the remote repository:"
      echo "$UPDATED_FILES"

      # Reset only the files that were updated remotely (discard local changes to them)
      echo "$UPDATED_FILES" | xargs git checkout --

      # Pull the latest changes
      git pull --ff-only
      if [[ $? -ne 0 ]]; then
        echo
        echo "Error: Update failed. Delete the PSBBN-Definitive-English-Patch directory and run the command:"
        echo
        echo "git clone https://github.com/CosmicScale/PSBBN-Definitive-English-Patch.git"
        echo
        read -n 1 -s -r -p "Then try running the script again. Press any key to exit"
        echo
        exit 1
      fi
      echo
      echo "The repository has been successfully updated."
      read -n 1 -s -r -p "Press any key to exit, then run the script again."
      echo
      exit 0
    else
      echo "The repository is up to date."
    fi
  fi
fi

echo "                                      _____      _               ";
echo "                                     /  ___|    | |              ";
echo "                                     \ \`--.  ___| |_ _   _ _ __  ";
echo "                                      \`--. \/ _ \ __| | | | '_ \ ";
echo "                                     /\__/ /  __/ |_| |_| | |_) |";
echo "                                     \____/ \___|\__|\__,_| .__/ ";
echo "                                                          | |    ";
echo "                                                          |_|    ";
echo
echo "   This script installs all dependencies required for the 'PSBBN Installer' and 'Game Installer'."
echo "   It must be run first."
echo
read -n 1 -s -r -p "   Press any key to continue..."
echo
echo

# Path to the sources.list file
SOURCES_LIST="/etc/apt/sources.list"

# Check if the file exists
if [[ -f "$SOURCES_LIST" ]]; then
    # Remove the "deb cdrom" line and store the result
if grep -q 'deb cdrom' "$SOURCES_LIST"; then
        sudo sed -i '/deb cdrom/d' "$SOURCES_LIST"
	echo "'deb cdrom' line has been removed from $SOURCES_LIST."
else
        echo "No 'deb cdrom' line found in $SOURCES_LIST."
fi
fi
# Check if user is on Debian-based system
if [ -x "$(command -v apt)" ]; then
    sudo apt update && sudo apt install -y axel imagemagick xxd python3 python3-venv python3-pip nodejs npm bc rsync curl zip wget chromium
# Or if user is on Fedora-based system, do this instead
elif [ -x "$(command -v dnf)" ]; then
    sudo dnf install -y gcc axel ImageMagick xxd python3 python3-devel python3-pip nodejs npm bc rsync curl zip wget chromium
# Or if user is on Arch-based system, do this instead
elif [ -x "$(command -v pacman)" ]; then
    sudo pacman -Sy --needed archlinux-keyring && sudo pacman -S --needed axel imagemagick xxd python pyenv python-pip nodejs npm bc rsync curl zip wget chromium
fi
if [ $? -ne 0 ]; then
    echo
    echo "Error: Package installation failed."
    read -n 1 -s -r -p "Press any key to exit..."
    echo
    exit 1
fi

# Check if mkfs.exfat exists, and install exfat-fuse if not
if ! command -v mkfs.exfat &> /dev/null; then
    echo
    echo "mkfs.exfat not found. Installing exfat driver..."
if [ -x "$(command -v apt)" ]; then
    sudo apt install -y exfat-fuse
elif [ -x "$(command -v dnf)" ]; then
        sudo dnf install -y exfatprogs
elif [ -x "$(command -v pacman)" ]; then
	sudo pacman -S exfatprogs
fi
if [ $? -ne 0 ]; then
    	echo
    	echo "Error: Failed to install exfat driver."
    	read -n 1 -s -r -p "Press any key to exit..."
        echo
    	exit 1
fi
fi

# Setup Python virtual environment and install Python dependencies
python3 -m venv venv
if [ $? -ne 0 ]; then
    echo
    echo "Error: Failed to create Python virtual environment."
    read -n 1 -s -r -p "Press any key to exit..."
    echo
    exit 1
fi

source venv/bin/activate
pip install lz4 natsort
if [ $? -ne 0 ]; then
    echo
    echo "Error: Failed to install Python dependencies."
    read -n 1 -s -r -p "Press any key to exit..."
    echo
    deactivate
    exit 1
fi
deactivate

npm install puppeteer
if [ $? -ne 0 ]; then
    echo
    echo "Error: Failed to install puppeteer."
    read -n 1 -s -r -p "Press any key to exit..."
    echo
    exit 1
fi

echo
echo "Setup completed successfully!"
read -n 1 -s -r -p "Press any key to exit..."
echo
