#!/usr/bin/env bash

# Set paths
TOOLKIT_PATH="$(pwd)"
HELPER_DIR="${TOOLKIT_PATH}/scripts/helper"
ASSETS_DIR="${TOOLKIT_PATH}/scripts/assets"
OPL="${TOOLKIT_PATH}/scripts/storage/OPL"
LOG_FILE="${TOOLKIT_PATH}/logs/extras.log"

current_branch=$(git rev-parse --abbrev-ref HEAD)

if ! git remote | xargs -n1 git ls-remote --heads 2>/dev/null | grep -q "refs/heads/$current_branch$"; then
    echo "Testing is over. Please delete the ${TOOLKIT_PATH} folder"
    echo "and clone the main repository."
    echo
    read -n 1 -s -r -p "Press any key to exit..." </dev/tty
    rm -rf "${TOOLKIT_PATH}/scripts"
    echo
fi

path_arg="$1"

copy_log() {
    if [[ -n "$path_arg" ]]; then
        cp "${LOG_FILE}" "$path_arg" > /dev/null 2>&1
    fi
}

error_msg() {
    type=$1
    error_1="$2"
    error_2="$3"
    error_3="$4"
    error_4="$5"

    echo
    echo "$type: $error_1" | tee -a "${LOG_FILE}"
    [ -n "$error_2" ] && echo "$error_2" | tee -a "${LOG_FILE}"
    [ -n "$error_3" ] && echo "$error_3" | tee -a "${LOG_FILE}"
    [ -n "$error_4" ] && echo "$error_4" | tee -a "${LOG_FILE}"
    echo
    if [ "$type" = "Error" ]; then
        read -n 1 -s -r -p "Press any key to exit..." </dev/tty
        echo
        exit 1;
    else
        read -n 1 -s -r -p "Press any key to continue..." </dev/tty
        echo
    fi
}

trap 'echo; exit 130' INT
trap copy_log EXIT

cd "${TOOLKIT_PATH}"

echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    sudo rm -f "${LOG_FILE}"
    echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo
        echo "Error: Cannot to create log file."
        read -n 1 -s -r -p "Press any key to exit..." </dev/tty
        echo
        exit 1
    fi
fi

