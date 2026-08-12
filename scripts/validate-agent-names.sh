#!/usr/bin/env bash
# Cross-references the kebab-case internal agent-name sets declared in the 4
# project-scoped sources (DIA-045 audit gap 1; change dev-infra-config-validators,
# task T2). Owner ruling row 420 defines the DECLARED-⊆-RESOLVED containment
# contract — NOT the strict 4-way set-equality lockstep of the original spec:
#   S1 AGENTS.md            §9 "Agent Naming Convention" table — Internal name
#                           column (the canonical display→internal mapping).
#   S2 .opencode/opencode.jsonc — `agent` block keys (project-scoped).
#   S3 .opencode/oh-my-opencode-slim.jsonc — `agents` block keys AND the values
#      referenced by the routing/preset assignments AND the disabled_agents
#      list (Q2 ruling: disabled agents STILL validated) AND the PRESENCE of
#      the top-level `council` KEY itself (owner ruling row 420: the council
#      KEY makes the single name `council` S3-valid; its block MEMBERS are
#      model seats — deepseek, gemini-3.1-pro, gpt-5.3-codex,
#      claude-sonnet-4.5, qwen3.7-plus — NOT agent names, so they are NOT
#      extracted into S3).
#   S4 .opencode/agents/*.md — filename stems (agent definition files). EXCEPT
#      the S4-exempt set (owner ruling row 415, retained as a clause of the
#      row-420 contract): explore, general, oracle, fixer, explorer, librarian
#      are exempt from the S4 file requirement — they are OpenCode built-ins /
#      OMO native aliases that legitimately live in S1/S2/S3 only; creating S4
#      files for them would register real agents at next OpenCode startup
#      (`.opencode/agents/` is the auto-loaded agent-definition directory).
#
# WHY this gate exists: a rename in one source can silently drift from the
# others — "no test fails, but dispatch-by-name silently misses at runtime"
# (DIA-045 F13/F14 underscore→hyphen renames, F18 explorer lingering in one
# source while removed from others). This script is the deterministic
# pre-runtime cross-reference gate.
#
# Contract (design.md §1, §3, §4 — locked rulings + owner ruling row 420):
#   - Canonical key: the kebab-case internal name. Every source is normalized
#     to the same kebab-case form before equality comparison.
#   - Invariant 1 — every §9 (S1) name RESOLVES in S2∪S3∪S4∪exempt. A §9 name
#     absent from all four resolution paths is a HARD failure.
#   - Invariant 2 — every S2∪S3-declared name appears in §9 (S1). A name
#     declared in config but missing from the canonical table is a HARD
#     failure.
#   - Containment contract, NOT set-equality: a name may legitimately exist in
#     S1+S2 but not S4 (a config-defined agent with no definition file) — that
#     is PASS, not drift.
#   - Empty agents/ directory → exit 0 with a `0 passed, 0 failed, 0 warnings`
#     line (Q5 ruling — empty agents dir is OK).
#   - JSONC parse failure → exit 1 (HARD per Q2 ruling — parse failure is a
#     config defect, not an INFRA error).
#   - Stream contract: `FAIL:`/`warn:` to stderr, `ok:` to stdout, final
#     `N passed, M failed, K warnings` to stdout.
#
# Exit codes: 0 no HARD failures, 1 HARD failure (containment violation per
# either invariant / JSONC parse error), 2 INFRA error (missing source file /
# python3 unavailable).
#
# AGENTS_ROOT env override points the walk elsewhere (defaults to the repo
# root) — bats meta-tests use it to validate hermetic temp fixture trees.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_ROOT="${AGENTS_ROOT:-$ROOT}"

AGENTS_MD="$AGENTS_ROOT/AGENTS.md"
OPENCODE_JSONC="$AGENTS_ROOT/.opencode/opencode.jsonc"
SLIM_JSONC="$AGENTS_ROOT/.opencode/oh-my-opencode-slim.jsonc"
AGENTS_DIR="$AGENTS_ROOT/.opencode/agents"

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 is required to parse JSONC configs." >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Source existence gates (INFRA → exit 2). Design.md §3 reserves exit 2 for
# "the validator's own environment is broken — cannot run the check at all".
# ---------------------------------------------------------------------------
for src in "$AGENTS_MD" "$OPENCODE_JSONC" "$SLIM_JSONC"; do
  if [ ! -f "$src" ]; then
    echo "FAIL: missing source $src" >&2
    exit 2
  fi
done

