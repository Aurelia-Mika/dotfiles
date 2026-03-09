#!/bin/bash

WALLPAPER_ROOT="$HOME/.config/hypr/Wallpapers"
LOG_FILE="$WALLPAPER_ROOT/logs/$(date "+%d %B %H:%M:%S").log"
DAY_START=7
DAY_END=19
core_folders=(
    "$WALLPAPER_ROOT"
    "$WALLPAPER_ROOT/horizontal"
    "$WALLPAPER_ROOT/horizontal/day"
    "$WALLPAPER_ROOT/horizontal/night"
    "$WALLPAPER_ROOT/vertical"
    "$WALLPAPER_ROOT/vertical/day"
    "$WALLPAPER_ROOT/vertical/night"
    )

setup_monitors_and_daemon(){
    start_daemon_if_not_working
    while read -r name orientation; do
        manage_monitor "$name" "$orientation" &
        log "Monitor: $name, orientation: $orientation"
    done < <(check_orientation)
}

manage_monitor() {
    local monitor_name=$1
    local orientation=$2
    
    local search_dir="$WALLPAPER_ROOT/$orientation"
    
    while true; do
        local wallpaper=""

        if is_daytime; then
            wallpaper=$(choice_wallpaper "day" "night" "$search_dir" "$monitor_name")
        else
            wallpaper=$(choice_wallpaper "night" "night" "$search_dir" "$monitor_name")
        fi

        set_wallpaper "$monitor_name" "$orientation" "$wallpaper" "$search_dir"

        local sleep_time=$(( RANDOM % 3601 + 1800 ))
        log_sleep_info "$monitor_name" "$sleep_time"
        sleep "$sleep_time"
    done
}

choice_wallpaper(){
    local search_dir="$3"
    local monitor_name="$4"
    local wallpaper=$(find "$search_dir/$1" "$search_dir/$2" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) 2>/dev/null | shuf -n 1)
    local short_path="${wallpaper#"$HOME/.config/hypr/"}"
    echo "$wallpaper"
    if [ -n "$wallpaper" ]; then
        log "$short_path was chosen for $monitor_name"
    else
        local count=$(find "$search_dir/$1" "$search_dir/$2" -maxdepth 1 -type f 2>/dev/null | wc -l)
        log "$short_path is empty ($count files)"
    fi
}

set_wallpaper(){
    local monitor_name="$1"
    local orientation="$2"
    local wallpaper="$3"
    local search_dir="$4"
    local short_path="${wallpaper#"$HOME/.config/hypr/"}"

    if [ -n "$wallpaper" ]; then
        swww img -o "$monitor_name" "$wallpaper" --transition-type center &>/dev/null
        log "Monitor $monitor_name: set $short_path"
    else

        log "Błąd: Brak tapet w folderach dla $monitor_name ($orientation)"
        log "Number of files in $short_path: $(find "$search_dir" -type f 2>/dev/null | wc -l)"
    fi
}

# lowlevel logic

start_daemon_if_not_working(){
    if ! pgrep -x "swww-daemon" > /dev/null; then

        swww-daemon &>/dev/null &
        # Wait for swww to respond
        local timeout=10
        while [ $timeout -gt 0 ]; do
            if swww query &>/dev/null; then break; fi
            sleep 0.5
            ((timeout--))
        done
    fi
}

check_orientation(){
    hyprctl monitors -j | jq -r '.[] | "\(.name) \(.transform)"' | while read -r name transform; do
        if [[ "$transform" -eq 1 || "$transform" -eq 3 ]]; then
            local orientation="vertical"
        else
            local orientation="horizontal"
        fi
        sleep 0.1
        echo "$name $orientation"
    done
}


init_folders() {
    created=$(make_folders "${core_folders[@]}")

    if (( created )); then
    noti "Please Add Wallpapers to $WALLPAPER_ROOT" 30000 "critical"
    fi
}

make_folders(){
    for folder in "$@"; do
        if [ ! -d "$folder" ]; then
            mkdir -p "$folder"
            log "Folder $folder created."
            made_any="1"
        fi
    done
    echo "$made_any"
}

is_daytime() {
    local hour
    hour=$(date +%-H)
    (( hour >= DAY_START && hour < DAY_END ))
}

# diagnostic tools
noti(){
    notify-send "Wallpaper Script" \
    "$1" \
    -t "${2:-100}" -u "${3:-low}"
    log "$1"
}

log(){
    echo "$(date +%H:%M:%S): $1">>"$LOG_FILE"
}

log_sleep_info() {
    local monitor_name="$1"
    local seconds="$2"
    local hour=$(( seconds / 3600 ))
    local minutes=$(( (seconds % 3600) / 60 ))
    log "$monitor_name: next change in $(printf "%02d:%02d" $hour $minutes)"
}

initialize_environment(){
    if [ ! -d "$WALLPAPER_ROOT/logs" ]; then
        mkdir -p "$WALLPAPER_ROOT/logs"
        log "Folder $WALLPAPER_ROOT/logs has been created."
        created=1
    fi
    ls -1t "$WALLPAPER_ROOT/logs/"*.log 2>/dev/null | tail -n +6 | xargs -d '\n' -r rm --
    for folder in "${core_folders[@]}"; do
        if [ ! -d "$folder" ]; then
            noti  "Folder $folder does not exist." 1000
            init_folders
        fi
    done
}

initialize_environment
setup_monitors_and_daemon