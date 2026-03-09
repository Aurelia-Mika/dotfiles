#!/bin/bash

WALLPAPER_ROOT="$HOME/.config/hypr/Wallpapers"

DAY_START=7
DAY_END=19

# create folder tree
init_folders() {
    local folders=(
        "$WALLPAPER_ROOT"
        "$WALLPAPER_ROOT/horizontal"
        "$WALLPAPER_ROOT/horizontal/day"
        "$WALLPAPER_ROOT/horizontal/night"
        "$WALLPAPER_ROOT/vertical"
        "$WALLPAPER_ROOT/vertical/day"
        "$WALLPAPER_ROOT/vertical/night"
    )

    for folder in "${folders[@]}"; do
        if [ ! -d "$folder" ]; then
            echo "Tworzenie folderu: $folder"
            mkdir -p "$folder"
            notify-send "Wallpaper Script" "Folder $folder created." -t 100 -u low
            missing=1
        fi
    done
    if (( missing )); then
    notify-send "Wallpaper Script" \
    "Please Add Wallpapers to $WALLPAPER_ROOT" \
    -t 30000 -u critical
fi
}

manage_monitor() {
    local monitor_name=$1
    local orientation=$2
    
    local search_dir="$WALLPAPER_ROOT/$orientation"
    
    if [ ! -d "$search_dir/day" ] || [ ! -d "$search_dir/night" ]; then
        notify-send "Wallpaper Script" "Folder $search_dir does not exist." -t 5000
        init_folders
        return 1
    fi

    while true; do

        local current_hour=$(date +%H)
        local wallpaper=""

        if [ "$current_hour" -ge "$DAY_START" ] && [ "$current_hour" -lt "$DAY_END" ]; then
            wallpaper=$(find "$search_dir/day" "$search_dir/night" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) 2>/dev/null | shuf -n 1)
        else
            wallpaper=$(find "$search_dir/night" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) 2>/dev/null | shuf -n 1)
        fi

        if [ -n "$wallpaper" ]; then
            swww img -o "$monitor_name" "$wallpaper" --transition-type center &>/dev/null
            echo "Monitor $monitor_name: set $wallpaper"
        else
            echo "Błąd: Brak tapet w folderach dla $monitor_name ($orientation)"
        fi

        local sleep_time=$(( RANDOM % 3601 + 1800 ))
        sleep "$sleep_time"
    done

}

start_wallpaper_daemon() {
    # start swww if not working
    if ! pgrep -x "swww-daemon" > /dev/null; then

        swww-daemon &>/dev/null &
        # Wait to respond swww
        local timeout=10
        while [ $timeout -gt 0 ]; do
            if swww query &>/dev/null; then break; fi
            sleep 0.5
            ((timeout--))
        done
    fi

    hyprctl monitors -j | jq -r '.[] | "\(.name) \(.width) \(.height) \(.transform)"' | while read -r name width height transform; do
        if [[ "$transform" -eq 1 || "$transform" -eq 3 ]]; then
            if [ "$width" -gt "$height" ]; then
                local orientation="vertical"
            else
                local orientation="horizontal"
            fi
        else
            if [ "$width" -gt "$height" ]; then
                local orientation="horizontal"
            else
                local orientation="vertical"
            fi
        fi
        sleep 0.1
            manage_monitor "$name" "$orientation" &
    done
}

start_wallpaper_daemon