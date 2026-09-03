#!/usr/bin/env bash
# Validates the YAML frontmatter of every .opencode/skills/*/SKILL.md
# (`make test-skills`, wired into `make test-config`).
#
# WHY this gate exists: OpenCode parses SKILL.md frontmatter at load time to
# register each skill. A typo, a name/directory drift, or an empty required
# field ships silently today — the skill fails to activate only when an agent
# tries to invoke it at runtime. This script is the deterministic pre-runtime
# gate (DIA-037).
#
# Checks per skill file:
#   HARD (exit 1 on any failure, collect-all — never fail-fast):
#     1. YAML frontmatter parses (PyYAML if available, stdlib fallback).
#     2. `name` present + non-empty.
#     3. `description` present + non-empty.
#     4. `name` equals the parent directory name.
#   SOFT (warn-only to stderr, never affects exit code):
#     5. Body's first non-blank line starts with an activation phrase
#        ("Use when" / "Invoke when" / "Trigger via" / "Use for" / "Use ONLY
#        when", case-insensitive).
#     6. Frontmatter declares a `license:` field (provenance audit concern,
#        not a runtime one — some vendored skills legitimately omit it).
#
# SOFT checks are skipped for a file that fails any HARD check (no parsed
# frontmatter / no extracted body to inspect).
#
# Exit codes: 0 all HARD pass (SOFT warnings may print), 1 HARD failure,
# 2 infrastructure failure (python3 missing / skills root missing /
# sha256sum missing while the global skills tree is present).
#
# SKILLS_ROOT env override points the walk elsewhere (defaults to the repo's
# .opencode/skills) — bats meta-tests use it to validate temp fixture trees.
#
# Cross-location duplicate detection (DIA-052): after the per-skill loop, the
# project tree (SKILLS_ROOT) is compared against the global skills tree
# (GLOBAL_SKILLS_ROOT, default ${XDG_CONFIG_HOME:-$HOME/.config}/opencode/skills) in two tiers:
#   HARD (exit 1)  — byte-exact duplicate (same sha256 in both trees).
#   SOFT (warn)    — near-duplicate (same dirname, different content).
# Matching policy is a human contract, documented not enforced: CASE-SENSITIVE
# exact match, and FOLLOWS SYMLINKS (sha256sum hashes the resolved file
# content, so a symlinked SKILL.md is compared by its target's bytes).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILLS_ROOT="${SKILLS_ROOT:-$ROOT/.opencode/skills}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 is required to validate YAML frontmatter." >&2
  exit 2
fi

if [ ! -d "$SKILLS_ROOT" ]; then
  echo "error: skills directory not found: $SKILLS_ROOT" >&2
  exit 2
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
fm_tmp="$workdir/frontmatter.yaml"
body_tmp="$workdir/body.txt"
py_out="$workdir/py.out"
py_err="$workdir/py.err"

# ---------------------------------------------------------------------------
# Inline python3 frontmatter validator. Emits a line protocol on stdout:
#   HARD|<message>   -> bash prints "FAIL: <message>" to stderr, file fails
#   WARN|<message>   -> bash prints "warn: <message>" to stderr, counts warning
#   OK               -> no HARD failures for this file
# Exit status is non-zero iff at least one HARD check failed for the file.
# WARN lines are emitted only when no HARD failure exists (E6: SOFT checks
# need successfully parsed data).
# ---------------------------------------------------------------------------
cat > "$workdir/validate.py" <<'PYEOF'
import re
import sys


