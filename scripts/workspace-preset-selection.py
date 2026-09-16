#!/usr/bin/env python3
"""Persist and resolve exact preset names for one canonical workspace."""

import json
import os
import re
import sys
import tempfile
from pathlib import Path
from typing import Any

STORE_VERSION = 1


def store_path() -> Path:
    config_dir = os.environ.get("OPENCODE_CONFIG_DIR", "").strip()
    if not config_dir:
        config_dir = str(Path(os.environ.get("XDG_CONFIG_HOME", "~/.config")).expanduser() / "opencode")
    return Path(config_dir) / "workspace-presets.json"


def canonical_workspace(value: str) -> str:
    return str(Path(value).resolve(strict=True))


def strip_jsonc(text: str) -> str:
    result = []
    quoted = False
    escaped = False
    block_comment = False
    line_comment = False
    index = 0
    while index < len(text):
        char = text[index]
        next_char = text[index + 1] if index + 1 < len(text) else ""
        if block_comment:
            if char == "*" and next_char == "/":
                block_comment = False
                index += 2
                continue
            index += 1
            continue
        if line_comment:
            if char in "\r\n":
                line_comment = False
                result.append(char)
            index += 1
            continue
        if quoted:
            result.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                quoted = False
            index += 1
            continue
        if char == '"':
            quoted = True
            result.append(char)
        elif char == "/" and next_char == "*":
            block_comment = True
            index += 2
            continue
        elif char == "/" and next_char == "/":
            line_comment = True
            index += 2
            continue
        else:
            result.append(char)
        index += 1
    return re.sub(r",\s*([}\]])", r"\1", "".join(result))


def configured_presets(workspace: Path) -> dict[str, Any]:
    locations = []
    config_dir = os.environ.get("OPENCODE_CONFIG_DIR", "").strip()
    if not config_dir:
        config_dir = str(Path(os.environ.get("XDG_CONFIG_HOME", "~/.config")).expanduser() / "opencode")
    for base in (
        Path(config_dir) / "oh-my-opencode-slim",
        workspace / ".opencode" / "oh-my-opencode-slim",
    ):
        for suffix in (".jsonc", ".json"):
            location = Path(f"{base}{suffix}")
            if location.is_file():
                locations.append(location)
                break

    merged: dict[str, Any] = {}
    for location in locations:
        if not location.is_file():
            continue
        try:
            value = json.loads(strip_jsonc(location.read_text()))
        except (OSError, ValueError) as error:
            raise ValueError(f"cannot read preset configuration {location}: {error}") from error
        if isinstance(value, dict) and isinstance(value.get("presets"), dict):
            merged.update(value["presets"])
    return merged


def parse_store() -> dict[str, Any]:
    try:
        value = json.loads(store_path().read_text())
    except FileNotFoundError:
        return {"version": STORE_VERSION, "workspaces": {}}
    except (OSError, ValueError) as error:
        raise ValueError(f"cannot parse workspace preset store: {error}") from error
    if (
        not isinstance(value, dict)
        or value.get("version") != STORE_VERSION
        or not isinstance(value.get("workspaces"), dict)
        or any(not isinstance(key, str) or not isinstance(preset, str) for key, preset in value["workspaces"].items())
    ):
        raise ValueError("workspace preset store has an invalid shape")
    return value


def stored_selection(workspace: str) -> str | None:
    return parse_store()["workspaces"].get(workspace)


def available_text(presets: dict[str, Any]) -> str:
    return ", ".join(presets) or "none"


def resolve(workspace: Path, override: str) -> tuple[str | None, str, str]:
    key = canonical_workspace(str(workspace))
    presets = configured_presets(workspace)
    if override:
        if override not in presets:
            try:
                stored = parse_store()["workspaces"].get(key)
            except ValueError:
                stored = "invalid store"
            raise ValueError(
                f'Preset "{override}" not found for workspace {key}. '
                f'Stored selection: {stored or "none"}. Available presets: {available_text(presets)}'
            )
        return override, "override", key
    store = parse_store()
    stored = store["workspaces"].get(key)
    if stored is not None:
        if stored not in presets:
            raise ValueError(
                f'Stored preset "{stored}" is not found for workspace {key}. '
                f"Available presets: {available_text(presets)}"
            )
        return stored, "stored", key
    return None, "none", key


def save(workspace: Path, name: str) -> str:
    key = canonical_workspace(str(workspace))
    path = store_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    lock_path = Path(f"{path}.lock")
    try:
        descriptor = os.open(lock_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except OSError as error:
        raise ValueError(f"could not lock workspace preset store: {error}") from error
    try:
        value = parse_store()
        value["workspaces"][key] = name
        handle, temporary = tempfile.mkstemp(prefix=f"{path.name}.", suffix=".tmp", dir=path.parent)
        try:
            with os.fdopen(handle, "w") as output:
                json.dump(value, output, indent=2)
                output.write("\n")
                output.flush()
                os.fsync(output.fileno())
            os.replace(temporary, path)
            verified = parse_store()
            if verified["workspaces"].get(key) != name:
                raise ValueError("workspace preset store verification failed")
        finally:
            try:
                os.unlink(temporary)
            except FileNotFoundError:
                pass
    finally:
        os.close(descriptor)
        try:
            lock_path.unlink()
        except FileNotFoundError:
            pass
    return key


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: workspace-preset-selection.py save|resolve WORKSPACE [NAME]", file=sys.stderr)
        return 2
    command = sys.argv[1]
    workspace = Path(sys.argv[2])
    try:
        presets = configured_presets(workspace)
        if command == "save":
            name = sys.argv[3] if len(sys.argv) > 3 else ""
            if not name:
                current = stored_selection(canonical_workspace(str(workspace)))
                print(f"Stored selection: {current or 'none'}")
                print("Usage: make preset NAME=NAME")
                return 0
            if name not in presets:
                raise ValueError(f'Preset "{name}" not found. Available presets: {available_text(presets)}')
            key = save(workspace, name)
            print(f'Saved preset "{name}" for workspace {key}. It applies on the next launch only.')
            return 0
        if command in ("resolve", "value", "source"):
            override = sys.argv[3] if len(sys.argv) > 3 else ""
            name, source, key = resolve(workspace, override)
            if command == "value":
                print(name or "")
                return 0
            if command == "source":
                print(source)
                return 0
            if source == "override":
                print(f"Effective preset: {name} (source: PRESET override)")
            else:
                print(f"PRESET override: none (no preset override)")
                print(f"Effective preset: {name or 'no preset'} (source: {source})")
            return 0
        raise ValueError(f"unknown command: {command}")
    except (OSError, ValueError) as error:
        print(f"workspace preset selection failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
