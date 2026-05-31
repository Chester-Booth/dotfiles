# Boot Themes

This repo vendors the active SDDM theme and the matching GRUB theme.

- SDDM source: `sddm/usr/share/sddm/themes/sddm-astronaut-theme`
- GRUB source: `grub/usr/share/grub/themes/blox-astronaut`
- GRUB drop-ins: `grub/etc/default/grub.d`
- GRUB scripts: `grub/etc/grub.d`
- mkinitcpio resume hook: `initcpio`

The SDDM theme is based on Keyitdev's `sddm-astronaut-theme`, which is
GPL-3.0-or-later. Its upstream license is preserved at
`sddm/usr/share/sddm/themes/sddm-astronaut-theme/LICENSE`

GRUB cannot play videos or apply QML shader blur at boot. The matching GRUB
theme therefore uses a captured SDDM-rendered background in `background.png`,
plus GRUB-converted PF2 fonts generated from the vendored SDDM fonts.

Install or refresh the live links with:

```sh
sudo bin/install-boot-themes
```

The SDDM theme is copied into `/usr/share/sddm/themes/sddm-astronaut-theme`.
SDDM runs as its own user and cannot reliably traverse a private home directory,
so a direct symlink into this repo can break login. The copied tree is kept in
sync by rerunning `sudo bin/install-boot-themes`.

The GRUB source is symlinked at `/usr/share/grub/themes/blox-astronaut` for
normal system-side discovery, but the configured boot theme is copied into
`/boot/grub/themes/blox-astronaut`; `/boot` is a FAT partition on this machine,
so it cannot store Unix symlinks and GRUB needs the theme available before
Linux mounts the root filesystem.
