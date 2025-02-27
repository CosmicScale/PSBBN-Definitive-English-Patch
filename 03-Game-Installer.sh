#!/bin/bash
# Set terminal size: 100 columns and 40 rows
echo -e "\e[8;40;100t"

# Set paths
TOOLKIT_PATH="$(pwd)"
ICONS_DIR="${TOOLKIT_PATH}/icons"
ARTWORK_DIR="${ICONS_DIR}/art"
HELPER_DIR="${TOOLKIT_PATH}/helper"
ASSETS_DIR="${TOOLKIT_PATH}/assets"
POPSTARTER="${ASSETS_DIR}/POPSTARTER.ELF"
NEUTRINO_DIR="${ASSETS_DIR}/neutrino"
LOG_FILE="${TOOLKIT_PATH}/game-installer.log"
MISSING_ART=${TOOLKIT_PATH}/missing-art.log


# Modify this path if your games are stored in a different location:
GAMES_PATH="${TOOLKIT_PATH}/games"

POPS_FOLDER="${GAMES_PATH}/POPS"
PS1_LIST="${TOOLKIT_PATH}/ps1.list"
PS2_LIST="${TOOLKIT_PATH}/ps2.list"
ALL_GAMES="${TOOLKIT_PATH}/master.list"

clear

cd "${TOOLKIT_PATH}"

# Check if the helper files exists
if [[ ! -f "${HELPER_DIR}/PFS Shell.elf" || ! -f "${HELPER_DIR}/HDL Dump.elf" ]]; then
    echo "Required helper files not found. Please ensure you are in the 'PSBBN-Definitive-English-Patch'"
    echo "directory and try again."
    exit 1
fi

echo "########################################################################################################">> "${LOG_FILE}";
date >> "${LOG_FILE}"
echo >> "${LOG_FILE}"
echo "Path set to: $TOOLKIT_PATH" >> "${LOG_FILE}"
echo "Helper files found." >> "${LOG_FILE}"

# Check if the Python virtual environment exists
if [ -f "./venv/bin/activate" ]; then
    echo "The Python virtual environment exists." >> "${LOG_FILE}"
else
    echo "Error: The Python virtual environment does not exist. Run 01-Setup.sh and try again." | tee -a "${LOG_FILE}"
    read -n 1 -s -r -p "Press any key to exit..."
    echo
    exit 1
fi

# Check if the current directory is a Git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "This is not a Git repository. Skipping update check." | tee -a "${LOG_FILE}"
else
  # Fetch updates from the remote
  git fetch >> "${LOG_FILE}" 2>&1

  # Check the current status of the repository
  LOCAL=$(git rev-parse @)
  REMOTE=$(git rev-parse @{u})
  BASE=$(git merge-base @ @{u})

  if [ "$LOCAL" = "$REMOTE" ]; then
    echo "The repository is up to date." | tee -a "${LOG_FILE}"
  else
    echo "Downloading updates..."
    # Get a list of files that have changed remotely
    UPDATED_FILES=$(git diff --name-only "$LOCAL" "$REMOTE")

    if [ -n "$UPDATED_FILES" ]; then
      echo "Files updated in the remote repository:" | tee -a "${LOG_FILE}"
      echo "$UPDATED_FILES" | tee -a "${LOG_FILE}"

      # Reset only the files that were updated remotely (discard local changes to them)
      echo "$UPDATED_FILES" | xargs git checkout -- >> "${LOG_FILE}" 2>&1

      # Pull the latest changes
      git pull --ff-only >> "${LOG_FILE}" 2>&1

      echo "The script has been updated to the latest version." | tee -a "${LOG_FILE}"
      read -n 1 -s -r -p "Press any key to exit, set your custom game path if needed, and then run the script again."
      echo
      exit 0
    else
      echo "The repository is up to date." | tee -a "${LOG_FILE}"
    fi
  fi
fi

