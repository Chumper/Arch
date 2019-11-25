#!/usr/bin/env bash

##### CONSTANTS
drive=/dev/sda

partition () {
  if ! /sbin/sfdisk -d ${drive} > /dev/null 2>&1 ; then
    ### CONSTANTS
    boot_size=512M
    
    echo -e "\n######## Calculating partitions...\n"
    
    available_memory=$(free -b | grep Mem | awk '{print $2}')
    available_disk=$(fdisk -l | grep "${drive}" | awk '{print $5}')
    
    swap_size="$(( ${available_memory} / 2 ))"
    home_size="$(( ${available_disk} - $(numfmt --from=iec ${boot_size}) - ${swap_size} ))"

    echo -e "\n######## Partitioning...\n"

    # partition the disk
    echo -e "Total Memory:\t\t$(numfmt --format=%.1f --to=iec ${available_memory})"
    echo -e "Total Disk Size:\t$(numfmt --format=%.1f --to=iec ${available_disk})"
    echo -e "--------"
    echo -e "Boot Partition:\t\t${boot_size}"
    echo -e "Swap Partition:\t\t$(numfmt --format=%.1f --to=iec ${swap_size})"
    echo -e "Home Partition:\t\t$(numfmt --format=%.1f --to=iec ${home_size})" 

    parted ${drive} mklabel gpt
    parted -a optimal ${drive} mkpart primary ext4 1MiB ${boot_size}
    parted set 1 boot on
    parted -a optimal ${drive} mkpart primary ext4 ${boot_size} $(numfmt --to=iec --format=%.2f $(( $(numfmt --from=iec ${boot_size}) + ${home_size} )) )
    parted -a optimal ${drive} mkpart primary linux-swap $(numfmt --to=iec --format=%.2f $(( $(numfmt --from=iec ${boot_size}) + ${home_size} )) ) 100%

    echo -e "\n######## Creating file systems...\n"

    #  create fs system
    mkfs.ext4 /dev/sda1
    mkfs.ext4 /dev/sda2
    mkswap /dev/sda3

    echo -e "\n######## Mounting...\n"

    # mount
    swapon /dev/sda3
    mount /dev/sda2 /mnt
    mkdir -p /mnt/boot
    mount /dev/sda1 /mnt/boot
  fi
}

base () {
    if [ ! -d "/mnt/etc" ]; then
        echo -e "\n######## Installing base system...\n"
        pacstrap /mnt base linux linux-firmware
    fi
}

fstab () {
    if [ $(cat /mnt/etc/fstab | wc -l) -lt 5 ]; then
        echo -e "\n######## Generating fstab...\n"
        genfstab -U /mnt >> /mnt/etc/fstab
    fi
}

archroot () {
    if command arch-chroot /mnt; then 
        echo -e "\n######## Setting root to /mnt...\n"
        arch-chroot /mnt
    fi
}

### MAIN

partition
base
fstab
archroot
