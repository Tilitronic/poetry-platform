# DIA-078 coder snip-wrapper loop recurrence — class-level guardrail + native doom_loop enforcement (2026-08-10)

- **Date:** 2026-08-10
- **Source:** DIA-078 fix implementation (§10 Phase 4, code-executor lane); gate research from ai-specialist, conspect `knowledge/res010-dia078-loop-hardening/`. Registered per AGENTS.md §10 Phase 6; follows `2026-08-10-dia063-ticket-gate-non-determinism.md` (which recorded the DIA-078 NEW INCIDENT).
- **Status:** DIA-078 fix APPLIED (all 3 changes); ticket OPEN pending restart smoke.

## Ticket

- **DIA-078** (Major, OPEN) — coder snip-wrapper loop recurrence: coder sessions ran 7+ byte-identical `snip make test-config` commands (EXIT_CODE=0, no progress) until session error.

## Symptom

- cod-2 (ses_014d638bfffemyvUdhEaa4uhTq) + cod-3 (ses_014cf7024ffe1gvwIMsRvHb0jH) both errored looping `snip make test-config` — identical command + identical EXIT_CODE=0 output, 7+ repetitions, no progress.
- DIA-075 recurrence broader than jq: the prior guardrail only forbade `snip jq` (hashing/integrity work), leaving `snip make` and every other snip-prefixed command as a hole.

## Findings

### 1. Native `doom_loop` permission — discovery (previously unknown to the project)

- OpenCode has a native agent-permission key `doom_loop` with a **default of "ask"**.
- Setting `"doom_loop": "deny"` on an agent **mechanically halts execution when the same tool call repeats 3× with identical input** — a platform-level hard stop that fires regardless of prompt compliance.
- Previously unknown to the project: prior loop mitigation relied on prompt-level anti-loop rules only. This discovery closes that gap — `.opencode/opencode.jsonc` coder block now carries `"permission": { "doom_loop": "deny" }`.

### 2. Class-vs-instance guardrail lesson (DIA-075 → DIA-078)

- The DIA-075 guard was scoped to a single **instance** (`snip jq` for checksum/hashing/integrity work) → the `make` hole: `snip make test-config` repeated 7+ times with identical output.
- Guardrails MUST be specified against the **entire class**, not a single example. Generalized rule: `snip` as a prefix is FORBIDDEN for ANY command — snip is an output-display filter for interactive use, NOT a command executor. Never prefix builds, tests, lint, integrity checks, or git operations with `snip`. Run all commands plain.
- Applied to the coder prompt in all 3 presets (cebula, opencode-go, free) as `## Snip-prefix Guardrail (DIA-075, DIA-078)`; the DIA-075 jq-specific guidance is retained as a subsection documenting the incident.

### 3. Prompt-vs-mechanical enforcement

- **Advisory prompt rules are NOT enforced** — a looping agent can ignore them (proven by the 7× recurrence despite the existing anti-loop sentence in the coder prompt).
- **Mechanical permission rules ARE enforced** — `doom_loop: deny` halts the 3×-identical repetition at the platform level.
- Lesson: recurrence-prone agent failure modes get BOTH a class-level prompt guardrail (guidance) AND a mechanical permission (enforcement).

## Fix applied (DIA-078)

1. `.opencode/oh-my-opencode-slim.jsonc` — coder prompt guardrail generalized in all 3 presets: section renamed `## Snip-prefix Guardrail (DIA-075, DIA-078)`, universal FORBIDDEN class rule, jq guidance kept as a subsection, anti-loop rule hardened to the 2-attempt STOP-and-escalate form.
2. `.opencode/opencode.jsonc` — coder agent `"permission": { "doom_loop": "deny" }` (mechanical 3×-identical-call halt).
3. Learnings registered (this file) + CHANGELOG entry dated 2026-08-10.

## Reuse notes

- NEVER prefix any command with `snip` — run plain (builds, tests, lint, integrity checks, git operations).
- After ONE byte-identical output, attempt exactly ONE different approach (different command, different flags, or read the error trace). If the SECOND attempt is also byte-identical, STOP immediately and escalate to the orchestrator with the evidence — never run the same command a third time.
- Recurrence-prone agent failure modes get BOTH a class-level prompt guardrail AND a mechanical `doom_loop: deny` permission.

## Tags

DIA-078, DIA-075, snip-loop, doom_loop, guardrail, class-vs-instance, prompt-vs-mechanical, config-hardening, §10
