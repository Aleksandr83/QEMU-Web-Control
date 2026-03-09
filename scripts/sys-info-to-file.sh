#!/bin/bash

# Function to show help message
usage() {
    echo "Usage: $0 [path] [filename]"
    echo "Example: $0 ./data system_info.txt"
    exit 1
}

# Check if correct number of arguments are given
if [[ $# -ne 2 ]]; then
    usage
fi

directory=$1
file=$2

# Resolve relative paths to absolute
directory=$(cd "$(dirname -- "$directory")"; pwd)/$(basename -- "$directory")

# Check if directory exists and is not empty
if [[ ! -d "$directory" || -z "$(ls -A "$directory")" ]]; then
    echo "Directory does not exist or is empty: $directory"
    exit 1
fi

# Get system information
hostname=$(hostname)
os_name=$(cat /etc/os-release | grep ^NAME= | cut -d'=' -f2- | tr -d '"')
os_version=$(cat /etc/os-release | grep ^VERSION_ID= | cut -d'=' -f2 | tr -d '"')
kernel_version=$(uname -r)
root_device=$(df --output=source / 2>/dev/null | tail -1)
root_disk_id=$(lsblk -no UUID "$root_device" 2>/dev/null | head -1)
if [ -z "$root_disk_id" ]; then
    root_disk_id=$(blkid -s UUID -o value "$root_device" 2>/dev/null \
        || /sbin/blkid -s UUID -o value "$root_device" 2>/dev/null \
        || /usr/sbin/blkid -s UUID -o value "$root_device" 2>/dev/null \
        || echo "")
fi

# Prepare the content
content="hostname=$hostname
os_name=$os_name
os_version=$os_version
kernel_version=$kernel_version
root_disk_id=$root_disk_id"

# Check if file exists with different parameters
full_path="$directory/$file"
if [[ -f "$full_path" ]]; then
    existing_content=$(cat "$full_path")
    if [[ "$existing_content" == "$content" ]]; then
        echo "Parameters unchanged. No update needed."
        exit 0
    fi
fi

# Write to file
echo "$content" > "$full_path"
echo "File updated with system parameters at $full_path"

