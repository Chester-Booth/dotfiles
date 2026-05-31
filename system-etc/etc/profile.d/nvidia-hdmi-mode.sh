#!/bin/bash

# Check if we booted with modeset=1 (HDMI mode)
if grep -q "nvidia-drm.modeset=1" /proc/cmdline; then
	export AQ_DRM_DEVICES=/dev/dri/card0:/dev/dri/card1
	export LIBVA_DRIVER_NAME=nvidia
	export __GLX_VENDOR_LIBRARY_NAME=nvidia
	export GBM_BACKEND=nvidia-drm
	export WLR_NO_HARDWARE_CURSORS=1
fi
