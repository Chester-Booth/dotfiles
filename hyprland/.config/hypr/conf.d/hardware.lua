-- NVIDIA HDMI modes.

-- Check if HDMI mode is enabled and set appropriate GPU.
-- This is intentionally first so later monitor/GPU config can be overridden.
pcall(require, "hdmi-override")

-- Default GPU configuration for battery mode.
-- This will be overridden by hdmi-override.lua if in HDMI mode.
-- hl.env("AQ_DRM_DEVICES", "/dev/dri/card1:/dev/dri/card0")