def parse_flat(text):
    """Minimal YAML-subset parser for SKILL.md frontmatter.

    Handles flat top-level `key: value` mappings (quoted or unquoted scalars),
    the `>-` folded block scalar, comments, and blank lines. Indented
    continuation lines that belong to nested maps (e.g. `metadata:`) are
    skipped — the gate only inspects top-level keys (name/description/license)
    and several real skills carry nested metadata blocks, so a strict flat
    parser would false-positive on them. Any non-indented line that is not a
    `key:` pair raises a parse error so genuinely malformed frontmatter (and
    non-mapping roots like bare scalars or lists) is still caught.

    Observed inventory (2026-08): 17 of 19 skills carry nested metadata maps,
    1 uses the `>-` folded block scalar (book-rag), and no skill uses literal
    block style — so only `>-` is handled.

    Limitation: quoted-string stripping removes the surrounding quotes but
    does not unescape `\"` inside values — the PyYAML path handles that
    correctly when available.
    """
    result = {}
    block_key = None
    skipped_nested = False
    for raw in text.splitlines():
        line = raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        stripped = line.lstrip()
        if line != stripped:
            # Indented line: `>-` block-scalar continuation or nested-map
            # content. Nested content is tolerated (permissive subset parser)
            # and flagged once per file so the tolerance stays visible.
            if block_key is not None:
                result[block_key] = (result.get(block_key, "") + " " + stripped).strip()
            else:
                skipped_nested = True
            continue
        block_key = None
        match = re.match(r"^([A-Za-z0-9_.-]+):\s*(.*)$", line)
        if not match:
            raise ValueError("not a YAML mapping")
        key, value = match.group(1), match.group(2).strip()
        if value == ">-":
            block_key = key
            result[key] = ""
            continue
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        result[key] = value
    return result, skipped_nested


def load(text):
    try:
        import yaml
        return yaml.safe_load(text), False
    except ImportError:
        # stdlib-only fallback (bare CI runners / host python without PyYAML)
        return parse_flat(text)


def main():
    fm_file, skill_name, skill_file = sys.argv[1], sys.argv[2], sys.argv[3]
    with open(fm_file) as f:
        text = f.read()
    try:
        data, skipped_nested = load(text)
    except ValueError as e:
        if str(e) == "not a YAML mapping":
            print(f"HARD|frontmatter is not a YAML mapping (expected key-value pairs) in {skill_file}")
        else:
            print(f"HARD|YAML parse error in {skill_file}: {' '.join(str(e).split())}")
        sys.exit(1)
    except Exception as e:  # PyYAML parse errors (ScannerError etc.)
        # Collapse multi-line parser diagnostics into one line so the
        # HARD|... line protocol stays intact (bash consumes it line-by-line).
        print(f"HARD|YAML parse error in {skill_file}: {' '.join(str(e).split())}")
        sys.exit(1)

    # Empty frontmatter parses to None; treat it as an empty mapping so the
    # missing-name/description HARD checks fire (E3) instead of a mapping error.
    if data is None:
        data = {}
    if not isinstance(data, dict):
        print(f"HARD|frontmatter is not a YAML mapping (expected key-value pairs) in {skill_file}")
        sys.exit(1)

    hard = 0
    name = data.get("name")
    if not name:
        print(f"HARD|missing or empty: name in {skill_file}")
        hard = 1
    description = data.get("description")
    if not description:
        print(f"HARD|missing or empty: description in {skill_file}")
        hard = 1
    # E5: exact string equality — accidental whitespace around a name is a bug.
    if name and str(name) != skill_name:
        print(f"HARD|name mismatch in {skill_file}: expected '{skill_name}', got '{name}'")
        hard = 1

    # E6: skip SOFT (license WARN, activation phrase) if any HARD failed;
    # D7: HARD checks accumulate within a file (collect-all, never fail-fast).
    if not hard:
        if not data.get("license"):
            print(f"WARN|no license declared in {skill_file} — verify provenance")
        # B4: the fallback subset parser tolerates nested maps (17 of 19 real
        # skills carry nested `metadata:` blocks) by skipping their indented
        # lines. Surface that tolerance as one WARN per file so it stays
        # visible in the warn count instead of being silently swallowed.
        if skipped_nested:
            print(f"WARN|nested frontmatter content skipped (fallback subset parser) in {skill_file}")
        print("OK")
    sys.exit(1 if hard else 0)


if __name__ == "__main__":
    main()
PYEOF

failures=0
passed=0
warnings=0

