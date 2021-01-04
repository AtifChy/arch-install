#!/bin/bash

echo "READ THE SCRIPT BEFORE RUNNING IT. Have you finished reading it?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) echo "Ok, let's continue."; break;;
        No ) exit;;
    esac
done


########### important ##############
# partition you disk using ===>[[    cfdisk   ]]<===
# Also comment everything you don't need.

# partition? [e.g. ROOT_disk=/dev/sda8]
export ROOT_disk=/dev/sda8 	#example
export EFI_disk=/dev/sda1 	#example
#export HOME_disk=
export BOOT_disk=/dev/sda7 	# Do you want separate boot partition?

# Update the system clock
timedatectl set-ntp true

# list of disks
lsblk

echo "Formating..."

## btrfs root
mkfs.btrfs -f -L "Archlinux" $ROOT_disk

# boot partition
mkfs.ext4 -f $BOOT_disk

# ext4 root
#mkfs.ext4 -f -L "Archlinux" $ROOT_disk

# EFI
#mkfs.fat -F32 $EFI_disk

# Home
#mkfs.ext4 -f -L "Home" $HOME_disk

echo "DONE"

echo "Mounting..."

## btrfs
# btrfs subvolume creationn
#===> start of 1st phase
mount $ROOT_disk /mnt
btrfs subvolume create /mnt/@ 			# root
btrfs subvolume create /mnt/@home 		# /home
btrfs subvolume create /mnt/@opt 		# /opt
btrfs subvolume create /mnt/@srv 		# /srv
btrfs subvolume create /mnt/@var 		# /var
btrfs subvolume create /mnt/@tmp 		# /tmp
btrfs subvolume create /mnt/@snapshots 		# /.snapshots
btrfs subvolume create /mnt/@swap 		# /swap
btrfs subvolume create /mnt/@var_log 		# /var/log
btrfs subvolume create /mnt/@var_cache 		# /var/cache
#btrfs subvolume create /mnt/@boot 		# enable this if you want /boot as a btrfs subvolume
umount -l /mnt
#===> end of 1st phase
#===> start of 2nd phase
mount -o noatime,compress=zstd,nossd,space_cache,subvol=@ $ROOT_disk /mnt
mkdir /mnt/{boot,home,opt,srv,var,tmp,.snapshots,swap}
mount -o noatime,compress=zstd,nossd,space_cache,subvol=@home $ROOT_disk /mnt/home
mount -o noatime,compress=zstd,nossd,space_cache,subvol=@opt $ROOT_disk /mnt/opt
mount -o noatime,compress=zstd,nossd,space_cache,subvol=@srv $ROOT_disk /mnt/srv
mount -o noatime,compress=zstd,nossd,space_cache,subvol=@var $ROOT_disk /mnt/var
mount -o noatime,compress=zstd,nossd,space_cache,subvol=@tmp $ROOT_disk /mnt/tmp
mount -o noatime,compress=zstd,nossd,space_cache,subvol=@snapshots $ROOT_disk /mnt/.snapshots
mount -o noatime,compress=zstd,nossd,space_cache,subvol=@swap $ROOT_disk /mnt/swap
#
# uncomment the follow line to mount /boot on /mnt/boot
#mount -o noatime,compress=zstd,nossd,space_cache,subvol=@boot $ROOT_disk /mnt/boot
mkdir /mnt/var/{log,cache}
mount -o noatime,compress=zstd,nossd,space_cache,subvol=@var_log $ROOT_disk /mnt/var/log
mount -o noatime,compress=zstd,nossd,space_cache,subvol=@var_cache $ROOT_disk /mnt/var/cache
#===> end of 2nd phase

## end of btrfs

## ext4 root
#mount $ROOT_disk /mnt
## end of ext4 root

## ext4 boot partition
mkdir /mnt/boot/efi
mount $EFI_disk /mnt/boot/efi
## end of ext4 boot partition

echo "DONE"

# mirror
reflector -c Bangladesh --save /etc/pacman.d/mirrorlist

echo "Installing..."

pacstrap /mnt base base-devel linux-zen linux-zen-headers linux-firmware reflector git btrfs-progs neovim xclip

echo "DONE"

echo "Generating fstab..."

genfstab -U /mnt >> /mnt/etc/fstab

echo "DONE"

echo "Entering newly installed system..."

arch-chroot /mnt

echo "DONE"

