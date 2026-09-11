#!/usr/bin/env bash
# validate-changelog.sh — JSON Schema gate for .opencode/CHANGELOG.yaml.
#
# WHY this gate exists: .opencode/CHANGELOG.yaml is the machine-first changelog
# ledger that replaced the prose .opencode/CHANGELOG.md (DIA-194 Variant B,
# ana024 EBDV recommendation). It is written by agents via text tools and
# rendered to the derived .opencode/CHANGELOG.md view by scripts/changelog-render.
# A structural slip (missing required key, malformed date, unknown key,
# non-array files) would silently degrade both the ledger queries
# (yq select on .ticket) and the derived view until a reader hits a wrong
# header. This gate makes the shape contract machine-enforced at
# `make test-config` time — the same place the repo already validates
# memory-shelf.yaml (validate-memory-shelf.sh, DIA-180 A2). It is the DIA-194
# extension of the Deliverable-A pattern: second YAML artifact under contract.
#
# Two-layer validation (mirrors validate-memory-shelf.sh's PyYAML-first
# resilience):
#   1. SCHEMA layer (primary): parses with PyYAML, normalizes YAML-native
#      datetime.date objects to ISO strings (unquoted `date: 2026-08-16`
#      parses as a date, not a string), and validates against
#      scripts/schemas/changelog.schema.json via the `jsonschema` pip
#      package. This host and the dev container both ship jsonschema, so the
#      schema file is exercised on every gate run and cannot drift from the
#      real ledger without failing the gate.
#   2. STRUCTURAL fallback (jsonschema absent): an embedded mirror of the
#      schema's checks in code, so bare CI hosts / fresh machines without the
#      jsonschema pip package still get gate coverage (same fail-closed
#      behavior). Contract parity between the two layers is pinned MECHANICALLY:
#      scripts/__tests__/validate-changelog.bats runs each divergence fixture
#      on BOTH layers — the fallback via a jsonschema.py shim that raises
#      ImportError on PYTHONPATH — and asserts identical outcomes.
#
# PyYAML itself is REQUIRED (exit 2 INFRA when missing): the ledger uses
# folded/escaped block scalars for summary/verification prose that a stdlib
# subset parser cannot handle — same rationale as validate-memory-shelf.sh.
#
# CHANGELOG_FILE / SCHEMA_FILE env overrides point the gate at other files
# (bats meta-tests use committed fixtures; mirror of validate-memory-shelf.sh's
# SHELF_FILE override seam). Exit codes: 0 all pass, 1 violation, 2 INFRA.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHANGELOG_FILE="${CHANGELOG_FILE:-$SCRIPT_DIR/../.opencode/CHANGELOG.yaml}"
SCHEMA_FILE="${SCHEMA_FILE:-$SCRIPT_DIR/schemas/changelog.schema.json}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 is required to validate .opencode/CHANGELOG.yaml (same requirement as validate-memory-shelf.sh)." >&2
  exit 2
fi
if [ ! -f "${CHANGELOG_FILE}" ]; then
  echo "error: CHANGELOG.yaml not found at ${CHANGELOG_FILE} (override with CHANGELOG_FILE). See docs/dev-infra/host-lsp-setup.md for repo layout." >&2
  exit 2
fi
if [ ! -f "${SCHEMA_FILE}" ]; then
  echo "error: schema file not found at ${SCHEMA_FILE} (override with SCHEMA_FILE). Restore scripts/schemas/changelog.schema.json and re-run." >&2
  exit 2
fi

python3 - "${CHANGELOG_FILE}" "${SCHEMA_FILE}" <<'PYEOF'
import datetime
import re
import sys

changelog_path, schema_path = sys.argv[1], sys.argv[2]

try:
    import yaml
except ImportError:
    # INFRA: no stdlib YAML parser can handle the ledger's folded block
    # scalars; validate-memory-shelf.sh's rationale applies 1:1.
    print(
        "error: PyYAML is required to parse .opencode/CHANGELOG.yaml "
        "(block-scalar prose). Install it (pip install pyyaml) "
        "or run inside the dev container.",
        file=sys.stderr,
    )
    sys.exit(2)

