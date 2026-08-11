#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    open | generateCurrent | status | cancel)
        action=$1
        ;;
    *)
        echo "Usage: picker-ipc.sh {open|generateCurrent|status|cancel}" >&2
        exit 2
        ;;
esac

main_pid=""
while IFS= read -r process_id; do
    command=()
    mapfile -d '' -t command < "/proc/$process_id/cmdline" 2>/dev/null || continue
    if ((${#command[@]} == 1)) && [[ "${command[0]##*/}" == "quickshell" ]]; then
        main_pid=$process_id
        break
    fi
done < <(pgrep -x quickshell | sort -n)

if [[ -z "$main_pid" ]]; then
    echo "The main Quickshell instance is not running" >&2
    exit 1
fi

exec quickshell ipc --pid "$main_pid" call themePicker "$action"
