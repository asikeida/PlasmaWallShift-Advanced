#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later

"""Copy Plasma WallShift settings from the original plugin ID to Advanced."""

from __future__ import annotations

import argparse
import datetime as dt
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


OLD_ID = "org.wallshift.wallpaper"
NEW_ID = "io.github.asikeida.wallshiftadvanced"
DEFAULT_CONFIG = Path.home() / ".config/plasma-org.kde.plasma.desktop-appletsrc"


def plasmashell_running() -> bool:
    return subprocess.run(
        ["pgrep", "-x", "plasmashell"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    ).returncode == 0


def migrate(text: str, activate: bool) -> tuple[str, int, int]:
    lines = text.splitlines(keepends=True)
    header_pattern = re.compile(r"^\[Containments\]\[([^]]+)\]\[Wallpaper\]\[([^]]+)\](.*)\s*$")
    existing_headers = {line.rstrip("\r\n") for line in lines if line.startswith("[")}
    output: list[str] = []
    copied = 0
    activated = 0
    index = 0

    while index < len(lines):
        line = lines[index]
        header = line.rstrip("\r\n")
        match = header_pattern.match(header)
        if match and match.group(2) == OLD_ID:
            end = index + 1
            while end < len(lines) and not lines[end].startswith("["):
                end += 1
            block = lines[index:end]
            output.extend(block)
            new_header = f"[Containments][{match.group(1)}][Wallpaper][{NEW_ID}]{match.group(3)}"
            if new_header not in existing_headers:
                newline = "\r\n" if line.endswith("\r\n") else "\n"
                output.append(new_header + newline)
                output.extend(block[1:])
                existing_headers.add(new_header)
                copied += 1
            index = end
            continue

        if activate and line.rstrip("\r\n") == f"wallpaperplugin={OLD_ID}":
            newline = "\r\n" if line.endswith("\r\n") else "\n"
            output.append(f"wallpaperplugin={NEW_ID}" + newline)
            activated += 1
        else:
            output.append(line)
        index += 1

    return "".join(output), copied, activated


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG, help="Plasma desktop config file")
    parser.add_argument("--activate", action="store_true", help="also select Advanced for desktops using the old ID")
    parser.add_argument("--dry-run", action="store_true", help="report changes without writing files")
    parser.add_argument("--allow-running", action="store_true", help="write even while plasmashell is running")
    args = parser.parse_args()

    config = args.config.expanduser().resolve()
    if not config.is_file():
        parser.error(f"config file not found: {config}")
    if not args.dry_run and not args.allow_running and plasmashell_running():
        parser.error(
            "plasmashell is running; stop it first with "
            "'systemctl --user stop plasma-plasmashell.service', or pass --allow-running"
        )

    original = config.read_text(encoding="utf-8")
    updated, copied, activated = migrate(original, args.activate)
    print(f"sections copied: {copied}")
    print(f"desktops activated: {activated}")
    if updated == original or args.dry_run:
        return 0

    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = config.with_name(f"{config.name}.bak-{stamp}")
    shutil.copy2(config, backup)
    fd, temporary_name = tempfile.mkstemp(prefix=f".{config.name}.", dir=config.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as temporary:
            temporary.write(updated)
        os.chmod(temporary_name, config.stat().st_mode)
        os.replace(temporary_name, config)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)
    print(f"backup: {backup}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
