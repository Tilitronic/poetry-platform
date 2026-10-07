# Design: ai-self-improvement-auditor-and-cleanup

> **Proposal:** `openspec/changes/ai-self-improvement-auditor-and-cleanup/proposal.md`
> **Scope:** implementation design only — no system architecture decisions, no `.sdd/` escalation required. The change is within existing module boundaries; routing is split per §10 (AI-tooling config) and §2.4 (dev-infra shell validators + `NEXT-RUN.md` docs).

## Approach

This change stays entirely within existing module boundaries. It does not introduce any new module, does not alter any data flow described in `architecture.md` (root), and does not affect the DIA redispatch cycle. The `.sdd/` directory contains only `.sdd/dia-redispatch-cycle/architecture.md` + `README.md` — no module doc governs `.opencode/scripts/`, `.opencode/agents/`, `.opencode/skills/`, or the AI-tooling config surface. Per AGENTS.md §3, the absence of a governing `.sdd/` is a documentation gap, but one this change does not fill. The precedent is `openspec/changes/dev-infra-config-validators/design.md` (same conclusion, same routing, same absence of `.sdd/`).

**Existing patterns followed:**

- **3-tier exit contract + HARD/SOFT partition** — copied verbatim from `.opencode/scripts/validate-skills.sh` (the immediate prior art for the dup-detection extension).
- **Stderr/stdout stream protocol** — `FAIL:` to stderr, `warn:` to stderr, `ok:` to stdout, final summary `N passed, N failed, N warnings` to stdout. Same as `validate-skills.sh`.
- **Collect-all, never fail-fast** — same as `validate-skills.sh`. A HARD dup finding does not abort the walk; the script accumulates all findings and reports them in one pass.
- **Env override for bats meta-tests** — `validate-skills.bats` uses `SKILLS_ROOT` to point the validator at a fixture tree; this change adds `GLOBAL_SKILLS_ROOT` as a parallel override for the global-side fixture.
- **`set -euo pipefail`** — same fail-fast default as `validate-skills.sh` and all other project scripts.
- **4-source agent registration contract** — copied from `scripts/validate-agent-names.sh` (S1 §9 row / S2 opencode.jsonc / S3 oh-my-opencode-slim.jsonc / S4 `.opencode/agents/*.md` frontmatter). The `@ai-auditor` addition is a mechanical extension of the existing pattern.
- **Frontmatter shape of memory-manager.md** — mirrored for `ai-auditor.md` (description + mode only; permissions live in `opencode.jsonc`).

## Files changed

