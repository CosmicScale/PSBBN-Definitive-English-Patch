#!/usr/bin/env bash
export LC_ALL=en_US.UTF-8

# Check if the shell is bash
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script must be run using Bash. Try running it with: bash $0"
    exit 1
fi

# Set paths
export PATH="$PATH:/sbin:/usr/sbin"
TOOLKIT_PATH="$(pwd)"
HELPER_DIR="${TOOLKIT_PATH}/scripts/helper"
LOG_FILE="${TOOLKIT_PATH}/logs/setup.log"

# Initialize variable
wsl=false

# Check if first argument is -wsl and at least 2 more arguments follow
if [[ "$1" == "-wsl" && -n "$2" && -n "$3" ]]; then
    wsl=true
    serialnumber="$2"
    path_arg="$3"
fi

error_msg() {
  error_1="$1"
  error_2="$2"
  error_3="$3"
  error_4="$4"

  echo
  echo "[X] Error: $error_1" | tee -a "${LOG_FILE}"
  [ -n "$error_2" ] && echo && echo "$error_2" | tee -a "${LOG_FILE}"
  [ -n "$error_3" ] && echo "$error_3" | tee -a "${LOG_FILE}"
  [ -n "$error_4" ] && echo "$error_4" | tee -a "${LOG_FILE}"
  echo
  read -n 1 -s -r -p "Press any key to exit..." </dev/tty
  echo
  exit 1
}

copy_log() {
    if [[ -n "$path_arg" ]]; then
        cp "${LOG_FILE}" "$path_arg" > /dev/null 2>&1
    fi
}

git_update() {
    # Check if the current directory is a Git repository
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        echo "This is not a Git repository. Skipping update check." >> "${LOG_FILE}"
    else
        # Fetch updates from the remote
        git fetch >> "${LOG_FILE}" 2>&1

        # Check the current status of the repository
        LOCAL=$(git rev-parse @)
        REMOTE=$(git rev-parse @{u})
        BASE=$(git merge-base @ @{u})

        if [ "$LOCAL" = "$REMOTE" ]; then
            echo "No updates available — running the latest version." >> "${LOG_FILE}"
        else
            echo "Downloading updates..." | tee -a "${LOG_FILE}"
            # Get a list of files that have changed remotely
            UPDATED_FILES=$(git diff --name-only "$LOCAL" "$REMOTE")

            if [ -n "$UPDATED_FILES" ]; then
                echo "Files updated in the remote repository:" | tee -a "${LOG_FILE}"
                echo "$UPDATED_FILES" | tee -a "${LOG_FILE}"

                # Reset only the files that were updated remotely (discard local changes to them)
                echo "$UPDATED_FILES" | xargs git checkout -- >> "${LOG_FILE}" 2>&1

                # Pull the latest changes
                if ! git pull --ff-only >> "${LOG_FILE}" 2>&1; then
                    error_msg "Update failed. Delete the PSBBN-Definitive-English-Patch directory and run the command:" "git clone https://github.com/CosmicScale/PSBBN-Definitive-English-Patch.git" "Then try running the script again."
                fi
                echo
                echo "[✓] The repository has been successfully updated." | tee -a "${LOG_FILE}"
                echo
                read -n 1 -s -r -p "Press any key to exit, then run the script again." </dev/tty
                echo
                exit 0
            fi
        fi
    fi
}

check_required_files() {
    local missing=false

    # List of required files
    local required_files=(
        "./scripts/Extras.sh"
        "./scripts/Game-Installer.sh"
        "./scripts/PSBBN-Installer.sh"
        "./scripts/Setup.sh"
        "./scripts/helper/AppDB.csv"
        "./scripts/helper/ArtDB.csv"
        "./scripts/helper/art_downloader.py"
        "./scripts/helper/HDL Dump.elf"
        "./scripts/helper/icon_sys_to_txt.py"
        "./scripts/helper/list-builder.py"
        "./scripts/helper/list-sorter.py"
        "./scripts/helper/mkfs.exfat"
        "./scripts/helper/PFS Fuse.elf"
        "./scripts/helper/PFS Shell.elf"
        "./scripts/helper/PS2 APA Header Checksum Fixer.elf"
        "./scripts/helper/ps2iconmaker.sh"
        "./scripts/helper/PSU Extractor.elf"
        "./scripts/helper/TitlesDB_PS1_English.csv"
        "./scripts/helper/TitlesDB_PS2_English.csv"
        "./scripts/helper/txt_to_icon_sys.py"
        "./scripts/helper/vmc_groups.list"
        "./scripts/helper/ziso.py"
    )

    # List of required non-empty directories
    local required_dirs=(
        "./scripts/assets"
        "./icons/art"
        "./icons/ico"
    )

    # Check each file
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo "Missing file: $file"
            missing=true
        fi
    done

    # Check each directory
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" || -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
            echo "Missing or empty directory: $dir"
            missing=true
        fi
    done

    # If any were missing, exit with error
    if [[ "$missing" == true ]]; then
        error_msg "Essential files not found." "The script must be run from the 'PSBBN-Definitive-English-Patch' directory."
    fi
}

