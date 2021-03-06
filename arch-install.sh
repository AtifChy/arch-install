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

USER_install=atif 	# what's your name?
COUNTRY=Bangladesh 	# for mirror

# partition? [e.g. ROOT_disk=/dev/sda8]
ROOT_disk=/dev/sda9 	#example; recommended size = 20GB+
EFI_disk=/dev/sda1 	    #example; recommended size = 100MB+
#export HOME_disk= 		# recommended size = 30GB+
#BOOT_disk=/dev/sda8 	# Do you want separate boot partition?
				        # recommended size = 1GB+

# Update the system clock
timedatectl set-ntp true

# list of disks
lsblk
###########################################################
##############           Formating          ###############
###########################################################
echo "Formating..."

## btrfs root
mkfs.btrfs -f -L "Archlinux" $ROOT_disk

# boot partition
#mkfs.ext4 -L "Boot" $BOOT_disk

# ext4 root
#mkfs.ext4 -f -L "Archlinux" $ROOT_disk

# EFI
mkfs.fat -F32 $EFI_disk
#fatlabel /dev/sda1 EFI

# Home
#mkfs.ext4 -f -L "Home" $HOME_disk

echo "DONE"

echo "Mounting..."

###########################################################
##############    Create btrfs Subvolume    ###############
###########################################################
## btrfs
# btrfs subvolume creationn
#===> start of 1st phase
mount $ROOT_disk /mnt
btrfs subvolume create /mnt/@ 			# root
btrfs subvolume create /mnt/@home 		# /home
#btrfs subvolume create /mnt/@boot 		# enable this if you want /boot as a btrfs subvolume
btrfs subvolume create /mnt/@opt 		# /opt
btrfs subvolume create /mnt/@srv 		# /srv
#btrfs subvolume create /mnt/@tmp 		# /tmp
btrfs subvolume create /mnt/@snapshots 		# /.snapshots
#btrfs subvolume create /mnt/@swap 		# /swap
btrfs subvolume create /mnt/@var_cache 		# /var/cache
btrfs subvolume create /mnt/@var_log 		# /var/log
#btrfs subvolume create /mnt/@var_tmp 		# /var/tmp      # NOT Recommended

umount -l /mnt
#===> end of 1st phase
#===> start of 2nd phase
###########################################################
##############           Mounting           ###############
###########################################################
mount -o noatime,compress=zstd,space_cache,subvol=@ $ROOT_disk /mnt
#
# create necessary directorys for mounting btrfs subvolume
mkdir /mnt/{boot,home,opt,srv,var,tmp,.snapshots}
mount -o noatime,compress=zstd,space_cache,subvol=@home $ROOT_disk /mnt/home
#
# comment the following line if you don't want /boot in a separate subvolume
#
mount -o noatime,compress=zstd,space_cache,subvol=@boot $ROOT_disk /mnt/boot
#
#
#
mount -o noatime,compress=zstd,space_cache,subvol=@opt $ROOT_disk /mnt/opt
mount -o noatime,compress=zstd,space_cache,subvol=@srv $ROOT_disk /mnt/srv
#mount -o noatime,compress=zstd,space_cache,subvol=@tmp $ROOT_disk /mnt/tmp
mount -o noatime,compress=zstd,space_cache,subvol=@snapshots $ROOT_disk /mnt/.snapshots
#mount -o noatime,compress=zstd,space_cache,subvol=@swap $ROOT_disk /mnt/swap

mkdir /mnt/var/{log,cache,tmp}
mount -o noatime,compress=zstd,space_cache,subvol=@var_cache $ROOT_disk /mnt/var/cache
mount -o noatime,compress=zstd,space_cache,subvol=@var_log $ROOT_disk /mnt/var/log
mount -o noatime,compress=zstd,space_cache,subvol=@var_tmp $ROOT_disk /mnt/var/tmp

# disable CoW (Copy on Write)?
chattr +C /mnt/home
chattr +C /mnt/var/log
chattr +C /mnt/var/cache
chattr +C /mnt/var/tmp
#===> end of 2nd phase

