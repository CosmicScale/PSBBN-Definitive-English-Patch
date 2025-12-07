#!/usr/bin/env bash

if [[ "$LAUNCHED_BY_MAIN" != "1" ]]; then
    echo "This script should not be run directly. Please run: PSBBN-Definitive-Patch.sh"
    exit 1
fi

# Set paths
TOOLKIT_PATH="$(pwd)"
SCRIPTS_DIR="${TOOLKIT_PATH}/scripts"
HELPER_DIR="${SCRIPTS_DIR}/helper"
ASSETS_DIR="${SCRIPTS_DIR}/assets"
STORAGE_DIR="${SCRIPTS_DIR}/storage"
OPL="${SCRIPTS_DIR}/OPL"
LOG_FILE="${TOOLKIT_PATH}/logs/extras.log"

path_arg="$1"

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

error_msg() {
    error_1="$1"
    error_2="$2"
    error_3="$3"
    error_4="$4"

    echo
    echo "$error_1" | tee -a "${LOG_FILE}"
    [ -n "$error_2" ] && echo "$error_2" | tee -a "${LOG_FILE}"
    [ -n "$error_3" ] && echo "$error_3" | tee -a "${LOG_FILE}"
    [ -n "$error_4" ] && echo "$error_4" | tee -a "${LOG_FILE}"
    echo
    read -n 1 -s -r -p "Press any key to return to the menu..." </dev/tty
    echo
}

clean_up() {
    failure=0

    submounts=$(findmnt -nr -o TARGET | grep "^${STORAGE_DIR}/" | sort -r)

    if [ -n "$submounts" ]; then
        echo "Found mounts under ${STORAGE_DIR}, attempting to unmount..." >> "$LOG_FILE"
        while read -r mnt; do
            [ -z "$mnt" ] && continue
            echo "Unmounting $mnt..." >> "$LOG_FILE"
            sudo umount "$mnt" >> "${LOG_FILE}" 2>&1 || failure=1
        done <<< "$submounts"
    fi

    if [ -d "${STORAGE_DIR}" ]; then
        submounts=$(findmnt -nr -o TARGET | grep "^${STORAGE_DIR}/" | sort -r)
        if [ -z "$submounts" ]; then
            echo "Deleting ${STORAGE_DIR}..." >> "$LOG_FILE"
            sudo rm -rf "${STORAGE_DIR}" || { echo "[X] Error: Failed to delete ${STORAGE_DIR}" >> "$LOG_FILE"; failure=1; }
            echo "Deleted ${STORAGE_DIR}." >> "$LOG_FILE"
        else
            echo "Some mounts remain under ${STORAGE_DIR}, not deleting." >> "$LOG_FILE"
            failure=1
        fi
    else
        echo "Directory ${STORAGE_DIR} does not exist." >> "$LOG_FILE"
    fi

    # Get the device basename
    DEVICE_CUT=$(basename "$DEVICE")

    # List all existing maps for this device
    existing_maps=$(sudo dmsetup ls 2>/dev/null | awk -v dev="$DEVICE_CUT" '$1 ~ "^"dev"-" {print $1}')

    # Force-remove each existing map
    for map_name in $existing_maps; do
        echo "Removing existing mapper $map_name..." >> "$LOG_FILE"
        if ! sudo dmsetup remove -f "$map_name" 2>/dev/null; then
            echo "Failed to delete mapper $map_name." >> "$LOG_FILE"
            failure=1
        fi
    done

    # Abort if any failures occurred
    if [ "$failure" -ne 0 ]; then
        echo | tee -a "${LOG_FILE}"
        error_msg "[X] Error: Cleanup error(s) occurred. Aborting."
        return 1
    fi

}

exit_script() {
    clean_up
    if [[ -n "$path_arg" ]]; then
        cp "${LOG_FILE}" "${path_arg}" > /dev/null 2>&1
    fi
}

mapper_probe() {
    DEVICE_CUT=$(basename "${DEVICE}")

    # 1) Remove existing maps for this device
    existing_maps=$(sudo dmsetup ls 2>/dev/null | awk -v p="^${DEVICE_CUT}-" '$1 ~ p {print $1}')
    for map in $existing_maps; do
        sudo dmsetup remove "$map" 2>/dev/null
    done

    # 2) Build keep list
    keep_partitions=( "${LINUX_PARTITIONS[@]}" "${APA_PARTITIONS[@]}" )

    # 3) Get HDL Dump --dm output, split semicolons into lines
    dm_output=$(sudo "${HDL_DUMP}" toc "${DEVICE}" --dm | tr ';' '\n')

    # 4) Create each kept partition individually
    while IFS= read -r line; do
        for part in "${keep_partitions[@]}"; do
            if [[ "$line" == "${DEVICE_CUT}-${part},"* ]]; then
                echo "$line" | sudo dmsetup create --concise
                break
            fi
        done
    done <<< "$dm_output"

    # 5) Export base mapper path
    MAPPER="/dev/mapper/${DEVICE_CUT}-"
}

