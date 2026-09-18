#!/usr/bin/env python3
"""Preset registry reader for the single-path launch contract (DIA-260918-vsq8).

Exactly one supported launch path: `make opencode PRESET=<name>` (one-run
override, nothing persisted) and `make presets` (list names). This helper is
the only registry reader on that path: it prints the sorted `presets` keys
from .opencode/oh-my-opencode-slim.jsonc using stdlib only (no jq, no bun,
no OMO source import), so the Makefile stays on the clean npm track.

Usage:
  presets.py list            print sorted preset keys, one per line (exit 0)
  presets.py check <name>    exit 0 if <name> is a registry key, else print
                             "Available presets: ..." to stderr and exit 1

Any registry failure (missing file, malformed JSONC, missing presets key)
fails closed via RegistryError, mapped to stderr plus exit 1.

Test seam: PRESETS_JSONC overrides the config path (used by bats fixtures).
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from jsonc_strip import strip_jsonc  # noqa: E402

CONFIG = os.environ.get("PRESETS_JSONC") or os.path.normpath(
    os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "..",
        ".opencode",
        "oh-my-opencode-slim.jsonc",
    )
)


class RegistryError(Exception):
    """Raised when the preset registry cannot be loaded (missing file,
    malformed JSONC, or missing presets key)."""


def load_names():
    try:
        with open(CONFIG, encoding="utf-8") as f:
            data = json.loads(strip_jsonc(f.read()))
    except (OSError, ValueError) as exc:
        raise RegistryError("preset registry unreadable: %s" % exc)
    if not isinstance(data, dict) or not isinstance(data.get("presets"), dict):
        raise RegistryError("preset registry has no presets key: %s" % CONFIG)
    return sorted(data["presets"])


def main(argv):
    if argv == ["list"]:
        try:
            names = load_names()
        except RegistryError as exc:
            print(exc, file=sys.stderr)
            return 1
        for name in names:
            print(name)
        return 0
    if len(argv) == 2 and argv[0] == "check":
        try:
            names = load_names()
        except RegistryError as exc:
            print(exc, file=sys.stderr)
            return 1
        if argv[1] not in names:
            print(
                'Unknown preset "%s". Available presets: %s'
                % (argv[1], ", ".join(names) or "none"),
                file=sys.stderr,
            )
            return 1
        print(argv[1])
        return 0
    print("usage: presets.py list | presets.py check <name>", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