| File                                                              | Action | Task | Description                                                                                                                                                                                                                                                                                                                                                                                                                  |
| ----------------------------------------------------------------- | ------ | ---- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.opencode/skills/<dupe-1>/` through `.opencode/skills/<dupe-5>/` | delete | T1   | Five byte-exact duplicate skill directories (byte-identical to skills already loaded from the global `~/.config/opencode/skills/`). Keeper set: `playwright-browser` (project-local acceptance-test extensions) + `git-diff` (project-local context injection). Net effect: `.opencode/skills/` drops from 20 to 15 entries.                                                                                                 |
| `.opencode/scripts/validate-skills.sh`                            | modify | T1   | Add two-tier dup detection between project skills (under `SKILLS_ROOT`) and global skills (under `GLOBAL_SKILLS_ROOT`). Byte-exact match → HARD exit 1 via single-pass `sha256sum` group-by-hash O(n). Near-dupe → SOFT warn via single `diff -r`. Missing global dir → exit 2 INFRA. Empty dirs → exit 0. Script-header documents case-sensitive exact + follow-symlinks policy (docs-only; not enforced programmatically). |
| `scripts/__tests__/validate-skills.bats`                          | modify | T1   | Add 6-case dup-detection fixture matrix per proposal §Testing Decisions. Uses `SKILLS_ROOT` + new `GLOBAL_SKILLS_ROOT` env overrides to point the validator at fixture trees.                                                                                                                                                                                                                                                |
| `.opencode/agents/ai-auditor.md`                                  | create | T2   | New agent definition file. Frontmatter: description + mode only (mirroring `memory-manager.md`). Permissions live in `opencode.jsonc`. Body: short mandate description (the auditor's read-only scope).                                                                                                                                                                                                                      |
| `.opencode/opencode.jsonc`                                        | modify | T2   | Two changes: (a) add `ai-auditor` agent block with `description`, `mode: "subagent"`, read-only `permission` block (edit: deny, bash narrow allowlist, task: deny). (b) narrow the existing `ai-specialist` `description` field to a docs-only mandate wording (no change to `prompt`, `orchestratorPrompt`, model, temperature, color, or other permissions).                                                               |
| `.opencode/oh-my-opencode-slim.jsonc`                             | modify | T2   | Add `ai-auditor` to the `agents` block + 3 preset slots (one per existing preset shape that currently carries `ai-specialist`). No changes to `ai-specialist`'s slim entry (the narrowing is confined to the `opencode.jsonc` description field per T2).                                                                                                                                                                     |
| `AGENTS.md`                                                       | modify | T2   | Add `ai-auditor` row to the §9 agent naming table (display name `@ai-auditor`, internal name `ai-auditor`, lane `AI-tooling audit (read-only)`).                                                                                                                                                                                                                                                                             |
| `docs/dev-infra-audit/NEXT-RUN.md`                                | modify | T3   | Add a new bullet under §2 (Orchestrator Operating Rules) capturing the council budget rule: warn at 75% (1125 of 1500 credits), hard-stop at 90% (1350 of 1500 credits). Text per §Implementation details below.                                                                                                                                                                                                             |

> **Errata (2026-08-06):** factual correction to the files-changed table row above — **not a rule change**. The pre-deletion audit (DIA-052) found only **3 of 5** candidates were byte-exact duplicates: `mermaid-diagramming`, `console-charting`, and `teaching` were deleted. `book-rag` and `debugging-workflow` differ from their global counterparts (project-local fixes) and were **retained** as near-duplicates per the HARD/SOFT partition (SOFT warn, no deletion). Actual post-cleanup count: **17 entries** (from 20), not 15; **3 deletions**, not 5. Verification-gate references that hard-code "15 skills" / "15 entries" / "5 deletions" (Verification gate summary rows) are superseded by this correction.

## Implementation details

### §1 — Dup-detection extension to `.opencode/scripts/validate-skills.sh`

**Inputs:**

1. **Project skills tree** — `SKILLS_ROOT` (default `$ROOT/.opencode/skills`, overridable via env for bats). Existing walk iterates `$SKILLS_ROOT/*/` and validates each `SKILL.md` frontmatter.
2. **Global skills tree** — `GLOBAL_SKILLS_ROOT` (new env override; default `$HOME/.config/opencode/skills`). Missing global dir → exit 2 INFRA.

**Two-tier detection (per Q2 ruling — HARD vs SOFT partition):**

- **Tier 1 — byte-exact (HARD, exit 1):** single-pass `sha256sum` over every `SKILL.md` in both trees, grouped by hash. If any hash has ≥2 entries (one from project, one from global), emit one `FAIL:` line per pair to stderr and flip the HARD failure counter. O(n) in the total number of SKILL.md files (one hash per file).
- **Tier 2 — near-dupe (SOFT, warn-only):** for every project `SKILL.md` that did NOT match byte-exact, run a single `diff -r` against the global skill dir of the same name (if present). If `diff -r` reports any differences, emit one `warn:` line to stderr. Does NOT flip the exit code; joins the soft-warnings bucket.
- **Empty dirs → exit 0** per the existing `validate-skills.sh` empty-root pattern (Q5 precedent).
- **Missing global dir → exit 2 INFRA.** The dup-detection step cannot run; this is an INFRA condition, not a HARD finding.

**Script-header docs (per interview Q2 ruling — case-sensitive exact + follow symlinks):** the script header documents the policy ("case-sensitive exact match; follows symlinks") as a human contract, not as a programmatic enforcement. The implementation uses `sha256sum` on the literal file content (which is case-sensitive and symlink-following by default in bash). No special flags are needed; the docs exist so a future reader understands the intent without inferring it from the code.

**Stream contract (extends existing):**

- Each project skill that passes all existing HARD checks AND is not a byte-exact duplicate → `ok: <skill_file>` (existing line).
- Each byte-exact duplicate → `FAIL: duplicate skill '<name>' (byte-exact match with global '<global-path>')` to stderr.
- Each near-dupe → `warn: near-duplicate skill '<name>' (differs from global '<global-path>')` to stderr.
- Final summary line aggregates all HARD failures (existing + dup-detection) and all warnings (existing + near-dupes).

**Exit code (extends existing):**

- 0 — all HARD checks pass (incl. no byte-exact duplicates); SOFT warnings may print.
- 1 — any HARD check fails (incl. at least one byte-exact duplicate).
- 2 — INFRA: missing `python3`, missing `SKILLS_ROOT`, missing `GLOBAL_SKILLS_ROOT`, missing `sha256sum` command.

**Fold counters into existing summary (per interview Q6 ruling):** the dup-detection HARD/SOFT counts are folded into the existing `$passed/$failures/$warnings` accumulators. No separate counter, no separate summary line. The final output remains a single `N passed, M failed, K warnings` line.

### §2 — `@ai-auditor` 4-source registration

**S1 (AGENTS.md §9 row):** add one row to the §9 table. Fields:

- Display name: `@ai-auditor`
- Internal name: `ai-auditor`
- Lane: `AI-tooling audit (read-only)`

The `scripts/validate-agent-names.sh` validator extracts this row automatically; no validator change needed.

**S2 (opencode.jsonc agent block):** add an `ai-auditor` block under `agent`:

```jsonc
"ai-auditor": {
  "description": "Read-only auditor for AI-tooling config changes. Independent Phase-6 reviewer under AGENTS.md §10.",
  "mode": "subagent",
  "model": "opencode-go/qwen3.7-plus",
  "temperature": 0.2,
  "color": "info",
  "permission": {
    "edit": "deny",
    "bash": {
      "curl": "allow",
      "wget": "allow",
      "*": "deny"
    },
    "task": "deny"
  }
}
```

The read-only `permission` block is the behavioural enforcement — `mode: subagent` alone does not prevent writes. The `edit: deny` + narrow `bash` allowlist + `task: deny` enforce read-only at the runtime level.

**S3 (oh-my-opencode-slim.jsonc agents + 3 presets):** add `ai-auditor` to the `agents` block (model/variant/skills/mcps) AND to each of the 3 preset shapes that currently carry `ai-specialist`. The preset slots use the same model/variant/skills/mcps structure as existing agents; the coder lane decides exact model allocation per preset shape based on the existing `ai-specialist` preset entries (mirror those shapes).

**S4 (`.opencode/agents/ai-auditor.md` frontmatter):**

```yaml
---
description: Read-only auditor for AI-tooling config changes. Independent Phase-6 reviewer under AGENTS.md §10.
mode: subagent
---
```

Only `description` and `mode` in frontmatter — mirroring `memory-manager.md` (interview Q3 ruling). Permissions live in `opencode.jsonc`; the `.md` file's body carries the short mandate description.

### §3 — Narrow `@ai-specialist`

In `.opencode/opencode.jsonc`, revise the `description` field of the existing `ai-specialist` block from:

> "Researches agent/skill/config best practices for OpenCode itself. Read-only — findings routed through orchestrator for persistence."

to a docs-only mandate wording. Exact text:

> "Read-only researcher of agent/skill/config best practices for OpenCode itself. Findings routed through orchestrator for persistence. Scope: documentation + config review only; no runtime dispatch authority; no implementation."

No change to `prompt`, `orchestratorPrompt`, `model`, `temperature`, `color`, or the `permission` block (already `edit: deny`). The narrowing is a `description`-field rewording only — making the docs-only mandate explicit in the field that surfaces in runtime agent listings.

### §4 — Council budget controls in `NEXT-RUN.md` §2

Add one new bullet to the §2 Orchestrator Operating Rules list (insertion point: after the existing `CRISIS-DETECTION` bullet, before `PROGNOSIS-DISCIPLINE`). Text:

> **COUNCIL-BUDGET-GUARD**: the orchestrator MUST monitor cumulative council-dispatch credit spend against a 1500-credit session budget. **Warn** at 75% (1125 credits): emit a visible notice to the developer with the current spend + remaining budget; continue dispatching. **Hard-stop** at 90% (1350 credits): cease all council dispatches for the remainder of the session; notify the developer; hand off remaining council-needs to the next session via the HANDOFF.md prognosis. Detection: `token_stats` + the council-dispatch subset of the spend; credit cost per councillor dispatch is model-dependent (use the live `token_stats` cost field, not a static lookup).

The credit base (1500) is a session budget, not a per-dispatch cap. The warn threshold is informational; the hard-stop is a dispatch freeze. The detection mechanism reuses the existing `token_stats` call pattern from the SELF-RERUN rule.

## Seams

> Per `openspec/config.yaml`: "Include a Seams section listing the pre-agreed public boundaries where tests will live. Prefer existing seams; propose new ones only at the highest level necessary."

| Seam                                                            | What it is                                                                                                      | Test location                                                                                                  | Test type                                                                |
| --------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| **S1 — `.opencode/scripts/validate-skills.sh`**                 | Extended with dup detection (byte-exact HARD + near-dupe SOFT).                                                 | `scripts/__tests__/validate-skills.bats` (extended suite, `SKILLS_ROOT` + `GLOBAL_SKILLS_ROOT` env overrides). | Behavioral: exit code + stderr/stdout content per 6-case fixture matrix. |
| **S2 — `scripts/validate-agent-names.sh`**                      | Pre-existing 4-source validator; the `ai-auditor` registration is validated by this script.                     | No test change — the existing real-config run must report `22 passed, 0 failed, 0 warnings` post-change.       | Implicit: real-config run is the integration test.                       |
| **S3 — `make test-skills` / `make test-config` exit-code seam** | Pre-existing make-level seam; the dup-detection validator + the 4-source validator both feed through this seam. | `make test-skills` + `make test-config` end-to-end runs post-T1/T2.                                            | Integration: exit 0 on real project config.                              |
| **S4 — §10 Phase-5 restart+smoke seam** (manual)                | Post-implementation OpenCode restart + `@ai-auditor` minimal-task dispatch.                                     | Manual orchestrator action (documented in tasks.md T2 verification procedure).                                 | Behavioural: dispatchable + read-only enforced.                          |
| **S5 — `docs/dev-infra-audit/NEXT-RUN.md` §2** (doc)            | Council budget rule addition.                                                                                   | Visual review (no automated test).                                                                             | Doc invariant.                                                           |

### New seams vs. existing seams

- **S1 is the only seam extended** — the dup-detection logic slots into the existing `validate-skills.sh` walk. The existing `SKILLS_ROOT` env override is retained; `GLOBAL_SKILLS_ROOT` is the only new env seam (parallel shape).
- **S2/S3 are pre-existing seams** — the `@ai-auditor` registration is mechanical; it is exercised by the existing `validate-agent-names.sh` real-config run. No new test is needed; the invariant "22 passed, 0 failed, 0 warnings" is the acceptance criterion.
- **S4 is a manual §10 seam** — the only way to prove runtime dispatchability + read-only enforcement is to restart OpenCode and dispatch the agent on a minimal task. This is the Phase-5 contract of AGENTS.md §10; no bats substitute exists.
- **S5 is a doc seam** — the council budget rule is a prose addition; verification is visual review.

### Testability env seams

- **`GLOBAL_SKILLS_ROOT` env override** for `validate-skills.sh` — points the dup-detection step at a temp fixture tree for bats tests. Same shape as `SKILLS_ROOT`. bats tests set both overrides explicitly; the default path (`$HOME/.config/opencode/skills`) is only used in production (make-callable) invocation.

## Design constraints and trade-offs

### Why byte-exact HARD + near-dupe SOFT (Q2 ruling)

A byte-exact duplicate is a clear defect — the same file is loaded twice, wasting context and masking drift. It should fail the build (HARD exit 1). A near-duplicate (different whitespace, minor comment drift) is a judgement call — the files are not identical, and the difference may be intentional (e.g., a project-local extension of a global skill). Categorizing near-dupes as SOFT (warn without exit-code flip) surfaces the drift risk without over-constraining legitimate divergence. A future need to harden the near-dupe check is a design change; overloading this first pass is not justified.

### Why single-pass `sha256sum` group-by-hash O(n) (Q3 ruling)

A naive O(n²) pair-comparison of every project skill against every global skill scales quadratically with the number of skills. The project currently has ~20 project skills and ~20 global skills — tolerable today but a scalability hazard. Hashing every `SKILL.md` once (O(n)) and grouping by hash value is linear and produces the byte-exact match set in one pass. `sha256sum` is POSIX-standard, available on every dev host and CI runner, and fast enough to run on every `make test-skills` invocation without perceptible latency.

### Why `GLOBAL_SKILLS_ROOT` env override mirrors `SKILLS_ROOT` (Q3 ruling)

The existing `SKILLS_ROOT` env override in `validate-skills.sh` is the established pattern for isolating bats tests from the developer's real project tree. Mirroring it with `GLOBAL_SKILLS_ROOT` means the dup-detection bats tests can point at two temp fixture trees (one for "project", one for "global") without touching the developer's actual global skills dir (`~/.config/opencode/skills`). This is the minimal-env change that preserves the hermetic-test discipline of the existing bats suite.

### Why the `@ai-auditor` `.md` frontmatter carries description+mode only (Q3 ruling)

The existing `memory-manager.md` establishes the precedent: frontmatter carries only `description` + `mode: subagent`; permissions live in `opencode.jsonc`. This separation is deliberate — the `.md` file is the human-readable mandate (surfaces in the agent listing as the `description`); the `opencode.jsonc` block is the runtime-behavioural contract (permissions, model, temperature). Mixing permissions into the `.md` frontmatter would produce two sources of truth for the same fact. Following the `memory-manager.md` pattern keeps the two-source split clean.

### Why `@ai-specialist` narrowing is description-only (interview Q5 ruling)

The `ai-specialist` `prompt` and `orchestratorPrompt` fields already express a read-only research mandate. The narrowing is a `description`-field rewording to make the docs-only scope explicit in the runtime-visible agent listing — the field that other agents see when introspecting the agent surface. No behavioural change; no permission change (already `edit: deny`). Changing `prompt` would risk breaking the existing ai-specialist workflow; the description-only narrowing is the minimal change that makes the overlap with `@ai-auditor` explicit in the listing without touching the working mandate.

### Why no OMO JSONC schema validation (Q7 known gap)

`oh-my-opencode-slim.jsonc` has no upstream JSON schema — the OMO project does not publish one. Adding local schema validation would require authoring and maintaining a schema from scratch, which is out of scope for this change (interview Q7 ruling — future work). The current parsing via inline Python is the contract; any schema effort belongs in a separate change that can address the broader OMO schema surface, not just this project's slice.

### Why fold dup-detection counters into the existing summary (Q6 ruling)

The existing `validate-skills.sh` emits a single `N passed, M failed, K warnings` line. Adding a separate dup-detection summary line would split the output into two reports, complicating CI log parsing and the make-callable contract. Folding the dup-detection HARD/SOFT counts into the existing accumulators preserves the single-line summary contract — a byte-exact duplicate joins the failures bucket, a near-dupe joins the warnings bucket. The FAIL/warn messages themselves name the dup-detection cause, so the developer can distinguish dup findings from frontmatter findings in the output.

## Verification gate summary

| Gate                                           | When     | Required                                                                                                                                                                                                                              |
| ---------------------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `make test-skills`                             | After T1 | Exit 0 on the real project config post-cleanup (15 skills, no dups).                                                                                                                                                                  |
| `make test-shell`                              | After T1 | Pre-existing bats baseline + the 6 new dup-detection cases pass.                                                                                                                                                                      |
| `make test-config`                             | After T2 | `validate-agent-names.sh` reports `22 passed, 0 failed, 0 warnings` (post-`@ai-auditor` registration).                                                                                                                                |
| `scripts/validate-agent-names.sh` (standalone) | After T2 | `22 passed, 0 failed, 0 warnings` on real project config.                                                                                                                                                                             |
| §10 Phase-5 restart+smoke                      | After T2 | OpenCode restarted; `@ai-auditor` dispatchable on a minimal test task; `edit: deny` enforced (attempt to edit a file fails at the permission layer); bash narrow allowlist enforced.                                                  |
| Visual review: `NEXT-RUN.md` §2                | After T3 | Council budget rule + 75% warn / 90% hard-stop thresholds present and well-formed.                                                                                                                                                    |
| Visual review: 5 skill-dir deletions           | After T1 | `ls .opencode/skills/` shows 15 entries; keeper skills (`playwright-browser`, `git-diff`) present and byte-identical to pre-change (`git diff HEAD@{1} -- .opencode/skills/playwright-browser/ .opencode/skills/git-diff/` is empty). |

## Traceability to confirmed rulings

Every design decision above is locked to a confirmed interview ruling. The mapping:

| Decision                                                                                | Ruling source                                                |
| --------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| Single change `ai-self-improvement-auditor-and-cleanup`                                 | Q1                                                           |
| Phase 1 (CLASH) dropped                                                                 | Q1                                                           |
| Keeper skills: `playwright-browser` + `git-diff` only                                   | Q1                                                           |
| 5 skill-dir deletions                                                                   | Q1                                                           |
| Dup-detection extension to `validate-skills.sh`                                         | Q1                                                           |
| `@ai-auditor` 4-source registration                                                     | Q1, Q3                                                       |
| Narrow `@ai-specialist` description                                                     | Q5                                                           |
| Council budget controls in `NEXT-RUN.md` §2                                             | Q1, Q7                                                       |
| Byte-exact HARD + near-dupe SOFT partition                                              | Q2                                                           |
| Single-pass `sha256sum` group-by-hash O(n) for byte-exact                               | Q3                                                           |
| `GLOBAL_SKILLS_ROOT` env seam (mirror `SKILLS_ROOT`)                                    | Q3                                                           |
| Missing global dir → exit 2 INFRA                                                       | Q2 (parallel with exit-2 INFRA precedent)                    |
| Empty dirs → exit 0                                                                     | Q5 (parallel with `validate-skills.sh` empty-root precedent) |
| Case-sensitive exact + follow symlinks as script-header docs only                       | Q2                                                           |
| Fold dup counters into existing summary                                                 | Q6                                                           |
| `ai-auditor.md` frontmatter = description+mode only (mirror `memory-manager.md`)        | Q3                                                           |
| Permissions live in `opencode.jsonc`, not the `.md` frontmatter                         | Q3 (parallel `memory-manager.md` precedent)                  |
| No OMO JSONC schema validation in this change (known gap, future work)                  | Q7                                                           |
| No `.sdd/` module doc authored                                                          | §Design authority (precedent allows)                         |
| §10 Phase-1 ai-specialist gate already DONE (finding `ai--1`)                           | Interview preamble                                           |
| §10 Phase-5 restart+smoke required                                                      | AGENTS.md §10 (Phase 5 of the workflow chain)                |
| Warn 75% (1125) / hard-stop 90% (1350) of 1500 credits                                  | Q7                                                           |
| Out of scope: global skills dir mods, keeper merge-to-global, dcp.jsonc, DIA-051, CLASH | Q1                                                           |
| Out of scope: global opencode config                                                    | Q2                                                           |

No decision in this design.md is invented beyond the confirmed rulings. If a gap emerges during implementation, the coder lane flags it to the orchestrator rather than deciding silently.
