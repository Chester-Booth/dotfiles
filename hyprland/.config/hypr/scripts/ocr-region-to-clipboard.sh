#!/usr/bin/env sh

set -eu

required_tools="grim slurp tesseract wl-copy"

for tool in $required_tools; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf '%s\n' "Missing required command: $tool" >&2
        exit 1
    fi
done

tmp_file="$(mktemp --suffix=.png)"
trap 'rm -f "$tmp_file"' EXIT INT TERM HUP

selection="$(slurp)" || exit 0
[ -n "$selection" ] || exit 0

grim -g "$selection" "$tmp_file"

ocr_text="$(tesseract "$tmp_file" stdout -l eng --psm 6 quiet 2>/dev/null | sed '/^[[:space:]]*$/d')"
[ -n "$ocr_text" ] || exit 0

printf '%s' "$ocr_text" | wl-copy

title="Text copied to clipboard"
text="$ocr_text"
notify-send "$title" "$text"