## end of btrfs

## ext4 root
#mount $ROOT_disk /mnt
## end of ext4 root

## ext4 boot partition
#mount $BOOT_disk /mnt/boot
## end of ext4 boot partition

## mount EFI partition
mkdir /mnt/boot
mount $EFI_disk /mnt/boot
## end EFI

echo "DONE"

# mirror
reflector -c $COUNTRY --save /etc/pacman.d/mirrorlist

echo "Press Enter to Continue..."
read

echo "Installing..."

pacstrap /mnt base base-devel linux-zen linux-zen-headers linux-firmware reflector git btrfs-progs neovim xclip

echo "DONE"

echo "Generating fstab..."

genfstab -U /mnt >> /mnt/etc/fstab

echo "DONE"

echo "Creating swapfile for btrfs"
arch-chroot /mnt truncate -s 0 /swap/swapfile
arch-chroot /mnt chattr +C /swap/swapfile
arch-chroot /mnt btrfs property set /swap/swapfile compression none
arch-chroot /mnt dd if=/dev/zero of=/swap/swapfile bs=1G count=4 status=progress 	# increase count number if you want more swap space or decrease if you want less
arch-chroot /mnt chmod 600 /swap/swapfile
arch-chroot /mnt mkswap /swap/swapfile
arch-chroot /mnt swapon /swap/swapfile
arch-chroot /mnt echo " " >> /etc/fstab
arch-chroot /mnt echo "/swap/swapfile 		none 		swap 		defaults 	0 0" >> /etc/fstab
echo "DONE"

echo "Entering newly installed system..."

arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Dhaka /etc/localtime
arch-chroot /mnt hwclock --systohc
echo "Uncomment whatever locale you need"
read
arch-chroot /mnt nvim /etc/locale.gen
arch-chroot /mnt locale-gen
arch-chroot /mnt echo "LANG=en_US.UTF-8" >> /etc/locale.conf
arch-chroot /mnt echo "KEYMAP=us" >> /etc/vconsole.conf
arch-chroot /mnt echo "archlinux" >> /etc/hostname
arch-chroot /mnt echo "127.0.0.1	localhost" >> /etc/hosts
arch-chroot /mnt echo "::1		localhost" >> /etc/hosts
arch-chroot /mnt echo "127.0.1.1	archlinux.localdomain	archlinux" >> /etc/hosts

echo "root passwd"
arch-chroot /mnt passwd

echo "adding a user..."
arch-chroot /mnt useradd -mG wheel,network,audio,kvm,optical,storage,video $USER_install
echo "password for new user"
arch-chroot /mnt passwd $USER_install
echo "DONE"
echo "Enable sudo for new user"
arch-chroot /mnt EDITOR=nvim visudo

echo "Installing some useful tools"
arch-chroot /mnt pacman -Syu grub grub-btrfs efibootmgr networkmanager wpa_supplicant dialog os-prober mtools dosfstools openssh wget curl nano pacman-contrib bash-completion usbutils lsof dmidecode zip unzip unrar p7zip lzop rsync traceroute bind-tools ntfs-3g exfat-utils gptfdisk autofs fuse2 fuse3 fuseiso alsa-utils alsa-plugins pulseaudio pulseaudio-alsa xorg-server xorg-xinit font-bh-ttf gsfonts sdl_ttf ttf-bitstream-vera ttf-dejavu ttf-liberation xorg-fonts-type1 ttf-fira-code ttf-fira-sans ttf-hack xf86-input-libinput xf86-video-amdgpu gst-plugins-base gst-plugins-good gst-plugins-ugly gst-libav ttf-nerd-fonts-symbols ttf-jetbrains-mono --needed

echo "Installing grub..."
# EFI:
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
arch-chroot /mnt systemctl enable NetworkManager sshd

echo "Add btrfs to modules"
read

arch-chroot /mnt nvim /etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -P

echo "Reboot"

