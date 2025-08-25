#!/bin/bash
# clean-disk.sh
# WARNING: This will DESTROY ALL DATA on the selected disk.

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

echo "Available disks:"
lsblk -p -o MODEL,NAME,SIZE,LABEL,MOUNTPOINT
echo
read -p "Enter the disk to wipe (e.g. /dev/sdX or /dev/nvme0n1): " DISK

if [ ! -b "$DISK" ]; then
    echo "Error: $DISK is not a valid block device."
    exit 1
fi

# Show details for confirmation
echo
lsblk "$DISK"
echo
read -p "WARNING: All data on $DISK will be LOST! Type YES to continue: " CONFIRM
if [ "$CONFIRM" != "YES" ]; then
    echo "Aborted."
    exit 1
fi

echo "Wiping first and last 1 MB of $DISK..."
SECTORS=$(blockdev --getsz "$DISK")

# First MB
dd if=/dev/zero of="$DISK" bs=512 count=2048 status=progress

# Last MB
dd if=/dev/zero of="$DISK" bs=512 seek=$((SECTORS - 2048)) count=2048 status=progress

echo "Done. $DISK is now blank."
echo "You can now create a new partition table with: sudo parted $DISK mklabel gpt"
