#!/usr/bin/env bash

# Check if the shell is bash
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script must be run using Bash. Try running it with: bash $0"
    exit 1
fi

export LC_ALL=C.UTF-8
export LAUNCHED_BY_MAIN=1

# Set paths
export PATH="$PATH:/sbin:/usr/sbin"
TOOLKIT_PATH="$(pwd)"
SCRIPTS_DIR="${TOOLKIT_PATH}/scripts"
HELPER_DIR="${SCRIPTS_DIR}/helper"
STORAGE_DIR="${SCRIPTS_DIR}/storage"
LOG_FILE="${TOOLKIT_PATH}/logs/setup.log"
arch="$(uname -m)"

if [[ "$arch" = "x86_64" ]]; then
    # x86-64
    CUE2POPS="${HELPER_DIR}/cue2pops"
    HDL_DUMP="${HELPER_DIR}/HDL Dump.elf"
    MKFS_EXFAT="${HELPER_DIR}/mkfs.exfat"
    PFS_FUSE="${HELPER_DIR}/PFS Fuse.elf"
    PFS_SHELL="${HELPER_DIR}/PFS Shell.elf"
    APA_FIXER="${HELPER_DIR}/PS2 APA Header Checksum Fixer.elf"
    PSU_EXTRACT="${HELPER_DIR}/PSU Extractor.elf"
    SQLITE="${HELPER_DIR}/sqlite"
elif [[ "$arch" = "aarch64" ]]; then
    # ARM64
    CUE2POPS="${HELPER_DIR}/aarch64/cue2pops"
    HDL_DUMP="${HELPER_DIR}/aarch64/HDL Dump.elf"
    MKFS_EXFAT="${HELPER_DIR}/aarch64/mkfs.exfat"
    PFS_FUSE="${HELPER_DIR}/aarch64/PFS Fuse.elf"
    PFS_SHELL="${HELPER_DIR}/aarch64/PFS Shell.elf"
    APA_FIXER="${HELPER_DIR}/aarch64/PS2 APA Header Checksum Fixer.elf"
    PSU_EXTRACT="${HELPER_DIR}/aarch64/PSU Extractor.elf"
    SQLITE="${HELPER_DIR}/aarch64/sqlite"
fi

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
        "${SCRIPTS_DIR}/Setup.sh"
        "${SCRIPTS_DIR}/PSBBN-Installer.sh"
        "${SCRIPTS_DIR}/HOSDMenu-Installer.sh"
        "${SCRIPTS_DIR}/Game-Installer.sh"
        "${SCRIPTS_DIR}/Extras.sh"
        "${SCRIPTS_DIR}/Game-Installer.sh"
        "${SCRIPTS_DIR}/Media-Installer.sh"
        "${HELPER_DIR}/art_downloader.py"
        "${HELPER_DIR}/binmerge.py"
        "${HELPER_DIR}/icon_sys_to_txt.py"
        "${HELPER_DIR}/list-builder.py"
        "${HELPER_DIR}/list-sorter.py"
        "${HELPER_DIR}/music-installer.py"
        "${HELPER_DIR}/ps2iconmaker.sh"
        "${HELPER_DIR}/txt_to_icon_sys.py"
        "${HELPER_DIR}/ziso.py"
        "${HELPER_DIR}/AppDB.csv"
        "${HELPER_DIR}/ArtDB.csv"
        "${HELPER_DIR}/TitlesDB_PS1_English.csv"
        "${HELPER_DIR}/TitlesDB_PS2_English.csv"
        "${HELPER_DIR}/txt_to_icon_sys.py"
        "${HELPER_DIR}/vmc_groups.list"
        "${CUE2POPS}"
        "${HDL_DUMP}"
        "${MKFS_EXFAT}"
        "${PFS_FUSE}"
        "${PFS_SHELL}"
        "${APA_FIXER}"
        "${PSU_EXTRACT}"
        "${SQLITE}"
    )

    # List of required non-empty directories
    local required_dirs=(
        "${SCRIPTS_DIR}/assets"
        "${TOOLKIT_PATH}/icons/art"
        "${TOOLKIT_PATH}/icons/ico"
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

check_dep(){
    MISSING=0
    echo >> "$LOG_FILE"
    echo "Checking Dependences:" >> "$LOG_FILE"
    echo "--- System commands ---" >> "$LOG_FILE"
    check_cmd axel
    check_cmd convert       # from ImageMagick
    check_cmd xxd
    check_cmd python3
    check_cmd bc
    check_cmd rsync
    check_cmd curl
    check_cmd zip
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
    check_cmd bchunk

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

    if { ldconfig -p 2>/dev/null | grep -q "libfuse.so.2"; } || pkg-config --exists fuse 2>/dev/null; then
        echo "[✓] FUSE2 (libfuse.so.2) is installed." >> "$LOG_FILE"
    else
        echo "[X] FUSE2 (libfuse.so.2) is missing." >> "$LOG_FILE"
        MISSING=1
    fi

    if [ "$MISSING" -ne 0 ]; then
        return 1
    fi
}

option_one() {
    "${SCRIPTS_DIR}/PSBBN-Installer.sh" -install $serialnumber "$path_arg"
}

option_two() {
    "${SCRIPTS_DIR}/PSBBN-Installer.sh" -update
}

option_three() {
    "${SCRIPTS_DIR}/HOSDMenu-Installer.sh" $serialnumber "$path_arg"
}

option_four() {
    "${SCRIPTS_DIR}/Game-Installer.sh" "$path_arg"
}

option_five() {
    "${SCRIPTS_DIR}/Media-Installer.sh" "$path_arg"
}

option_six() {
    "${SCRIPTS_DIR}/Extras.sh" "$path_arg"
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
               1) Install PSBBN & HOSDMenu (Official Sony Network Adapter required)
               2) Update PSBBN Software
               3) Install HOSDMenu only (3rd-party HDD adapters supported)
               4) Install Games and Apps
               5) Install Media
               6) Optional Extras
                                     
               q) Quit

EOF
}

if [ "$wsl" = "false" ]; then
        git_update
fi

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

if [[ "$arch" != "x86_64" && "$arch" != "aarch64" ]]; then
    error_msg "Unsupported CPU architecture: $(uname -m). This script requires x86-64 or ARM64."
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
rm -rf "${TOOLKIT_PATH}/scripts/"{node_modules,package.json,package-lock.json} >/dev/null 2>&1
rm -rf "${TOOLKIT_PATH}/scripts/assets/"psbbn-definitive-image* >/dev/null 2>&1
rmdir "${TOOLKIT_PATH}/OPL" >/dev/null 2>&1

check_required_files

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
    read -p "               Select an option: " choice

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
            clear
            break
            ;;
        *)
            echo
            echo -n "               Invalid option, please try again."
            sleep 2
            ;;
    esac
done