#!/usr/bin/env bash

echo -e "\e[8;45;100t"

clear

# Check if the shell is bash
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script must be run using Bash. Try running it with: bash $0" >&2
    exit 1
fi

# Set paths
TOOLKIT_PATH="$(pwd)"
HELPER_DIR="${TOOLKIT_PATH}/helper"

if [[ "$(uname -m)" != "x86_64" ]]; then
    error_msg "Error" "Unsupported CPU architecture: $(uname -m). This script requires x86-64."
fi

cd "${TOOLKIT_PATH}"

# Check if the helper files exists
if [[ ! -f "${HELPER_DIR}/PFS Shell.elf" || ! -f "${HELPER_DIR}/HDL Dump.elf" ]]; then
    error_msg "Error" "Helper files not found. Scripts must be from the 'PSBBN-Definitive-English-Patch' directory."
fi

prevent_sleep_start() {
    if command -v xdotool >/dev/null; then
        (
            while true; do
                xdotool key shift >/dev/null 2>&1
                sleep 50
            done
        ) &
        SLEEP_PID=$!

    elif command -v dbus-send >/dev/null; then
        if dbus-send --session --dest=org.freedesktop.ScreenSaver \
            --type=method_call --print-reply \
            /ScreenSaver org.freedesktop.DBus.Introspectable.Introspect \
            >/dev/null 2>&1; then

            (
                while true; do
                    dbus-send --session \
                        --dest=org.freedesktop.ScreenSaver \
                        --type=method_call \
                        /ScreenSaver org.freedesktop.ScreenSaver.SimulateUserActivity \
                        >/dev/null 2>&1
                    sleep 50
                done
            ) &
            SLEEP_PID=$!

        elif dbus-send --session --dest=org.kde.screensaver \
            --type=method_call --print-reply \
            /ScreenSaver org.freedesktop.DBus.Introspectable.Introspect \
            >/dev/null 2>&1; then

            (
                while true; do
                    dbus-send --session \
                        --dest=org.kde.screensaver \
                        --type=method_call \
                        /ScreenSaver org.kde.screensaver.simulateUserActivity \
                        >/dev/null 2>&1
                    sleep 50
                done
            ) &
            SLEEP_PID=$!
        fi
    fi
}

prevent_sleep_stop() {
    if [[ -n "$SLEEP_PID" ]]; then
        kill "$SLEEP_PID" 2>/dev/null
        wait "$SLEEP_PID" 2>/dev/null
        unset SLEEP_PID
    fi
}

# Clean up on exit (even if interrupted)
trap prevent_sleep_stop EXIT

prevent_sleep_start

option_one() {
    "${TOOLKIT_PATH}/scripts/Setup.sh"
}

option_two() {
    "${TOOLKIT_PATH}/scripts/PSBBN-Installer.sh"
}

option_three() {
    "${TOOLKIT_PATH}/scripts/Game-Installer.sh"
}

option_four() {
    "${TOOLKIT_PATH}/scripts/Extras.sh"
}


# Function to display the menu
display_menu() {
    cat << "EOF"
______  _________________ _   _  ______      __ _       _ _   _            ______     _       _     
| ___ \/  ___| ___ \ ___ \ \ | | |  _  \    / _(_)     (_) | (_)           | ___ \   | |     | |    
| |_/ /\ `--.| |_/ / |_/ /  \| | | | | |___| |_ _ _ __  _| |_ ___   _____  | |_/ /_ _| |_ ___| |__  
|  __/  `--. \ ___ \ ___ \ . ` | | | | / _ \  _| | '_ \| | __| \ \ / / _ \ |  __/ _` | __/ __| '_ \ 
| |    /\__/ / |_/ / |_/ / |\  | | |/ /  __/ | | | | | | | |_| |\ V /  __/ | | | (_| | || (__| | | |
\_|    \____/\____/\____/\_| \_/ |___/ \___|_| |_|_| |_|_|\__|_| \_/ \___| \_|  \__,_|\__\___|_| |_|

                                       Created by CosmicScale


                                     1) System Setup
                                     2) Install PSBBN
                                     3) Install Games
                                     4) Install Optional Extras

                                     q) Quit

EOF
}

# Main loop

while true; do
    clear
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