check_cmd() {
    if ! command -v "$1" &> /dev/null; then
        echo "[X] Missing command: $1" >> "$LOG_FILE"
        MISSING=1
    else
        echo "[✓] $1 found" >> "$LOG_FILE"
    fi
}

check_python_pkg() {
    if ! scripts/venv/bin/python -c "import $1" &> /dev/null; then
        echo "[X] Missing Python package: $1" >> "$LOG_FILE"
        MISSING=1
    else
        echo "[✓] Python package '$1' found" >> "$LOG_FILE"
    fi
}

check_node_pkg() {
    PACKAGE="$1"
    NODE_MODULES_PATH="./scripts/node_modules"

    if NODE_PATH="$NODE_MODULES_PATH" node -e "require('$PACKAGE');" >/dev/null 2>&1; then
        echo "[✓] Node.js package '$PACKAGE' found" >> "$LOG_FILE"
    else
        echo "[X] Missing Node.js package: '$PACKAGE'" >> "$LOG_FILE"
        MISSING=1
    fi
}

check_dep(){
    MISSING=0
    echo >> "$LOG_FILE"
    echo "Checking Dependences:" >> "$LOG_FILE"
    echo "--- System commands ---" >> "$LOG_FILE"
    check_cmd axel
    check_cmd convert       # from ImageMagick
    check_cmd xxd
    check_cmd python3
    check_cmd node
    check_cmd npm
    check_cmd bc
    check_cmd rsync
    check_cmd curl
    check_cmd unzip
    check_cmd wget
    check_cmd ffmpeg
    check_cmd lvm
    check_cmd timeout
    check_cmd mkfs.vfat
    check_cmd mke2fs
    check_cmd ldconfig
    check_cmd sfdisk
    check_cmd partprobe

    echo >> "$LOG_FILE"
    echo "--- exFAT support ---" >> "$LOG_FILE"

    if grep -qw exfat /proc/filesystems; then
        echo "[✓] Native kernel exFAT support detected." >> "$LOG_FILE"
    else
        sudo modprobe exfat 2>/dev/null
        if grep -qw exfat /proc/filesystems; then
            echo "[✓] Native kernel exFAT support detected (after modprobe)." >> "$LOG_FILE"
        elif command -v mount.exfat-fuse &>/dev/null; then
            echo "[✓] FUSE-based exFAT support detected (mount.exfat-fuse)." >> "$LOG_FILE"
        else
            echo "[X] No exFAT support found. Running setup..." >> "$LOG_FILE"
            MISSING=1
        fi
    fi

    echo >> "$LOG_FILE"
    echo "--- Python virtual environment ---" >> "$LOG_FILE"
    if [ ! -d "scripts/venv" ]; then
        echo "[X] Python venv not found in scripts/venv" >> "$LOG_FILE"
        MISSING=1
    else
        echo "[✓] Python venv found" >> "$LOG_FILE"
        check_python_pkg lz4
        check_python_pkg natsort
        check_python_pkg mutagen
        check_python_pkg tqdm
    fi

    if ldconfig -p | grep -q "libfuse.so.2"; then
        echo "[✓] FUSE2 (libfuse.so.2) is installed." >> "$LOG_FILE"
    else
        echo "[X] FUSE2 (libfuse.so.2) is missing." >> "$LOG_FILE"
        MISSING=1
    fi

    echo >> "$LOG_FILE"
    echo "--- Node.js packages ---" >> "$LOG_FILE"
    check_node_pkg puppeteer

    if [ "$MISSING" -ne 0 ]; then
        return 1
    fi
}

option_one() {
    if [ "$wsl" = "true" ]; then
        "${TOOLKIT_PATH}/scripts/PSBBN-Installer.sh" -install $serialnumber "$path_arg"
    else
        "${TOOLKIT_PATH}/scripts/PSBBN-Installer.sh" -install
    fi
}

option_two() {
    "${TOOLKIT_PATH}/scripts/PSBBN-Installer.sh" -update
}

