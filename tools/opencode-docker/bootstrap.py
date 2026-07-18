#!/usr/bin/env python3

import os
import subprocess
import sys
import time
from pathlib import Path


SECRETS_DIR = Path("/run/secrets")

ALLOWED_SECRETS = {
    "anthropic_api_key",
    "openai_api_key",
    "context7_api_key",
    "google_application_credentials",
    "aws_access_key_id",
    "aws_secret_access_key",
    "github_token",
    "exa_api_key",
}


def env_var_name(secret_name: str) -> str:
    return secret_name.upper().replace("-", "_").replace(".", "__")


def load_secrets() -> None:
    if not SECRETS_DIR.is_dir():
        return

    for entry in SECRETS_DIR.iterdir():
        if not entry.is_file():
            continue

        name = entry.name
        if name not in ALLOWED_SECRETS:
            print(f"Warning: skipping unknown secret '{name}' — not in ALLOWED_SECRETS", file=sys.stderr)
            continue

        try:
            value = entry.read_text(encoding="utf-8").rstrip("\r\n")
        except OSError as e:
            print(f"Warning: skipping unreadable secret {name}: {e}", file=sys.stderr)
            continue

        os.environ[env_var_name(name)] = value


def start_xvfb() -> None:
    try:
        proc = subprocess.Popen(
            ["Xvfb", ":99", "-screen", "0", "1024x768x24"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except OSError as e:
        print(f"Warning: Xvfb failed to start ({e}). Browser automation unavailable.", file=sys.stderr)
        return

    # Wait for X11 socket instead of arbitrary sleep
    for _ in range(20):
        if Path("/tmp/.X11-unix/X99").exists():
            break
        time.sleep(0.1)


def init_openspec() -> None:
    """Initialize OpenSpec in the workspace if not already set up."""
    cwd = Path.cwd()
    openspec_dir = cwd / "openspec"
    config = openspec_dir / "config.yaml"
    if openspec_dir.exists() or config.is_file():
        return  # Already initialized or partial setup exists

    try:
        subprocess.run(
            ["openspec", "init", "--tools", "opencode"],
            cwd=cwd,
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except (subprocess.CalledProcessError, OSError) as e:
        print(f"Note: OpenSpec init skipped ({e})", file=sys.stderr)


def main() -> None:
    load_secrets()
    start_xvfb()
    init_openspec()
    os.execvp("opencode", ["opencode", *sys.argv[1:]])


if __name__ == "__main__":
    main()