# ---------------------------------------------------------------------------
# Q5 ruling: empty agents/ directory → 0/0/0, exit 0. Nothing declared as an
# agent definition file means there is nothing to cross-reference, so the
# validator short-circuits before any parsing or set comparison.
# ---------------------------------------------------------------------------
if [ ! -d "$AGENTS_DIR" ] || ! compgen -G "$AGENTS_DIR"/*.md >/dev/null 2>&1; then
  echo "0 passed, 0 failed, 0 warnings"
  exit 0
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
s1_file="$workdir/s1.txt"
s2_file="$workdir/s2.txt"
s3_file="$workdir/s3.txt"
s4_file="$workdir/s4.txt"
py_out="$workdir/py.out"
py_err="$workdir/py.err"

# ---------------------------------------------------------------------------
# Inline python3 JSONC key extractor. JSONC = JSON with // and /* */ comments
# plus trailing commas; the config files also contain URLs (https://...) so the
# comment stripper must be char-level and string-aware (same rationale as
# validate-opencode-config.sh). Emits the extracted agent-name keys one per
# line on stdout; exit status non-zero iff the JSONC failed to parse.
#
# Modes:
#   opencode  — keys of the top-level `agents` block (falls back to `agent`,
#               the key name the real .opencode/opencode.jsonc uses).
#   slim      — keys of the top-level `agents` block + keys of every preset in
#               `presets` (the routing/reference values) + the disabled_agents
#               list (disabled agents STILL validated, Q2 ruling) + the single
#               name `council` when the top-level `council` KEY is present
#               (owner ruling row 420: council KEY → S3-valid; its block
#               MEMBERS are model seats, NOT agent names — not extracted).
# ---------------------------------------------------------------------------
cat > "$workdir/extract.py" <<'PYEOF'
import json
import sys


