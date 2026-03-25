#!/bin/bash

WALLPAPER_ROOT="$HOME/.config/hypr/Wallpapers"
LOG_DIR="$HOME/.local/log/wallpaper"
LOG_FILE="$LOG_DIR/$(date "+%d-%b-%H:%M:%S").log"
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
WALLPAPERS_IN_USE_DIR="/tmp/wallpaper.sh"
TRANSITION_TYPE="wipe"
SLEEP_MIN=1800
SLEEP_MAX=7200
TRANSITION_DURATION=1  # seconds
TRANSITION_FPS=60

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

        if [ -n "$wallpaper" ]; then
            echo "$wallpaper" > "$WALLPAPERS_IN_USE_DIR/$monitor_name"
    
            local sleep_time=$(( RANDOM % (SLEEP_MAX - SLEEP_MIN + 1) + SLEEP_MIN ))
            log_sleep_info "$monitor_name" "$sleep_time"
            sleep "$sleep_time"
            rm -f "$WALLPAPERS_IN_USE_DIR/$monitor_name"
        else
            sleep 5
        fi
    done
}

choice_wallpaper(){
    local search_dir="$3"
    local monitor_name="$4"
    local wallpaper
    wallpaper=$(find "$search_dir/$1" "$search_dir/$2" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" -o -name "*.tiff" -o -name "*.webp" \) 2>/dev/null \
        | grep -Fxv -f <(ls "$WALLPAPERS_IN_USE_DIR"/ 2>/dev/null | xargs -I {} cat "$WALLPAPERS_IN_USE_DIR/{}" || echo "") \
        | shuf -n 1)
    local short_path="${wallpaper#"$HOME/.config/hypr/Wallpapers/"}"
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
    local short_path="${wallpaper#"$HOME/.config/hypr/Wallpapers/"}"
    
    log "DEBUG: set_wallpaper called - monitor=$monitor_name, wallpaper=$wallpaper"
    
    if [ -n "$wallpaper" ]; then
        local angle=$((RANDOM % 360))
        log "DEBUG: Running awww img command with angle=$angle, fps=$TRANSITION_FPS"
        
        timeout 5 awww img -o "$monitor_name" "$wallpaper" \
            --transition-type "$TRANSITION_TYPE" \
            --transition-angle "$angle" \
            --transition-duration "$TRANSITION_DURATION" \
            --transition-fps "$TRANSITION_FPS"
        
        local result=$?
        log "DEBUG: awww result code: $result"
        
        if [ $result -eq 0 ]; then
            log "Monitor $monitor_name: set $short_path"
        else
            log "Błąd: awww failed (code $result) dla $monitor_name"
        fi
    else
        log "Błąd: Brak tapet w folderach dla $monitor_name ($orientation)"
    fi
}

# lowlevel logic

start_daemon_if_not_working(){
    if ! pgrep -x "awww-daemon" > /dev/null; then
        awww-daemon &>/dev/null &
        log "Wait for awww to respond"
        local timeout=10
        while [ $timeout -gt 0 ]; do
            if awww query &>/dev/null; then break; fi
            sleep 0.5
            ((timeout--))
        done
    fi
}

check_orientation(){
    if ! command -v hyprctl &> /dev/null; then
        log "Błąd: hyprctl nie znaleziony"
        return 1
    fi
    
    hyprctl monitors -j | jq -r '.[] | "\(.name) \(.transform)"' 2>/dev/null | while read -r name transform; do
        if [[ "$transform" =~ ^[0-3]$ ]]; then
            if [[ "$transform" -eq 1 || "$transform" -eq 3 ]]; then
                local orientation="vertical"
            else
                local orientation="horizontal"
            fi
            sleep 0.1
            echo "$name $orientation"
        else
            log "Błąd: Nieznana orientacja $transform dla $name"
        fi
    done
}


init_folders() {
    created=$(make_folders "${core_folders[@]}")

    if (( created )); then
    noti "Please Add Wallpapers to $WALLPAPER_ROOT" 30000 "critical"
    fi
}

make_folders(){
    local made_any="0"
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
    local hour=$(date +%-H)
    (( hour >= DAY_START && hour < DAY_END ))
}

# diagnostic tools
noti(){
    notify-send "Wallpaper Script" "$1" -t "${2:-100}" -u "${3:-low}"
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
    local second=$(( seconds % 60 ))
    log "$monitor_name: next change in $(printf "%02d:%02d:%02d" $hour $minutes $second)"
}

initialize_environment(){
    log "Wallpaper Script started"
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        log "Folder $LOG_DIR has been created."
    fi
    ls -1t "$LOG_DIR/"*.log 2>/dev/null | tail -n +6 | xargs -d '\n' -r rm --
    log "Wallpaper Script has deleted old log"
    for folder in "${core_folders[@]}"; do
        if [ ! -d "$folder" ]; then
            noti  "Folder $folder does not exist." 1000
            init_folders
        fi
    done
    mkdir -p "$WALLPAPERS_IN_USE_DIR"
}

cleanup() {
    log "Wallpaper Script stopped gracefully"
    rm -rf "$WALLPAPERS_IN_USE_DIR"
}

trap 'cleanup; exit 0' SIGTERM SIGINT
initialize_environment
setup_monitors_and_daemon