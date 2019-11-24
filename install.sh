#!/usr/bin/env bash

##### CONSTANTS
drive=/dev/sda

partition () {
  if  [[ $(/sbin/sfdisk -d ${drive} 2>&1) =~ "does not contain" ]]; then
    printf "Partitioning..."
    
    available_memory=$(free -m | grep Mem | awk '{print $2}')
    available_disk=$(fdisk -l | grep "${drive}" | awk '{print $5}')
    
    boot_size=500000000 # 500M
    swap_size=$(expr ${available_memory} / 2)
    home_size=$(expr ${available_disk} - ${boot_size} - ${home_size} )

    # partition the disk
    printf "Total Memory:\t${available_memory}"
    printf "Total Disk Size:\t${available_disk}"
    printf "--------"
    printf "Boot Partition:\t$(numfmt --to=si ${boot_size})"
    printf "Swap Partition:\t$(numfmt --to=si ${swap_size})"
    printf "Home Partition:\t$(numfmt --to=si ${home_size})" 
  fi
}

### MAIN

partition
