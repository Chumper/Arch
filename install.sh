#!/usr/bin/env bash

##### CONSTANTS
drive=/dev/sda

partition () {
  if  [[ $(/sbin/sfdisk -d ${drive}) =~ "does not contain" ]]; then
    echo "Partitioning..."
    
    available_memory=$(free -m | grep Mem | awk '{print $2}')
    available_disk=$(fdisk -l | grep "${drive}" | aws '{print $5}')
    
    boot_size=500000000 # 500M
    swap_size=$(expr $available_memory / 2)
    home_size=$(expr $available_disk - boot_size - home_size )

    # partition the disk
    echo "Total Memory:\t${$available_memory}"
    echo "Total Disk Size:\t${$available_disk}"
    echo "--------"
    echo "Boot Partition:\t$(numfmt --to=si ${boot_size})"
    echo "Swap Partition:\t$(numfmt --to=si ${swap_size})"
    echo "Home Partition:\t$(numfmt --to=si ${home_size})" 
  fi
}

### MAIN

partition
