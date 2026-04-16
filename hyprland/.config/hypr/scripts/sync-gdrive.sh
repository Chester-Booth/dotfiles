#!/usr/bin/env bash

set -euo pipefail

exec "${HOME}/.config/hypr/scripts/cloud-bisync.sh" \
    gdrive \
    gdrive: \
    "${HOME}/Cloud/GoogleDrive" \
    --drive-export-formats docx,xlsx,pptx,svg