function clean_up() {
# Loop through all items in the target directory
for item in "$ICONS_DIR"/*; do
    # Check if the item is a directory and not the 'art' folder
    if [ -d "$item" ] && [ "$(basename "$item")" != "art" ]; then
        rm -rf "$item" >> "${LOG_FILE}" 2>&1
    fi
done

rm "${TOOLKIT_PATH}/package.json" >> "${LOG_FILE}" 2>&1
rm "${TOOLKIT_PATH}/package-lock.json" >> "${LOG_FILE}" 2>&1
rm "${PS1_LIST}" >> "${LOG_FILE}" 2>&1
rm "${PS2_LIST}" >> "${LOG_FILE}" 2>&1
rm "${ALL_GAMES}" >> "${LOG_FILE}" 2>&1
rm "${ARTWORK_DIR}/tmp"/* >> "${LOG_FILE}" 2>&1
}

clean_up
rm $MISSING_ART 2>>"${LOG_FILE}"

echo "                  _____                        _____          _        _ _           ";
echo "                 |  __ \                      |_   _|        | |      | | |          ";
echo "                 | |  \/ __ _ _ __ ___   ___    | | _ __  ___| |_ __ _| | | ___ ___ ";
echo "                 | | __ / _\` | '_ \` _ \ / _ \   | || '_ \/ __| __/ _\` | | |/ _ \ __|";
echo "                 | |_\ \ (_| | | | | | |  __/  _| || | | \__ \ || (_| | | |  __/ |    ";
echo "                  \____/\__,_|_| |_| |_|\___|  \___/_| |_|___/\__\__,_|_|_|\___|_|    ";
echo "                                                                      ";
echo "                                         Written by CosmicScale"
echo
echo "   ##############################################################################################"
echo "   #  This tool synchronizes the games on your PC with those on your PS2's HDD/SSD.             #"
echo "   #                                                                                            #"
echo "   #  Ensure the PS2 drive is connected to your PC before proceeding.                           #"
echo "   #                                                                                            #"
echo "   #  How Syncing Works:                                                                        #"
echo "   #                                                                                            #"
echo "   #  Copying: Games in your PC's 'games' folder that are missing from your PS2 will be added   #"
echo "   #                                                                                            #"
echo "   #  Removal: Games on your PS2 that are not in your PC's 'games' folder will be removed.      #"
echo "   #                                                                                            #"
echo "   ##############################################################################################"
echo
read -n 1 -s -r -p "   Press any key to continue..."
echo

# Choose the PS2 storage device
while true; do
clear
echo
echo "                  _____                        _____          _        _ _           ";
echo "                 |  __ \                      |_   _|        | |      | | |          ";
echo "                 | |  \/ __ _ _ __ ___   ___    | | _ __  ___| |_ __ _| | | ___ ___ ";
echo "                 | | __ / _\` | '_ \` _ \ / _ \   | || '_ \/ __| __/ _\` | | |/ _ \ __|";
echo "                 | |_\ \ (_| | | | | | |  __/  _| || | | \__ \ || (_| | | |  __/ |    ";
echo "                  \____/\__,_|_| |_| |_|\___|  \___/_| |_|___/\__\__,_|_|_|\___|_|    ";
echo "                                                                      ";
echo "                                         Written by CosmicScale"
    echo | tee -a "${LOG_FILE}"
    lsblk -p -o MODEL,NAME,SIZE,LABEL,MOUNTPOINT | tee -a "${LOG_FILE}"
    echo | tee -a "${LOG_FILE}"
        
    read -p "Choose your PS2 HDD from the list above (e.g., /dev/sdx): " DEVICE
        
    # Validate input format (must start with /dev/)
    if [[ $DEVICE == /dev/* ]]; then
        # Check if the device exists
        if lsblk -p | grep -q "^${DEVICE}"; then
            echo
            echo -e "Selected drive: \"${DEVICE}\"" | tee -a "${LOG_FILE}"
            break
        else
            echo
            echo "Error: Device ${DEVICE} not found. Please choose a valid disk from the list."
        fi
    else
        echo
        echo "Error: Invalid input. Please enter a valid device name (e.g., /dev/sdx)."
    fi
    
    read -n 1 -s -r -p "Press any key to try again..."
    echo
done

# Find all mounted volumes associated with the device
mounted_volumes=$(lsblk -ln -o MOUNTPOINT "$DEVICE" | grep -v "^$")

# Iterate through each mounted volume and unmount it
echo | tee -a "${LOG_FILE}"
echo "Unmounting volumes associated with $DEVICE..."
for mount_point in $mounted_volumes; do
    echo "Unmounting $mount_point..." | tee -a "${LOG_FILE}"
    if sudo umount "$mount_point"; then
        echo "Successfully unmounted $mount_point." | tee -a "${LOG_FILE}"
    else
        echo "Failed to unmount $mount_point. Please unmount manually." | tee -a "${LOG_FILE}"
        read -n 1 -s -r -p "Press any key to exit..."
        echo
        exit 1
    fi
done

echo "All volumes unmounted for $DEVICE."| tee -a "${LOG_FILE}"

# Validate the GAMES_PATH
if [[ ! -d "$GAMES_PATH" ]]; then
    echo
    echo "Error: GAMES_PATH is not a valid directory: $GAMES_PATH" | tee -a "${LOG_FILE}"
    read -n 1 -s -r -p "Press any key to exit..."
    echo
    exit 1
fi

echo | tee -a "${LOG_FILE}"
echo "GAMES_PATH is valid: $GAMES_PATH" | tee -a "${LOG_FILE}"

# Create necessary folders if they don't exist
for folder in APPS ART CFG CHT LNG THM VMC POPS CD DVD; do
    dir="${GAMES_PATH}/${folder}"
    [[ -d "$dir" ]] || sudo mkdir -p "$dir" || { 
        echo "Error: Failed to create $dir. Make sure you have write permissions to $GAMES_PATH" | tee -a "${LOG_FILE}"
        read -n 1 -s -r -p "Press any key to continue..."
        echo
        exit 1
    }
done

echo | tee -a "${LOG_FILE}"
echo "Please choose a game launcher:"
echo "1) Open PS2 Loader (OPL)"
echo "2) Neutrino"
echo

while true; do
    read -p "Enter 1 or 2: " choice
    case "$choice" in
        1) LAUNCHER="OPL"; DESC="Open PS2 Loader (OPL)";;
        2) LAUNCHER="NEUTRINO"; DESC="Neutrino";;
        *) echo; echo "Invalid choice. Please enter 1 or 2."; continue ;;
    esac

    echo
    read -p "You selected $DESC. Are you sure? (y/n): " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] && break  # Exit loop if "y"
done

echo "$DESC selected." >> "${LOG_FILE}"
echo  >> "${LOG_FILE}"

# Delete old game partitions
delete_partition=$(sudo "${HELPER_DIR}/HDL Dump.elf" toc "$DEVICE" | grep -o 'PP\.[^ ]\+' | grep -Ev '^(PP\.WLE|PP\.LAUNCHER|PP\.DISC)$')
COMMANDS="device ${DEVICE}\n"

while IFS= read -r partition; do
    COMMANDS+="rmpart ${partition}\n"
done <<< "$delete_partition"

COMMANDS+="exit"

echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" >> "${LOG_FILE}" 2>&1
echo | tee -a "${LOG_FILE}"
echo "Checking installed apps:" | tee -a "${LOG_FILE}"

# Check if PP.DISC exists and create it if not
if ! sudo "${HELPER_DIR}/HDL Dump.elf" toc "${DEVICE}" | grep -q 'PP.DISC'; then
    echo >> "${LOG_FILE}"
    echo "Creating PP.DISC partition..." | tee -a "${LOG_FILE}"
    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="rmpart PP.WLE\n"
    COMMANDS+="rmpart PP.LAUNCHER\n"
    COMMANDS+="mkpart PP.DISC 128M PFS\n"
    COMMANDS+="mount PP.DISC\n"
    COMMANDS+="mkdir res\n"
    COMMANDS+="cd res\n"
    COMMANDS+="lcd '${ASSETS_DIR}/DISC'\n"
    COMMANDS+="put info.sys\n"
    COMMANDS+="put jkt_001.png\n"
    COMMANDS+="cd /\n"
    COMMANDS+="umount\n"
    COMMANDS+="exit"
    echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" >> "${LOG_FILE}" 2>&1
    cd "${ASSETS_DIR}/DISC"
    sudo "${HELPER_DIR}/HDL Dump.elf" modify_header "${DEVICE}" PP.DISC >> "${LOG_FILE}" 2>&1
fi

echo >> "${LOG_FILE}"
echo "Updating Disc Launcher..." | tee -a "${LOG_FILE}"
COMMANDS="device ${DEVICE}\n"
COMMANDS+="mount PP.DISC\n"
COMMANDS+="lcd '${ASSETS_DIR}/DISC'\n"
COMMANDS+="rm disc-launcher.KELF\n"
COMMANDS+="put disc-launcher.KELF\n"
COMMANDS+="rm PS1VModeNeg.elf\n"
COMMANDS+="put PS1VModeNeg.elf\n"
COMMANDS+="umount\n"
COMMANDS+="exit"

echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" >> "${LOG_FILE}" 2>&1

# Check if PP.WLE exists and create it if not
if ! sudo "${HELPER_DIR}/HDL Dump.elf" toc "${DEVICE}" | grep -q 'PP.WLE'; then
    echo >> "${LOG_FILE}"
    echo "Creating PP.WLE partition..." | tee -a "${LOG_FILE}"
    COMMANDS="device ${DEVICE}\n"
    COMMANDS+="rmpart PP.LAUNCHER\n"
    COMMANDS+="mkpart PP.WLE 128M PFS\n"
    COMMANDS+="mount PP.WLE\n"
    COMMANDS+="mkdir res\n"
    COMMANDS+="cd res\n"
    COMMANDS+="lcd '${ASSETS_DIR}/WLE'\n"
    COMMANDS+="put info.sys\n"
    COMMANDS+="put jkt_001.png\n"
    COMMANDS+="cd /\n"
    COMMANDS+="umount\n"
    COMMANDS+="exit"
    echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" >> "${LOG_FILE}" 2>&1
    cd "${ASSETS_DIR}/WLE"
    sudo "${HELPER_DIR}/HDL Dump.elf" modify_header "${DEVICE}" PP.WLE >> "${LOG_FILE}" 2>&1
fi

echo >> "${LOG_FILE}"
echo "Updating WLaunchELF..." | tee -a "${LOG_FILE}"
COMMANDS="device ${DEVICE}\n"
COMMANDS+="mount PP.WLE\n"
COMMANDS+="lcd '${ASSETS_DIR}/WLE'\n"
COMMANDS+="rm WLE.KELF\n"
COMMANDS+="put WLE.KELF\n"
COMMANDS+="umount\n"
COMMANDS+="exit"

echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" >> "${LOG_FILE}" 2>&1

# Check if PP.LAUNCHER exists and create it if not
if ! sudo "${HELPER_DIR}/HDL Dump.elf" toc "${DEVICE}" | grep -q 'PP.LAUNCHER'; then
   echo >> "${LOG_FILE}"
   echo "Creating PP.LAUNCHER partition..." | tee -a "${LOG_FILE}"
   COMMANDS="device ${DEVICE}\n"
   COMMANDS+="mkpart PP.LAUNCHER 128M PFS\n"
   COMMANDS+="mount PP.LAUNCHER\n"
   COMMANDS+="mkdir res\n"
   COMMANDS+="umount\n"
   COMMANDS+="exit"
   echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" >> "${LOG_FILE}" 2>&1
   cd "${ASSETS_DIR}/LAUNCHER"
   sudo "${HELPER_DIR}/HDL Dump.elf" modify_header "${DEVICE}" PP.LAUNCHER >> "${LOG_FILE}" 2>&1
fi

echo >> "${LOG_FILE}"
echo "Updating OPL/Neutrino..." | tee -a "${LOG_FILE}"
COMMANDS="device ${DEVICE}\n"
COMMANDS+="mount PP.LAUNCHER\n"
COMMANDS+="lcd '${ASSETS_DIR}'\n"
COMMANDS+="rm launcher.KELF\n"
COMMANDS+="put launcher.KELF\n"
COMMANDS+="cd res\n"

if [ "$LAUNCHER" = "OPL" ]; then
    COMMANDS+="lcd OPL\n"
    COMMANDS+="rm info.sys\n"
    COMMANDS+="rm jkt_001.png\n"
    COMMANDS+="put info.sys\n"
    COMMANDS+="put jkt_001.png\n"
    COMMANDS+="cd /\n"
    COMMANDS+="rm nhddl.elf.lch\n"
    COMMANDS+="put OPNPS2LD.ELF.lch\n"
elif [ "$LAUNCHER" = "NEUTRINO" ]; then
    COMMANDS+="lcd NHDDL\n"
    COMMANDS+="put info.sys\n"
    COMMANDS+="put jkt_001.png\n"
    COMMANDS+="cd /\n"
    COMMANDS+="rm OPNPS2LD.ELF.lch\n"
    COMMANDS+="put nhddl.elf.lch\n"
fi

COMMANDS+="umount\n"

# Generate the Neutrino file list
neutrino_config=$( { ls -1 "$NEUTRINO_DIR/config" | sort; } 2>> "${LOG_FILE}" )
neutrino_modules=$( { ls -1 "$NEUTRINO_DIR/modules" | sort; } 2>> "${LOG_FILE}" )

COMMANDS+="rmpart +OPL\n"
COMMANDS+="mkpart +OPL 128M PFS\n"
COMMANDS+="mount +OPL\n"
COMMANDS+="cd /\n"
COMMANDS+="lcd '${ASSETS_DIR}'\n"
COMMANDS+="put OPNPS2LD.ELF\n"
COMMANDS+="put nhddl.elf\n"
COMMANDS+="mkdir neutrino\n"
COMMANDS+="cd neutrino\n"
COMMANDS+="lcd '${NEUTRINO_DIR}'\n"
COMMANDS+="put neutrino.elf\n"
COMMANDS+="put version.txt\n"
COMMANDS+="mkdir config\n"
COMMANDS+="mkdir modules\n"
COMMANDS+="cd config\n"
COMMANDS+="lcd '${NEUTRINO_DIR}/config'\n"

# Add put commands for neutrino_config
if [ -n "$neutrino_config" ]; then
    while IFS= read -r file; do
        COMMANDS+="put \"$file\"\n"
    done <<< "$neutrino_config"
fi

COMMANDS+="cd ..\n"
COMMANDS+="cd modules\n"
COMMANDS+="lcd '${NEUTRINO_DIR}/modules'\n"

# Add put commands for neutrino_modules
if [ -n "$neutrino_modules" ]; then
    while IFS= read -r file; do
        COMMANDS+="put \"$file\"\n"
    done <<< "$neutrino_modules"
fi

COMMANDS+="cd /\n"
COMMANDS+="umount\n"
COMMANDS+="exit"

echo >> "${LOG_FILE}"
echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" >> "${LOG_FILE}" 2>&1

# Activate the virtual environment
sleep 5
source ./venv/bin/activate 2>>"${LOG_FILE}"

# Check if activation was successful
if [ $? -ne 0 ]; then
    echo "Failed to activate the Python virtual environment." | tee -a "${LOG_FILE}"
    read -n 1 -s -r -p "Press any key to exit..."
    echo
    exit 1
fi

if [ "$LAUNCHER" = "NEUTRINO" ]; then
    if find "$GAMES_PATH/CD" "$GAMES_PATH/DVD" -type f \( -iname "*.zso" \) | grep -q .; then
        echo | tee -a "${LOG_FILE}"
        echo "Games in the compressed ZSO format have been found in the CD/DVD folder." | tee -a "${LOG_FILE}"
        echo "Neutrino does not support compressed ZSO files."
        echo
        echo "ZSO files will be converted to ISO files before proceeding."
        read -n 1 -s -r -p "Press any key to continue..."
        echo
        echo

        while IFS= read -r -d '' zso_file; do
            iso_file="${zso_file%.*}.iso"
            echo "Converting: $zso_file -> $iso_file"

            python3 "${HELPER_DIR}/ziso.py" -c 0 "$zso_file" "$iso_file"
            if [ "${PIPESTATUS[0]}" -ne 0 ]; then
                rm -f "$iso_file"
                echo "Error: Failed to uncompress $zso_file" | tee -a "${LOG_FILE}"
                read -n 1 -s -r -p "Press any key to exit..."
                echo
                exit 1  # Properly exits the main script
            fi

            rm -f "$zso_file"
        done < <(find "$GAMES_PATH/CD" "$GAMES_PATH/DVD" -type f -iname "*.zso" -print0)
    fi
fi

# Create games list of PS1 and PS2 games to be installed
echo | tee -a "${LOG_FILE}"

echo "Creating PS1 games list..." | tee -a "${LOG_FILE}"
python3 -u "${HELPER_DIR}/list-builder-ps1.py" "${GAMES_PATH}" "${PS1_LIST}" | tee -a "${LOG_FILE}"
if [ "${PIPESTATUS[0]}" -ne 0 ]; then
    echo "Error: Failed to create PS1 games list." | tee -a "${LOG_FILE}"
    read -n 1 -s -r -p "Press any key to exit..."
    echo
    exit 1
fi

echo | tee -a "${LOG_FILE}"
echo "Creating PS2 games list..." | tee -a "${LOG_FILE}"
python3 -u "${HELPER_DIR}/list-builder-ps2.py" "${GAMES_PATH}" "${PS2_LIST}" | tee -a "${LOG_FILE}"
if [ "${PIPESTATUS[0]}" -ne 0 ]; then
    echo "Error: Failed to create PS2 games list." | tee -a "${LOG_FILE}"
    read -n 1 -s -r -p "Press any key to exit..."
    echo
    exit 1
fi

# Deactivate the virtual environment
deactivate

# Create master list combining PS1 and PS2 games to a single list
if [[ ! -f "${PS1_LIST}" && ! -f "${PS2_LIST}" ]]; then
    echo
    read -n 1 -s -r -p "No games found to install. Press any key to exit..."
    echo
    exit 1
elif [[ ! -f "${PS1_LIST}" ]]; then
    { cat "${PS2_LIST}" > "${ALL_GAMES}"; } 2>> "${LOG_FILE}"
else
    { cat "${PS1_LIST}" > "${ALL_GAMES}"; } 2>> "${LOG_FILE}"
    { cat "${PS2_LIST}" >> "${ALL_GAMES}"; } 2>> "${LOG_FILE}"
fi

# Check for master.list
if [[ ! -s "${ALL_GAMES}" ]]; then
    echo "Failed to create games list (file is missing or empty)." | tee -a "${LOG_FILE}"
    read -n 1 -s -r -p "Press any key to exit..."
    echo
    exit 1
fi

echo "Games list successfully created."| tee -a "${LOG_FILE}"
    
# Function to find available space
function function_space() {

output=$(sudo "${HELPER_DIR}/HDL Dump.elf" toc ${DEVICE} 2>&1)

# Check for the word "aborting" in the output
if echo "$output" | grep -q "aborting"; then
    echo
    echo "${DEVICE}: APA partition is broken; aborting." | tee -a "${LOG_FILE}"
    read -n 1 -s -r -p "Press any key to exit..."
    echo
    exit 1
fi

# Extract the "used" value, remove "MB" and any commas
used=$(echo "$output" | awk '/used:/ {print $6}' | sed 's/,//; s/MB//')
capacity=124416

# Calculate available space (capacity - used)
available=$((capacity - used))
}

# Count the number of games to be installed
count=$(grep -c '^[^[:space:]]' "${ALL_GAMES}")
echo
echo "Number of games to install: $count" | tee -a "${LOG_FILE}"

function_space

partition_count=$((available / 128))

if [ "$count" -gt "$partition_count" ]; then

    echo "Not enough space for $count partitions." | tee -a "${LOG_FILE}"
    echo "The first $partition_count games will appear in the PSBBN Game Channel" | tee -a "${LOG_FILE}"
    echo "Remaining PS2 games will appear in OPL/NHDDL only"

    # Overwrite master.list with the first $partition_count lines
    head -n "$partition_count" "$ALL_GAMES" > "${ALL_GAMES}.tmp"
    mv "${ALL_GAMES}.tmp" "$ALL_GAMES"
fi

echo
echo "master.list:" >> "${LOG_FILE}"
cat "$ALL_GAMES" >> "${LOG_FILE}"

echo | tee -a "${LOG_FILE}"
read -n 1 -s -r -p "Ready to install games. Press any key to continue..."
echo
echo
echo "Preparing to sync PS1 games..." | tee -a "${LOG_FILE}"

# Step 1: Create matching .ELF files for .VCD files
echo "Creating matching .ELF files for .VCDs..." | tee -a "${LOG_FILE}"
for vcd_file in "$POPS_FOLDER"/*.VCD; do
    if [ -f "$vcd_file" ]; then
        # Extract the base name (without extension) from the .VCD file
        base_name=$(basename "$vcd_file" .VCD)
        # Define the corresponding .ELF file name
        elf_file="$POPS_FOLDER/$base_name.ELF"
        # Copy and rename POPSTARTER.ELF to match the .VCD file
        if [ ! -f "$elf_file" ]; then
            echo "Creating $elf_file..." | tee -a "${LOG_FILE}"
            sudo cp "$POPSTARTER" "$elf_file" 2>>"${LOG_FILE}" || {
                echo
                echo "Error: Failed to create $elf_file." | tee -a "${LOG_FILE}"
                echo "Chech that $POPSTARTER exists and you have write permissions to $GAMES_PATH" | tee -a "${LOG_FILE}"
                echo
                read -n 1 -s -r -p "Press any key to exit..."
                echo
                exit 1
            }
        fi
    fi
done
echo "Matching .ELF files created successfully." | tee -a "${LOG_FILE}"

# Step 2: Delete .ELF files without matching .VCD files
echo "Removing orphan .ELF files..." | tee -a "${LOG_FILE}"
for elf_file in "$POPS_FOLDER"/*.ELF; do
    if [ -f "$elf_file" ]; then
        # Extract the base name (without extension) from the .ELF file
        base_name=$(basename "$elf_file" .ELF)
        # Check if a corresponding .VCD file exists
        vcd_file="$POPS_FOLDER/$base_name.VCD"
        if [ ! -f "$vcd_file" ]; then
            echo "Deleting orphan $elf_file..." | tee -a "${LOG_FILE}"
            sudo rm "$elf_file" 2>>"${LOG_FILE}" || {
                echo
                echo "Error: Failed to delete $elf_file." | tee -a "${LOG_FILE}"
                echo "Chech that you have write permissions to $GAMES_PATH" | tee -a "${LOG_FILE}"
                echo
                read -n 1 -s -r -p "Press any key to exit..."
                echo
                exit 1
            }
        fi
    fi
done
echo "Orphan .ELF files removed successfully." | tee -a "${LOG_FILE}"

# Generate the local file list directly in a variable
local_files=$( { ls -1 "$POPS_FOLDER" | grep -Ei '\.VCD$|\.ELF$' | sort; } 2>> "${LOG_FILE}" )

# Build the commands for PFS Shell
COMMANDS="device ${DEVICE}\n"
COMMANDS+="mount __.POPS\n"
COMMANDS+="ls\n"
COMMANDS+="umount\n"
COMMANDS+="exit"

# Get the PS1 file list directly from PFS Shell output, filtered and sorted
ps1_files=$(echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" 2>/dev/null | grep -iE "\.vcd$|\.elf$" | sort)

# Compute differences and store them in variables
files_only_in_local=$(comm -23 <(echo "$local_files") <(echo "$ps1_files"))
files_only_in_ps2=$(comm -13 <(echo "$local_files") <(echo "$ps1_files"))

# Only display "Files to delete:" if there are files to delete
if [ -n "$files_only_in_ps2" ]; then
    echo "Files to delete:" | tee -a "${LOG_FILE}"
    echo "$files_only_in_ps2" | tee -a "${LOG_FILE}"
else
    echo "No files to delete." | tee -a "${LOG_FILE}"
fi

# Only display "Files to copy:" if there are files to copy
if [ -n "$files_only_in_local" ]; then
    echo "Files to copy:" | tee -a "${LOG_FILE}"
    echo "$files_only_in_local" | tee -a "${LOG_FILE}"
else
    echo "No files to copy." | tee -a "${LOG_FILE}"
fi

# Syncing PS1 games
if [ -n "$files_only_in_ps2" ] || [ -n "$files_only_in_local" ]; then
    cd "$POPS_FOLDER" >> "${LOG_FILE}" 2>&1
    combined_commands="device ${DEVICE}\n"
    combined_commands+="mount __.POPS\n"

    # Add delete commands for files_only_in_ps2
    if [ -n "$files_only_in_ps2" ]; then
        while IFS= read -r file; do
            combined_commands+="rm \"$file\"\n"
        done <<< "$files_only_in_ps2"
    fi

    # Add put commands for files_only_in_local
    if [ -n "$files_only_in_local" ]; then
        while IFS= read -r file; do
            combined_commands+="put \"$file\"\n"
        done <<< "$files_only_in_local"
    fi

    combined_commands+="umount\n"
    combined_commands+="exit"

    # Execute the combined commands with PFS Shell
    echo "Syncing PS1 games to HDD..." | tee -a "${LOG_FILE}"
    echo -e "$combined_commands" | sudo "${HELPER_DIR}/PFS Shell.elf" >> "${LOG_FILE}" 2>&1
    echo | tee -a "${LOG_FILE}"
    echo "PS1 games synced successfully." | tee -a "${LOG_FILE}"
    echo | tee -a "${LOG_FILE}"
else
    echo
    echo "PS1 games are already synced." | tee -a "${LOG_FILE}"
    echo | tee -a "${LOG_FILE}"
fi

# Check contents of __.POPS after sync
COMMANDS="device ${DEVICE}\n"
COMMANDS+="mount __.POPS\n"
COMMANDS+="ls\n"
COMMANDS+="umount\n"
COMMANDS+="exit"

echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" >> "${LOG_FILE}" 2>&1
echo >> "${LOG_FILE}"

# Syncing PS2 games
echo "Mounting OPL partition" | tee -a "${LOG_FILE}"
mkdir "${TOOLKIT_PATH}"/OPL 2>> "${LOG_FILE}"

sudo mount ${DEVICE}3 "${TOOLKIT_PATH}"/OPL

# Handle possibility host system's `mount` is using Fuse
if [ $? -ne 0 ] && hash mount.exfat-fuse; then
    sudo mount.exfat-fuse ${DEVICE}3 "${TOOLKIT_PATH}"/OPL
fi

if [ $? -ne 0 ]; then
    echo
    echo
    echo "Error: Failed to mount ${DEVICE}3 - did you run 01-Setup.sh?"
    read -n 1 -s -r -p "Press any key to exit..."
    echo
    exit 1;
fi

echo | tee -a "${LOG_FILE}"
echo "Syncing PS2 games..." | tee -a "${LOG_FILE}"
sudo rsync -r --progress --ignore-existing --delete --exclude=".*" "${GAMES_PATH}/CD/" "${TOOLKIT_PATH}/OPL/CD/" 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"
if [ $? -ne 0 ]; then
    echo
    echo
    echo "Error: Failed to sync PS2 games. See ${LOG_FILE} for details." | tee -a "${LOG_FILE}"
    read -n 1 -s -r -p "Press any key to exit..."
    echo
    exit 1
fi

sudo rsync -r --progress --ignore-existing --delete --exclude=".*" "${GAMES_PATH}/DVD/" "${TOOLKIT_PATH}/OPL/DVD/" 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"
if [ $? -ne 0 ]; then
    echo
    echo
    echo "Error: Failed to sync PS2 games. See ${LOG_FILE} for details." | tee -a "${LOG_FILE}"
    read -n 1 -s -r -p "Press any key to exit..."
    echo
    exit 1
fi
sudo cp --update=none "${GAMES_PATH}/APPS/"* "${TOOLKIT_PATH}"/OPL/APPS >> "${LOG_FILE}" 2>&1
sudo cp --update=none "${GAMES_PATH}/ART/"* "${TOOLKIT_PATH}"/OPL/ART >> "${LOG_FILE}" 2>&1
sudo cp --update=none "${GAMES_PATH}/CFG/"* "${TOOLKIT_PATH}"/OPL/CFG >> "${LOG_FILE}" 2>&1
sudo cp --update=none "${GAMES_PATH}/CHT/"* "${TOOLKIT_PATH}"/OPL/CHT >> "${LOG_FILE}" 2>&1
sudo cp --update=none "${GAMES_PATH}/LNG/"* "${TOOLKIT_PATH}"/OPL/LNG >> "${LOG_FILE}" 2>&1
sudo cp --update=none "${GAMES_PATH}/THM/"* "${TOOLKIT_PATH}"/OPL/THM >> "${LOG_FILE}" 2>&1
sudo cp --update=none "${GAMES_PATH}/VMC/"* "${TOOLKIT_PATH}"/OPL/VMC >> "${LOG_FILE}" 2>&1
echo | tee -a "${LOG_FILE}"
echo "PS2 Games on PS2 drive:" >> "${LOG_FILE}"
ls -1 "${TOOLKIT_PATH}/OPL/CD/" >> "${LOG_FILE}" 2>&1
ls -1 "${TOOLKIT_PATH}/OPL/DVD/" >> "${LOG_FILE}" 2>&1
echo "PS2 games successfully synced" | tee -a "${LOG_FILE}"
echo | tee -a "${LOG_FILE}"
echo "Unmounting OPL partition..." | tee -a "${LOG_FILE}"
sleep 5
sudo umount "${TOOLKIT_PATH}"/OPL

mkdir -p "${ARTWORK_DIR}/tmp" 2>> "${LOG_FILE}"

echo | tee -a "${LOG_FILE}"
echo "Downloading artwork..."  | tee -a "${LOG_FILE}"

cd "${TOOLKIT_PATH}"

# First loop: Run the art downloader script for each game_id if artwork doesn't already exist
while IFS='|' read -r game_title game_id publisher disc_type file_name; do
  # Check if the artwork file already exists
  png_file="${ARTWORK_DIR}/${game_id}.png"
  if [[ -f "$png_file" ]]; then
    echo "Artwork for game ID $game_id already exists. Skipping download." | tee -a "${LOG_FILE}"
  else
    # Attempt to download artwork using wget
    echo "Artwork not found locally. Attempting to download from the PSBBN art database..." | tee -a "${LOG_FILE}"
    wget --quiet --timeout=10 --tries=3 --output-document="$png_file" \
        "https://raw.githubusercontent.com/CosmicScale/psbbn-art-database/main/art/${game_id}.png"
    if [[ -s "$png_file" ]]; then
      echo "Successfully downloaded artwork for game ID: $game_id" | tee -a "${LOG_FILE}"
    else
      # If wget fails, run the art downloader
        [[ -f "$png_file" ]] && rm "$png_file"
        echo "Trying IGN for game ID: $game_id" | tee -a "${LOG_FILE}"
        node "${HELPER_DIR}/art_downloader.js" "$game_id" 2>&1 | tee -a "${LOG_FILE}"
    fi
  fi
done < "$ALL_GAMES"

echo | tee -a "${LOG_FILE}"
echo "Converting artwork..." | tee -a "${LOG_FILE}"

# Define input directory
input_dir="${ARTWORK_DIR}/tmp"

# Check if the directory contains any files
if compgen -G "${input_dir}/*" > /dev/null; then
    for file in "${input_dir}"/*; do
        # Extract the base filename without the path or extension
        base_name=$(basename "${file%.*}")

        # Define output filename with .png extension
        output="${ARTWORK_DIR}/tmp/${base_name}.png"

        # Get image dimensions using identify
        dimensions=$(identify -format "%w %h" "$file")
        width=$(echo "$dimensions" | cut -d' ' -f1)
        height=$(echo "$dimensions" | cut -d' ' -f2)

        # Check if width >= 256 and height >= width
        if [[ $width -ge 256 && $height -ge $width ]]; then
            # Determine whether the image is square
            if [[ $width -eq $height ]]; then
                # Square: Resize without cropping
                echo "Resizing square image $file"
                convert "$file" -resize 256x256! -depth 8 -alpha off "$output"
            else
                # Not square: Resize and crop
                echo "Resizing and cropping $file"
                convert "$file" -resize 256x256^ -crop 256x256+0+44 -depth 8 -alpha off "$output"
            fi
            rm "$file"
        else
            echo "Skipping $file: does not meet size requirements" | tee -a "${LOG_FILE}"
            rm "$file"
        fi
    done
else
    echo "No files to process in ${input_dir}" | tee -a "${LOG_FILE}"
fi

cp ${ARTWORK_DIR}/tmp/* ${ARTWORK_DIR} >> "${LOG_FILE}" 2>&1

echo | tee -a "${LOG_FILE}"
echo "Creating game assets..."  | tee -a "${LOG_FILE}"

# Read the file line by line
while IFS='|' read -r game_title game_id publisher disc_type file_name; do
  pp_game_id=$(echo "$game_id" | sed -E 's/_(...)\./-\1/;s/\.//')
  # Create a sub-folder named after the game_id
  game_dir="$ICONS_DIR/$game_id"
  mkdir -p "$game_dir" | tee -a "${LOG_FILE}"

   # Determine the launcher value for this specific game
  if [[ "$disc_type" == "POPS" ]]; then
    launcher_value="POPS"
  else
    launcher_value="$LAUNCHER"
  fi

  # Generate the launcher.cfg file
  launcher_cfg_filename="$game_dir/launcher.cfg"
  cat > "$launcher_cfg_filename" <<EOL
file_name=$file_name
title_id=$game_id
disc_type=$disc_type
launcher=$launcher_value
EOL
  echo "Created launcher.cfg: $launcher_cfg_filename" | tee -a "${LOG_FILE}"

  # Generate the info.sys file
  info_sys_filename="$game_dir/info.sys"
  cat > "$info_sys_filename" <<EOL
title = $game_title
title_id = $pp_game_id
title_sub_id = 0
release_date = 
developer_id = 
publisher_id = $publisher
note = 
content_web = 
image_topviewflag = 0
image_type = 0
image_count = 1
image_viewsec = 600
copyright_viewflag = 0
copyright_imgcount = 0
genre = 
parental_lock = 1
effective_date = 0
expire_date = 0
violence_flag = 0
content_type = 255
content_subtype = 0
EOL
  echo "Created info.sys: $info_sys_filename"  | tee -a "${LOG_FILE}"

  # Copy the matching .png file and rename it to jkt_001.png
  png_file="${TOOLKIT_PATH}/icons/art/${game_id}.png"
  if [[ -f "$png_file" ]]; then
    cp "$png_file" "$game_dir/jkt_001.png"
    echo "Artwork found for $game_title"  | tee -a "${LOG_FILE}"
  else
    if [[ "$disc_type" == "POPS" ]]; then
      cp "${TOOLKIT_PATH}/icons/art/ps1.png" "$game_dir/jkt_001.png"
      echo "Artwork not found for $game_title. Using default PS1 image" | tee -a "${LOG_FILE}"
      echo "$game_id $game_title" >> "${MISSING_ART}"
    else
      cp "${TOOLKIT_PATH}/icons/art/ps2.png" "$game_dir/jkt_001.png"
      echo "Artwork not found for $game_title. Using default PS2 image" | tee -a "${LOG_FILE}"
      echo "$game_id $game_title" >> "${MISSING_ART}"
    fi
  fi

done < "$ALL_GAMES"

echo | tee -a "${LOG_FILE}"
echo "All .cfg, info.sys, and .png files have been created in their respective sub-folders." | tee -a "${LOG_FILE}"
echo | tee -a "${LOG_FILE}"
echo "Installing game assets..." | tee -a "${LOG_FILE}"

cd "${ASSETS_DIR}"

i=0
# Reverse the lines of the file using tac and process each line
while IFS='|' read -r game_title game_id publisher disc_type file_name; do

    # Check the value of available
    if [ "$available" -lt 128 ]; then
        echo | tee -a "${LOG_FILE}"
        echo "Insufficient space for another partition." | tee -a "${LOG_FILE}"
        break
    fi

    # Format game id correctly for partition
    pp_game_id=$(echo "$game_id" | sed -E 's/_(...)\./-\1/;s/\.//')

    # Sanitize game_title by keeping only uppercase A-Z, 0-9, and underscores, and removing any trailing underscores
    sanitized_title=$(echo "$game_title" | tr 'a-z' 'A-Z' | sed 's/[^A-Z0-9]/_/g' | sed 's/^_//; s/_$//; s/__*/_/g')
    PARTITION_LABEL=$(printf "PP.%s.%s" "$pp_game_id" "$sanitized_title" | cut -c 1-32 | sed 's/_$//')

    COMMANDS="device ${DEVICE}\n"

    COMMANDS+="mkpart ${PARTITION_LABEL} 128M PFS\n"
    COMMANDS+="mount ${PARTITION_LABEL}\n"
    COMMANDS+="cd /\n"
    COMMANDS+="lcd '${ASSETS_DIR}'\n"
    COMMANDS+="put bbnl.KELF\n"

    # Navigate into the sub-directory named after the gameid
    COMMANDS+="lcd '${ICONS_DIR}/${game_id}'\n"
    COMMANDS+="put 'launcher.cfg'\n"
    COMMANDS+="mkdir res\n"
    COMMANDS+="cd res\n"
    COMMANDS+="put info.sys\n"
    COMMANDS+="put jkt_001.png\n"
    COMMANDS+="umount\n"
    COMMANDS+="exit\n"

    echo "Creating $PARTITION_LABEL" | tee -a "${LOG_FILE}"
    echo -e "$COMMANDS" | sudo "${HELPER_DIR}/PFS Shell.elf" >> "${LOG_FILE}" 2>&1

    sudo "${HELPER_DIR}/HDL Dump.elf" modify_header "${DEVICE}" "${PARTITION_LABEL}" >> "${LOG_FILE}" 2>&1

    function_space
    ((i++))
done < <(tac "$ALL_GAMES")

# Submit missing artwork to the PSBBN Art Database

cp $MISSING_ART $ARTWORK_DIR/tmp >> "${LOG_FILE}" 2>&1

if [ "$(ls -A "${ARTWORK_DIR}/tmp")" ]; then
    echo | tee -a "${LOG_FILE}"
    echo "Contributing to the PSBBN art database..." | tee -a "${LOG_FILE}"
    cd $ARTWORK_DIR/tmp/
    zip -r $ARTWORK_DIR/tmp/art.zip *
    # Upload the file using transfer.sh
    upload_url=$(curl -F "reqtype=fileupload" -F "time=72h" -F "fileToUpload=@art.zip" https://litterbox.catbox.moe/resources/internals/api.php)

    if [[ "$upload_url" == https://* ]]; then
        echo "File uploaded successfully: $upload_url" | tee -a "${LOG_FILE}"

    # Send a POST request to Webhook.site with the uploaded file URL
    webhook_url="https://webhook.site/75a25957-c114-439e-93b0-1feab2e2d417"
    curl -X POST -H "Content-Type: application/json" \
        -d "{\"url\": \"$upload_url\"}" \
        "$webhook_url" >/dev/null 2>&1
    else
        echo "Error: Failed to upload the file." | tee -a "${LOG_FILE}"
    fi
else
    echo | tee -a "${LOG_FILE}"
    echo "No art work to contribute." | tee -a "${LOG_FILE}"
fi

echo | tee -a "${LOG_FILE}"
echo "Cleaning up..." | tee -a "${LOG_FILE}"
clean_up

sudo "${HELPER_DIR}/HDL Dump.elf" toc "$DEVICE" >> "${LOG_FILE}" 2>&1
echo | tee -a "${LOG_FILE}"
echo "Game installer script complete." | tee -a "${LOG_FILE}"
echo
read -n 1 -s -r -p "Press any key to exit..."
echo
