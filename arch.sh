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

mkfs.fat -F32 $efi_disk
if [ ! -z $home_disk ]; then
    mkfs.ext4 -L "Home" $home_disk
fi

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
    mkdir /mnt/{boot,home,opt,srv,var,tmp,.snapshots}
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
    mount -o noatime,compress=zstd,space_cache,subvol=@snapshots $root_disk /mnt/.snapshots
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
