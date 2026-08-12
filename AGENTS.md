# Blox dotfiles

These files drive my Hyprland workstation. Quickshell provides the bar,
popouts, notifications, OSD, launcher, clipboard, emoji picker, desktop
widgets, theme picker, and wallpaper. The wider repo keeps Hyprland, app
settings, shell tools, user services, boot themes, and machine config in step.

The goal is a coherent desktop with simple parts and clear boundaries. Keep a
change as small as possible, but carry it through every layer it truly affects.

These instructions are good defaults for work in this repo. The user's request
wins when it conflicts with them.

## Terms

- **source** means a tracked file in this repo.
- **live config** means the file read by the current desktop, often a symlink to
  source.
- **generated state** means output under `$XDG_STATE_HOME/blox-theme/`, which
  defaults to `~/.local/state/blox-theme/`, or another runtime data path.
- **shell** means the active Quickshell config under
  `quickshell/.config/quickshell/blox/`.
- **status producer** means a script which prints JSON for QML to poll.
- **theme source** means schema-valid JSON under `themes/builtin/` or the user
  theme library. It does not mean rendered target files.

Use these terms in reports so it is clear whether a change touched the repo,
the running desktop, or generated output.

## What must stay true

1. **Quickshell stays the active shell.** Top-level Waybar, Eww, and Wofi trees
   are stale and ignored. Do not inspect, restore, or edit them unless asked.
2. **One model feeds every theme target.** Do not fix drift by adding a second
   colour or font source beside the theme schema and renderer.
3. **Script output stays typed.** QML reads fields from JSON contracts, not from
   tooltip text or display strings.
4. **Tracked source and generated state stay separate.** Edit theme sources and
   render code. Never hand-edit files under the generated theme state tree.
5. **Machine changes remain deliberate.** Repo edits do not grant permission to
   apply themes, change services, write to `/etc`, alter GPU state, or touch boot files.
6. **The working tree stays under the user's control.** Do not commit, push,
   create a branch, merge, or rebase unless the current request asks for it.

## Failures to avoid

The dotfiles conversation history shows these repeat failures. Treat them as
checks on your own work:

- **Claiming a UI fix from static checks.** `qmllint`, unit tests, and
  `make check` do not prove pointer behaviour, focus, rendered geometry,
  animation, or visual match. Say `fixed` only when you observed the changed
  behaviour. Otherwise say which static checks passed and mark the live result
  unverified.
- **Fixing one state and breaking another.** Hover work has broken keyboard
  input; notification work has broken gestures and toasts; theme work has left
  the bar, wallpaper, or custom widget actions missing. Build a small state
  matrix from the change and check the relevant reverse and alternate states.
- **Losing items from a long prompt.** Keep a checklist based on the user's
  exact request. Before handoff, account for every item as done and proved,
  done but unproved, or blocked.
- **Replacing an existing visual pattern.** Start from the closest working
  control or surface. Reuse its spacing, tooltip, menu, scroll speed, hover,
  icon, font, and empty-state behaviour unless the task asks for a new design.
- **Testing only hot state.** Saved shell and theme state must also survive the
  next open or cold start. Hot reload can hide broken persistence and missing
  generated files.
- **Editing live config first.** Find or create the tracked source before
  touching the live path. Check the link with `realpath`. Do not create a real
  file in `~/.config` and move it into dotfiles later.
- **Launching a new Quickshell Instance.** Quickshell live-reloads, never spawn a new quickshell process, unless the active process has crashed, and the systemd retry service has failed after 5 attempts, and you are only permitted to restart the service, not spawn processes yourself

## Repo map

### Quickshell

- `shell.qml` creates the top-level surfaces.
- `modules/` owns top-level shell features and their controllers.
- `popouts/` owns panel surfaces opened from the bar.
- `shared/` owns reusable controls, icons, and the in-process theme model.
- `services/` owns shared state, status polling, actions, notifications, and
  workspace control.
- `scripts/status/` produces JSON for the shell.
- Other `scripts/` folders own action and domain backends.
- `scripts/contracts/status.json` defines status fields and types.

Before finishing a shell change, check its producer, shared state, visible
surfaces, action path, and empty or error state. Say which parts applied.

### Themes

- `themes/schema/theme.schema.json` is the source contract.
- `themes/builtin/` contains tracked built-in theme documents.
- `themes/lib/blox_theme/` validates, renders, imports, exports, and applies
  themes.