def strip_jsonc(src):
    """Char-level JSONC comment/trailing-comma stripper.

    Comments (// and /* */) are removed only when outside string literals, and
    trailing commas before } or ] are dropped — mirroring the node tokenizer in
    validate-opencode-config.sh. URLs (https://...) survive because the '/'
    inside a string never enters comment-scanning.
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


def extract_keys(data, mode):
    names = set()
    if mode == "opencode":
        block = data.get("agents")
        if not isinstance(block, dict):
            block = data.get("agent")
        if isinstance(block, dict):
            names.update(block.keys())
    elif mode == "slim":
        block = data.get("agents")
        if isinstance(block, dict):
            names.update(block.keys())
        presets = data.get("presets")
        if isinstance(presets, dict):
            for preset in presets.values():
                if isinstance(preset, dict):
                    names.update(preset.keys())
        disabled = data.get("disabled_agents")
        if isinstance(disabled, list):
            names.update(str(d) for d in disabled)
        # Owner ruling row 420: the PRESENCE of the top-level `council` KEY
        # itself makes the single name `council` S3-valid. The council block's
        # MEMBERS are NOT extracted — they are model seat names (deepseek,
        # gemini-3.1-pro, gpt-5.3-codex, claude-sonnet-4.5, qwen3.7-plus), not
        # agent names; reading them would inject 5 non-agents into S3.
        if isinstance(data.get("council"), dict):
            names.add("council")
    return names


def main():
    path, mode = sys.argv[1], sys.argv[2]
    with open(path) as f:
        src = f.read()
    data = json.loads(strip_jsonc(src))
    for name in sorted(extract_keys(data, mode)):
        print(name)


if __name__ == "__main__":
    main()
PYEOF

# ---------------------------------------------------------------------------
# S1 — AGENTS.md §9 table, Internal name column. State machine: find the
# `## ... Agent Naming Convention` heading, then print the SECOND cell of every
# `| ... |` table row until the next `## ` heading (so later sections cannot
# leak in). The Internal name column is cell 2 (0-indexed from awk's -F'|':
# $1 is the leading empty field, $2 the display name, $3 the internal name).
# Rows whose cells are all dashes (the markdown header separator) are skipped.
# Empty / missing heading → exit 2 (INFRA per design §1).
# ---------------------------------------------------------------------------
if ! grep -qE '^## .*Agent Naming Convention' "$AGENTS_MD"; then
  echo "FAIL: missing '## Agent Naming Convention' heading in $AGENTS_MD" >&2
  exit 2
fi

awk -F'|' '
  /^## / {
    if (in_table) exit
    if ($0 ~ /Agent Naming Convention/) in_table = 1
    next
  }
  in_table && /^\|/ {
    cell = $3
    gsub(/[` ]/, "", cell)
    # Skip the markdown header row and the dashes separator row.
    # The "Internalname" magic string is the header cell "Internal name" with
    # spaces/backticks stripped by the gsub above — coupling the parser to the
    # exact §9 table header text.
    if (cell == "" || cell ~ /^-+$/ || cell == "Internalname") next
    print cell
  }
' "$AGENTS_MD" > "$s1_file"

# ---------------------------------------------------------------------------
# S2 — opencode.jsonc `agent` block keys (JSONC parse → HARD on failure).
# ---------------------------------------------------------------------------
if python3 "$workdir/extract.py" "$OPENCODE_JSONC" opencode >"$py_out" 2>"$py_err"; then
  sort -u "$py_out" > "$s2_file"
else
  echo "FAIL: cannot parse JSONC $OPENCODE_JSONC: $(tr '\n' ' ' < "$py_err" | cut -c1-200)" >&2
  echo "0 passed, 1 failed, 0 warnings"
  exit 1
fi

# ---------------------------------------------------------------------------
# S3 — oh-my-opencode-slim.jsonc `agents` keys + preset routing values +
# disabled_agents (JSONC parse → HARD on failure).
# ---------------------------------------------------------------------------
if python3 "$workdir/extract.py" "$SLIM_JSONC" slim >"$py_out" 2>"$py_err"; then
  sort -u "$py_out" > "$s3_file"
else
  echo "FAIL: cannot parse JSONC $SLIM_JSONC: $(tr '\n' ' ' < "$py_err" | cut -c1-200)" >&2
  echo "0 passed, 1 failed, 0 warnings"
  exit 1
fi

# ---------------------------------------------------------------------------
# S4 — agents/*.md filename stems. The directory is non-empty here (guarded
# above); every *.md file in it is an agent definition (proposal risk note).
# ---------------------------------------------------------------------------
for f in "$AGENTS_DIR"/*.md; do
  [ -f "$f" ] || continue
  basename "$f" .md
done | sort -u > "$s4_file"

# ---------------------------------------------------------------------------
# Normalize every source to the canonical kebab-case form (Q2 ruling): strip
# display-name backticks/@ (already done for S1), lowercase, and collapse
# underscores to hyphens so historical underscore holdovers (ai_specialist →
# ai-specialist) compare equal instead of false-failing.
# ---------------------------------------------------------------------------
normalize() {
  tr '[:upper:]' '[:lower:]' | tr '_' '-'
}

S1="$(normalize < "$s1_file")"
S2="$(normalize < "$s2_file")"
S3="$(normalize < "$s3_file")"
S4="$(normalize < "$s4_file")"

# ---------------------------------------------------------------------------
# S4-exemption set (owner ruling row 415, retained as a clause of the row-420
# declared-⊆-resolved contract — invariant 1). These 6 names are OpenCode
# built-ins (explore, general — disabled in opencode.jsonc) or OMO native
# aliases (oracle, fixer, explorer, librarian — all in slim disabled_agents).
# They legitimately live in S1/S2/S3 only: `.opencode/agents/` (PLURAL) is
# OpenCode's auto-loaded agent-definition directory, so creating an S4 file for
# them would REGISTER a real agent at next startup — the opposite of the
# intended disabled state. S4 absence for the exempt set is therefore correct,
# not drift; an exempt name resolves via the exempt branch of invariant 1 even
# if it is absent from S2/S3/S4 entirely.
# ---------------------------------------------------------------------------
S4_EXEMPT="explore general oracle fixer explorer librarian"

# ---------------------------------------------------------------------------
# Declared-⊆-resolved containment contract (owner ruling row 420, supersedes
# the strict 4-way symmetric-difference lockstep of cod-11):
#
#   Invariant 1 — every §9 (S1) name RESOLVES in S2 ∪ S3 ∪ S4 ∪ exempt. A §9
#                 name absent from all four resolution paths is a HARD failure
#                 (drift: a canonical name that no config/definition backs).
#   Invariant 2 — every S2∪S3-declared name appears in §9 (S1). A config-
#                 declared name missing from the canonical table is a HARD
#                 failure (drift: an undeclared agent exists at runtime).
#
# Containment, NOT set-equality: S1+S2 without S4 (a config-defined agent with
# no definition file) and S4-only names are legitimate subset differences —
# PASS, not drift.
# ---------------------------------------------------------------------------
passed=0
failed=0

# is_s4_exempt <name>: word-boundary match against the space-delimited exempt
# set (grep -w, not -x — the set is one line, -x would never match a token).
is_s4_exempt() {
  printf '%s\n' "$S4_EXEMPT" | grep -qwF -- "$1"
}

# in_set <name> <set-var>: literal line-match against the newline-delimited set
# stored in the variable named by <set-var>. Safe under `set -e` because every
# call site tests its status (if/|| contexts disable errexit for the call).
in_set() {
  printf '%s\n' "${!2}" | grep -qxF -- "$1"
}

# Invariant 1 — every §9 (S1) name resolves in S2∪S3∪S4∪exempt.
while IFS= read -r name; do
  [ -n "$name" ] || continue
  if is_s4_exempt "$name" || in_set "$name" S2 || in_set "$name" S3 || in_set "$name" S4; then
    echo "ok: $name"
    passed=$((passed + 1))
  else
    echo "FAIL: $name — declared in §9 but unresolved in S2∪S3∪S4∪exempt" >&2
    failed=$((failed + 1))
  fi
done <<< "$S1"

# Invariant 2 — every S2∪S3-declared name appears in §9 (S1).
while IFS= read -r name; do
  [ -n "$name" ] || continue
  if in_set "$name" S1; then
    continue
  fi
  srcs=""
  if in_set "$name" S2; then srcs="S2"; fi
  if in_set "$name" S3; then
    if [ -n "$srcs" ]; then srcs="$srcs,S3"; else srcs="S3"; fi
  fi
  echo "FAIL: $name — declared in $srcs but absent from §9" >&2
  failed=$((failed + 1))
done <<< "$(printf '%s\n%s\n' "$S2" "$S3" | sed '/^$/d' | sort -u)"

echo "$passed passed, $failed failed, 0 warnings"
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
