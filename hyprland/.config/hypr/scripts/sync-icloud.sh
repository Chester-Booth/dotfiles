#!/usr/bin/env bash

set -euo pipefail

exec "${HOME}/.config/hypr/scripts/cloud-bisync.sh" \
    icloud \
    icloud: \
    "${HOME}/Cloud/iCloudDrive"