- `themes/tests/` checks source, render, runtime, picker, and target behaviour.
- Stable target integration files live in their tracked app folders.
- Rendered state lives outside the repo under the XDG state tree.

A new or changed theme field may require a schema update, built-in data,
defaults for older themes, rendered output, picker support, runtime apply and
reset paths, docs, and tests. Do not add each part by habit. Decide which parts
the field needs and report that decision.

For changes to save, apply, reset, import, or reconcile, check both immediate
state and next-start state. Generated output must come from the saved source,
not from in-process preview state.

### Hyprland and the system

`hyprland/.config/hypr/hyprland.lua` loads the Lua modules in an intentional
order. Keep environment setup before autostart, programs before binds, and
rules after layout values. User units live under `systemd/`. Files below
`system-etc/`, `grub/`, `sddm/`, and `initcpio/` can affect the whole machine.

## How to work

1. Read the nearest source, its callers or consumers, and the relevant docs.
2. Check the working tree, resolve any live link to its tracked source, and
   preserve changes that are not yours.
3. For a multi-part task, turn the original request into a short checklist and
   keep it current while you work.
4. Make the smallest complete change. Avoid new helpers, state, or settings
   until existing parts cannot express the result cleanly.
5. For a non-trivial UI or copy change, follow the user's mock-first rule and
   stop for a choice before editing live components.
6. Keep comments and docs in step with behaviour. Comments should explain use,
   ownership, or a constraint that the code cannot show on its own.
7. Run focused checks, inspect the diff, then compare the result with the
   checklist and report any gap.

Follow the icon system used by the nearby component:

- shared controls and several picker actions use the Lucide-backed repo
  components;
- content which already uses `PhosphorIcon` should use an existing or upstream
  Phosphor asset from the current tree;
- bar glyphs use the active theme's panel font, which must remain a
  `Nerd Font Propo` family.

Do not replace one system with another or insert a raw Unicode glyph to get a
quick visual result.

## JSON status contracts

Every status producer must emit valid JSON matching
`quickshell/.config/quickshell/blox/scripts/contracts/status.json`.

If a producer changes a field or type:

1. update the producer;
2. update the contract;
3. update each QML or service consumer;
4. cover useful, empty, and failure output where they differ;
5. run `make validate-status`.

Do not make QML recover structured values by parsing `tooltip`, `label`, or
other user-facing strings.


## Checks

Choose the smallest useful set:

| Change | Checks |
| --- | --- |
| QML | `make qmllint`; relevant tests under `tests/qml` |
| Hyprland Lua | `make lua-check` |
| Python | `make py-compile`; focused `unittest` module |
| Shell | `make shellcheck`; format only files you changed when needed |
| Status JSON | `make validate-status` |
| Theme system | focused test module, then `make validate-themes` for broad changes |
| User units | `make systemd-verify` |
| Launcher | focused Python test, or `make test-launcher` when it spans layers |
| `floating_sudo` | `make test-floating-sudo` |
| Any code diff | `git diff --check` |

Use `make check` before handing off a broad change that crosses several repo
areas. A small docs or isolated config edit does not need the full suite.

`make format` is mutating. Run it only when formatting is part of the task, and review every changed file. 
For exmaple run it before commits as all commits should be formatted. 
`make doctor` is read-only but checks the live machine and runs `make check`; 
use it for tasks about live links, required tools, Hyprland, Quickshell IPC, or user timers.

Do not add tests for removed behaviour or repeat the same fact at several
levels. Add focused tests for a contract, branch, or failure that could regress.

### Integrated UI proof

After I have chosen a mock and asked for implementation, static checks are
the first proof. For an authorised live check, exercise the changed behaviour
in Quickshell and inspect the result with a screenshot or computer use.

Choose only the states the change can affect:

- left, right, top, and bottom bar placement;
- open and close, hover across the icon-to-popout gap, click, and right click;
- keyboard focus and text input;
- drag inside and outside the original item;
- empty, one-item, many-item, active, disabled, and hidden states;
- saved state after close and reopen;
- cold start when runtime or generated state changed.

For GRUB, SDDM, login, resume, or boot work, static checks cannot prove the
screen shown after reboot. Say exactly what passed and what still needs a real
boot or login.

## Handoff

State:

- what changed and why;
- which source and surfaces changed;
- which checks passed;
- what you observed in the real UI, if anything;
- what you did not verify;
- whether any user action, reload, or privileged apply step remains.
