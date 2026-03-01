#!/bin/bash

# Get month calendar - use timeout to prevent hanging
month_cal=$(timeout 10s gcalcli --nocolor calm 2>/dev/null)

# Check if we got output
if [ -z "$month_cal" ] || [ $? -ne 0 ]; then
    tooltip="󰸗 Month View

Unable to load month calendar

Right-click to cycle modes"
else
    tooltip="󰸗 Month View

$month_cal

Right-click to cycle modes"
fi

# Output JSON
jq -nc --arg tooltip "$tooltip" '{"text": "󰸗", "tooltip": $tooltip}'

