#!/bin/bash
printf "Do you wish to install this program? [y/n] "
read -r input
case $input in
[Yy]*) echo "Ok, Let's continue" ;;
[Nn]*) exit ;;
*) echo "Please answer yes or no." ;;
esac

printf "user name (lower case) = "
read -r user_name
echo hi, "$user_name"

printf "country (for mirror) [e.g. Bangladesh] = "
read -r country

printf "time zome [e.g. Asia/Dhaka] = "
read -r time_zone

printf "Do you wish to create new partitions? [y/n] "
read -r partition
case $partition in
[Yy]*) cfdisk ;;
[Nn]*) echo 'skipping' ;;
*)
	echo "Please answer yes or no."
	exit
	;;
esac

lsblk
printf "root partition [e.g. /dev/sda8] = "
read -r root_disk
printf "efi partition [e.g. /dev/sda7] = "
read -r efi_disk

echo "Which file system do you want to use?"
select file_system in "btrfs" "ext4"; do
	case $file_system in
	btrfs)
		FILE_SYSTEM=btrfs
		printf "do want to make /boot a subvolume?(NOT RECOMMENDED) [y/n] "
		read -r boot_sub
		case $boot_sub in
		[Yy]*) BOOT_SUBVOL=true ;;
		*) BOOT_SUBVOL=false ;;
		esac
		break
		;;
	ext4)
		FILE_SYSTEM=ext4
		printf "Do you want to create home partition? [y/n] "
		read -r home_ask
		case $home_ask in
		[Yy]*)
			printf "home partition [e.g. /dev/sda6] = "
			read -r home_disk
			;;
		*) echo 'skipping' ;;
		esac
		break
		;;
	esac
done

if [ $FILE_SYSTEM = btrfs ]; then
	mkfs.btrfs -f -L "Archlinux" "$root_disk"

	###########################################################
	##############    Create btrfs Subvolume    ###############
	###########################################################
	mount "$root_disk" /mnt
	btrfs subvolume create /mnt/@     # root
	btrfs subvolume create /mnt/@home # /home
	if [ $BOOT_SUBVOL = true ]; then
		btrfs subvolume create /mnt/@boot
	fi
	btrfs subvolume create /mnt/@opt # /opt
	btrfs subvolume create /mnt/@srv # /srv
	#btrfs subvolume create /mnt/@tmp 		    # /tmp  # NOT Recommended
	#btrfs subvolume create /mnt/@snapshots 	    	# /.snapshots
	#btrfs subvolume create /mnt/@swap 		    # /swap
	btrfs subvolume create /mnt/@var_cache # /var/cache
	btrfs subvolume create /mnt/@var_log   # /var/log
	btrfs subvolume create /mnt/@var_tmp   # /var/tmp

	umount -l /mnt

	###########################################################
	##############           Mounting           ###############
	###########################################################
	mount -o noatime,compress=zstd,space_cache=v2,subvol=@ "$root_disk" /mnt
	#
	# create necessary directorys for mounting btrfs subvolume
	mkdir /mnt/{boot,home,opt,srv,var,tmp}
	if [ -z "$home_disk" ]; then
		mount -o noatime,compress=zstd,space_cache=v2,subvol=@home "$root_disk" /mnt/home
	fi
	if [ $BOOT_SUBVOL = true ]; then
		mount -o noatime,compress=zstd,space_cache=v2,subvol=@boot "$root_disk" /mnt/boot
	fi
	mount -o noatime,compress=zstd,space_cache=v2,subvol=@opt "$root_disk" /mnt/opt
	mount -o noatime,compress=zstd,space_cache=v2,subvol=@srv "$root_disk" /mnt/srv
	#mount -o noatime,compress=zstd,space_cache=v2,subvol=@tmp $root_disk /mnt/tmp
	#mount -o noatime,compress=zstd,space_cache=v2,subvol=@snapshots $root_disk /mnt/.snapshots
	#mount -o noatime,compress=zstd,space_cache=v2,subvol=@swap $root_disk /mnt/swap

	mkdir /mnt/var/{log,cache,tmp}
	mount -o noatime,compress=zstd,space_cache=v2,subvol=@var_cache "$root_disk" /mnt/var/cache
	mount -o noatime,compress=zstd,space_cache=v2,subvol=@var_log "$root_disk" /mnt/var/log
	mount -o noatime,compress=zstd,space_cache=v2,subvol=@var_tmp "$root_disk" /mnt/var/tmp

	# disable CoW (Copy on Write)?
	if [ -z "$home_disk" ]; then
		chattr +C /mnt/home
	fi
	chattr +C /mnt/var/log
	chattr +C /mnt/var/cache
	chattr +C /mnt/var/tmp
