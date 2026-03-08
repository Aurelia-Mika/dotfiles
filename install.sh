#!/bin/bash

if ! grep -qi "cachyos" /etc/os-release; then
    uname -a
    echo "It not CachyOS"
    exit 1
fi

source ./biblioteka.sh

installation

if sudo sbctl status | grep "Setup Mode:" | grep -q "Enabled"; then
    Secure_Boot_Setup
fi

base_conf
bootloader
apparmor