mount_cfs() {
  for PARTITION_NAME in "${LINUX_PARTITIONS[@]}"; do
    MOUNT_PATH="${STORAGE_DIR}/${PARTITION_NAME}"
    if [ -e "${MAPPER}${PARTITION_NAME}" ]; then
        [ -d "${MOUNT_PATH}" ] || mkdir -p "${MOUNT_PATH}"
        if ! sudo mount "${MAPPER}${PARTITION_NAME}" "${MOUNT_PATH}" >>"${LOG_FILE}" 2>&1; then
            error_msg "[X] Error: Failed to mount ${PARTITION_NAME} partition."
            clean_up
            return 1
        fi
    else
        error_msg "[X] Error: Partition ${PARTITION_NAME} not found on disk."
        clean_up
        return 1
    fi
  done
}

mount_pfs() {
    for PARTITION_NAME in "${APA_PARTITIONS[@]}"; do
        MOUNT_POINT="${STORAGE_DIR}/$PARTITION_NAME/"
        mkdir -p "$MOUNT_POINT"
        if ! sudo "${PFS_FUSE}" \
            -o allow_other \
            --partition="$PARTITION_NAME" \
            "${DEVICE}" \
            "$MOUNT_POINT" >>"${LOG_FILE}" 2>&1; then
            error_msg "[X] Error: Failed to mount $PARTITION_NAME partition." "Check the device or filesystem and try again."
            clean_up
            return 1
        fi
    done
}

detect_drive() {
    DEVICE=$(sudo blkid -t TYPE=exfat | grep OPL | awk -F: '{print $1}' | sed 's/[0-9]*$//')

    if [[ -z "$DEVICE" ]]; then
        echo | tee -a "${LOG_FILE}"
        echo "[X] Error: Unable to detect the PS2 drive. Please ensure the drive is properly connected." | tee -a "${LOG_FILE}"
        echo
        echo "You must install PSBBN first before insalling extras."
        echo
        read -n 1 -s -r -p "Press any key to return to the menu..." </dev/tty
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
            echo "[✓] Successfully unmounted $mount_point." >> "${LOG_FILE}"
        else
            echo
            echo "Failed to unmount $mount_point. Please unmount manually." | tee -a "${LOG_FILE}"
            read -n 1 -s -r -p "Press any key to return to the menu..." </dev/tty
            return 1
        fi
    done

    if ! sudo "${HDL_DUMP}" toc $DEVICE >> "${LOG_FILE}" 2>&1; then
        echo
        echo "[X] Error: APA partition is broken on ${DEVICE}." | tee -a "${LOG_FILE}"
        read -n 1 -s -r -p "Press any key to return to the menu..." </dev/tty
        return 1
    else
        echo "PS2 HDD detected as $DEVICE" >> "${LOG_FILE}"
    fi
}

MOUNT_OPL() {
    echo | tee -a "${LOG_FILE}"
    echo "Mounting OPL partition..." >> "${LOG_FILE}"

    if ! mkdir -p "${OPL}" 2>>"${LOG_FILE}"; then
        read -n 1 -s -r -p "Failed to create ${OPL}. Press any key to return to the menu..." </dev/tty
        return 1
    fi

    sudo mount -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1

    # Handle possibility host system's `mount` is using Fuse
    if [ $? -ne 0 ] && hash mount.exfat-fuse; then
        echo "Attempting to use exfat.fuse..." | tee -a "${LOG_FILE}"
        sudo mount.exfat-fuse -o uid=$UID,gid=$(id -g) ${DEVICE}3 "${OPL}" >> "${LOG_FILE}" 2>&1
    fi

    if [ $? -ne 0 ]; then
        error_msg "[X] Error: Failed to mount ${DEVICE}3"
        return 1
    fi

}

UNMOUNT_OPL() {
    sync
    if ! sudo umount -l "${OPL}" >> "${LOG_FILE}" 2>&1; then
        read -n 1 -s -r -p "Failed to unmount $DEVICE. Press any key to return to the menu..." </dev/tty
        return 1;
    fi
}

