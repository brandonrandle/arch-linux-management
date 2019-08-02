#!/bin/bash
# WARNING: This script will destroy data on the selected disk.

###############################################################################
# ERROR HANDLING
###############################################################################

# Ensures failure when shell tries to expand unset variables and ensures
# failure on the first command in a pipeline that fails instead of waiting for
# the whole pipe
set -uo pipefail

# catches error messages
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR


###############################################################################
# UPDATE MIRRORS TODO: TEST
###############################################################################

# REPO_URL=""
MIRRORLIST_URL="https://www.archlinux.org/mirrorlist/?country=US&protocol=https&use_mirror_status=on"

# install pacman-contrib for rankmirrors utility
pacman -Sy --noconfirm pacman-contrib

echo "Updating mirror list"
curl -s "$MIRRORLIST_URL" | \
  sed -e 's/^#Server/Server/' -e '/^#/d' | \
  rankmirrors -n 5 - > /etc/pacman.d/mirrorlist


###############################################################################
# USER INPUT
###############################################################################

# hostname
hostname=$(dialog --stdout --inputbox "Enter hostname:" 0 0 ) || exit 1
clear
: ${hostname:?"hostname can not be empty"}

# username
username=$(dialog --stdout --inputbox "Enter admin username:" 0 0 ) || exit 1
clear
: ${username:?"username can not be empty"}

# password
password=$(dialog --stdout --inputbox "Enter admin password:" 0 0 ) || exit 1
clear
: ${password:?"password can not be empty"}
password2=$(dialog --stdout --inputbox "Re-enter admin password:" 0 0 ) || exit 1
clear
: ${password2:?"password can not be empty"}
[[ "$password" == "$password2" ]] || ( echo "Passwords did not match."; exit 1; )

# install disk
# TODO: TEST
devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
device=$(dialog --stdout --menu "Select installation disk:" 0 0 0 ${devicelist}) || exit 1
clear


###############################################################################
# LOGGING
###############################################################################

# saves stdout and stderr to log files while still displaying them on screen
exec 1> >(tee "stdout.log")
exec 2> >(tee "stderr.log")


###############################################################################
# TIME
###############################################################################

# enables network time protocol for automatic clock syncronization
timedatectl set-ntp true


###############################################################################
# DISK & PARTITIONS TODO
###############################################################################

# set swap variables
swap_size=$(free --mebi | awk '/Mem:/ {print $2}')
swap_end=$(( $swap_size + 129 + 1 ))MiB

# create partitions
parted --script "${device}" -- mklabel gpt      \
  mkpart ESP fat32 1Mib 129MiB                  \
  set 1 boot on                                 \
  mkpart primary linux-swap 129MiB ${swap_end}  \
  mkpart primary ext4 ${swap_end} 100%

# set variables for partitions
part_boot="$(ls ${device}* | grep -E "^${device}p?1$")"
part_swap="$(ls ${device}* | grep -E "^${device}p?2$")"
part_root="$(ls ${device}* | grep -E "^${device}p?3$")"

# wipe device signatures
wipefs "${part_boot}"
wipefs "${part_swap}"
wipefs "${part_root}"

# create file systems
mkfs.vfat -F32 "${part_boot}"
mkswap "${part_swap}"
mkfs.fsfs -f "${part_root}"

# perform mounting
swapon "${part_swap}"
mount "${part_root}" /mnt
mkdir /mnt/boot
mount "${part_boot}" /mnt/boot


###############################################################################
# BASIC INSTALLATION & CONFIGURATION TODO
###############################################################################

# install packages
pacstrap /mnt base

# generate fstab file
genfstab -U /mnt >> /mnt/etc/fstab

# set time zone
# TODO

# set hostname
echo "${hostname}" > /mnt/etc/hostname

# set hosts file
cat <<EOT >> /mnt/etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.0.1   ${hostname}.localdomain ${hostname}
EOT

# user setup
arch-chroot /mnt useradd -mU -G wheel "$user"

echo "$user:$password" | chpasswd --root /mnt
echo "root:$password" | chpasswd --root /mnt


###############################################################################
# SETUP LOCALE
###############################################################################

echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf


###############################################################################
# INSTALL BOOTLOADER TODO
###############################################################################