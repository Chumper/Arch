#!/usr/bin/env bash

##### CONSTANTS
drive=/dev/sda
root_password=<changeme>
user_name=John
user_password=doe


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

    parted ${drive} mklabel msdos
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

locale () {
    if [[ $(arch-chroot /mnt bash -c 'cat /etc/locale.gen | wc -l') -gt 1 ]]; then
        echo -e "\n######## Generating locale...\n"
        arch-chroot /mnt bash -c 'echo "en_US UTF-8" > /etc/locale.gen'
        arch-chroot /mnt bash -c 'locale-gen'
        arch-chroot /mnt bash -c 'Lang="en_US.UTF-8" > /etc/locale.conf'
    fi
}

timezone () {
    if ! arch-chroot /mnt bash -c 'test -f /etc/localtime'; then
        echo -e "\n######## Linking timezone...\n"
        arch-chroot /mnt bash -c 'ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime'
    fi
}

hostname () {
    if ! arch-chroot /mnt bash -c 'test -f /etc/hostname'; then
        echo -e "\n######## Setting hostname...\n"
        arch-chroot /mnt bash -c 'echo "arch" > /etc/hostname'
    fi
}

hosts () {
    if [[ $(arch-chroot /mnt bash -c 'cat /etc/hosts | grep arch | wc -l') -lt 1 ]]; then
        echo -e "\n######## Setting hosts...\n"
        arch-chroot /mnt bash -c 'echo -e "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\tarch.localdomain\tarch" >> /etc/hosts'
    fi
}

passwd () {
    echo -e "\n######## Setting root password...\n"
    arch-chroot /mnt bash -c "echo 'root:${root_password}' | chpasswd"
}

adduser () {
    if ! arch-chroot /mnt bash -c "id ${user_name} > /dev/null 2>&1"; then
        echo -e "\n######## Adding user '${user_name}'...\n"
        arch-chroot /mnt bash -c "useradd --home-dir /home/${user_name} --create-home ${user_name}"
        arch-chroot /mnt bash -c "echo '${user_name}:${user_password}' | chpasswd"
    fi
    if [[ $(arch-chroot /mnt bash -c 'cat /etc/hosts | grep arch | wc -l') -lt 1 ]]; then
        echo -e "\n######## Adding user '${user_name}' to sudoers...\n"
        arch-chroot /mnt bash -c "pacman -S sudo --noconfirm"
        arch-chroot /mnt bash -c "sed '/^root ALL=(ALL) ALL$/a ${user_name} ALL=(ALL) ALL' /etc/sudoers"
    fi
}

grub () {
    if ! arch-chroot /mnt bash -c 'test -f /boot/grub/grub.cfg'; then
        echo -e "\n######## Installing grub...\n"
        arch-chroot /mnt bash -c 'pacman -S grub --noconfirm'
        arch-chroot /mnt bash -c "grub-install ${drive}"
        arch-chroot /mnt bash -c 'grub-mkconfig -o /boot/grub/grub.cfg'
        arch-chroot /mnt bash -c 'mkinitcpio -P'
    fi
}

### MAIN

partition
base
fstab
locale
timezone
hostname
hosts
passwd
adduser
grub
