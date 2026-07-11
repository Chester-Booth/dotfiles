#!/usr/bin/env python3
"""Capture one bounded plain-text frame from a supported terminal widget."""

from __future__ import annotations

import argparse
import os
import pty
import re
import select
import signal
import shlex
import struct
import subprocess
import termios
import time


PRESET_COMMANDS: dict[str, tuple[str, ...]] = {
    "music": ("cava",),
    "clock": ("tty-clock", "-c"),
    "aquarium": ("asciiquarium",),
    "pipes": ("pipes.sh",),
    "tree": ("cbonsai", "-l"),
    "matrix": ("unimatrix",),
    "train": ("sl",),
}
CSI_FINAL = re.compile(r"[@-~]")


class AnsiScreen:
    """Small ANSI/VT screen model sufficient for common terminal toys."""

    def __init__(self, rows: int, columns: int) -> None:
        self.rows = rows
        self.columns = columns
        self.cells = [[" "] * columns for _ in range(rows)]
        self.row = 0
        self.column = 0
        self.state = "text"
        self.csi = ""
        self.background = False

    def feed(self, data: bytes) -> None:
        for char in data.decode("utf-8", errors="replace"):
            if self.state == "escape":
                if char == "[":
                    self.state = "csi"
                    self.csi = ""
                elif char in "]P^_":
                    self.state = "string"
                elif char in "()*+":
                    self.state = "charset"
                else:
                    self.state = "text"
                continue
            if self.state == "charset":
                self.state = "text"
                continue
            if self.state == "string":
                if char in "\a\x1b":
                    self.state = "text" if char == "\a" else "string_escape"
                continue
            if self.state == "string_escape":
                self.state = "text" if char == "\\" else "string"
                continue
            if self.state == "csi":
                self.csi += char
                if CSI_FINAL.fullmatch(char):
                    self._csi(self.csi[:-1], char)
                    self.state = "text"
                elif len(self.csi) > 64:
                    self.state = "text"
                continue
            if char == "\x1b":
                self.state = "escape"
            elif char == "\r":
                self.column = 0
            elif char == "\n":
                self.row = min(self.rows - 1, self.row + 1)
            elif char == "\b":
                self.column = max(0, self.column - 1)
            elif char == "\t":
                self.column = min(self.columns - 1, (self.column // 8 + 1) * 8)
            elif char >= " " and char != "\x7f":
                self.cells[self.row][self.column] = "█" if char == " " and self.background else char
                self.column += 1
                if self.column >= self.columns:
                    self.column = 0
                    self.row = min(self.rows - 1, self.row + 1)

    @staticmethod
    def _parameters(raw: str) -> list[int]:
        raw = raw.lstrip("?<=>")
        return [int(value) if value.isdigit() else 0 for value in raw.split(";")]

    def _csi(self, raw: str, final: str) -> None:
        values = self._parameters(raw)
        amount = values[0] or 1
        if final in "Hf":
            self.row = max(0, min(self.rows - 1, (values[0] or 1) - 1))
            self.column = max(0, min(self.columns - 1, (values[1] if len(values) > 1 else 1) - 1))
        elif final == "A":
            self.row = max(0, self.row - amount)
        elif final == "B":
            self.row = min(self.rows - 1, self.row + amount)
        elif final == "C":
            self.column = min(self.columns - 1, self.column + amount)
        elif final == "D":
            self.column = max(0, self.column - amount)
        elif final == "G":
            self.column = max(0, min(self.columns - 1, amount - 1))
        elif final == "d":
            self.row = max(0, min(self.rows - 1, amount - 1))
        elif final == "J":
            mode = values[0]
            if mode in (2, 3):
                self.cells = [[" "] * self.columns for _ in range(self.rows)]
                self.row = self.column = 0
            elif mode == 0:
                self._erase_to_end()
        elif final == "K":
            mode = values[0]
            start, end = (0, self.columns) if mode == 2 else ((0, self.column + 1) if mode == 1 else (self.column, self.columns))
            self.cells[self.row][start:end] = [" "] * (end - start)
        elif final == "m":
            # Preserve shapes drawn with coloured terminal backgrounds (notably
            # tty-clock) even though the QML widget supplies the final colour.
            if not values or 0 in values or 49 in values:
                self.background = False
            if any(40 <= value <= 47 or 100 <= value <= 107 or value == 48 for value in values):
                self.background = True
        # Styling, cursor visibility and alternate-screen controls need no action.

    def _erase_to_end(self) -> None:
        self.cells[self.row][self.column:] = [" "] * (self.columns - self.column)
        for row in range(self.row + 1, self.rows):
            self.cells[row] = [" "] * self.columns

    def text(self) -> str:
        lines = ["".join(row).rstrip() for row in self.cells]
        while lines and not lines[-1]:
            lines.pop()
        return "\n".join(lines)


def command_for(preset: str, requested: str = "") -> tuple[str, ...]:
    try:
        default = PRESET_COMMANDS[preset]
    except KeyError as error:
        raise ValueError(f"unsupported terminal widget preset: {preset}") from error
    if not requested:
        return default
    command = tuple(shlex.split(requested))
    if not command or os.path.basename(command[0]) != default[0]:
        raise ValueError(f"{preset} widgets must run {default[0]}")
    if len(command) > 24 or any(len(argument) > 256 or "\x00" in argument for argument in command):
        raise ValueError("terminal widget command options exceed the safety limits")
    return command


def capture(command: tuple[str, ...], rows: int, columns: int, duration: float, max_bytes: int) -> str:
    master, slave = pty.openpty()
    termios.tcsetwinsize(slave, (rows, columns))
    environment = {**os.environ, "TERM": "xterm-256color", "COLUMNS": str(columns), "LINES": str(rows)}
    process = subprocess.Popen(command, stdin=slave, stdout=slave, stderr=slave, env=environment, start_new_session=True, close_fds=True)
    os.close(slave)
    screen = AnsiScreen(rows, columns)
    deadline = time.monotonic() + duration
    received = 0
    try:
        while time.monotonic() < deadline and received < max_bytes:
            ready, _, _ = select.select([master], [], [], min(0.05, max(0, deadline - time.monotonic())))
            if not ready:
                if process.poll() is not None:
                    break
                continue
            try:
                chunk = os.read(master, min(8192, max_bytes - received))
            except OSError:
                break
            if not chunk:
                break
            received += len(chunk)
            screen.feed(chunk)
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=0.2)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait(timeout=0.2)
        os.close(master)
    return screen.text()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("preset", choices=tuple(PRESET_COMMANDS))
    parser.add_argument("--rows", type=int, default=20)
    parser.add_argument("--columns", type=int, default=60)
    parser.add_argument("--duration-ms", type=int, default=350)
    parser.add_argument("--command", default="")
    args = parser.parse_args()
    rows = max(4, min(80, args.rows))
    columns = max(10, min(200, args.columns))
    duration = max(0.05, min(1.5, args.duration_ms / 1000))
    try:
        rendered = capture(command_for(args.preset, args.command), rows, columns, duration, 256 * 1024)
    except FileNotFoundError:
        print(f"{PRESET_COMMANDS[args.preset][0]} is not installed")
        return 0
    except ValueError as error:
        print(str(error))
        return 2
    print(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