failures = []


def normalize(value):
    """Recursively convert YAML-native datetime.date/datetime objects to ISO
    strings. WHY: `date: 2026-08-16` (unquoted) parses as a date object,
    which fails a JSON-Schema `type: string` check; both quoted and unquoted
    spellings are legitimate in the real ledger (the migration wrote quoted
    dates; future hand-written entries may not), so the parser must normalize
    them to one representation before validation."""
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
REQUIRED_KEYS = ("date", "ticket", "scope", "files", "summary", "verification")
ALLOWED_KEYS = REQUIRED_KEYS + ("severity", "status", "area", "route")
DATE_RE = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$")


def structural_checks(doc):
    if not isinstance(doc, list):
        failures.append("root is not a list (expected a YAML array of changelog entries)")
        return
    if not doc:
        # An empty ledger is structurally a valid empty array — nothing to
        # check. The render script treats it as an empty derived view.
        return
    for idx, item in enumerate(doc):
        where = "changelog[%d]" % idx
        if not isinstance(item, dict):
            failures.append("%s is not a mapping" % where)
            continue
        for key in REQUIRED_KEYS:
            value = item.get(key)
            # Contract parity: the schema declares `minLength: 1` for
            # ticket/scope/summary/verification and the files items, so a
            # whitespace-only string (len >= 1) PASSES by contract — the
            # fallback must match. Only absent / non-string / empty-string
            # values fail; trimming whitespace here would reject ledger
            # entries the committed schema accepts and break the
            # "both layers agree" invariant the bats suite pins.
            if key == "files":
                # Contract parity (re-review 1/2, FIX-1): the schema declares
                # `files` as an array with NO `minItems: 1`, so an EMPTY array
                # (`files: []`) is valid - the committed ledger legitimately
                # contains empty files lists for entries whose source prose had
                # no Files block (e.g. DIA-189b). The fallback must accept
                # empty lists: only MISSING/None files fails. (Pre-fix, the
                # truthiness `not value` wrongly rejected `[]` on
                # jsonschema-absent hosts, breaking the "both layers agree"
                # invariant.)
                if value is None:
                    failures.append("%s missing required 'files'" % where)
                    continue
                if not isinstance(value, list):
                    failures.append("%s 'files' is not a list" % where)
                    continue
                for f in value:
                    if not isinstance(f, str) or len(f) < 1:
                        failures.append("%s files entries must be non-empty strings" % where)
                continue
            if not isinstance(value, str) or len(value) < 1:
                failures.append("%s missing required '%s'" % (where, key))
        for key in item:
            if key not in ALLOWED_KEYS:
                failures.append("%s has unknown key '%s'" % (where, key))
        # The schema's `pattern` applies to ANY string instance, including the
        # empty string, so `date: ""` must fail here too. The absent-optional
        # case (value is None) is the ONLY pass-through — no truthiness
        # short-circuit, which would wrongly let "" pass.
        value = item.get("date")
        if value is None:
            continue
        if isinstance(value, str) and not DATE_RE.fullmatch(value):
            failures.append(
                "%s 'date' is not an ISO-8601 date (YYYY-MM-DD): %s" % (where, value)
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
    with open(changelog_path) as f:
        doc = normalize(yaml.safe_load(f))
except Exception as exc:  # yaml.ScannerError, IOError, ...
    # Collapse multi-line parser diagnostics into one line so the FAIL
    # protocol stays intact (bash consumes stdout line-by-line).
    print("FAIL: YAML parse error in %s: %s" % (changelog_path, " ".join(str(exc).split())))
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

print("ok: %s (changelog shape matches scripts/schemas/changelog.schema.json)" % changelog_path)
print("1 passed, 0 failed")
sys.exit(0)
PYEOF
