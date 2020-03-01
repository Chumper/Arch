#!/usr/bin/env bash

if [[ $(swaymsg -t get_outputs -r | jq '.[0].modes[] | select(.width == 3440 and .height == 1440) | .' | wc -l) -eq 0 ]]; then
    swaymsg output "Virtual-1" scale 2
else
    swaymsg output "Virtual-1" scale 1
fi 
