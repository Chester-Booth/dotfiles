#!/usr/bin/env bash

set -euo pipefail

print_paths=0
print_themes=0
theme_override=""

usage() {
    cat <<'EOF'
Usage: icon-lookup.sh [--theme THEME] [--paths] [--themes]

Print icon names available from the active icon theme and its inherited themes.

Options:
  --theme THEME  Override the detected icon theme.
  --paths        Print "theme<TAB>icon-name<TAB>full-path" instead of just icon names.
  --themes       Print the resolved theme chain and exit.
  -h, --help     Show this help text.
EOF
}

trim() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s\n' "$value"
}

detect_theme() {
    local theme=""

    if command -v gsettings >/dev/null 2>&1; then
        theme="$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null || true)"
        theme="${theme%\'}"
        theme="${theme#\'}"
    fi

    if [[ -z "$theme" && -f "$HOME/.config/gtk-3.0/settings.ini" ]]; then
        theme="$(awk -F= '/^gtk-icon-theme-name=/{print $2; exit}' "$HOME/.config/gtk-3.0/settings.ini")"
    fi

    if [[ -z "$theme" && -f "$HOME/.config/gtk-4.0/settings.ini" ]]; then
        theme="$(awk -F= '/^gtk-icon-theme-name=/{print $2; exit}' "$HOME/.config/gtk-4.0/settings.ini")"
    fi

    theme="$(trim "${theme:-}")"
    printf '%s\n' "${theme:-Adwaita}"
}

find_theme_dir() {
    local theme="$1"
    local candidate

    for candidate in \
        "$HOME/.icons/$theme" \
        "$HOME/.local/share/icons/$theme" \
        "/usr/local/share/icons/$theme" \
        "/usr/share/icons/$theme"
    do
        if [[ -d "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

read_inherits() {
    local theme_dir="$1"
    local inherits=""

    if [[ -f "$theme_dir/index.theme" ]]; then
        inherits="$(awk -F= '/^Inherits=/{print $2; exit}' "$theme_dir/index.theme")"
    fi

    printf '%s\n' "$inherits"
}

resolve_theme_chain() {
    local root_theme="$1"
    local queue=("$root_theme")
    local theme inherits inherited

    declare -gA SEEN_THEMES=()
    declare -ga THEME_CHAIN=()

    while ((${#queue[@]} > 0)); do
        theme="${queue[0]}"
        queue=("${queue[@]:1}")

        [[ -n "${SEEN_THEMES[$theme]:-}" ]] && continue
        SEEN_THEMES["$theme"]=1
        THEME_CHAIN+=("$theme")

        if theme_dir="$(find_theme_dir "$theme" 2>/dev/null)"; then
            inherits="$(read_inherits "$theme_dir")"
            IFS=',' read -r -a inherited <<< "$inherits"

            for inherited_theme in "${inherited[@]}"; do
                inherited_theme="$(trim "$inherited_theme")"
                [[ -n "$inherited_theme" ]] && queue+=("$inherited_theme")
            done
        fi
    done

    if [[ -z "${SEEN_THEMES[hicolor]:-}" ]]; then
        THEME_CHAIN+=("hicolor")
    fi
}

parse_args() {
    while (($# > 0)); do
        case "$1" in
            --theme)
                if (($# < 2)); then
                    printf 'Missing value for --theme\n' >&2
                    exit 1
                fi
                theme_override="$2"
                shift 2
                ;;
            --paths)
                print_paths=1
                shift
                ;;
            --themes)
                print_themes=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                printf 'Unknown option: %s\n' "$1" >&2
                usage >&2
                exit 1
                ;;
        esac
    done
}

main() {
    local theme_dir file base icon_name theme

    parse_args "$@"
    resolve_theme_chain "${theme_override:-$(detect_theme)}"

    if (( print_themes == 1 )); then
        printf '%s\n' "${THEME_CHAIN[@]}"
        exit 0
    fi

    declare -A seen_icons=()

    for theme in "${THEME_CHAIN[@]}"; do
        theme_dir="$(find_theme_dir "$theme" 2>/dev/null || true)"
        [[ -n "$theme_dir" ]] || continue

        while IFS= read -r file; do
            [[ "$file" == */cursors/* ]] && continue

            base="$(basename "$file")"
            icon_name="${base%.*}"

            if (( print_paths == 1 )); then
                printf '%s\t%s\t%s\n' "$theme" "$icon_name" "$file"
                continue
            fi

            if [[ -z "${seen_icons[$icon_name]:-}" ]]; then
                seen_icons["$icon_name"]=1
                printf '%s\n' "$icon_name"
            fi
        done < <(find "$theme_dir" -type f \( -name '*.png' -o -name '*.svg' -o -name '*.xpm' \) | sort)
    done
}

main "$@"
