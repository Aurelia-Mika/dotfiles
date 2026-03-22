#!/bin/bash

env NVPRESENT_ENABLE_SMOOTH_MOTION=1 taskset -c 0-15 gamescope -W 2560 -H 1440 -r 360 -f --adaptive-sync --force-grab-cursor -- flatpak run --file-forwarding org.vinegarhq.Sober

EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ] &&[ $EXIT_CODE -ne 143 ] && [ $EXIT_CODE -ne 137 ]; then
    
    notify-send "Sober" "Błąd uruchomienia (Kod błędu: $EXIT_CODE). Aktualizuję..." -t 4000
    flatpak update -y
    
    notify-send "Sober" "Aktualizacja zakończona. Restart..." -t 3000
    
    env NVPRESENT_ENABLE_SMOOTH_MOTION=1 taskset -c 0-15 gamescope -W 2560 -H 1440 -r 360 -f --adaptive-sync --force-grab-cursor -- flatpak run --file-forwarding org.vinegarhq.Sober
fi
