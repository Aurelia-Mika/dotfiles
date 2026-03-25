#!/bin/bash

PACKAGES=(
        sbctl
        appmenu-gtk-module
        libdbusmenu-glib
        flatpak
        cachyos-samba-settings
        apparmor 
        apparmor.d
        grub-btrfs-support
        btrfs-assistant-launcher
        linux-cachyos-bore
        cachyos-gaming-meta
        cachyos-gaming-applications
        cachyos/umu-launcher
        proton-cachyos-slr
        protonup-qt
        easyeffects
        lsp-plugins-lv2
        zam-plugins
        calf
        mda.lv2
        obs-studio-browser
        thunar
        thunar-archive-plugin
        thunar-media-tags-plugin
        thunar-volman
        tumbler
        ffmpegthumbnailer
        thunar-vcs-plugin
        gvfs 
        gvfs-mtp 
        gvfs-smb 
        gvfs-afc 
        gvfs-gphoto2
        vesktop
        libqalculate
        qalculate-gtk
        keepassxc
        krita
        gimp
        thunderbird
        prismlauncher
        lact
        calibre
        librevenge
        libreoffice-still
        signal-desktop
        jdk8-openjdk
        jdk11-openjdk
        jdk17-openjdk
        jdk21-openjdk
        yazi
        awww
        mpvpaper
        hyprpaper
        jq
    )
PACKAGES_FLATPAK=(
        it.mijorus.gearlever
        com.spotify.Client
        org.vinegarhq.Sober
        com.moonlight_stream.Moonlight
        md.obsidian.Obsidian
        net.ankiweb.Anki
        org.texmacs.TeXmacs
        io.github.wxmaxima_developers.wxMaxima
    )

installation() {
    sudo chwd -a
    sudo cachyos-rate-mirrors
    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm "${PACKAGES[@]}"
    tldr --update
    flatpak install -y flathub "${PACKAGES_FLATPAK[@]}"
    paru -S brother-dcp7065dn 
}

Secure_Boot_Setup() {
    sudo sbctl create-keys # Create your custom secure boot keys
    sudo sbctl enroll-keys --microsoft # Enroll your keys with Microsoft's keys
    sudo sbctl-batch-sign
    sudo sbctl verify
    sudo sbctl sign -s -o /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed /usr/lib/systemd/boot/efi/systemd-bootx64.efi
}

base_conf() {
    sudo ufw enable
    sudo sed -i 's/^#WIRELESS_REGDOM="PL"/WIRELESS_REGDOM="PL"/' /etc/conf.d/wireless-regdom #Set Wi-Fi Regulatory Domain to Poland
    mkdir -p ~/.config/environment.d
    touch ~/.config/environment.d/gaming.conf
    echo "__GL_SHADER_DISK_CACHE_SIZE=50000000000" > ~/.config/environment.d/gaming.conf
}

apparmor() {
    sudo sed -i '/^options/ s/$/ lsm=landlock,lockdown,yama,integrity,apparmor,bpf' /boot/loader/entries/linux-cachyos-bore.conf
    sudo systemctl enable --now apparmor.service
    cat <<EOF | sudo tee /etc/apparmor/parser.conf > /dev/null
write-cache
Optimize=compress-fast
cache-loc /etc/apparmor/earlypolicy/
EOF
}

bootloader() {
    cat <<EOF | sudo tee /boot/loader/loader.conf > /dev/null
default linux-cachyos-bore.conf
timeout 4
console-mode keep
EOF
}