#!/usr/bin/env bash
# Audits OpenCode agent x tool permission coverage and surfaces tools NOT
# explicitly covered by permission rules.
#
# WHY this gate exists (DIA-066): in the OpenCode v1 permission model, unlisted
# tools fall through to the global permission block -> permissive default-allow.
# A write-capable tool that is unlisted from every agent's effective coverage
# (global rules UNION agent rules) is a silent write-exposure hole: it ships
# the moment a plugin registers a new tool. This script is the deterministic
# pre-runtime cross-reference gate that catches that drift.
#
# Hybrid enumeration (design.md Decision 1):
#   - Static JSONC parse (python3) of the config's global + per-agent
#     permission blocks -> file:line source locations.
#   - Runtime census (one `opencode debug agent <first-alphabetical-agent>`
#     invocation, or the AUDIT_TOOL_CENSUS_FILE env override for hermetic
#     tests) -> the complete tool universe, including plugin/MCP-registered
#     tools that a static list cannot see.
#
# Effective coverage semantics (Decision 3): a tool is "covered" for agent X
# iff it appears in agent X's permission block OR the global permission block.
# Gaps = census universe - effective coverage.
#
# Severity tiering (Decision 6 — resolved ruling): gaps split into:
#   HARD (exit 1): unlisted WRITE-CAPABLE tool (canonical list below) missing
#                  from every agent's effective coverage.
#   WARN (exit 0): all other unlisted default-allow tools.
#
# Exit codes (Decision 2):
#   0  run completed, no HARD (write-capable) gaps found (WARNs do not fail)
#   1  HARD (write-capable) gap found OR malformed JSONC (config defect)
#   2  INFRA error (no `opencode`, no `python3`, no default model, v2 schema
#      detected, missing config file)
#
# Stream contract (matches scripts/validate-agent-names.sh):
#   FAIL:/WARN:  -> stderr
#   ok:          -> stdout
#   final summary -> stdout: "N agents audited, M gaps, K warnings"
#
# Env overrides (hermetic test seams):
#   AUDIT_TOOL_CENSUS_FILE      path to JSON {"tools": {toolId: enabled}}
#                               (stubs the runtime census — tests never need a
#                               live `opencode` install)
#   AUDIT_WRITE_CAPABLE_TOOLS   space-delimited override of the canonical
#                               write-capable tool list (tests)
set -euo pipefail

CONFIG_FILE="${1:-.opencode/opencode.jsonc}"

# ---------------------------------------------------------------------------
# INFRA gates (exit 2). Decision 2: exit 2 = "the validator's own environment
# is broken — cannot run the check at all".
# ---------------------------------------------------------------------------
if [ ! -f "$CONFIG_FILE" ]; then
  echo "error: config file not found: $CONFIG_FILE" >&2
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 is required to parse JSONC configs." >&2
  exit 2
fi

# The runtime census is only needed when AUDIT_TOOL_CENSUS_FILE is NOT set
# (hermetic test mode skips the live opencode requirement entirely).
if [ -z "${AUDIT_TOOL_CENSUS_FILE:-}" ]; then
  if ! command -v opencode >/dev/null 2>&1; then
    echo "error: opencode binary not found in PATH; install opencode or set AUDIT_TOOL_CENSUS_FILE" >&2
    exit 2
  fi
fi

# Canonical write-capable tool list (Decision 6) is owned by crossref.py below
# (AUDIT_WRITE_CAPABLE_TOOLS env override is read there directly) — the Python
# copy is the single source of truth; no bash-level duplicate.

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# ---------------------------------------------------------------------------
# T1/T2: static JSONC parse (python3) -> emit machine-readable coverage JSON.
# Python exit codes:
#   0  parse ok, output JSON on stdout
#   1  malformed JSONC (HARD — config defect)
#   2  v2 permission schema detected (INFRA)
#   3  missing permission structure (treat as no rules; e.g. docker profile)
# ---------------------------------------------------------------------------
cat > "$workdir/parse.py" <<'PYEOF'
import json
import sys


def strip_jsonc(src):
    """Char-level JSONC comment/trailing-comma stripper (mirrors
    validate-opencode-config.sh). Comments are removed only outside string
    literals; URLs (https://...) survive because '/' inside a string never
    enters comment-scanning."""
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


def find_line(src, target, start=0):
    """Return the 1-based line of the first occurrence of target in src at or
    after index start, else -1. Used for file:line reporting of the agent
    block that owns a gap."""
    idx = src.find(target, start)
    if idx < 0:
        return -1
    return src.count("\n", 0, idx) + 1


