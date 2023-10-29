#! /usr/bin/env bash

sudo apt install x11-apps -y

sudo apt install x11-xserver-utils
sudo xmodmap -e "pointer = 3 2 1"
