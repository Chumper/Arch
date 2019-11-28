#!/usr/bin/env bash

##### CONSTANTS
drive=/dev/sda
root_password=123
user_name=nils
user_password=123


partition () {
    if command -v arch-chroot > /dev/null 2>&1; then
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

            parted ${drive} mklabel msdos > /dev/null 2>&1
            parted -a optimal ${drive} mkpart primary ext4 1MiB ${boot_size} > /dev/null 2>&1
            parted -a optimal ${drive} mkpart primary ext4 ${boot_size} $(numfmt --to=iec --format=%.2f $(( $(numfmt --from=iec ${boot_size}) + ${home_size} )) ) > /dev/null 2>&1
            parted -a optimal ${drive} mkpart primary linux-swap $(numfmt --to=iec --format=%.2f $(( $(numfmt --from=iec ${boot_size}) + ${home_size} )) ) 100% > /dev/null 2>&1
            parted ${drive} set 1 boot on > /dev/null 2>&1
        fi
    fi
}

filesystem () {
    if command -v arch-chroot > /dev/null 2>&1; then
        if mount /dev/sda1 /mnt; then
            umount /dev/sda1
        else
            echo -e "\n######## Creating file system on /dev/sda1...\n"
            mkfs.ext4 /dev/sda1
        fi
        if mount /dev/sda2 /mnt; then
            umount /dev/sda2
        else
            echo -e "\n######## Creating file system on /dev/sda2...\n"
            mkfs.ext4 /dev/sda2
        fi
        if swapon /dev/sda3; then
            swapoff /dev/sda3
        else
            echo -e "\n######## Creating file system on /dev/sda3...\n"
            mkswap /dev/sda3
        fi
    fi
}

domount () {
    if command -v arch-chroot > /dev/null 2>&1; then
        if ! mountpoint /mnt > /dev/null 2>&1; then
            echo -e "\n######## Mounting...\n"
            swapon /dev/sda3 || true
            mount /dev/sda2 /mnt || true
            mkdir -p /mnt/boot
            mount /dev/sda1 /mnt/boot || true
        fi
    fi
}

base () {
    if command -v arch-chroot > /dev/null 2>&1; then
        if [ ! -d "/mnt/etc" ]; then
            echo -e "\n######## Installing base system...\n"
            pacstrap /mnt base linux linux-firmware
        fi
    fi
}

fstab () {
    if command -v arch-chroot > /dev/null 2>&1; then   
        if [ $(cat /mnt/etc/fstab | wc -l) -lt 5 ]; then
            echo -e "\n######## Generating fstab...\n"
            genfstab -U /mnt >> /mnt/etc/fstab
        fi
    fi
}

locale () {
    if command -v arch-chroot > /dev/null 2>&1; then
        if [[ $(arch-chroot /mnt bash -c 'cat /etc/locale.gen | wc -l') -gt 1 ]]; then
            echo -e "\n######## Generating locale...\n"
            arch-chroot /mnt bash -c 'echo "en_US UTF-8" > /etc/locale.gen'
            arch-chroot /mnt bash -c 'locale-gen'
            arch-chroot /mnt bash -c 'Lang="en_US.UTF-8" > /etc/locale.conf'
        fi
    fi
}

timezone () {
    if command -v arch-chroot > /dev/null 2>&1; then
        if ! arch-chroot /mnt bash -c 'test -f /etc/localtime'; then
            echo -e "\n######## Linking timezone...\n"
            arch-chroot /mnt bash -c 'ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime'
        fi
    fi
}

hostname () {
    if command -v arch-chroot > /dev/null 2>&1; then
        if ! arch-chroot /mnt bash -c 'test -f /etc/hostname'; then
            echo -e "\n######## Setting hostname...\n"
            arch-chroot /mnt bash -c 'echo "arch" > /etc/hostname'
        fi
    fi
}

hosts () {
    if command -v arch-chroot > /dev/null 2>&1; then
        if [[ $(arch-chroot /mnt bash -c 'cat /etc/hosts | grep arch | wc -l') -lt 1 ]]; then
            echo -e "\n######## Setting hosts...\n"
            arch-chroot /mnt bash -c 'echo -e "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\tarch.localdomain\tarch" >> /etc/hosts'
        fi
    fi
}

passwd () {
    if command -v arch-chroot > /dev/null 2>&1; then
        echo -e "\n######## Setting root password...\n"
        arch-chroot /mnt bash -c "echo 'root:${root_password}' | chpasswd"
    fi
}

adduser () {
    if command -v arch-chroot > /dev/null 2>&1; then
        if ! arch-chroot /mnt bash -c "id ${user_name} > /dev/null 2>&1"; then
            echo -e "\n######## Adding user '${user_name}'...\n"
            arch-chroot /mnt bash -c "useradd --home-dir /home/${user_name} --create-home ${user_name}"
            arch-chroot /mnt bash -c "echo '${user_name}:${user_password}' | chpasswd"
        fi
        if ! arch-chroot /mnt bash -c 'command -v sudo > /dev/null 2>&1'; then
            echo -e "\n######## Installing sudoers...\n"
            arch-chroot /mnt bash -c "pacman -S sudo --noconfirm"
        fi
        if [[ $(arch-chroot /mnt bash -c "cat /etc/sudoers | grep ${user_name} | wc -l") -lt 1 ]]; then
            echo -e "\n######## Adding user '${user_name}' to sudoers...\n"
            arch-chroot /mnt bash -c "sed -i '/^root ALL=(ALL) ALL$/a ${user_name} ALL=(ALL) ALL' /etc/sudoers"
        fi
    fi
}

grub () {
    if command -v arch-chroot > /dev/null 2>&1; then
        if ! arch-chroot /mnt bash -c 'test -f /boot/grub/grub.cfg'; then
            echo -e "\n######## Installing grub...\n"
            arch-chroot /mnt bash -c 'pacman -S grub --noconfirm'
            arch-chroot /mnt bash -c "grub-install ${drive}"
            arch-chroot /mnt bash -c 'grub-mkconfig -o /boot/grub/grub.cfg'
            arch-chroot /mnt bash -c 'mkinitcpio -P'
        fi
    fi
}

dhcp () {
    if command -v arch-chroot > /dev/null 2>&1; then
        if ! arch-chroot /mnt bash -c 'pacman -Qi dhcpcd'; then
            echo -e "\n######## Installing dhcpcd...\n"
            pacman -S dhcpcd --noconfirm
        fi
    fi
    if ! command -v arch-chroot > /dev/null 2>&1; then
        iname=$(ip -o link show | sed -rn '/^[0-9]+: en/{s/.: ([^:]*):.*/\1/p}')
        echo -e "\n######## Starting dhcpcd...\n"
        dhcpcd
        systemctl enable dhcpcd@${iname}.service
    fi
}

vbox () {
    pacman -S virtualbox-guest-modules-arch virtualbox-guest-utils
    echo -e "vboxguest\nvboxsf\nvboxvideo" > /etc/modules-load.d/virtualbox.conf
    systemctl enable vboxservice.service
}


### MAIN

partition
filesystem
domount
# base
# fstab
# locale
# timezone
# hostname
# hosts
# passwd
# adduser
# grub
# dhcp