def main():
    path = sys.argv[1]
    with open(path) as f:
        src = f.read()
    stripped = strip_jsonc(src)
    data = json.loads(stripped)  # raises -> malformed JSONC (exit 1)

    # v2 schema detection (Decision 5): ordered `permissions` array form with
    # last-match-wins semantics. We refuse to run on v2.
    if "permissions" in data and isinstance(data.get("permissions"), list):
        print("error: v2 permission schema detected — audit script not yet adapted for last-match-wins semantics", file=sys.stderr)
        sys.exit(2)

    # Agents block: the real .opencode/opencode.jsonc uses `agent` (singular).
    agents_block = data.get("agents")
    if not isinstance(agents_block, dict):
        agents_block = data.get("agent")
    if not isinstance(agents_block, dict):
        agents_block = {}

    global_perm = data.get("permission")

    out = {
        "global": None,
        "agents": [],
        "first_alphabetical": None,
    }

    if isinstance(global_perm, dict):
        out["global"] = {
            "tools": sorted(global_perm.keys()),
            "line": find_line(stripped, '"permission"'),
            "blanket": False,
        }
    elif isinstance(global_perm, str):
        # Scalar blanket form (container profile): separate exposure mode.
        out["global"] = {
            "blanket": True,
            "value": global_perm,
            "line": find_line(stripped, '"permission"'),
        }
    # missing global permission -> no global rules (treated as empty dict)

    agent_names = sorted(agents_block.keys())
    for name in agent_names:
        entry = agents_block[name]
        perm = entry.get("permission") if isinstance(entry, dict) else None
        block = {"name": name}
        # locate this agent's permission key line: search for the agent key
        # first, then the first "permission" after it. All lookups use the
        # comment-stripped `stripped` so indices stay in one coordinate space
        # (raw `src` includes comment lines that would skew the start index).
        agent_idx = stripped.find('"%s"' % name)
        agent_key_line = find_line(stripped, '"%s"' % name)
        perm_line = find_line(stripped, '"permission"', agent_idx)
        if isinstance(perm, dict):
            block["tools"] = sorted(perm.keys())
            block["line"] = perm_line if perm_line > 0 else agent_key_line
            block["blanket"] = False
        elif isinstance(perm, str):
            block["blanket"] = True
            block["value"] = perm
            block["line"] = perm_line if perm_line > 0 else agent_key_line
        else:
            # no permission block -> no agent rules (effective = global only)
            block["tools"] = []
            block["line"] = agent_key_line
            block["blanket"] = False
        out["agents"].append(block)

    out["first_alphabetical"] = agent_names[0] if agent_names else None
    print(json.dumps(out))


if __name__ == "__main__":
    main()
PYEOF

set +e
python3 "$workdir/parse.py" "$CONFIG_FILE" > "$workdir/coverage.json" 2> "$workdir/parse.err"
parse_rc=$?
set -e
if [ "$parse_rc" -ne 0 ]; then
  if [ "$parse_rc" -eq 2 ]; then
    cat "$workdir/parse.err" >&2
    exit 2
  fi
  echo "FAIL: cannot parse JSONC $CONFIG_FILE: $(tr '\n' ' ' < "$workdir/parse.err" | cut -c1-200)" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# T3: runtime census. AUDIT_TOOL_CENSUS_FILE (hermetic test mode) or one
# `opencode debug agent <first-alphabetical-agent>` invocation.
# ---------------------------------------------------------------------------
if [ -n "${AUDIT_TOOL_CENSUS_FILE:-}" ]; then
  if [ ! -e "$AUDIT_TOOL_CENSUS_FILE" ]; then
    echo "error: AUDIT_TOOL_CENSUS_FILE not found: $AUDIT_TOOL_CENSUS_FILE" >&2
    exit 2
  fi
  cp "$AUDIT_TOOL_CENSUS_FILE" "$workdir/census.json"
else
  FIRST_AGENT="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["first_alphabetical"] or "")' "$workdir/coverage.json")"
  if [ -z "$FIRST_AGENT" ]; then
    # No agents block. If the global block is blanket-form (container profile),
    # the blanket WARN still fires (T5) — run crossref with an empty census so
    # the exposure is reported. Otherwise there is nothing to cross-reference.
    if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); g=d.get("global") or {}; sys.exit(0 if g.get("blanket") else 1)' "$workdir/coverage.json"; then
      printf '{"tools": {}}\n' > "$workdir/census.json"
    else
      echo "0 agents audited, 0 gaps, 0 warnings"
      exit 0
    fi
  else
    if ! opencode debug agent "$FIRST_AGENT" > "$workdir/census.json" 2> "$workdir/census.err"; then
      echo "error: opencode debug agent failed — no default model resolvable" >&2
      cat "$workdir/census.err" >&2
      exit 2
    fi
  fi