for skill_dir in "$SKILLS_ROOT"/*/; do
  # With nullglob off, an empty root leaves the literal glob pattern — skip it.
  [ -d "$skill_dir" ] || continue
  # The glob pattern carries a trailing slash; drop it so error messages and
  # the name==dirname comparison use clean single-slash paths.
  skill_dir="${skill_dir%/}"
  skill_name="$(basename "$skill_dir")"
  skill_file="$skill_dir/SKILL.md"

  if [ ! -f "$skill_file" ]; then
    echo "FAIL: no SKILL.md found in $skill_dir" >&2
    failures=$((failures + 1))
    continue
  fi

  # Extract frontmatter (between the first two ^---$ delimiters) and the body
  # (everything after the second delimiter). awk tracks the delimiter count so
  # missing/truncated frontmatter is detected in the same single pass.
  #
  # State machine: n=0 (pre-first-`---`), n=1 (inside frontmatter, write to
  # fm), n=2 (post-second-`---`, write to body). The delimiter is matched only
  # at a full-line `^---$`. END prints the count for bash to parse.
  # Pre-create the temp files: an empty frontmatter block (two adjacent ---
  # lines) never triggers awk's print, and python must still open the file.
  : > "$fm_tmp"
  : > "$body_tmp"
  delim_count="$(awk -v fm="$fm_tmp" -v body="$body_tmp" '
    /^---$/ { if (n < 2) { n++; next } }
    n == 1 { print > fm; next }
    n >= 2 { print > body }
    END { print n + 0 }
  ' "$skill_file")"

  if [ "$delim_count" -lt 2 ]; then
    if [ "$delim_count" -eq 0 ]; then
      echo "FAIL: no frontmatter found (expected \`---\` delimiters) in $skill_file" >&2
    else
      echo "FAIL: truncated frontmatter (expected two \`---\` delimiters, found one) in $skill_file" >&2
    fi
    failures=$((failures + 1))
    continue
  fi

  file_failed=0
  file_warned=0
  if ! python3 "$workdir/validate.py" "$fm_tmp" "$skill_name" "$skill_file" >"$py_out" 2>"$py_err"; then
    file_failed=1
  fi
  while IFS= read -r line; do
    case "$line" in
      HARD\|*)
        echo "FAIL: ${line#HARD|}" >&2
        file_failed=1
        ;;
      WARN\|*)
        echo "warn: ${line#WARN|}" >&2
        file_warned=$((file_warned + 1))
        ;;
      OK|"") : ;;
      *)
        # Unrecognized protocol line — never silently swallow python output.
        echo "FAIL: unexpected validator output: $line" >&2
        file_failed=1
        ;;
    esac
  done < "$py_out"
  if [ -s "$py_err" ]; then
    # python3 crashed outside its error handlers — surface the traceback.
    cat "$py_err" >&2
    file_failed=1
  fi

  # SOFT check: activation-phrase prefix on the body's first non-blank line.
  if [ "$file_failed" -eq 0 ]; then
    first_body="$(awk 'NF { print; exit }' "$body_tmp")"
    matched=0
    # B2/S2: lowercase via tr, not bash 4+ parameter-expansion case-folding
    # (the var,, / var^^ forms) — keeps the script POSIX-portable across shells.
    lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
    for phrase in "Use when" "Invoke when" "Trigger via" "Use for" "Use ONLY when"; do
      if [[ "$(lower "$first_body")" == "$(lower "$phrase")"* ]]; then
        matched=1
        break
      fi
    done
    if [ "$matched" -eq 0 ]; then
      echo "warn: no activation phrase found in $skill_file (expected 'Use when', 'Invoke when', 'Trigger via', 'Use for', or 'Use ONLY when')" >&2
      warnings=$((warnings + 1))
    fi
  fi

  if [ "$file_failed" -eq 1 ]; then
    failures=$((failures + 1))
  else
    echo "ok: $skill_file"
    passed=$((passed + 1))
  fi
  warnings=$((warnings + file_warned))
done

# ---------------------------------------------------------------------------
# M4 check (change dia-086-m1-m5-agent-contracts-eval-lite, task 4.2;
# design.md Seam S3): the hypothesis question must appear AFTER the
# `<!-- FIRST-QUESTION -->` anchor in the two Socratic-interview skills, and
# each file must carry at least one explicit '?'-ending example question after
# the anchor (defense-in-depth so the anchor is never orphaned). Scoped to
# the two files below -- other skill files are unaffected (task 4.2 AC5).
# Participates in the shared HARD accounting: a missing anchor, missing
# question, wrong line order, or missing example question all FAIL and
# contribute to the existing exit-1 path.
# ---------------------------------------------------------------------------
M4_ANCHOR='<!-- FIRST-QUESTION -->'
M4_QUESTION='What is the primary hypothesis this feature/design validates, and how will you know if it is falsified?'
for m4_file in "$SKILLS_ROOT/openspec-propose/SKILL.md" "$SKILLS_ROOT/domain-grilling/SKILL.md"; do
  if [ ! -f "$m4_file" ]; then
    echo "FAIL: M4: missing skill file $m4_file" >&2
    failures=$((failures + 1))
    continue
  fi

  # `|| true` guards `set -e` when grep finds no match (exit 1).
  anchor_line="$(grep -nF "$M4_ANCHOR" "$m4_file" | head -n1 | cut -d: -f1 || true)"
  question_line="$(grep -nF "$M4_QUESTION" "$m4_file" | head -n1 | cut -d: -f1 || true)"

  m4_failed=0
  if [ -z "$anchor_line" ]; then
    echo "FAIL: M4: missing <!-- FIRST-QUESTION --> anchor in $m4_file" >&2
    m4_failed=1
  fi
  if [ -z "$question_line" ]; then
    echo "FAIL: M4: missing hypothesis question in $m4_file" >&2
    m4_failed=1
  elif [ -n "$anchor_line" ] && [ "$question_line" -le "$anchor_line" ]; then
    echo "FAIL: M4: hypothesis question (line $question_line) must appear after the FIRST-QUESTION anchor (line $anchor_line) in $m4_file" >&2
    m4_failed=1
  fi

  # Defense-in-depth: at least one explicit '?'-ending example question AFTER
  # the anchor, distinct from the hypothesis question itself. The scan stops at
  # the next section heading (`## ` or numbered step line) so it stays within
  # the file's Phase 1 section rather than counting unrelated `?`-ending lines
  # in later sections.
  if [ -n "$anchor_line" ]; then
    example_count="$(awk -v start="$anchor_line" -v skip="$question_line" '
      NR > start && NR != skip {
        if ($0 ~ /^## / || $0 ~ /^[0-9]+\. /) { exit }
        if ($0 ~ /\?[[:space:]]*$/) { n++ }
      }
      END { print n + 0 }
    ' "$m4_file")"
    if [ "$example_count" -lt 1 ]; then
      echo "FAIL: M4: no explicit '?'-ending example question after the FIRST-QUESTION anchor in $m4_file" >&2
      m4_failed=1
    fi
  fi

  if [ "$m4_failed" -eq 1 ]; then
    failures=$((failures + 1))
  else
    echo "ok: M4 hypothesis-question placement: $m4_file"
    passed=$((passed + 1))
  fi
done

# ---------------------------------------------------------------------------
# DIA-052 (T1) — two-tier cross-location duplicate detection.
#
# Tier 1 (HARD, exit 1) — byte-exact duplicate. Every SKILL.md under both
# trees is hashed once (O(n) hashing); a project file whose hash appears in
# the global tree is a byte-exact duplicate. One FAIL per project/global
# pair, collect-all (never fail-fast). Group-by-hash avoids the O(n^2)
# content comparison of the naive pairwise diff (design.md Q3 ruling).
#
# Tier 2 (SOFT, warn-only) — near-duplicate. A project skill that did NOT
# match byte-exact but shares its dirname with a global skill is diffed
# (`diff -r`); any difference emits one warn and joins the warnings bucket.
# Never flips the exit code — legitimate project-local divergence must not
# fail the build (design.md Q2 ruling).
#
# Empty project OR global tree -> dup checks are skipped (falls through to
# the summary). Missing global dir -> warn + skipped tier (optional tree;
# contract change 2026-08-12, DIA-071). Missing sha256sum command while the
# global tree is present -> exit 2 INFRA.
# ---------------------------------------------------------------------------
GLOBAL_SKILLS_ROOT="${GLOBAL_SKILLS_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode/skills}"

# The global skills tree is OPTIONAL (contract change 2026-08-12, DIA-071):
# environments without global skills (the poetry-dev image ships none) skip
# the duplicate-detection tier with a WARN - absence of the global tree cannot
# invalidate the project frontmatter checks (DIA-037 core purpose). Only when
# the dir EXISTS does the tier run, and only then is sha256sum required. The
# tier's own has_skill_dirs guard below already tolerates a missing root, so
# this branch only decides warn-vs-run.
if [ ! -d "$GLOBAL_SKILLS_ROOT" ]; then
  echo "warn: global skills directory not found: $GLOBAL_SKILLS_ROOT - DIA-052 duplicate-detection tier skipped (global skills tree is optional; project frontmatter checks unaffected)" >&2
  warnings=$((warnings + 1))
else
  if ! command -v sha256sum >/dev/null 2>&1; then
    echo "error: sha256sum is required for duplicate detection." >&2
    exit 2
  fi
fi

# has_skill_dirs <root>: returns 0 iff <root> holds at least one
# subdirectory. With nullglob off, an empty root leaves the literal glob
# pattern — the [ -d ] guard catches that. Shared by the empty-tree guard
# below (the full processing loop keeps its inline per-dir guard to stay a
# minimal-diff from the pre-DIA-052 shape).
has_skill_dirs() {
  local root="$1"
  for d in "$root"/*/; do
    [ -d "$d" ] && return 0
  done
  return 1
}