download_linux() {
# Check for HDD-OSD files
    if [ -f "${ASSETS_DIR}/PS2Linux.tar.gz" ]; then
        echo | tee -a "${LOG_FILE}"
        echo "All required files are present. Skipping download" | tee -a "${LOG_FILE}"
    else
        echo | tee -a "${LOG_FILE}"
        echo "Downloading required files..." | tee -a "${LOG_FILE}"
        if axel -a https://archive.org/download/psbbn-definitive-patch-v3/PS2Linux.tar.gz -o "${ASSETS_DIR}"; then
            echo "[✓] Download completed successfully." | tee -a "${LOG_FILE}"
        else
            error_msg "[X] Error: Download failed." "Please check the status of archive.org. You may need to use a VPN depending on your location."
            return 1
        fi
    fi
}

CHECK_PARTITIONS() {
    TOC_OUTPUT=$(sudo "${HDL_DUMP}" toc "${DEVICE}")
    STATUS=$?

    if [ $STATUS -ne 0 ]; then
        error_msg "APA partition is broken on ${DEVICE}. Install failed."
    fi

    # List of required partitions
    required=(__linux.1 __linux.4 __linux.5 __linux.6 __linux.7 __linux.8 __linux.9 __contents __system __sysconf __.POPS __common)

    # Check all required partitions
    for part in "${required[@]}"; do
        if ! echo "$TOC_OUTPUT" | grep -Fq "$part"; then
            error_msg "[X] Error: This feature requires PSBBN." " " "Some partitions are missing on ${DEVICE}. See log for details."
            exit 1
        fi
    done
}

PFS_COMMANDS() {
PFS_COMMANDS=$(echo -e "$COMMANDS" | sudo "${PFS_SHELL}" >> "${LOG_FILE}" 2>&1)
if echo "$PFS_COMMANDS" | grep -q "Exit code is"; then
    error_msg "PFS Shell returned an error. See ${LOG_FILE}"
    return 1
fi
}

HDL_TOC() {
    rm -f "$hdl_output"
    hdl_output=$(mktemp)
    if ! sudo "${HDL_DUMP}" toc "$DEVICE" 2>>"${LOG_FILE}" > "$hdl_output"; then
        rm -f "$hdl_output"
        error_msg "[X] Error: Failed to extract list of partitions." "APA partition could be broken on ${DEVICE}"
        return 1
    fi
}

AVAILABLE_SPACE(){
    HDL_TOC || return 1
    # Extract the "used" value, remove "MB" and any commas
    used=$(cat "$hdl_output" | awk '/used:/ {print $6}' | sed 's/,//; s/MB//')

    # Calculate available space (APA_SIZE - used)
    available=$((APA_SIZE - used - 6400 - 128))
    free_space=$((available / 1024))
    echo "Free Space: $free_space GB" >> "${LOG_FILE}"
}


