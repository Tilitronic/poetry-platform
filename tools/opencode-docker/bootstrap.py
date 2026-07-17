#!/usr/bin/env python3

import os
import subprocess
import sys
from pathlib import Path


SECRETS_DIR = Path("/run/secrets")


def env_var_name(secret_name: str) -> str:
    return secret_name.upper().replace("-", "_").replace(".", "_")


def load_secrets() -> None:
    if not SECRETS_DIR.is_dir():
        return

    for entry in SECRETS_DIR.iterdir():
        if not entry.is_file():
            continue

        try:
            value = entry.read_text(encoding="utf-8").rstrip("\r\n")
        except OSError as e:
            print(f"Warning: skipping unreadable secret {entry.name}: {e}", file=sys.stderr)
            continue

        os.environ[env_var_name(entry.name)] = value


def start_xvfb() -> None:
    try:
        subprocess.Popen(
            ["Xvfb", ":99", "-screen", "0", "1024x768x24"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except OSError:
        pass


def init_openspec() -> None:
    """Initialize OpenSpec in the workspace if not already set up."""
    cwd = Path.cwd()
    config = cwd / "openspec" / "config.yaml"
    if config.is_file():
        return  # Already initialized

    try:
        subprocess.run(
            ["openspec", "init", "--tools", "opencode", "--force"],
            cwd=cwd,
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except (subprocess.CalledProcessError, OSError):
        pass  # Non-fatal — OpenSpec is optional


def main() -> None:
    load_secrets()
    start_xvfb()
    init_openspec()
    os.execvp("opencode", ["opencode", *sys.argv[1:]])


if __name__ == "__main__":
    main()