fi

# ---------------------------------------------------------------------------
# T4/T5: cross-reference + gap detection (python3 reads coverage + census).
# Emits the stream-contract report lines; exit status 0/1.
# ---------------------------------------------------------------------------
cat > "$workdir/crossref.py" <<'PYEOF'
import json
import os
import sys

CONFIG_FILE = sys.argv[1]
COVERAGE = json.load(open(sys.argv[2]))
try:
    CENSUS = json.load(open(sys.argv[3]))
except json.JSONDecodeError:
    # Empty census file (e.g. AUDIT_TOOL_CENSUS_FILE=/dev/null in the T1
    # verification path) means an empty tool universe — nothing to audit.
    # A non-empty but malformed census is an INFRA error (cannot run the
    # cross-reference at all).
    if open(sys.argv[3]).read().strip() == "":
        CENSUS = {"tools": {}}
    else:
        print(f"error: cannot parse tool census {sys.argv[3]}", file=sys.stderr)
        sys.exit(2)
WRITE_CAPABLE = set(
    os.environ.get("AUDIT_WRITE_CAPABLE_TOOLS",
                   "write edit ast_grep_replace bash webfetch task "
                   "envsitter_set envsitter_delete envsitter_format "
                   "envsitter_reorder envsitter_unset envsitter_add "
                   "envsitter_copy").split()
)

# T3: tool universe = union of census tool IDs where enabled=true.
tools_map = CENSUS.get("tools", CENSUS) if isinstance(CENSUS, dict) else {}
universe = sorted(tid for tid, enabled in tools_map.items() if enabled is not False)

global_tools = set()
global_blanket = False
global_line = -1
if COVERAGE.get("global"):
    g = COVERAGE["global"]
    if g.get("blanket"):
        global_blanket = True
        global_line = g.get("line", -1)
    else:
        global_tools = set(g.get("tools", []))
        global_line = g.get("line", -1)

# Decision 6 severity tiering (resolved ruling): a write-capable tool is HARD
# only when it is missing from EVERY agent's effective coverage — i.e. nobody
# in the config has addressed it at all (default-allow everywhere). Tools
# covered by at least one agent (or globally) are deliberate, so agents that
# still miss them get WARN, never HARD. This is what keeps `make test-config`
# green despite ~440 non-write-capable unlisted default-allow tools.
union_coverage = set(global_tools)
for agent in COVERAGE["agents"]:
    if not agent.get("blanket"):
        union_coverage |= set(agent.get("tools", []))
universally_uncovered = set(universe) - union_coverage

hard_gaps = 0
warnings = 0
agents_audited = 0

for agent in COVERAGE["agents"]:
    name = agent["name"]
    line = agent.get("line", -1)
    if agent.get("blanket"):
        # T5: blanket form — WARN with unlisted-by-name count, no per-tool
        # enumeration against the blanket.
        warnings += 1
        print(f"WARN: {CONFIG_FILE}:{line} blanket permission={agent.get('value', '?')} — {len(universe)} tools unlisted-by-name", file=sys.stderr)
        agents_audited += 1
        continue
    covered = global_tools | set(agent.get("tools", []))
    agent_hard = 0
    for tool in universe:
        if tool in covered:
            continue
        if tool in WRITE_CAPABLE and tool in universally_uncovered:
            hard_gaps += 1
            agent_hard += 1
            print(f"FAIL: {CONFIG_FILE}:{line} agent={name} tool={tool} default=allow severity=HARD", file=sys.stderr)
        else:
            warnings += 1
            print(f"WARN: {CONFIG_FILE}:{line} agent={name} tool={tool} default=allow severity=WARN", file=sys.stderr)
    if agent_hard == 0:
        n_covered = len([t for t in universe if t in covered])
        print(f"ok: agent={name} {n_covered} tools covered, 0 hard gaps")
    agents_audited += 1

# Global blanket form (docker profile): separate exposure mode, WARN only.
if global_blanket:
    warnings += 1
    print(f"WARN: {CONFIG_FILE}:{global_line} blanket permission={COVERAGE['global'].get('value', '?')} — {len(universe)} tools unlisted-by-name", file=sys.stderr)

print(f"{agents_audited} agents audited, {hard_gaps} gaps, {warnings} warnings")
sys.exit(1 if hard_gaps > 0 else 0)
PYEOF

set +e
python3 "$workdir/crossref.py" "$CONFIG_FILE" "$workdir/coverage.json" "$workdir/census.json"
xref_rc=$?
set -e
if [ "$xref_rc" -eq 2 ]; then exit 2; fi
if [ "$xref_rc" -ne 0 ]; then exit 1; fi
exit 0
