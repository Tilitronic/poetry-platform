#!/usr/bin/env bash
# validate-memory-shelf.sh — JSON Schema gate for .opencode/memory-shelf.yaml.
#
# WHY this gate exists: memory-shelf.yaml is the central RAG index agents read
# to locate conspects, analyses, ADRs, specs, and architectures. It is written
# by agents via text tools (no LSP diagnostics consumed at write time), so a
# structural slip (missing required key, mis-indented section, non-list
# section, unknown key) silently degrades the shelf until a reader greps a
# wrong path. This gate makes the shape contract machine-enforced at
# `make test-config` time — the same place the repo already validates
# SKILL.md frontmatter (validate-skills.sh, DIA-037). It is the A2 enabler of
# DIA-180: first YAML artifact under contract, before any deliverable-B
# conversions.
#
# Two-layer validation (mirrors validate-skills.sh's PyYAML-first resilience):
#   1. SCHEMA layer (primary): parses with PyYAML, normalizes YAML-native
#      datetime.date objects to ISO strings (unquoted `created: 2026-08-15`
#      parses as a date, not a string), and validates against
#      scripts/schemas/memory-shelf.schema.json via the `jsonschema` pip
#      package. This host and the dev container both ship jsonschema, so the
#      schema file is exercised on every gate run and cannot drift from the
#      real shelf without failing the gate.
#   2. STRUCTURAL fallback (jsonschema absent): an embedded mirror of the
#      schema's checks in code, so bare CI hosts / fresh machines without the
#      jsonschema pip package still get gate coverage (same fail-closed
#      behavior). Contract parity between the two layers is pinned MECHANICALLY
#      (re-review 1/2, Standards Minor #1): scripts/__tests__/validate-memory-shelf.bats
#      runs each divergence fixture on BOTH layers — the fallback via a
#      jsonschema.py shim that raises ImportError on PYTHONPATH — and asserts
#      identical outcomes.
#
# PyYAML itself is REQUIRED (exit 2 INFRA when missing): the 69 KB shelf uses
# folded/escaped double-quoted strings that a stdlib subset parser cannot
# handle — unlike the flat SKILL.md frontmatter validate-skills.sh parses.
#
# SHELF_FILE / SCHEMA_FILE env overrides point the gate at other files
# (bats meta-tests use committed fixtures; mirror of validate-skills.sh's
# SKILLS_ROOT override seam). Exit codes: 0 all pass, 1 violation, 2 INFRA.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELF_FILE="${SHELF_FILE:-$SCRIPT_DIR/../.opencode/memory-shelf.yaml}"
SCHEMA_FILE="${SCHEMA_FILE:-$SCRIPT_DIR/schemas/memory-shelf.schema.json}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 is required to validate .opencode/memory-shelf.yaml (same requirement as validate-skills.sh)." >&2
  exit 2
fi
if [ ! -f "${SHELF_FILE}" ]; then
  echo "error: memory-shelf.yaml not found at ${SHELF_FILE} (override with SHELF_FILE). See docs/dev-infra/host-lsp-setup.md for repo layout." >&2
  exit 2
fi
if [ ! -f "${SCHEMA_FILE}" ]; then
  echo "error: schema file not found at ${SCHEMA_FILE} (override with SCHEMA_FILE). Restore scripts/schemas/memory-shelf.schema.json and re-run." >&2
  exit 2
fi

python3 - "${SHELF_FILE}" "${SCHEMA_FILE}" <<'PYEOF'
import datetime
import re
import sys

shelf_path, schema_path = sys.argv[1], sys.argv[2]

try:
    import yaml
except ImportError:
    # INFRA: no stdlib YAML parser can handle the shelf's folded/escaped
    # strings; validate-skills.sh's flat-subset fallback does not apply here.
    print(
        "error: PyYAML is required to parse .opencode/memory-shelf.yaml "
        "(69 KB of folded/escaped strings). Install it (pip install pyyaml) "
        "or run inside the dev container.",
        file=sys.stderr,
    )
    sys.exit(2)

failures = []


def normalize(value):
    """Recursively convert YAML-native datetime.date/datetime objects to ISO
    strings. WHY: `created: 2026-08-15` (unquoted) parses as a date object,
    which fails a JSON-Schema `type: string` check; both quoted and unquoted
    spellings are legitimate in the real shelf (inventory 2026-08-15), so the
    parser must normalize them to one representation before validation."""
    if isinstance(value, datetime.datetime):
        return value.date().isoformat()
    if isinstance(value, datetime.date):
        return value.isoformat()
    if isinstance(value, list):
        return [normalize(v) for v in value]
    if isinstance(value, dict):
        return {k: normalize(v) for k, v in value.items()}
    return value


