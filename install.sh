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
            parted ${drive} set 1 boot on > /dev/null 2>&1

            parted -a optimal ${drive} mkpart primary ext4 ${boot_size} $(numfmt --to=iec --format=%.2f $(( $(numfmt --from=iec ${boot_size}) + ${home_size} )) ) > /dev/null 2>&1

            parted -a optimal ${drive} mkpart primary linux-swap $(numfmt --to=iec --format=%.2f $(( $(numfmt --from=iec ${boot_size}) + ${home_size} )) ) 100% > /dev/null 2>&1
            
            echo -e "\n######## Creating filesystem on /dev/sda1...\n"
            mkfs.ext4 /dev/sda1
            
            echo -e "\n######## Creating filesystems on /dev/sda2......\n"
            mkfs.ext4 /dev/sda2
            
            echo -e "\n######## Creating filesystems on /dev/sda3......\n"
            mkswap /dev/sda3
        fi
    fi
}

domount () {
    if command -v arch-chroot > /dev/null 2>&1; then
        if ! mount | grep -c /dev/sda2 > /dev/null 2>&1; then
            echo -e "\n######## Mounting /dev/sda2...\n"
            mount /dev/sda2 /mnt || true
        fi
        if ! mount | grep -c /dev/sda1 > /dev/null 2>&1; then
            echo -e "\n######## Mounting /dev/sda1...\n"
            mkdir -p /mnt/boot
            mount /dev/sda1 /mnt/boot || true
        fi
        if ! swapon -s | grep -c /dev/sda3 > /dev/null 2>&1; then
            echo -e "\n######## Mounting /dev/sda3...\n"
            swapon /dev/sda3 || true
        fi
    fi
}

base () {
    if command -v arch-chroot > /dev/null 2>&1; then
        if [ ! -d "/mnt/etc" ]; then
            echo -e "\n######## Installing base system...\n"
            pacstrap /mnt base linux linux-firmware base-devel
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
        if ! arch-chroot /mnt bash -c 'command -v dhcpcd > /dev/null 2>&1'; then
            echo -e "\n######## Installing dhcpcd...\n"
            arch-chroot /mnt bash -c 'pacman -Sy dhcpcd --noconfirm'
            echo -e "\n\n\n\nYOU NEED TO REBOOT!\n\nLog in as ${user_name} and start 'dhcpcd'\nThen continue running the script\n\n\n"
        fi
    fi
    if ! command -v arch-chroot > /dev/null 2>&1; then
        iname=$(ip -o link show | sed -rn '/^[0-9]+: en/{s/.: ([^:]*):.*/\1/p}')
        if ! systemctl is-enabled dhcpcd@${iname}.service > /dev/null 2>&1; then
            echo -e "\n######## Starting dhcpcd...\n"
            dhcpcd > /dev/null 2>&1
            systemctl enable dhcpcd@${iname}.service
        fi
    fi
}

vbox () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if [ ! -f "/etc/modules-load.d/virtualbox.conf" ]; then
            echo -e "\n######## Setting up virtual box...\n"
            pacman -S virtualbox-guest-modules-arch virtualbox-guest-utils
            echo -e "vboxguest\nvboxsf\nvboxvideo" > /etc/modules-load.d/virtualbox.conf
            systemctl enable vboxservice.service
        fi
    fi
}

install_xserver () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if ! command -v startx > /dev/null 2>&1; then
            echo -e "\n######## Installing xserver...\n"
            pacman -S xorg-server xorg-xinit xorg-apps --noconfirm
        fi
    fi
}

install_git () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if ! command -v git > /dev/null 2>&1; then
            echo -e "\n######## Installing git...\n"
            pacman -S git --noconfirm
        fi
    fi
}

install_go () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if ! command -v go > /dev/null 2>&1; then
            echo -e "\n######## Installing go...\n"
            pacman -S go --noconfirm
        fi
    fi
}

install_yay () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if ! command -v yay > /dev/null 2>&1; then
            echo -e "\n######## Installing yay...\n"
            cd /home/${user_name}
            rm -rf yay
            su ${user_name} -c 'git clone https://aur.archlinux.org/yay.git'
            cd yay
            su ${user_name} -c 'makepkg -s'
            pacman -U yay*xz --noconfirm
        fi
    fi
}

install_ttf () {
    echo "installing roboto ttf"
}

install_i3 () {
    echo "installing i3"
}

install_feh () {
    echo "installing feh"
}

install_zsh () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if ! command -v zsh > /dev/null 2>&1; then
            yay -S zsh --noconfirm
            su ${user_name} -c 'chsh -s /bin/zsh'
        fi
    fi
}

install_polybar () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if ! command -v polybar > /dev/null 2>&1; then
            yay -S polybar --noconfirm
        fi
    fi
}


### MAIN

partition
domount
base
fstab
locale
timezone
hostname
hosts
passwd
adduser
grub
dhcp
vbox
install_xserver
install_git
install_go
install_yay
install_zsh
