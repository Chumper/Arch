#!/usr/bin/env bash

##### CONSTANTS
drive=/dev/sda

partition () {
  if /sbin/sfdisk -d ${drive} 2>&1 ; then
    ### CONSTANTS
    boot_size=512M
    
    printf "Partitioning..."
    
    available_memory=$(free -b | grep Mem | awk '{print $2}')
    available_disk=$(fdisk -l | grep "${drive}" | awk '{print $5}')
    
    swap_size="$(( ${available_memory} / 2 ))""
    home_size="$(( ${available_disk} - $(numfmt --from=iec ${boot_size}) - ${hswap_size} ))""

    # partition the disk
    echo -e "Total Memory:\t\t$(numfmt --to=iec ${available_memory})"
    echo -e "Total Disk Size:\t$(numfmt --to=iec ${available_disk})"
    echo -e "--------"
    echo -e "Boot Partition:\t\t$(numfmt --to=iec ${boot_size})"
    echo -e "Swap Partition:\t\t$(numfmt --to=iec ${swap_size})"
    echo -e "Home Partition:\t\t$(numfmt --to=iec ${home_size})" 
  fi
}

### MAIN

partition
