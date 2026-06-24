-- Use NVIDIA as primary for HDMI output.
hl.env("AQ_DRM_DEVICES", "/dev/dri/nvidia-dgpu:/dev/dri/amd-igpu")

-- Keep NVIDIA settings.
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("WLR_NO_HARDWARE_CURSORS", "1")

-- Example monitor config (adjust to your needs).
hl.monitor({ output = "eDP-1", mode = "1920x1080@144", position = "0x0", scale = 1.25 })
hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto", scale = 1 })
