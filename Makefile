SHELL := /usr/bin/env bash
QS := quickshell/.config/quickshell/blox

.PHONY: check format lint doctor qmlformat shfmt shellcheck lua-check py-compile test-floating-sudo validate-status validate-themes systemd-verify diff-check

check: lua-check py-compile test-floating-sudo validate-status validate-themes systemd-verify diff-check

format: qmlformat shfmt

lint: shellcheck lua-check py-compile validate-status validate-themes systemd-verify diff-check

doctor:
	@bin/dotfiles-doctor

qmlformat:
	@find $(QS) -type f -name '*.qml' -print0 | xargs -0 -r qmlformat -i

shfmt:
	@if command -v shfmt >/dev/null 2>&1; then \
		find bin hyprland quickshell systemd system-etc -type f \( -name '*.sh' -o -name 'dotfiles-doctor' \) -print0 | xargs -0 -r shfmt -w; \
	else \
		echo 'skip shfmt: command not found'; \
	fi

shellcheck:
	@if command -v shellcheck >/dev/null 2>&1; then \
		find bin hyprland quickshell systemd system-etc -type f \( -name '*.sh' -o -name 'dotfiles-doctor' \) -print0 | xargs -0 -r shellcheck; \
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

validate-status:
	@$(QS)/scripts/validate-status.py --timeout 10

validate-themes:
	@PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s themes/tests -v

systemd-verify:
	@systemd-analyze --user verify systemd/*.service systemd/*.timer

diff-check:
	@git diff --check
