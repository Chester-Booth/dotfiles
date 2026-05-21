# Micro Fork Notes

I used a forked version of Micro to add more ctrl+f type search

[Fork Repo](https://github.com/Chester-Booth/micro)

Installed binary:

```sh
/home/blox/.local/bin/micro
```

The user `PATH` has `/home/blox/.local/bin` before `/usr/bin`, so this forked
binary overrides the packaged `/usr/bin/micro` without replacing it.

Patch summary:

- `bindings.json` now supports prompt-type-specific command bindings:

```json
{
    "command": {
        "Find": {
            "Down": "FindNext",
            "Up": "FindPrevious",
            "Enter": "FindNext"
        }
    }
}
```

- The nested `Find` bindings only apply while the find prompt is active.
- `FindNext` and `FindPrevious` are available as infobar actions and operate on
  the active editor buffer, not on the prompt text buffer.
- Dotfiles config lives at:

```sh
/home/blox/Code/personal/dotfiles/micro/.config/micro/bindings.json
```

Rebuild and reinstall after changing the fork:

```sh
cd /home/blox/Code/personal/micro
make build
install -m 0755 ./micro /home/blox/.local/bin/micro
micro -version
```

Verification used:

```sh
micro -version
micro -config-dir /home/blox/.config/micro -options
go test ./internal/action ./internal/config ./internal/info ./internal/buffer
```
