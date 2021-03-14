#!/bin/bash
read -p "Do you wish to install this program? [y/n] " input
case $input in
    [Yy]* ) neofetch;;
    [Nn]* ) exit;;
    * ) echo "Please answer yes or no.";;
esac

read -p "user name = " user_name
echo hi, $user_name

read -p "country (for mirror) =  " country

read -p "Do you wish to create new partitions? " partition
case $partition in
    [Yy]* ) cfdisk ;;
    [Nn]* ) echo 'skipping' ;;
    * ) echo "Please answer yes or no." ; exit ;;
esac

lsblk
read -p "root partition [e.g. /dev/sda8] = " root_disk
read -p "efi partition [e.g. /dev/sda7] = " efi_disk
read -p "Do you want to create home partition? [y/n] " home_ask
case $home_ask in
    [Yy]* )  read -p "home partition [e.g. /dev/sda6] = " home_disk;;
    [Nn]* ) echo 'skipping' ;;
    * ) echo 'skipping' ;;
esac

echo "Which file system do you want to use?"
select file_system in "btrfs" "ext4"; do
    case $file_system in
        btrfs ) FILE_SYSTEM=btrfs; break ;;
        ext4 ) FILE_SYSTEM=ext4; break ;;
    esac
done

if [ $FILE_SYSTEM = btrfs ]; then
    mkfs.btrfs -f -L "Archlinux" $root_disk

    ###########################################################
    ##############    Create btrfs Subvolume    ###############
    ###########################################################
    mount $root_disk /mnt
    btrfs subvolume create /mnt/@ 			    # root
    btrfs subvolume create /mnt/@home 		    # /home
    #btrfs subvolume create /mnt/@boot 		    # enable this if you want /boot as a btrfs subvolume
    btrfs subvolume create /mnt/@opt 		    # /opt
    btrfs subvolume create /mnt/@srv 		    # /srv
    #btrfs subvolume create /mnt/@tmp 		    # /tmp  # NOT Recommended
    #btrfs subvolume create /mnt/@snapshots 	    	# /.snapshots
    #btrfs subvolume create /mnt/@swap 		    # /swap
    btrfs subvolume create /mnt/@var_cache 		# /var/cache
    btrfs subvolume create /mnt/@var_log 		# /var/log
    btrfs subvolume create /mnt/@var_tmp 		# /var/tmp

    umount -l /mnt

    ###########################################################
    ##############           Mounting           ###############
    ###########################################################
    mount -o noatime,compress=zstd,space_cache,subvol=@ $root_disk /mnt
    #
    # create necessary directorys for mounting btrfs subvolume
    mkdir /mnt/{boot,home,opt,srv,var,tmp}
    if [ -z $home_disk ]; then
        mount -o noatime,compress=zstd,space_cache,subvol=@home $root_disk /mnt/home
    fi
    #
    # comment the following line if you don't want /boot in a separate subvolume
    #
    #mount -o noatime,compress=zstd,space_cache,subvol=@boot $root_disk /mnt/boot
    #
    mount -o noatime,compress=zstd,space_cache,subvol=@opt $root_disk /mnt/opt
    mount -o noatime,compress=zstd,space_cache,subvol=@srv $root_disk /mnt/srv
    #mount -o noatime,compress=zstd,space_cache,subvol=@tmp $root_disk /mnt/tmp
    #mount -o noatime,compress=zstd,space_cache,subvol=@snapshots $root_disk /mnt/.snapshots
    #mount -o noatime,compress=zstd,space_cache,subvol=@swap $root_disk /mnt/swap

    mkdir /mnt/var/{log,cache,tmp}
    mount -o noatime,compress=zstd,space_cache,subvol=@var_cache $root_disk /mnt/var/cache
    mount -o noatime,compress=zstd,space_cache,subvol=@var_log $root_disk /mnt/var/log
    mount -o noatime,compress=zstd,space_cache,subvol=@var_tmp $root_disk /mnt/var/tmp

    # disable CoW (Copy on Write)?
    if [ -z $home_disk ]; then
        chattr +C /mnt/home
    fi
    chattr +C /mnt/var/log
    chattr +C /mnt/var/cache
    chattr +C /mnt/var/tmp
fi

if [ $FILE_SYSTEM = ext4 ]; then
    mkfs.ext4 -f -L "Archlinux" $root_disk
    mount $root_disk /mnt
fi

if [ ! -z $home_disk ]; then
    mkfs.ext4 -L "Home" $home_disk
    mkdir /mnt/home
    mount $home_disk /mnt/home
fi

mkfs.fat -F32 $efi_disk
mount $efi_disk /mnt/boot

###########################################################
##############            Mirror            ###############
###########################################################
reflector -c $country --save /etc/pacman.d/mirrorlist

echo "Starting Installation. Press Enter to Continue..."
read

echo "Installing..."

pacstrap /mnt base base-devel linux-zen linux-zen-headers linux-firmware reflector git btrfs-progs neovim xclip

echo "DONE"

echo "Generating fstab..."

genfstab -U /mnt >> /mnt/etc/fstab

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
arch-chroot /mnt echo "127.0.0.1    localhost" >> /etc/hosts
arch-chroot /mnt echo "::1          localhost" >> /etc/hosts
arch-chroot /mnt echo "127.0.1.1    archlinux.localdomain   archlinux" >> /etc/hosts

echo "root passwd"
arch-chroot /mnt passwd

echo "adding a user..."
arch-chroot /mnt useradd -mG wheel,network,audio,kvm,optical,storage,video $user_name
echo "password for new user"
arch-chroot /mnt passwd $user_name
echo "DONE"
echo "Enable sudo for new user"
arch-chroot /mnt sed -i '/%wheel ALL=(ALL) ALL/s/^#//g' /etc/sudoers

echo "Installing some useful tools"
arch-chroot /mnt pacman -Syu --noconfirm grub grub-btrfs efibootmgr networkmanager wpa_supplicant dialog os-prober mtools dosfstools openssh wget curl nano pacman-contrib bash-completion usbutils lsof dmidecode zip unzip unrar p7zip lzop rsync traceroute bind-tools ntfs-3g exfat-utils gptfdisk autofs fuse2 fuse3 fuseiso alsa-utils alsa-plugins pulseaudio pulseaudio-alsa xorg-server xorg-xinit font-bh-ttf gsfonts sdl_ttf ttf-bitstream-vera ttf-dejavu ttf-liberation xorg-fonts-type1 ttf-fira-code ttf-fira-sans ttf-hack xf86-input-libinput xf86-video-amdgpu gst-plugins-base gst-plugins-good gst-plugins-ugly gst-libav ttf-nerd-fonts-symbols ttf-jetbrains-mono --needed

echo "Installing grub..."
# EFI:
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
arch-chroot /mnt systemctl enable NetworkManager sshd

echo "Add btrfs to modules"
read

arch-chroot /mnt nvim /etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -P

echo "Reboot"
