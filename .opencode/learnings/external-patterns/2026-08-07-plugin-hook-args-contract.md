# Plugin hook args contract — tool.execute.before reads output.args, not input.args

- **Date:** 2026-08-07
- **Source:** DIA-059 diagnosis (ai-specialist ses_024786e73ffehjdfRoq3d17ueu)
- **Status:** applied

## Pattern
OpenCode plugin SDK: `tool.execute.before(input, output)` — tool arguments live in
**`output.args`**, NOT `input.args`. `input` is read-only `{ tool, sessionID?, callID?, directory? }`; `output` is mutable `{ args }`.

Reading args from `input.args` yields `undefined` at runtime → guards on `filePath`
silently never fire → fail-open security gates.

## Fix applied
- `.opencode/plugins/delegation-observer.ts` L482: `async (input, _output)` → `async (input, output)`
- L514: `(input as ...).args` → `(output as ...).args`
- After-hooks (`tool.execute.after`) DO read `input.args` — that is the correct contract for after-hooks; do not "fix" those.

## Evidence / sources
- Official docs: https://opencode.ai/docs/plugins (`.env`-protection + shell-escape examples both use `output.args`)
- Reference impls: `.opencode/oh-my-opencode-slim/src/hooks/apply-patch/index.ts` L70; `task-session-manager/index.ts` L308

## Tags
plugin-development, hook-contract, §10-gate
