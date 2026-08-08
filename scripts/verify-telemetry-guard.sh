#!/usr/bin/env bash
# verify-telemetry-guard.sh — DIA-069 interim-guard verification (5 assertions).
#
# WHY: the opencode-telemetry@0.1.19 plugin rewrites
# .opencode/commands/telemetry-{report,inspect}.md with literal /home/qualt
# paths on every plugin load. The committed baseline is the shipped portable
# octm-template form. This guard asserts the baseline is intact (A1/A2), the
# tree is not polluted (A3), the config gate still passes (A4), and the command
# frontmatter is valid YAML (A5).
#
# A1 — no literal '/home/qualt' in either command doc.
# A2 — portable runtime-resolved form present in both docs (octm / bun pm ls -g
#      / ~/.config/opencode/...). The shipped templates use these forms; the
#      plugin's rewrite bakes in an absolute path instead.
# A3 — git status clean for the two command docs (no uncommitted pollution).
# A4 — `make test-config` exits 0 (JSONC + agent-name + handoff + coverage
#      gates all pass — the watcher.ignore JSONC edit must not break config).
# A5 — frontmatter valid YAML for both docs (python3 + PyYAML preferred; the
#      doc uses it — see frontmatter check below).
#
# Manual step (printed at the end): restart-twice resilience. This local guard
# does NOT stop the plugin writing on the next OpenCode load — that requires
# the upstream patch (DIA-069 part 2). Until then, run
# `make restore-telemetry-commands` between restart and verification, then
# re-run this guard.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -f "$ROOT/.opencode/commands/telemetry-report.md" ]; then
  echo "error: $ROOT/.opencode/commands/telemetry-report.md not found — not the poetry-platform repo root? Aborting." >&2
  exit 2
fi

ok=0
fail=0
status=0

fail_msg() { echo "fail: $1" >&2; fail=$((fail + 1)); status=1; }
pass_msg() { echo "pass: $1"; ok=$((ok + 1)); }

# --- A1: no literal /home/qualt -------------------------------------------------
a1_bad=0
for f in telemetry-report.md telemetry-inspect.md; do
  if grep -qF '/home/qualt' "$ROOT/.opencode/commands/$f"; then
    echo "fail: A1 — literal '/home/qualt' found in .opencode/commands/$f (plugin re-pollution)" >&2
    a1_bad=1
  fi
done
if [ "$a1_bad" -eq 0 ]; then
  pass_msg "A1 — no literal /home/qualt in either telemetry command doc"
else
  fail=$((fail + 1)); status=1
fi

# --- A2: portable runtime-resolved form present ----------------------------------
# The shipped templates use octm / `bun pm ls -g` discovery / ~/.config/opencode
# fallback. Require at least one of these portable forms per file.
a2_bad=0
for f in telemetry-report.md telemetry-inspect.md; do
  if ! grep -qE 'octm|bun pm ls -g|~/.config/opencode' "$ROOT/.opencode/commands/$f"; then
    echo "fail: A2 — no portable runtime-resolved form (octm / bun pm ls -g / ~/.config/opencode) in .opencode/commands/$f" >&2
    a2_bad=1
  fi
done
if [ "$a2_bad" -eq 0 ]; then
  pass_msg "A2 — portable runtime-resolved form present in both telemetry command docs"
else
  fail=$((fail + 1)); status=1
fi

# --- A3: git status clean for the two command docs -------------------------------
if [ -n "$(git -C "$ROOT" status --porcelain -- .opencode/commands/telemetry-report.md .opencode/commands/telemetry-inspect.md)" ]; then
  echo "fail: A3 — git status not clean for the telemetry command docs (uncommitted pollution?)" >&2
  git -C "$ROOT" status --short -- .opencode/commands/telemetry-report.md .opencode/commands/telemetry-inspect.md >&2 || true
  fail=$((fail + 1)); status=1
else
  pass_msg "A3 — git status clean for both telemetry command docs"
fi

# --- A4: make test-config exits 0 -------------------------------------------------
a4_out="$(mktemp)"
if make -C "$ROOT" test-config >"$a4_out" 2>&1; then
  pass_msg "A4 — make test-config exit 0"
else
  echo "fail: A4 — make test-config failed (tail of output below)" >&2
  tail -n 25 "$a4_out" >&2 || true
  fail=$((fail + 1)); status=1
fi
rm -f "$a4_out"

# --- A5: frontmatter valid YAML for both docs --------------------------------------
# Prefer python3 + PyYAML (available on this host: Python 3.14 + yaml). Parse
# the frontmatter block between the leading `---` delimiters; fail on parse
# error or missing frontmatter. This is the robust parse — not a grep fallback.
a5_out="$(mktemp)"
if python3 - "$ROOT/.opencode/commands" "$a5_out" <<'PYEOF'
import sys
import yaml

commands_dir, out_path = sys.argv[1], sys.argv[2]
fails = []
for name in ("telemetry-report.md", "telemetry-inspect.md"):
    path = f"{commands_dir}/{name}"
    try:
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
    except OSError as exc:
        fails.append(f"{name}: unreadable ({exc})")
        continue
    if not text.startswith("---\n"):
        fails.append(f"{name}: missing leading frontmatter delimiter")
        continue
    end = text.find("\n---", 4)
    if end == -1:
        fails.append(f"{name}: no closing frontmatter delimiter")
        continue
    block = text[4:end]
    try:
        doc = yaml.safe_load(block)
    except yaml.YAMLError as exc:
        fails.append(f"{name}: YAML parse error ({exc})")
        continue
    if not isinstance(doc, dict) or "description" not in doc:
        fails.append(f"{name}: frontmatter parsed but missing required 'description' key")

with open(out_path, "w", encoding="utf-8") as fh:
    fh.write("\n".join(fails))
sys.exit(1 if fails else 0)
PYEOF
then
  pass_msg "A5 — frontmatter valid YAML (description key present) in both telemetry command docs"
else
  echo "fail: A5 — frontmatter YAML check failed:" >&2
  cat "$a5_out" >&2 || true
  fail=$((fail + 1)); status=1
fi
rm -f "$a5_out"

# --- Manual step: restart-twice resilience ----------------------------------------
echo "manual: DIA-069 local guard does NOT stop the plugin writing on the next OpenCode load — the upstream patch (part 2) does. Until then, run \`make restore-telemetry-commands\` between restart and verification, then re-run this guard."

# Aggregate summary (mirrors check-host-jq.sh: stdout on pass, stderr on fail).
if [ "$fail" -gt 0 ]; then
  echo "summary: ${ok} pass, ${fail} fail — see above" >&2
else
  echo "summary: ${ok} pass, ${fail} fail"
fi
exit "$status"
