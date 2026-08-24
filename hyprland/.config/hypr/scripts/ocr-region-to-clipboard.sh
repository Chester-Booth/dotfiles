#!/usr/bin/env sh

set -eu

freeze=0
case "${1:-}" in
	"") ;;
	--freeze) freeze=1 ;;
	*)
		printf '%s\n' "Usage: $(basename "$0") [--freeze]" >&2
		exit 2
		;;
esac

required_tools="grim slurp tesseract wl-copy"
[ "$freeze" -eq 1 ] && required_tools="$required_tools hyprshot"

for tool in $required_tools; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		printf '%s\n' "Missing required command: $tool" >&2
		exit 1
	fi
done

tmp_file="$(mktemp --suffix=.png)"
trap 'rm -f "$tmp_file"' EXIT INT TERM HUP

if [ "$freeze" -eq 1 ]; then
	hyprshot -m region --freeze --raw > "$tmp_file"
else
	selection="$(slurp)" || exit 0
	[ -n "$selection" ] || exit 0

	grim -g "$selection" "$tmp_file"
fi

ocr_text="$(tesseract "$tmp_file" stdout -l eng --psm 6 quiet 2>/dev/null | sed '/^[[:space:]]*$/d')"
[ -n "$ocr_text" ] || exit 0

printf '%s' "$ocr_text" | wl-copy

title="Text copied to clipboard"
text="$ocr_text"
notify-send "$title" "$text"