# ---------------------------------------------------------------------------
# STRUCTURAL layer (fallback when jsonschema is absent; mirrors the schema)
# ---------------------------------------------------------------------------
SECTIONS = ("conspects", "analyses", "adrs", "specs", "architectures")
REQUIRED_KEYS = ("name", "description", "path", "created")
ALLOWED_KEYS = REQUIRED_KEYS + ("status", "task_ref", "id", "title", "date")
DATE_RE = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$")


def structural_checks(doc):
    if not isinstance(doc, dict):
        failures.append("root is not a mapping (expected top-level 'shelf:')")
        return
    shelf = doc.get("shelf")
    if not isinstance(shelf, dict):
        failures.append("missing 'shelf' mapping (expected top-level key 'shelf:')")
        return
    for key in shelf:
        if key not in SECTIONS + ("rag_bases",):
            failures.append("unknown shelf key 'shelf.%s'" % key)
    for section in SECTIONS:
        items = shelf.get(section)
        if not isinstance(items, list):
            failures.append("shelf.%s is not a list" % section)
            continue
        for idx, item in enumerate(items):
            where = "shelf.%s[%d]" % (section, idx)
            if not isinstance(item, dict):
                failures.append("%s is not a mapping" % where)
                continue
            for key in REQUIRED_KEYS:
                value = item.get(key)
                # Contract parity (re-review 1/2, option (i)): the schema
                # declares `minLength: 1` for name/description/path, so a
                # whitespace-only string (len >= 1) PASSES by contract — the
                # fallback must match. Only absent / non-string / empty-string
                # values fail; trimming whitespace here would reject shelf
                # entries the committed schema accepts and break the
                # "both layers agree" invariant the bats suite pins.
                if not isinstance(value, str) or len(value) < 1:
                    failures.append("%s missing required '%s'" % (where, key))
            for key in item:
                if key not in ALLOWED_KEYS:
                    failures.append("%s has unknown key '%s'" % (where, key))
            # Both date-typed fields must match the schema's ISO-8601 pattern
            # (re-review 1/2, Standards Minor #1; OBS-1): the schema validates
            # `created` AND the optional `date` against
            # ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ — a malformed optional `date` must
            # fail the fallback exactly as it fails the schema layer. OBS-1
            # closure: JSON Schema applies `pattern` to ANY string instance,
            # including the empty string, so `date: ""` must FAIL here too.
            # The absent-optional case (value is None) is the ONLY pass-through
            # — no truthiness short-circuit, which would wrongly let "" pass.
            for field in ("created", "date"):
                value = item.get(field)
                if value is None:
                    continue  # optional field absent -> nothing to check
                if isinstance(value, str) and not DATE_RE.fullmatch(value):
                    failures.append(
                        "%s '%s' is not an ISO-8601 date (YYYY-MM-DD): %s" % (where, field, value)
                    )


# ---------------------------------------------------------------------------
# SCHEMA layer (primary; runs when the jsonschema pip package is importable)
# ---------------------------------------------------------------------------
def schema_checks(doc):
    import json

    import jsonschema

    with open(schema_path) as f:
        schema = json.load(f)
    for error in sorted(
        jsonschema.Draft7Validator(schema).iter_errors(doc),
        key=lambda e: list(e.path),
    ):
        loc = ".".join(str(p) for p in error.path) or "<root>"
        failures.append("%s: %s" % (loc, error.message))


try:
    with open(shelf_path) as f:
        doc = normalize(yaml.safe_load(f))
except Exception as exc:  # yaml.ScannerError, IOError, ...
    # Collapse multi-line parser diagnostics into one line so the FAIL
    # protocol stays intact (bash consumes stdout line-by-line).
    print("FAIL: YAML parse error in %s: %s" % (shelf_path, " ".join(str(exc).split())))
    print("0 passed, 1 failed")
    sys.exit(1)

try:
    import jsonschema  # noqa: F401

    schema_checks(doc)
except ImportError:
    # jsonschema absent (bare host) -> embedded structural mirror.
    structural_checks(doc)

for message in failures:
    print("FAIL: %s" % message)

if failures:
    print("0 passed, 1 failed")
    sys.exit(1)

print("ok: %s (shelf shape matches scripts/schemas/memory-shelf.schema.json)" % shelf_path)
print("1 passed, 0 failed")
sys.exit(0)
PYEOF
