#!/bin/bash

STATE_FILE="/tmp/waybar-cal-state"
CACHE_DIR="$HOME/.cache/waybar-cal"
MODE_DIR="$HOME/.config/waybar/scripts/cal/modes"

mkdir -p "$CACHE_DIR"

# Check for gcalcli
if ! command -v gcalcli &> /dev/null; then
    jq -nc '{"text": "󰨱", "tooltip": "gcalcli not installed\n\nInstall: pip install gcalcli\nConfigure: gcalcli init"}'
    exit 0
fi

# Get current mode (default: day)
if [ -f "$STATE_FILE" ]; then
    MODE=$(cat "$STATE_FILE")
else
    MODE="day"
    echo "$MODE" > "$STATE_FILE"
fi

# Check cache age (update if older than 1 hour or doesn't exist)
CACHE_FILE="$CACHE_DIR/${MODE}.cache"
CACHE_AGE=3600  # 1 hour in seconds

if [ -f "$CACHE_FILE" ]; then
    CACHE_TIME=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null)
    CURRENT_TIME=$(date +%s)
    AGE=$((CURRENT_TIME - CACHE_TIME))
    
    if [ $AGE -lt $CACHE_AGE ]; then
        # Use cached version
        cat "$CACHE_FILE"
        exit 0
    fi
fi

# Generate fresh content with timeout
OUTPUT=$(timeout 15s "$MODE_DIR/${MODE}.sh" 2>/dev/null)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 124 ]; then
    # Timeout occurred
    jq -nc '{"text": "󰨱", "tooltip": "Calendar loading timed out\nTry again or check gcalcli"}'
    exit 1
fi

if [ -z "$OUTPUT" ]; then
    jq -nc '{"text": "󰨱", "tooltip": "Error generating calendar view"}'
    exit 1
fi

# Cache the output
echo "$OUTPUT" > "$CACHE_FILE"

# Return the output
echo "$OUTPUT"
