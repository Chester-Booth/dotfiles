# Blox themes

Theme JSON under `themes/` is editable source. Generated files under
`$XDG_STATE_HOME/blox-theme/` are disposable and must not be edited. Phase 1
only validates and renders; it does not activate output or reload applications.

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
```

Without `--output`, `render` operates in memory. `preview`, `diff`, `doctor`,
and all tests are read-only. An explicit render output is never treated as live
state.

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
