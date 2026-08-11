# Showcase font packages

Reviewed against the Arch repositories and AUR on 9 August 2026.  The values
in the **Fontconfig family** columns are the strings to put in a theme source,
not friendly font names.  Use the `Mono` Nerd Font family for terminal and
editor roles so powerline and icon glyphs keep a fixed cell width.

Package versions change; install by the exact package names below. `extra`
means the official Arch repository, `AUR` means an AUR helper is required,
and `upstream` means installing the checked-in font files from the linked
project. Outfit, Alegreya, and Space Grotesk no longer have live AUR recipes.

| Theme | UI | Mono | Panel |
| --- | --- | --- | --- |
| Catppuccin Latte | `ttf-nunito` (extra, LicenseRef-OFL-1.1), `Nunito` | `ttf-cascadia-code-nerd` (extra, OFL-1.1-RFN), `CaskaydiaCove Nerd Font Mono` | `ttf-cascadia-code-nerd` (extra, OFL-1.1-RFN), `CaskaydiaCove Nerd Font Propo` |
| Catppuccin Frappé | `ttf-rubik-vf` (AUR, OFL), `Rubik` | `ttf-victor-mono-nerd` (extra, OFL-1.1-no-RFN), `VictorMono Nerd Font Mono` | `ttf-victor-mono-nerd` (extra, OFL-1.1-no-RFN), `VictorMono Nerd Font Propo` |
| Catppuccin Macchiato | `lexend-fonts-git` (AUR, custom:OFL-1.1), `Lexend` | `ttf-iosevka-nerd` (extra, OFL-1.1-no-RFN), `Iosevka Nerd Font Mono` | `ttf-iosevka-nerd` (extra, OFL-1.1-no-RFN), `Iosevka Nerd Font Propo` |
| Catppuccin Mocha | [Outfit Fonts](https://github.com/Outfitio/Outfit-Fonts) (upstream, OFL-1.1), `Outfit` | `ttf-firacode-nerd` (extra, OFL-1.1-no-RFN), `FiraCode Nerd Font Mono` | `ttf-firacode-nerd` (extra, OFL-1.1-no-RFN), `FiraCode Nerd Font Propo` |
| Gruvbox Dark | `ttf-alegreya-sans` (AUR, custom:OFL), `Alegreya Sans` | `ttf-ibm-plex` (extra, custom:OFL), `IBM Plex Mono` | `otf-monaspace-nerd` (extra, OFL-1.1-RFN), `MonaspiceAr Nerd Font Propo` |
| Gruvbox Light | [Alegreya](https://github.com/huertatipografica/Alegreya) (upstream, OFL-1.1), `Alegreya` | `ttf-recursive` (AUR, OFL), `Recursive Mono Linear Static` | `otf-monaspace-nerd` (extra, OFL-1.1-RFN), `MonaspiceRn Nerd Font Propo` |
| Nord | `ttf-atkinson-hyperlegible` (extra, OFL), `Atkinson Hyperlegible` | `ttf-hack-nerd` (extra, Bitstream-Vera and MIT), `Hack Nerd Font Mono` | `ttf-hack-nerd` (extra, Bitstream-Vera and MIT), `Hack Nerd Font Propo` |
| Solarized Dark | `adobe-source-sans-fonts` (extra, OFL-1.1), `Source Sans 3` | `ttf-sourcecodepro-nerd` (extra, OFL-1.1-RFN), `SauceCodePro Nerd Font Mono` | `ttf-sourcecodepro-nerd` (extra, OFL-1.1-RFN), `SauceCodePro Nerd Font Propo` |
| Solarized Light | `ttf-lato` (extra, custom:OFL), `Lato` | `ttf-ubuntu-mono-nerd` (extra, LicenseRef-Ubuntu-Font-License-1.0), `UbuntuMono Nerd Font Mono` | `ttf-ubuntu-mono-nerd` (extra, LicenseRef-Ubuntu-Font-License-1.0), `UbuntuMono Nerd Font Propo` |
| Tokyo Night | [Space Grotesk](https://github.com/floriankarsten/space-grotesk) (upstream, OFL-1.1), `Space Grotesk` | `ttf-jetbrains-mono-nerd` (extra, OFL-1.1-no-RFN), `JetBrainsMono Nerd Font Mono` | `ttf-jetbrains-mono-nerd` (extra, OFL-1.1-no-RFN), `JetBrainsMono Nerd Font Propo` |
| Dracula | `ttf-fira-sans` (extra, custom:OFL), `Fira Sans` | `otf-monaspace-nerd` (extra, OFL-1.1-RFN), `MonaspiceNe Nerd Font Mono` | `otf-monaspace-nerd` (extra, OFL-1.1-RFN), `MonaspiceNe Nerd Font Propo` |
| Kanagawa | `noto-fonts` (extra, OFL-1.1-no-RFN), `Noto Serif` | `otf-commit-mono-nerd` (extra, OFL-1.1-no-RFN), `CommitMono Nerd Font Mono` | `otf-commit-mono-nerd` (extra, OFL-1.1-no-RFN), `CommitMono Nerd Font Propo` |

## Required source-name changes

The design-plan names below do not resolve from the named package.  Use the
documented values in the table when writing the theme JSON:

| Theme | Plan name | Use instead | Reason |
| --- | --- | --- | --- |
| Catppuccin Latte | `Nunito Sans`; `Nunito Sans SemiCondensed` | `Nunito`; `Nunito` | The current official `ttf-nunito` package ships Nunito.  The AUR `ttf-nunito-sans` recipe points to an obsolete Google download endpoint. |
| Catppuccin Latte | `Cascadia Code NF` | `CaskaydiaCove Nerd Font Mono` | The patched Nerd Font's registered family uses the upstream CaskaydiaCove name. |
| Catppuccin Frappé | `Rubik SemiCondensed` | `Rubik` | `ttf-rubik-vf` provides only the Rubik weight axis. |
| Gruvbox Light | `Recursive Mono` | `Recursive Mono Linear Static` | This is the fixed-width family actually installed by `ttf-recursive`. |
| Solarized Dark | `SourceCodePro Nerd Font Mono` | `SauceCodePro Nerd Font Mono` | Nerd Fonts registers the patched Source Code Pro family under its Sauce Code Pro name. |
| Solarized Light | `Lato Semibold` | `Lato` | Semibold is a style, not a family setting supported by the theme schema. |
| Tokyo Night | `Space Grotesk Medium` | `Space Grotesk` | Medium is a style, not a family setting supported by the theme schema. |
| Dracula | `Monaspace Neon NF` | `MonaspiceNe Nerd Font Mono` | The Arch Nerd Font package uses the Monaspice `Ne` family name. |
| Kanagawa | `Noto Serif SemiCondensed` | `Noto Serif` | `noto-fonts` does not provide a separately registered SemiCondensed family. |

`Outfit SemiBold` likewise becomes `Outfit`. Panel roles always use the
proportional family from a Nerd Font package so text keeps normal spacing and
panel icons remain available. Weight remains the renderer's default until the
theme schema grows a weight field.

## Verification after install

Run the matching checks after installing the packages.  A listed family must
return itself rather than a fallback:

```sh
fc-match -f '%{family}\n' 'CaskaydiaCove Nerd Font Mono'
fc-match -f '%{family}\n' 'MonaspiceNe Nerd Font Mono'
fc-match -f '%{family}\n' 'Recursive Mono Linear Static'
fc-match -f '%{family}\n' 'SauceCodePro Nerd Font Mono'
fc-match -f '%{family}\n' 'Noto Serif'
```

Use `fc-list : family` to audit the complete set.  Run `fc-cache -f` if a
fresh font install is not visible to a running desktop session.

## Sources

- [Arch package search](https://archlinux.org/packages/) for every `extra`
  package, including package licence metadata.
- [AUR RPC](https://aur.archlinux.org/rpc/) and each AUR package's PKGBUILD
  for the AUR package name, source, and licence declaration.
- The OFL-licensed upstream repos for Outfit, Alegreya, and Space Grotesk.
- The package archives were inspected with `fc-scan` for the less obvious
  patched families: Cascadia Code, Recursive, and Monaspace Neon.