date >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
cat /etc/*-release >> "${LOG_FILE}" 2>&1

# Function to detect PS2 HDD

detect_drive() {
    DEVICE=$(sudo blkid -t TYPE=exfat | grep OPL | awk -F: '{print $1}' | sed 's/[0-9]*$//')

    if [[ -z "$DEVICE" ]]; then
        echo | tee -a "${LOG_FILE}"
        echo "Error: Unable to detect PS2 drive." | tee -a "${LOG_FILE}"
        read -n 1 -s -r -p "Press any key to return to the extras menu..." </dev/tty
        return 1
    fi

    echo "OPL partition found on $DEVICE" >> "${LOG_FILE}"

    # Find all mounted volumes associated with the device
    mounted_volumes=$(lsblk -ln -o MOUNTPOINT "$DEVICE" | grep -v "^$")

    # Iterate through each mounted volume and unmount it
    echo "Unmounting volumes associated with $DEVICE..." >> "${LOG_FILE}"
    for mount_point in $mounted_volumes; do
        echo "Unmounting $mount_point..." >> "${LOG_FILE}"
        if sudo umount "$mount_point"; then
            echo "Successfully unmounted $mount_point." >> "${LOG_FILE}"
        else
            echo
            echo "Failed to unmount $mount_point. Please unmount manually." | tee -a "${LOG_FILE}"
            read -n 1 -s -r -p "Press any key to return to the extras menu..." </dev/tty
            return 1
        fi
    done

    if ! sudo "${HELPER_DIR}/HDL Dump.elf" toc $DEVICE >> "${LOG_FILE}" 2>&1; then
        echo
        echo "Error: APA partition is broken on ${DEVICE}." | tee -a "${LOG_FILE}"
        read -n 1 -s -r -p "Press any key to return to the extras menu..." </dev/tty
        return 1
    else
        echo "PS2 HDD detected as $DEVICE" >> "${LOG_FILE}"
    fi
}

check_device_size() {
    # Get the size of the device in bytes
    SIZE_CHECK=$(lsblk -o NAME,SIZE -b | grep -w "$(basename "$DEVICE")" | awk '{print $2}')
    
    # Check if we successfully got a size
    if [[ -z "$SIZE_CHECK" ]]; then
        echo "Error: Could not determine device size."
        return 1
    fi

    # Convert size to GB (1 GB = 1,000,000,000 bytes)
    size_gb=$(echo "$SIZE_CHECK / 1000000000" | bc)

    if (( size_gb > 960 )); then
        echo
        echo "Warning: Device is $size_gb GB. HDD-OSD may experience issues with drives larger than 960 GB." | tee -a "${LOG_FILE}"
        echo
        read -rp "Continue anyway? (y/n): " answer
        case "$answer" in
            [Yy]*) echo "Continuing...";;
            *) echo "Aborting."; return 1;;
        esac
    fi
}

MOUNT_OPL() {
    echo | tee -a "${LOG_FILE}"
    echo "Mounting OPL partition..." >> "${LOG_FILE}"

    if ! mkdir -p "${OPL}" 2>>"${LOG_FILE}"; then
        read -n 1 -s -r -p "Failed to create ${OPL}. Press any key to return to the extras menu..." </dev/tty
        return 1
    fi

    sudo mount -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1

    # Handle possibility host system's `mount` is using Fuse
    if [ $? -ne 0 ] && hash mount.exfat-fuse; then
        echo "Attempting to use exfat.fuse..." | tee -a "${LOG_FILE}"
        sudo mount.exfat-fuse -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1
    fi

    if [ $? -ne 0 ]; then
        error_msg "Error" "Failed to mount ${DEVICE}3"
    fi

}

UNMOUNT_OPL() {
    sync
    if ! sudo umount -l "${OPL}" >> "${LOG_FILE}" 2>&1; then
        read -n 1 -s -r -p "Failed to unmount $DEVICE. Press any key to return to the extras menu..." </dev/tty
        return 1;
    fi
}

hdd_osd_files_present() {
    local files=(
        FNTOSD
        HDD-OSD.elf
        ICOIMAGE
        JISUCS
        OSDSYS_A.XLF
        osdboot.elf
        PSBBN.ELF
        SKBIMAGE
        SNDIMAGE
        TEXIMAGE
    )

    for file in "${files[@]}"; do
        if [[ ! -f "${ASSETS_DIR}/extras/$file" ]]; then
            return 1  # false
        fi
    done

    return 0  # true
}

download_files() {
# Check for HDD-OSD files
    rm -rf "${ASSETS_DIR}/HDD-OSD.zip" "${ASSETS_DIR}/HDD-OSD" 2>>"$LOG_FILE"
    if hdd_osd_files_present; then
        echo | tee -a "${LOG_FILE}"
        echo "All required files are present. Skipping download" >> "${LOG_FILE}"
    else
        echo | tee -a "${LOG_FILE}"
        echo "Required files are missing in ${ASSETS_DIR}/extras." | tee -a "${LOG_FILE}"
        # Check if extras.zip exists
        if [[ -f "${ASSETS_DIR}/extras.zip" && ! -f "${ASSETS_DIR}/extras.zip.st" ]]; then
            echo | tee -a "${LOG_FILE}"
            echo "extras.zip found in ${ASSETS_DIR}. Extracting..." | tee -a "${LOG_FILE}"
            unzip -o "${ASSETS_DIR}/extras.zip" -d "${ASSETS_DIR}" >> "${LOG_FILE}" 2>&1
        else
            echo | tee -a "${LOG_FILE}"
            echo "Downloading required files..." | tee -a "${LOG_FILE}"
            axel -a https://archive.org/download/psbbn-definitive-english-patch-v2/extras.zip -o "${ASSETS_DIR}"
            unzip -o "${ASSETS_DIR}/extras.zip" -d "${ASSETS_DIR}" >> "${LOG_FILE}" 2>&1
        fi
        # Check if HDD-OSD files exist after extraction
        if hdd_osd_files_present; then
            echo | tee -a "${LOG_FILE}"
            echo "Files successfully extracted." | tee -a "${LOG_FILE}"
        else
            echo | tee -a "${LOG_FILE}"
            echo "Error: One or more files are missing after extraction." | tee -a "${LOG_FILE}"
            read -n 1 -s -r -p "Press any key to return to the extras menu..." </dev/tty
            return 1
        fi
    fi
}

# Function for Option 2 - Install HDD-OSD
option_one() {

    clear

    if ! detect_drive; then
        return
    fi

    # Now check size
    if ! check_device_size; then
        return
    fi

    if ! download_files; then
        return
    fi

    # Copy HDD-OSD files to __system
    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="mount __system\n"
    COMMANDS+="lcd '${ASSETS_DIR}/extras'\n"
    COMMANDS+="mkdir osd110u\n"
    COMMANDS+="cd osd110u\n"
    COMMANDS+="put FNTOSD\n"
    COMMANDS+="put HDD-OSD.elf\n"
    COMMANDS+="put ICOIMAGE\n"
    COMMANDS+="put JISUCS\n"
    COMMANDS+="put SKBIMAGE\n"
    COMMANDS+="put SNDIMAGE\n"
    COMMANDS+="put TEXIMAGE\n"
    COMMANDS+="cd /\n"
    COMMANDS+="umount\n"
    COMMANDS+="exit"

    # Pipe all commands to PFS Shell for mounting, copying, and unmounting
    echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" >> "${LOG_FILE}" 2>&1

    cp "${ASSETS_DIR}/extras/"{HDD-OSD.elf,PSBBN.ELF} "${TOOLKIT_PATH}/games/APPS" >> "${LOG_FILE}" 2>&1

    echo | tee -a "${LOG_FILE}"
    echo "HDD-OSD installed sucessfully." | tee -a "${LOG_FILE}"
    echo
    echo "Please run '03-Game-Installer.sh' to add HDD-OSD to the PSBBN Game Channel and update the icons"
    echo "for your game collection."
    echo
    read -n 1 -s -r -p "Press any key to return to the extras menu..." </dev/tty
}

# Function for Option 3 - Install PlayStation 2 Basic Boot Loader (PS2BBL)
option_two() {
    clear
    
    if ! download_files; then
        return
    fi

    if ! detect_drive; then
        return
    fi

    # Copy PS2BBL files to __system and __sysconf
    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="mount __system\n"
    COMMANDS+="lcd '${ASSETS_DIR}/extras'\n"
    COMMANDS+="cd p2lboot\n"
    COMMANDS+="rm osdboot.elf\n"
    COMMANDS+="put PSBBN.ELF\n"
    COMMANDS+="lcd '${ASSETS_DIR}/PS2BBL'\n"
    COMMANDS+="put osdboot.elf\n"
    COMMANDS+="cd /\n"
    COMMANDS+="umount\n"
    COMMANDS+="mount __sysconf\n"
    COMMANDS+="mkdir PS2BBL\n"
    COMMANDS+="cd PS2BBL\n"
    COMMANDS+="put CONFIG.INI\n"
    COMMANDS+="cd /\n"
    COMMANDS+="umount\n"
    COMMANDS+="exit"

    # Pipe all commands to PFS Shell for mounting, copying, and unmounting
    echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" >> "${LOG_FILE}" 2>&1

    echo | tee -a "${LOG_FILE}"
    echo "PS2BBL installed sucessfully."
    echo
    read -n 1 -s -r -p "Press any key to return to the extras menu..." </dev/tty

}

# Function for Option 4 - Uninstall PlayStation 2 Basic Boot Loader (PS2BBL)
option_three() {
    clear

    if ! download_files; then
        return
    fi

    if ! detect_drive; then
        return
    fi

    # Copy PS2BBL files to __system and __sysconf
    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="mount __system\n"
    COMMANDS+="cd p2lboot\n"
    COMMANDS+="rm osdboot.elf\n"
    COMMANDS+="lcd '${ASSETS_DIR}/extras'\n"
    COMMANDS+="put osdboot.elf\n"
    COMMANDS+="cd /\n"
    COMMANDS+="umount\n"
    COMMANDS+="mount __sysconf\n"
    COMMANDS+="cd PS2BBL\n"
    COMMANDS+="rm CONFIG.INI\n"
    COMMANDS+="cd /\n"
    COMMANDS+="rmdir PS2BBL\n"
    COMMANDS+="umount\n"
    COMMANDS+="exit"

    # Pipe all commands to PFS Shell for mounting, copying, and unmounting
    echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" >> "${LOG_FILE}" 2>&1

    echo | tee -a "${LOG_FILE}"
    echo "PS2BBL sucessfully uninstalled."
    echo
    read -n 1 -s -r -p "Press any key to return to the extras menu..." </dev/tty
}


# Function to display the menu
display_menu() {
    clear
    cat << "EOF"
                                     _____     _                 
                                    |  ___|   | |                
                                    | |____  _| |_ _ __ __ _ ___ 
                                    |  __\ \/ / __| '__/ _` / __|
                                    | |___>  <| |_| | | (_| \__ \
                                    \____/_/\_\\__|_|  \__,_|___/
                        


                         1) Install HDD-OSD/Browser 2.0
                         2) Install PlayStation 2 Basic Boot Loader (PS2BBL)
                         3) Uninstall PlayStation 2 Basic Boot Loader (PS2BBL)

                         b) Back to Main Menu

EOF
}

# Main loop

while true; do
    display_menu
    read -p "                         Select an option: " choice

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
        b|B)
            break
            ;;
        *)
            echo
            echo "                         Invalid option, please try again."
            sleep 2
            ;;
    esac
done
