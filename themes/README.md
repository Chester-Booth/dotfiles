# Blox themes

Theme JSON under `themes/` is editable source. Generated files under
`$XDG_STATE_HOME/blox-theme/` are disposable and must not be edited. Validation,
preview, diff, and in-memory render operations do not alter live state.

Install the preferred schema validator with:

```sh
python -m pip install -r themes/requirements.txt
```

The CLI includes a strict bootstrap validator so repository checks remain
available before that optional Python package is installed.

## Commands

```text
themectl list [--json]
themectl show THEME [--json]
themectl validate THEME [--json]
themectl render THEME [--output DIR] [--json]
themectl preview THEME [--json]
themectl diff THEME [--json]
themectl doctor [--json]
themectl apply THEME [--targets LIST] [--json]
themectl reconcile [--targets LIST] [--json]
themectl rollback [GENERATION] [--json]
themectl reset-target TARGET [--json]
```

Without `--output`, `render` operates in memory. `preview`, `diff`, and `doctor`
are read-only. An explicit render output is never treated as live state.

`apply` renders a complete candidate, verifies it, atomically switches the
`current` symlink, and then reloads requested targets. A reload failure leaves
valid generated files active, returns exit code 7, and prints a manual recovery
command. Unselected or disabled target files are carried forward byte for byte.
The current generation and five previous generations are retained.

`reconcile` verifies the active manifest and repeats runtime reload actions
without rendering. `rollback` activates a retained generation. `reset-target`
creates a new generation without that target and restores its non-generated
fallback. All mutating commands use a non-blocking application lock.

Every JSON response has `api_version`, `command`, `ok`, `status`, `data`,
`warnings`, and `errors` fields.

## Exit codes

| Code | Meaning |
| ---: | --- |
| 0 | success, including non-blocking warnings |
| 2 | command-line usage error |
| 3 | invalid JSON, schema, colour, or contrast |
| 4 | missing theme or required dependency |
| 5 | render failure |
| 6 | apply failure (reserved for Phase 2) |
| 7 | reload warning (reserved for Phase 2) |
| 8 | application lock contention (reserved for Phase 2) |

Run `make validate-themes` for schema fixtures, golden render checks, and
determinism coverage.
