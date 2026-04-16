#!/usr/bin/env bash

set -euo pipefail

name="${1:?sync name required}"
remote="${2:?remote required}"
local_dir="${3:?local dir required}"
shift 3

state_root="${XDG_STATE_HOME:-${HOME}/.local/state}/rclone"
work_dir="${state_root}/bisync/${name}"
log_dir="${state_root}/logs"
log_file="${log_dir}/${name}-bisync.log"
marker_file="${work_dir}/.initialized"

mkdir -p "${local_dir}" "${work_dir}" "${log_dir}"

if mountpoint -q "${local_dir}"; then
    fs_type="$(findmnt -n -o FSTYPE "${local_dir}" || true)"
    if [[ "${fs_type}" == "fuse.rclone" ]]; then
        fusermount3 -u "${local_dir}" 2>/dev/null || \
            fusermount -u "${local_dir}" 2>/dev/null || \
            umount "${local_dir}"
    else
        echo "Refusing to sync into mounted path: ${local_dir}" >&2
        exit 1
    fi
fi

common_flags=(
    --workdir "${work_dir}"
    --log-file "${log_file}"
    --log-level INFO
    --resilient
    --recover
    --create-empty-src-dirs
)

if [[ ! -f "${marker_file}" ]]; then
    rclone bisync "${local_dir}" "${remote}" \
        "${common_flags[@]}" \
        --resync-mode newer \
        "$@"
    touch "${marker_file}"
    exit 0
fi

exec rclone bisync "${local_dir}" "${remote}" \
    "${common_flags[@]}" \
    --track-renames \
    "$@"
