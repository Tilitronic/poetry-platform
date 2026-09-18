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

Any JSONC parse failure fails closed (stderr + exit 1) before container setup.
"""
import json
import os
import sys

CONFIG = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..",
    ".opencode",
    "oh-my-opencode-slim.jsonc",
)


def strip_jsonc(src):
    """Char-level JSONC comment/trailing-comma stripper (string-aware).

    Same shape as the stripper in scripts/check-orchestrator-prompt-drift.sh:
    // and /* */ comments are dropped only outside string literals, trailing
    commas before } or ] are dropped. URLs survive because a '/' inside a
    string never enters comment-scanning.
    """
    out = []
    i = 0
    n = len(src)
    in_string = None
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if in_string:
            out.append(c)
            if c == "\\":
                i += 1
                if i < n:
                    out.append(src[i])
            elif c == in_string:
                in_string = None
            i += 1
            continue
        if c in "\"'":
            in_string = c
            out.append(c)
            i += 1
            continue
        if c == "/" and nxt == "/":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if c == "/" and nxt == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                i += 1
            i += 2
            continue
        if c == ",":
            j = i + 1
            while j < n and src[j].isspace():
                j += 1
            if j < n and src[j] in "}]":
                i += 1
                continue
        out.append(c)
        i += 1
    return "".join(out)


def load_names():
    try:
        with open(CONFIG, encoding="utf-8") as f:
            data = json.loads(strip_jsonc(f.read()))
    except Exception as exc:
        print("preset registry parse failed: %s" % exc, file=sys.stderr)
        sys.exit(1)
    presets = data.get("presets") or {}
    return sorted(presets)


def main(argv):
    if argv == ["list"]:
        for name in load_names():
            print(name)
        return 0
    if len(argv) == 2 and argv[0] == "check":
        names = load_names()
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
