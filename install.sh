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

            echo -e "\n######## Creating filesystem on ${drive}1...\n"
            mkfs.ext4 ${drive}1

            echo -e "\n######## Creating filesystems on ${drive}2......\n"
            mkfs.ext4 ${drive}2

            echo -e "\n######## Creating filesystems on ${drive}3......\n"
            mkswap ${drive}3
        fi
    fi
}

domount () {
    if command -v arch-chroot > /dev/null 2>&1; then
        if ! mount | grep -c ${drive}2 > /dev/null 2>&1; then
            echo -e "\n######## Mounting ${drive}2...\n"
            mount ${drive}2 /mnt || true
        fi
        if ! mount | grep -c ${drive}1 > /dev/null 2>&1; then
            echo -e "\n######## Mounting ${drive}1...\n"
            mkdir -p /mnt/boot
            mount ${drive}1 /mnt/boot || true
        fi
        if ! swapon -s | grep -c ${drive}3 > /dev/null 2>&1; then
            echo -e "\n######## Mounting ${drive}3...\n"
            swapon ${drive}3 || true
        fi
    fi
}

base () {
    if command -v arch-chroot > /dev/null 2>&1; then
        if [ ! -d "/mnt/etc" ]; then
            echo -e "\n######## Installing base system...\n"
            pacstrap /mnt base linux linux-firmware base-devel vim tree
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

mirrors () {
    if command -v arch-chroot > /dev/null 2>&1; then
        if ! arch-chroot /mnt bash -c 'command -v reflector'; then
            echo -e "\n######## Adding mirrors...\n"
            arch-chroot /mnt bash -c 'pacman -S reflector --noconfirm'
            arch-chroot /mnt bash -c "reflector --verbose --latest 25 --sort rate --save /etc/pacman.d/mirrorlist"
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
            arch-chroot /mnt bash -c "usermod -a -G video ${user_name}" 
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

install_ly () {
    if command -v arch-chroot > /dev/null 2>&1; then
        if ! arch-chroot /mnt bash -c 'systemctl is-enabled ly.service > /dev/null 2>&1'; then
            echo -e "\n######## Installing ly...\n"
            yay -Sy ly-git --noconfirm
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
            sudo systemctl enable dhcpcd@${iname}.service
        fi
    fi
}

install_sway () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if ! command -v sway > /dev/null 2>&1; then
            echo -e "\n######## Installing sway...\n"
            yay -Sy sway-git --noconfirm
        fi
    fi
}

install_git () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if ! command -v git > /dev/null 2>&1; then
            echo -e "\n######## Installing git...\n"
            sudo pacman -Sy git --noconfirm
        fi
    fi
}

install_go () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if ! command -v go > /dev/null 2>&1; then
            echo -e "\n######## Installing go...\n"
            sudo pacman -Sy go --noconfirm
        fi
    fi
}

install_yay () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if ! command -v yay > /dev/null 2>&1; then
            echo -e "\n######## Installing yay...\n"
            cd /home/${user_name}
            rm -rf yay
            git clone https://aur.archlinux.org/yay.git
            cd yay
            makepkg -s
            sudo pacman -U yay*xz --noconfirm
        fi
    fi
}

install_ttf () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if ! pacman -Q noto-fonts > /dev/null 2>&1; then
            echo -e "\n######## Installing ttf font...\n"
            yay -Sy otf-font-awesome --noconfirm
            yay -Sy noto-fonts --noconfirm
        fi
    fi
}


install_zsh () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if ! command -v zsh > /dev/null 2>&1; then
            echo -e "\n######## Installing zsh...\n"
            yay -Sy zsh --noconfirm
            chsh -s /bin/zsh ${user_name}
        fi
    fi
}

install_kitty () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if ! command -v kitty > /dev/null 2>&1; then
            echo -e "\n######## Installing kitty...\n"
            yay -Sy kitty-git --noconfirm
        fi
    fi
}

install_spice () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if ! command -v spice-vdagent > /dev/null 2>&1; then
            echo -e "\n######## Installing spice...\n"
            yay -Sy spice-vdagent --noconfirm
        fi
    fi
}

install_waybar () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if ! command -v waybar > /dev/null 2>&1; then
            echo -e "\n######## Installing waybar...\n"
            yay -Sy waybar --noconfirm
        fi
    fi
}

install_brave () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if ! command -v brave > /dev/null 2>&1; then
            echo -e "\n######## Installing brave...\n"
            yay -Sy brave-bin --noconfirm
        fi
    fi
}

install_wofi () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if ! command -v wofi > /dev/null 2>&1; then
            echo -e "\n######## Installing wofi...\n"
            yay -Sy wofi --noconfirm
        fi
    fi
}

install_pulseaudio () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if ! command -v pulseaudio > /dev/null 2>&1; then
            echo -e "\n######## Installing pulseaudio...\n"
            yay -Sy pulseaudio --noconfirm
        fi
    fi
}

install_oh_my_zsh () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if [ ! -d ~/.oh-my-zsh ]; then
            echo -e "\n######## Installing oh-my-zsh...\n"
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        fi
    fi
}

show_cursor () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if ! grep -q "WLR_NO_HARDWARE_CURSORS" ~/.zshenv; then
            echo -e "\n######## Adding WLR_NO_HARDWARE_CURSORS ...\n"
            echo "export WLR_NO_HARDWARE_CURSORS=1" >> ~/.zshenv
        fi
    fi
}

install_vmtools () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if ! pacman -Q -q xf86-video-vmware; then
            echo -e "\n######## Installing vmtools...\n"
            yay -Sy open-vm-tools xf86-video-vmware --noconfirm
            systemctl enable vmtoolsd.service
            systemctl start vmtoolsd.service
            systemctl enable vmware-vmblock-fuse.service
            systemctl start vmware-vmblock-fuse.service
        fi
    fi
}

autostart_sway () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if ! grep -q "XKB_DEFAULT_LAYOUT" ~/.zshenv; then
            echo -e "\n######## Autostart sway...\n"
            echo -e 'if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then\n  XKB_DEFAULT_LAYOUT=us exec sway\nfi' >> ~/.zshenv
        fi
    fi
}

download_configs () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        echo -e "\n######## Download sway config...\n"
        mkdir -p ~/.config/sway
        curl -fsSL https://raw.githubusercontent.com/Chumper/Arch/master/.config/sway/config -o ~/.config/sway/config
    fi
}

early_kms () {
    if ! command -v arch-chroot > /dev/null 2>&1; then
        if ! grep -q "MODULES=()" /etc/mkinitcpio.conf; then
            echo -e "\n######## Initiate early KMS...\n"
            sed -i .bak 's/MODULES=()/MODULES(amdgpu)/' /etc/mkinitcpio.conf
            mkinitcpio -P
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
mirrors
hostname
hosts
passwd
adduser
grub
# install_ly
dhcp

install_git
install_go
install_yay
install_kitty
install_zsh
install_oh_my_zsh
install_ttf
install_sway
# install_spice
install_waybar
show_cursor
install_vmtools
autostart_sway
install_brave
install_wofi
# install_pulseaudio
download_configs
