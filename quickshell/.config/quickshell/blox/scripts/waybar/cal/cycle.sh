#!/bin/bash

STATE_FILE="/tmp/waybar-cal-state"
CACHE_DIR="$HOME/.cache/waybar-cal"

# Mode order: day -> agenda -> week -> month -> day "day" "week" "month"
MODES=( "agenda" "day" "week"  )

# Get current mode
if [ -f "$STATE_FILE" ]; then
    CURRENT_MODE=$(cat "$STATE_FILE")
else
    CURRENT_MODE="day"
fi

# Find current mode index
CURRENT_INDEX=0
for i in "${!MODES[@]}"; do
    if [ "${MODES[$i]}" = "$CURRENT_MODE" ]; then
        CURRENT_INDEX=$i
        break
    fi
done

# Get next mode
NEXT_INDEX=$(( (CURRENT_INDEX + 1) % ${#MODES[@]} ))
NEXT_MODE="${MODES[$NEXT_INDEX]}"

# Save new mode
echo "$NEXT_MODE" > "$STATE_FILE"

# Clear all caches to force refresh
rm -f "$CACHE_DIR"/*.cache

# Waybar will refresh on its interval