# Empty-tree guard: no dup checks when either root holds no skill dirs
# (parallel to the existing empty-SKILLS_ROOT fall-through, design.md Q5).
if has_skill_dirs "$SKILLS_ROOT" && has_skill_dirs "$GLOBAL_SKILLS_ROOT"; then
  # Tier 1 pre-pass: hash every global SKILL.md once into an associative
  # array (hash -> dirname). O(n) build + O(1) lookups keep the detection
  # phase linear end-to-end (design.md §1); a per-project linear scan of a
  # flat file would be O(n*m). Requires bash 4+ (declared shebang bash).
  declare -A hash_to_name
  for skill_file in "$GLOBAL_SKILLS_ROOT"/*/SKILL.md; do
    [ -f "$skill_file" ] || continue
    hash_to_name["$(sha256sum "$skill_file" | cut -d' ' -f1)"]="$(basename "$(dirname "$skill_file")")"
  done

  for skill_dir in "$SKILLS_ROOT"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_dir="${skill_dir%/}"
    skill_name="$(basename "$skill_dir")"
    skill_file="$skill_dir/SKILL.md"
    [ -f "$skill_file" ] || continue

    project_hash="$(sha256sum "$skill_file" | cut -d' ' -f1)"
    # O(1) hash lookup (bash 4+ assoc array). The ${var:-} guard is required
    # under `set -u`: a hash absent from the global table is an unset key.
    global_name="${hash_to_name[$project_hash]:-}"
    if [ -n "$global_name" ]; then
      # Tier 1 — byte-exact duplicate (HARD): identical content is loaded from
      # both locations, wasting context and masking drift. Name the global
      # counterpart so the project copy can be deleted (the global remains
      # authoritative).
      echo "FAIL: duplicate skill '$skill_name' (byte-exact match with global '$GLOBAL_SKILLS_ROOT/$global_name/SKILL.md')" >&2
      failures=$((failures + 1))
    elif [ -d "$GLOBAL_SKILLS_ROOT/$skill_name" ]; then
      # Tier 2 — near-duplicate (SOFT, warn-only): same dirname in both roots
      # but different content (whitespace/comment drift or an intentional
      # project-local extension such as playwright-browser / git-diff).
      if ! diff -r "$skill_dir" "$GLOBAL_SKILLS_ROOT/$skill_name" >/dev/null 2>&1; then
        echo "warn: near-duplicate skill '$skill_name' (differs from global '$GLOBAL_SKILLS_ROOT/$skill_name')" >&2
        warnings=$((warnings + 1))
      fi
    fi
  done
fi

echo "$passed passed, $failures failed, $warnings warnings"
if [ "$failures" -gt 0 ]; then
  exit 1
fi
exit 0
