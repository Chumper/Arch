#!/usr/bin/env bash

##### CONSTANTS
drive=/dev/sda

partition () {
  if  /sbin/sfdisk -d ${drive} 2>&1 -eq 1; then
    printf "Partitioning..."
    
    available_memory=$(free -m | grep Mem | awk '{print $2}')
    available_disk=$(fdisk -l | grep "${drive}" | awk '{print $5}')
    
    boot_size=500000000 # 500M
    swap_size=(( ${available_memory} / 2 ))
    home_size=(( ${available_disk} - ${boot_size} - ${home_size} ))

    # partition the disk
    echo -e "Total Memory:\t${available_memory}"
    echo -e "Total Disk Size:\t${available_disk}"
    echo -e "--------"
    echo -e "Boot Partition:\t$(numfmt --to=si ${boot_size})"
    echo -e "Swap Partition:\t$(numfmt --to=si ${swap_size})"
    echo -e "Home Partition:\t$(numfmt --to=si ${home_size})" 
  fi
}

### MAIN

partition