SWAP_SPLASH(){
    clear
    cat << "EOF"
            ______                   _              ______       _   _                  
            | ___ \                 (_)             | ___ \     | | | |                 
            | |_/ /___  __ _ ___ ___ _  __ _ _ __   | |_/ /_   _| |_| |_ ___  _ __  ___ 
            |    // _ \/ _` / __/ __| |/ _` | '_ \  | ___ \ | | | __| __/ _ \| '_ \/ __|
            | |\ \  __/ (_| \__ \__ \ | (_| | | | | | |_/ / |_| | |_| || (_) | | | \__ \
            \_| \_\___|\__,_|___/___/_|\__, |_| |_| \____/ \__,_|\__|\__\___/|_| |_|___/
                                        __/ |                                           
                                       |___/    


EOF
}

LINUX_SPLASH(){
    clear
    cat << "EOF"

                          ______  _____  _____   _     _                  
                          | ___ \/  ___|/ __  \ | |   (_)                 
                          | |_/ /\ `--. `' / /' | |    _ _ __  _   ___  __
                          |  __/  `--. \  / /   | |   | | '_ \| | | \ \/ /
                          | |    /\__/ /./ /___ | |___| | | | | |_| |>  < 
                          \_|    \____/ \_____/ \_____/_|_| |_|\__,_/_/\_\


EOF
}                         

# Function for Option 1 - Install PS2 Linux
option_one() {
    echo "########################################################################################################" >> "${LOG_FILE}"
    echo "Install PS2 Linux:" >> "${LOG_FILE}"
    LINUX_SPLASH


    detect_drive   && \
    MOUNT_OPL || return 1
    
    psbbn_version=$(head -n 1 "$OPL/version.txt" 2>/dev/null)
    APA_SIZE=$(awk -F' *= *' '$1=="APA_SIZE"{print $2}' "${OPL}/version.txt")
    
    UNMOUNT_OPL || return 1

    version_check="4.0.0"

    HDL_TOC || return 1

    if cat "${hdl_output}" | grep -q '\b__linux\.3\b'; then
        linux3="yes"
        if [ "$(printf '%s\n' "$psbbn_version" "$version_check" | sort -V | head -n1)" != "$version_check" ]; then
            error_msg "Linux is already installed." "If you want to reinstall Linux, update to PSBBN version 4.0.0 or higher first."
            return 0
        else
            while true; do
                LINUX_SPLASH
                echo "               Linux is already installed on your PS2. Do you want to reinstall it?" | tee -a "${LOG_FILE}"
                
                if cat "${hdl_output}" | grep -q '\b__linux\.10\b'; then
                    echo
                    echo "               - All Linux system files will be reinstalled." | tee -a "${LOG_FILE}"
                    echo "               - Your personal files in the home directory will not be affected." | tee -a "${LOG_FILE}"
                else
                    echo
                    echo "               ============================== WARNING ============================="
                    echo
                    echo "                All PS2 Linux data will be erased, including your home direcrtory." | tee -a "${LOG_FILE}"
                    echo "                Make sure to back up your files before continuing."
                    echo
                    echo "               ===================================================================="
                fi
                
                echo
                read -p "               Reinstall PS2 Linux? (y/n): " answer
                case "$answer" in
                    [Yy])
                        break
                        ;;
                    [Nn])
                        return 0
                        ;;
                    *)
                        echo
                        echo -n "               Please enter y or n."
                        sleep 3
                        ;;
                esac
            done
        fi
    fi

    LINUX_SPLASH

    if [ "$linux3" != "yes" ]; then
        if [ "$(printf '%s\n' "$psbbn_version" "$version_check" | sort -V | head -n1)" != "$version_check" ]; then
            error_msg "To install or reinstall PS2 Linux, update to PSBBN version 4.0.0 or higher."
            return 0
        else
            if [ -z "$APA_SIZE" ]; then
                error_msg "[X] Error: Unable to determine APA free space."
                return 1
            else
                AVAILABLE_SPACE || return 1
                if [ "$free_space" -lt 3 ]; then
                    error_msg "[X] Error: Insufficient disk space. At least 3 GB of free space is required to install Linux."
                    return 1
                else
                    free_space=$((free_space -2))
                fi
            fi
        fi
    fi

    download_linux || return 1

    if [ "$linux3" == "yes" ]; then
        HDL_TOC || return 1
        LINUX_SIZE=$(grep '__\linux.3' "$hdl_output" | awk '{print $4}' | grep -oE '[0-9]+')
        if [ "$LINUX_SIZE" -gt 2048 ]; then
            COMMANDS="device ${DEVICE}\n"
            COMMANDS+="rmpart __linux.3\n"
            COMMANDS+="exit"
            PFS_COMMANDS || return 1
            linux3="no"
        fi
    fi

    if ! cat "${hdl_output}" | grep -q '\b__linux\.10\b'; then
        echo "Free Space available for home partition: $free_space GB" >> "${LOG_FILE}"

        while true; do
            echo | tee -a "${LOG_FILE}"
            echo "APA Space Available: $free_space GB" >> "${LOG_FILE}"
            echo "What size would you like the \"home\" partition to be?"
            echo "Minimum 1 GB, maximum $free_space GB"
            echo
            read -p "Enter partition size (in GB): " home_gb

            if [[ ! "$home_gb" =~ ^[0-9]+$ ]]; then
                echo
                echo -n "Invalid input. Please enter a valid number."
                sleep 3
                continue
            fi

            if (( home_gb < 1 || home_gb > free_space )); then
                echo
                echo "Invalid size. Please enter a value between 1 and $free_space GB."
                sleep 3
                continue
            fi
            break
        done

        echo "Home partition size: $home_gb" >> "${LOG_FILE}"
        home_mb=$((home_gb * 1024))
    fi

    if [[ "$linux3" != "yes" || -n "$home_gb" ]]; then
        COMMANDS="device ${DEVICE}\n"

        if [ "$linux3" != "yes" ]; then
            COMMANDS+="mkpart __linux.3 2048M EXT2\n"
        fi

        if [ -n "$home_gb" ]; then
            COMMANDS+="mkpart __linux.10 ${home_mb}M EXT2\n"
        fi

        COMMANDS+="exit"
        echo "Creating partitions..." >>"${LOG_FILE}"
        PFS_COMMANDS || return 1
    fi

    echo | tee -a "${LOG_FILE}"
    echo -n "Installing PS2 Linux..." | tee -a "${LOG_FILE}"

    LINUX_PARTITIONS=("__linux.3" )
    APA_PARTITIONS=("__system" "__sysconf" )

    clean_up   && \
    mapper_probe || return 1

    if ! sudo mke2fs -t ext2 -b 4096 -I 128 -O ^large_file,^dir_index,^extent,^huge_file,^flex_bg,^has_journal,^ext_attr,^resize_inode "${MAPPER}__linux.3" >>"${LOG_FILE}" 2>&1; then
        error_msg "[X] Error: Failed to create filesystem __linux.3."
        return 1
    fi

    mount_cfs    && \
    mount_pfs    || return 1

    if ! sudo tar zxpf "${ASSETS_DIR}/PS2Linux.tar.gz" -C "${STORAGE_DIR}/__linux.3" >>"${LOG_FILE}" 2>&1; then
        error_msg "Failed to extract files. Install Failed."
        return 1
    fi

    cp -f "${ASSETS_DIR}/kernel/ps2-linux-"{ntsc,vga} "${STORAGE_DIR}/__system/p2lboot/" 2>> "${LOG_FILE}" || { error_msg "Failed to copy kernel files."; return 1; }

    TMP_FILE=$(mktemp /tmp/OSDMBR.XXXXXX)
    cp -f "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF" "$TMP_FILE" 2>> "${LOG_FILE}" || { error_msg "Failed to copy OSDMBR.CNF."; return 1; }

    # Remove any existing boot_circle lines
    sed -i '/^boot_circle/d' "$TMP_FILE" 2>> "${LOG_FILE}"

    # Append new PSBBN boot entries
    {
        echo 'boot_circle = $PSBBN'
        echo 'boot_circle_arg1 = --kernel'
        echo 'boot_circle_arg2 = pfs0:/p2lboot/ps2-linux-ntsc'
        echo 'boot_circle_arg3 = -noflags'
    } >> "$TMP_FILE"
    cp -f $TMP_FILE "${STORAGE_DIR}/__sysconf/osdmenu/OSDMBR.CNF" 2>> "${LOG_FILE}" || { error_msg "Failed to copy OSDMBR.CNF."; return 1; }

    clean_up || return 1

    LINUX_SPLASH
    echo "=============================== [✓] PS2 Linux Successfully Installed ==============================" | tee -a "${LOG_FILE}"
    cat << "EOF"

    To launch PS2 Linux, power on your PS2 console and hold the CIRCLE button on the controller.

    PS2 Linux requires a USB keyboard; a mouse is optional but recommended.

    Default "root" password: password
    Default password for "ps2" user account: password

    To launch a graphical interface type: startx

====================================================================================================

EOF
    read -n 1 -s -r -p "                               Press any key to return to the menu..." </dev/tty

}

# Function for Option 2 - Reassign X and O Buttons
option_two() {
    echo "########################################################################################################" >> "${LOG_FILE}"
    echo "Reassign Buttons:" >> "${LOG_FILE}"
    clear

    detect_drive    && \
    MOUNT_OPL   || return 1

    SWAP_SPLASH
    
    psbbn_version=$(head -n 1 "$OPL/version.txt" 2>/dev/null)
    
    UNMOUNT_OPL || return 1

    if [[ "$(printf '%s\n' "$psbbn_version" "2.10" | sort -V | head -n1)" != "2.10" ]]; then
        # $psbbn_version < 2.10
        error_msg "[X] Error: PSBBN Definitive Patch version is lower than 3.00." "To update, please select 'Install PSBBN' from the main menu and try again."
        exit 1
    elif [[ "$(printf '%s\n' "$psbbn_version" "3.00" | sort -V | head -n1)" = "$psbbn_version" ]] \
        && [[ "$psbbn_version" != "3.00" ]]; then
        error_msg "[X] Error: PSBBN Definitive Patch version is lower than 3.00." "To update, please select “Update PSBBN Software” from the main menu and try again."
        exit 1
    fi

    LINUX_PARTITIONS=("__linux.4" )
    APA_PARTITIONS=("__system" )

    clean_up   && \
    mapper_probe && \
    mount_cfs    && \
    mount_pfs    || return 1


    ls -l /dev/mapper >> "${LOG_FILE}"
    df >> "${LOG_FILE}"

    
    choice=""
    while :; do
        SWAP_SPLASH
        cat << "EOF"
                                  1) Cross = Enter, Circle = Back
                                  2) Circle = Enter, Cross = Back

                                  b) Back

EOF
        read -rp "                                  Select an option: " choice
        case "$choice" in
            1)
                echo "Western layout selected." >> "${LOG_FILE}"
                if sudo cp -f "${ASSETS_DIR}/kernel/vmlinux" "${STORAGE_DIR}/__system/p2lboot/vmlinux" >> "${LOG_FILE}" 2>&1 \
                    && sudo cp -f "${ASSETS_DIR}/kernel/x.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_r.tm2" >> "${LOG_FILE}" 2>&1 \
                    && sudo cp -f "${ASSETS_DIR}/kernel/o.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_d.tm2" >> "${LOG_FILE}" 2>&1
                then
                    SWAP_SPLASH
                    echo "================================= [✓] Buttons Swapped Successfully =================================" | tee -a "${LOG_FILE}"
                    echo
                    read -n 1 -s -r -p "                                Press any key to return to the menu..." </dev/tty
                else
                    SWAP_SPLASH
                    error_msg "[X] Error: Failed to swap buttons. See log for details."
                    return 1
                fi
                break
                ;;

                
            2)
                echo "Japanese layout selected." >> "${LOG_FILE}"
                if sudo cp -f "${ASSETS_DIR}/kernel/vmlinux_jpn" "${STORAGE_DIR}/__system/p2lboot/vmlinux" >> "${LOG_FILE}" 2>&1 \
                    && sudo cp -f "${ASSETS_DIR}/kernel/o.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_r.tm2" >> "${LOG_FILE}" 2>&1 \
                    && sudo cp -f "${ASSETS_DIR}/kernel/x.tm2" "${STORAGE_DIR}/__linux.4/bn/data/tex/btn_d.tm2" >> "${LOG_FILE}" 2>&1
                then
                    SWAP_SPLASH
                    echo "================================= [✓] Buttons Swapped Successfully =================================" | tee -a "${LOG_FILE}"
                    echo
                    read -n 1 -s -r -p "                                Press any key to return to the menu..." </dev/tty
                else
                    SWAP_SPLASH
                    error_msg "[X] Error: Failed to swap buttons. See log for details."
                    return 1
                fi
                break
                ;;
            b|B)
                break
                ;;
            *)
                echo -n "                                  Invalid choice, please enter 1, 2, or b."
                sleep 3
            ;;
        esac
    done

    clean_up || return 1
    echo clean up afterwards: >> "${LOG_FILE}"
    ls -l /dev/mapper >> "${LOG_FILE}"
    df >> "${LOG_FILE}"
}

EXTRAS_SPLASH() {
clear
    cat << "EOF"
                                     _____     _                 
                                    |  ___|   | |                
                                    | |____  _| |_ _ __ __ _ ___ 
                                    |  __\ \/ / __| '__/ _` / __|
                                    | |___>  <| |_| | | (_| \__ \
                                    \____/_/\_\\__|_|  \__,_|___/


EOF
}

# Function to display the menu
display_menu() {
    EXTRAS_SPLASH
    cat << "EOF"
                                1) Install PS2 Linux
                                2) Reassign Cross and Circle Buttons

                                b) Back to Main Menu

EOF
}

clear
trap 'echo; exit 130' INT
trap exit_script EXIT

cd "${TOOLKIT_PATH}"

echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    sudo rm -f "${LOG_FILE}"
    echo "########################################################################################################" | tee -a "${LOG_FILE}" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo
        echo "[X] Error: Cannot to create log file."
        read -n 1 -s -r -p "Press any key to exit..." </dev/tty
        echo
        exit 1
    fi
fi

date >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
cat /etc/*-release >> "${LOG_FILE}" 2>&1

EXTRAS_SPLASH
detect_drive || exit 1
CHECK_PARTITIONS

if ! sudo rm -rf "${STORAGE_DIR}"; then
    error_msg "Failed to remove $STORAGE_DIR folder."
fi

# Main loop

while true; do
    display_menu
    read -p "                                Select an option: " choice

    case $choice in
        1)
            option_one
            ;;
        2)
            option_two
            ;;
        b|B)
            break
            ;;
        *)
            echo
            echo -n "                                Invalid option, please try again."
            sleep 2
            ;;
    esac
done