fi

if [ $FILE_SYSTEM = ext4 ]; then
	mkfs.ext4 -f -L "Archlinux" "$root_disk"
	mount "$root_disk" /mnt
fi

if [ "$home_disk" ]; then
	mkfs.ext4 -L "Home" "$home_disk"
	mkdir /mnt/home
	mount "$home_disk" /mnt/home
fi

mkfs.fat -F32 "$efi_disk"
mount "$efi_disk" /mnt/boot

###########################################################
##############            Mirror            ###############
###########################################################
reflector -c "$country" --save /etc/pacman.d/mirrorlist

echo "Starting Installation. Press Enter to Continue..."
read -r

echo "Installing..."
pacstrap /mnt base base-devel linux-zen linux-zen-headers linux-firmware reflector git btrfs-progs neovim xclip
echo "DONE"

echo "Generating fstab..."
genfstab -U /mnt >>/mnt/etc/fstab
echo "DONE"

echo "Entering newly installed system..."
arch-chroot /mnt ln -sf /usr/share/zoneinfo/"$time_zone" /etc/localtime
arch-chroot /mnt hwclock --systohc
echo "Uncomment whatever locale you need"
read -r
arch-chroot /mnt nvim /etc/locale.gen
arch-chroot /mnt locale-gen
arch-chroot /mnt echo "LANG=en_US.UTF-8" >>/etc/locale.conf
arch-chroot /mnt echo "KEYMAP=us" >>/etc/vconsole.conf
arch-chroot /mnt echo "archlinux" >>/etc/hostname
arch-chroot /mnt cat <<EOF >>/etc/hosts
127.0.0.1    localhost
127.0.0.1    localhost
127.0.1.1    archlinux.localdomain   archlinux
EOF

echo "root passwd"
arch-chroot /mnt passwd

echo "adding a user..."
arch-chroot /mnt useradd -mG wheel,network,audio,kvm,optical,storage,video "$user_name"
echo "password for new user"
arch-chroot /mnt passwd "$user_name"
echo "DONE"
echo "Enable sudo for new user"
arch-chroot /mnt sed -i '/%wheel ALL=(ALL) ALL/s/^#//g' /etc/sudoers

echo "Installing some useful tools"
arch-chroot /mnt pacman -Syu --noconfirm efibootmgr networkmanager wpa_supplicant dialog mtools dosfstools openssh wget curl nano pacman-contrib bash-completion usbutils lsof dmidecode zip unzip unrar p7zip lzop rsync traceroute bind-tools ntfs-3g exfat-utils gptfdisk autofs fuse2 fuse3 fuseiso alsa-utils alsa-plugins pulseaudio pulseaudio-alsa xorg-server xorg-xinit font-bh-ttf gsfonts sdl_ttf ttf-bitstream-vera ttf-dejavu ttf-liberation xorg-fonts-type1 ttf-fira-code ttf-fira-sans ttf-hack xf86-input-libinput xf86-video-amdgpu gst-plugins-base gst-plugins-good gst-plugins-ugly gst-libav ttf-nerd-fonts-symbols ttf-jetbrains-mono --needed

###########################################################
##############          Bootloader          ###############
###########################################################
echo "Choose your bootloader"
select file_system in "systemd-boot" "grub"; do
	case $file_system in
	systemd-boot)
		arch-chroot /mnt bootctl -efi-parth=/boot install

		arch-chroot /mnt cat <<EOF >>/boot/loader/loader.conf
default 	arch-1.conf
#timeout 	5
console-mode 	keep
editor 		yes
EOF

		arch-chroot /mnt cat <<EOF >>/boot/loader/entries/arch-1.conf
title 		Arch Linux, with linux-zen
linux 		/vmlinuz-linux-zen
initrd 		/intel-ucode.img
initrd 		/initramfs-linux-zen.img
options 	root="LABEL=ArchLinux" rootflags=subvol=@ rw
EOF

		arch-chroot /mnt cat <<EOF >>/boot/loader/entries/arch-2.conf
title 		Arch Linux, with linux-zen (fallback initramfs)
linux 		/vmlinuz-linux-zen
initrd 		/intel-ucode.img
initrd 		/initramfs-linux-zen-fallback.img
options 	root="LABEL=ArchLinux" rootflags=subvol=@ rw
EOF

		break
		;;
	grub)
		arch-chroot /mnt pacman -Syu --noconfirm grub grub-btrfs os-prober
		arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch
		arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
		break
		;;
	esac
done

arch-chroot /mnt systemctl enable NetworkManager sshd

echo "Add btrfs to modules"
read -r

arch-chroot /mnt nvim /etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -P

echo "Reboot"
