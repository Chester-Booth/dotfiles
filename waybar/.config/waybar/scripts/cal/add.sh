#!/bin/bash

CACHE_DIR="$HOME/.cache/waybar-cal"

# Function to clear caches
clear_caches() {
    rm -f "$CACHE_DIR"/*.cache
}

# Launch kitty with interactive event creation
kitty --class cal --title cal bash -c '
echo "╔════════════════════════════════════════╗"
echo "║    󰢧 Add New Calendar Event            ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Get event title
echo -n "Event title: "
read -r title
if [ -z "$title" ]; then
    echo "󰃴 No title provided. Cancelled."
    echo ""
    echo "Press Enter to close..."
    read
    exit 1
fi

# Get event date
echo ""
echo "Date (examples: today, tomorrow, 2026-02-15, next friday):"
echo -n "Date: "
read -r date
if [ -z "$date" ]; then
    date="today"
fi

# Get start time
echo ""
echo "Start time (examples: 2pm, 14:00, 9:30am):"
echo -n "Start: "
read -r start_time
if [ -z "$start_time" ]; then
    echo "󰃴 No start time provided. Cancelled."
    echo ""
    echo "Press Enter to close..."
    read
    exit 1
fi

# Get duration
echo ""
echo "Duration (examples: 1h, 30m, 2h30m, or leave empty for 1 hour):"
echo -n "Duration: "
read -r duration
if [ -z "$duration" ]; then
    duration="1h"
fi

# Get location (optional)
echo ""
echo "Location (optional, press Enter to skip):"
echo -n "Location: "
read -r location

# Get description (optional)
echo ""
echo "Description (optional, press Enter to skip):"
echo -n "Description: "
read -r description

# Build gcalcli command
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "󰺎 Adding event..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cmd="gcalcli add --title \"$title\" --when \"$date $start_time\" --duration \"$duration\""
[ -n "$location" ] && cmd="$cmd --where \"$location\""
[ -n "$description" ] && cmd="$cmd --description \"$description\""

# Execute the command
if eval "$cmd" 2>&1; then
    echo ""
    echo "󰃯 Event added successfully!"
    
    # Clear waybar calendar cache to force refresh
    rm -f "$HOME/.cache/waybar-cal"/*.cache
    
    echo ""
    echo "Summary:"
    echo "  Title: $title"
    echo "  When: $date $start_time"
    echo "  Duration: $duration"
    [ -n "$location" ] && echo "  Where: $location"
    [ -n "$description" ] && echo "  Description: $description"
else
    echo ""
    echo "󰃴 Failed to add event"
    echo "Please check your input and try again"
fi

echo ""
echo "Press Enter to close..."
read
'

# Clear caches after the window closes
clear_caches