option_three() {
    if [ "$wsl" = "true" ]; then
        "${TOOLKIT_PATH}/scripts/Game-Installer.sh" "$path_arg"
    else
        "${TOOLKIT_PATH}/scripts/Game-Installer.sh"
    fi
}

option_four() {
    if [ "$wsl" = "true" ]; then
        "${TOOLKIT_PATH}/scripts/Media-Installer.sh" "$path_arg"
    else
        "${TOOLKIT_PATH}/scripts/Media-Installer.sh"
    fi
}

option_five() {
    if [ "$wsl" = "true" ]; then
        "${TOOLKIT_PATH}/scripts/Extras.sh" "$path_arg"
    else
        "${TOOLKIT_PATH}/scripts/Extras.sh"
    fi
}

SPLASH() {
    clear
    cat << "EOF"
______  _________________ _   _  ______      __ _       _ _   _            ______     _       _     
| ___ \/  ___| ___ \ ___ \ \ | | |  _  \    / _(_)     (_) | (_)           | ___ \   | |     | |    
| |_/ /\ `--.| |_/ / |_/ /  \| | | | | |___| |_ _ _ __  _| |_ ___   _____  | |_/ /_ _| |_ ___| |__  
|  __/  `--. \ ___ \ ___ \ . ` | | | | / _ \  _| | '_ \| | __| \ \ / / _ \ |  __/ _` | __/ __| '_ \ 
| |    /\__/ / |_/ / |_/ / |\  | | |/ /  __/ | | | | | | | |_| |\ V /  __/ | | | (_| | || (__| | | |
\_|    \____/\____/\____/\_| \_/ |___/ \___|_| |_|_| |_|_|\__|_| \_/ \___| \_|  \__,_|\__\___|_| |_|

                                       Created by CosmicScale


EOF
}

# Function to display the menu
display_menu() {
    SPLASH
    cat << "EOF"
                                     1) Install PSBBN
                                     2) Update PSBBN Software
                                     3) Install Games and Apps
                                     4) Install Media
                                     5) Optional Extras
                                     
                                     q) Quit

EOF
}

trap 'echo; exit 130' INT
trap copy_log EXIT

echo -e "\e[8;45;100t"

SPLASH

cd "${TOOLKIT_PATH}"

mkdir -p "${TOOLKIT_PATH}/logs" >/dev/null 2>&1

if ! echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1; then
    sudo rm -f "${LOG_FILE}"
    if ! echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1; then
        echo
        error_msg "Cannot create log file."
    fi
fi

date >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
echo "Tootkit path: $TOOLKIT_PATH" >> "${LOG_FILE}"
echo  >> "${LOG_FILE}"
cat /etc/*-release >> "${LOG_FILE}" 2>&1
echo >> "${LOG_FILE}"
echo "WSL: $wsl" >> "${LOG_FILE}"
echo "Disk Serial: $serialnumber" >> "${LOG_FILE}"
echo "Path: $path_arg" >> "${LOG_FILE}"
echo >> "${LOG_FILE}"

if [[ "$(uname -m)" != "x86_64" ]]; then
    error_msg "Unsupported CPU architecture: $(uname -m). This script requires x86-64."
    exit 1
fi

# Detect WSL
if grep -qi microsoft /proc/version; then
    # Detect distro
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            fedora|arch)
                echo "Unsupported distro under WSL: $NAME. Please use Debian instead."
                exit 1
                ;;
        esac
    fi
fi

rm "${TOOLKIT_PATH}/"*.log >/dev/null 2>&1
rm -rf "${TOOLKIT_PATH}/"{storage,node_modules,venv,gamepath.cfg} >/dev/null 2>&1
rm -rf "${TOOLKIT_PATH}/scripts/assets/"psbbn-definitive-image* >/dev/null 2>&1
rmdir "${TOOLKIT_PATH}/OPL" >/dev/null 2>&1


check_required_files

if [ "$wsl" = "false" ]; then
        git_update
fi

if ! check_dep; then
    if ! "${TOOLKIT_PATH}/scripts/Setup.sh"; then
        exit 1
    else
        check_dep || error_msg "Dependencies still missing after setup." 
    fi
fi

# Main loop

while true; do
    display_menu
    read -p "                                     Select an option: " choice

    case $choice in
        1)
            option_one
            ;;
        2)
            option_two
            ;;
        3)
            option_three
            ;;
        4)
            option_four
            ;;
        5)
            option_five
            ;;
        6)
            option_six
            ;;
        q|Q)
            echo
            break
            ;;
        *)
            echo
            echo "                                     Invalid option, please try again."
            sleep 2
            ;;
    esac
done