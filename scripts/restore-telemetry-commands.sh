#!/usr/bin/env bash
# restore-telemetry-commands.sh — DIA-069 interim guard: restore the committed
# portable telemetry command docs to the committed baseline.
#
# WHY: the opencode-telemetry@0.1.19 plugin rewrites
# .opencode/commands/telemetry-{report,inspect}.md with literal /home/qualt
# paths on EVERY plugin load (src/commands.ts L33-34 unconditional
# fs.writeFileSync; src/index.ts L7 registerCommands). The committed baseline is
# the shipped portable octm-template form (runtime-resolved: octm / bun pm ls -g
# / ~/.config/opencode/...). This script restores that baseline after any
# OpenCode load polluted it — run it BETWEEN restart and verification until the
# upstream patch (DIA-069 part 2) lands.
#
# NOTE: this local guard does NOT stop the plugin writing on the next OpenCode
# load — that requires the upstream patch. `make restore-telemetry-commands`
# must be run between restart and verification.
set -euo pipefail

# Repo root, regardless of cwd (mirrors other scripts/ probes).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Repo-root guard: refuse to run from anywhere that is not the poetry-platform
# tree (protects against running with the wrong git worktree / cwd).
if [ ! -f "$ROOT/.opencode/commands/telemetry-report.md" ]; then
  echo "error: $ROOT/.opencode/commands/telemetry-report.md not found — not the poetry-platform repo root? Aborting." >&2
  exit 1
fi

git -C "$ROOT" restore -- .opencode/commands/telemetry-report.md .opencode/commands/telemetry-inspect.md

echo "ok: restored .opencode/commands/telemetry-report.md + telemetry-inspect.md to the committed portable baseline (DIA-069)"
