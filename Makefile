SHELL := /usr/bin/env bash
QS := quickshell/.config/quickshell/blox

.PHONY: check format lint doctor qmlformat qmllint shfmt shellcheck lua-check py-compile test-floating-sudo test-launcher test-status-contracts test-bloxctl test-native validate-status validate-themes update-theme-golden systemd-verify diff-check

check: qmllint lua-check py-compile test-floating-sudo test-launcher test-status-contracts test-bloxctl test-native validate-status validate-themes systemd-verify diff-check

format: qmlformat shfmt

lint: shellcheck lua-check py-compile validate-status validate-themes systemd-verify diff-check

doctor:
	@bin/dotfiles-doctor

qmlformat:
	@find $(QS) -type f -name '*.qml' -print0 | xargs -0 -r qmlformat -i

qmllint:
	@if command -v qmllint >/dev/null 2>&1; then \
		find $(QS) -type f -name '*.qml' -print0 | xargs -0 -r qmllint -I $(QS); \
	else \
		echo 'skip qmllint: command not found'; \
	fi

shfmt:
	@if command -v shfmt >/dev/null 2>&1; then \
		find bin hyprland quickshell systemd system-etc -type f \( -name '*.sh' -o -name 'dotfiles-doctor' \) -print0 | xargs -0 -r shfmt -w; \
	else \
		echo 'skip shfmt: command not found'; \
	fi

shellcheck:
	@if command -v shellcheck >/dev/null 2>&1; then \
		find bin hyprland quickshell systemd system-etc -type f \( -name '*.sh' -o -name 'dotfiles-doctor' \) -print0 | xargs -0 -r shellcheck -x -P quickshell/.config/quickshell/blox/scripts/status; \
	else \
		echo 'skip shellcheck: command not found'; \
	fi

lua-check:
	@if command -v luac >/dev/null 2>&1; then \
		find hyprland -type f -name '*.lua' -print0 | xargs -0 -r -n1 luac -p; \
	else \
		echo 'skip lua-check: luac command not found'; \
	fi

py-compile:
	@while IFS= read -r -d '' file; do \
		python3 -c 'import ast, pathlib, sys; path = pathlib.Path(sys.argv[1]); ast.parse(path.read_text(), filename=str(path))' "$$file"; \
	done < <(find $(QS)/scripts -type f -name '*.py' -print0)
	@while IFS= read -r -d '' file; do \
		python3 -c 'import ast, pathlib, sys; path = pathlib.Path(sys.argv[1]); ast.parse(path.read_text(), filename=str(path))' "$$file"; \
	done < <(find themes -type f -name '*.py' -print0)
	@python3 -c 'import ast, pathlib; path = pathlib.Path("bin/floating_sudo"); ast.parse(path.read_text(), filename=str(path))'

test-floating-sudo:
	@PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests/test_floating_sudo.py -v

test-launcher:
	@PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests/test_launcher_apps.py tests/test_launcher_clipboard.py tests/test_launcher_dmenu.py tests/test_launcher_emoji.py tests/test_launcher_processes.py -v
	@QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -import tests/qml/imports -input tests/qml

test-status-contracts:
	@PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests/test_status_contracts.py -v

test-bloxctl:
	@PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests/test_bloxctl.py -v

test-native:
	@PYTHONDONTWRITEBYTECODE=1 python3 $(QS)/scripts/launcher/native/test_native.py

validate-status:
	@$(QS)/scripts/validate-status.py --timeout 10

validate-themes:
	@PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s themes/tests -v

update-theme-golden:
	@PYTHONDONTWRITEBYTECODE=1 python3 themes/tests/helpers/update_golden.py

systemd-verify:
	@systemd-analyze --user verify systemd/*.service systemd/*.timer

diff-check:
	@git diff --check
