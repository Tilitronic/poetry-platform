# Proposal: batch-d-parallel-coders

> **Status:** drafted
> **Scope:** opencode-config (BATCH-DISPATCH rule extension + quick-fix invariants)
> **Ticket:** `docs/dev-infra-audit/tickets/DIA-172-parallel-coders-batch-d-expansion.md`
> **Predecessor tickets:**
>
> - `docs/dev-infra-audit/tickets/DIA-159-*` (original BATCH-DISPATCH analysis, analysis report lost to persistence gap)
> - `docs/dev-infra-audit/tickets/DIA-162-*` (BATCH-DISPATCH rule text + plugin A1, implemented 2026-08-12, commit 0697a08)
> - `docs/dev-infra-audit/tickets/DIA-163-*` (plugin lockstep + batch A/B/C, implemented 2026-08-12, commit 7b08e90)
> - `docs/dev-infra-audit/tickets/DIA-162-*` (DIA-162 lockstep 5-surface invariant)
>
> **Architector design:** approved 2026-08-13 (see architector design in change directory).
> **Developer operational requirements (authoritative):** every coder works in its OWN git worktree; ONE worktree per task; per-worktree reviewer on committed fixed points; orchestrator manages worktree names + serialized squash-merges; final plan must be presented to developer for approval BEFORE implementation starts.
> **Implementation commits:** none yet (spec phase).
> **Routing:** AGENTS.md section 2.5 (OpenCode Configuration Changes) -> gate: `@ai-specialist` (read-only research; already satisfied by DIA-172 pre-work findings); `@coder` implements; `make test-config` validates; `@ai-auditor` independent review. Section 10 workflow applies.
> **Architecture gap (closed by this change):** `.sdd/opencode-config/architecture.md` did not exist. This change authors the two ADRs (Batch Pattern D + Singleton-Batch Semantic Exemption) as part of the change.

## Why

The DIA-162/DIA-163 implementation locked the batch-dispatch rule to three patterns (A read-only fan-out, B single-writer + readers, C post-fix reviewer pair). Two gaps surfaced on 2026-08-13:

1. **Throughput ceiling on parallel implementation.** Today, running two `@coder` lanes on disjoint files still triggers A1 because the plugin sees "two writers". The worktree-based parallel-dev model (DIA-100) already makes parallel coders physically safe -- the plugin just needs to recognize and assert the worktree invariant.
2. **Invariant drift across the five lockstep surfaces + a handful of quick-fix violations.** Pre-work findings (DIA-172) surfaced five concrete drifts: analyzer-escalated still claims a write to `memory-shelf.yaml` (violates DIA-162 sole-writer invariant), code-navigator and observer are classified read-only but inherit the global bash allow (technically write-capable), conspecter's allow list still mentions memory-shelf.yaml, the plugin false-positives on single-`task()` + semantic-tool turns, and `architector` is read-only by config but missing from batch A.

Parallel coders unlock multi-lane implementation throughput without re-introducing git-index contention, provided the plugin enforces distinct-worktree assertions and the orchestrator contract commits to one-worktree-per-task, per-worktree reviewer, and serialized squash-merges.

## What Changes

### Batch-D (parallel coders)

- **Plugin `delegation-observer.ts`:** extend per-turn task-call capture to extract `WORKTREE: <path>` from the task description+prompt via regex. Change `isSafeTaskBatch` signature to `tasks: Array<{agent: string, worktree?: string}>`. Add predicate D: multiple `@coder` lanes allowed ONLY IF (a) every non-coder lane is in READ_ONLY_LANES (after F5, this includes `architector`) and (b) every coder asserts a distinct worktree path (Set size == coder count; missing or duplicate => unsafe).
- **Prompt text (3 identical presets in `.opencode/oh-my-opencode-slim.jsonc` at lines 26/207/429):** replace the BATCH-DISPATCH RULE text with the extended version that adds batch D wording ("multiple @coder lanes ONLY IF each uses a separate git worktree and the dispatch payload asserts WORKTREE: <path> per coder, with disjoint file sets").
- **Coder inline instructions (presets where `coder` has existing inline prompts per DIA-128):** APPEND worktree confinement directive ("If dispatched as part of a parallel batch (batch D), strictly confine your work to the git worktree path specified in your task payload; do not touch the main tree or other worktrees; commit to your assigned branch only.") plus standard verification-evidence duty.
- **Orchestrator append (`orchestrator_append.md`):** A1 section extended with architector in batch A + batch D wording. A6 Serialization Points extended with item 6: "parallel coders -> reviewer: per-worktree reviews MUST operate on committed fixed points inside that worktree; squash-merges to the main branch MUST be serialized (one at a time)."

### Quick-fixes (F1-F5)

- **F1 (sole-writer invariant):** `.opencode/opencode.jsonc` removes the `".opencode/memory-shelf.yaml": "allow"` entry from analyzer-escalated's edit block (~line 257) and fixes the adjacent comment (~lines 244-245). `.opencode/agents/analyzer-escalated.md` (~lines 41-42) replaces the self-registration instruction with "do NOT write .opencode/memory-shelf.yaml; report artifact paths (memory-manager registers)".
- **F2 (strict read-only):** `.opencode/opencode.jsonc` adds `"bash": "deny"` to code-navigator (~line 320) and observer (~line 340) permission blocks.
- **F3 (doc drift):** `.opencode/agents/conspecter.md` (line 18 and ~lines 82-83): edit allow list becomes `knowledge/*` only (no memory-shelf.yaml; conspecter delegates shelf registration to memory-manager).
- **F4 (singleton-batch semantics):** `.opencode/plugins/delegation-observer.ts`: classification is safe if actual `task()` call count in the turn is <= 1. Eliminates false A1 warnings for "one task() + other semantic tools (log_decision)".
- **F5 (architector read-only):** add `architector` to `READ_ONLY_LANES` in `delegation-observer.ts` (~line 277) AND to batch A in ALL 5 lockstep surfaces: 3 BATCH-DISPATCH rule texts in `oh-my-opencode-slim.jsonc` (lines 26/207/429) + A1 section of `orchestrator_append.md` (~lines 156-167).

### ADRs (new `.sdd/` document)

- **`.sdd/opencode-config/architecture.md`:** new file with two ADRs transcribed from the architector design:
  - ADR 1 "Batch Pattern D (Parallel Coders)" (Status Accepted; DIA-172; parallel @coder gated by strict `WORKTREE: <path>` payload assertion; plugin validates distinct worktree paths).
  - ADR 2 "Singleton-Batch Semantic Exemption" (Status Accepted; single `task()` + semantic tools classified safe if exactly one `task()` call).

## Capabilities

### New Capabilities

None. This is a pure dev-infra/opencode-config change -- no spec-level behavior of the Poetry Platform application changes.

### Modified Capabilities

None. No spec-level behavior changes.

> **Spec opt-out rationale (`skip_specs: true`):** the change modifies OpenCode's own configuration (plugin, prompt presets, agent markdown files, orchestrator append) and authors a `.sdd/` document. None of this alters the Poetry Platform application's observable behavior, APIs, or data models. The change's test surface is `make test-config` + behavioral tests of the plugin classification function + lockstep grep across the five surfaces -- all internal tooling concerns. Adding spec files to satisfy the validator would invent requirements that do not exist.

## Impact

### Affected files (implementation)

| File                                                   | Change                                                                                                                                                                              |
| ------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.opencode/plugins/delegation-observer.ts`             | F4 (singleton-batch semantics, ~line 410-420 + 807) + F5 (add architector to READ_ONLY_LANES, ~line 277) + batch D predicate (new signature, new Set-based distinct-worktree check) |
| `.opencode/oh-my-opencode-slim.jsonc`                  | 3 identical preset edits at lines 26/207/429 (BATCH-DISPATCH rule text with architector in A + batch D wording)                                                                     |
| `.opencode/oh-my-opencode-slim/orchestrator_append.md` | A1 section extended (~156-167) + A6 item 6 added (serialized squash-merge contract)                                                                                                 |
| `.opencode/opencode.jsonc`                             | F1 (analyzer-escalated edit block ~257, comment ~244-245) + F2 (code-navigator ~320 + observer ~340 add `bash: deny`)                                                               |
| `.opencode/agents/analyzer-escalated.md`               | F1 (lines 41-42, replace self-registration instruction)                                                                                                                             |
| `.opencode/agents/conspecter.md`                       | F3 (line 18 + ~82-83, edit allow list = `knowledge/*` only)                                                                                                                         |
| `.sdd/opencode-config/architecture.md`                 | New file (2 ADRs)                                                                                                                                                                   |

### Affected systems

- **OpenCode orchestrator dispatch loop:** batch D becomes a legal dispatch pattern; orchestrator must construct dispatch payloads with `WORKTREE: <path>` per coder and manage the serialized squash-merge lifecycle.
- **Plugin `delegation-observer`:** signature change to `isSafeTaskBatch` is internal (no other callers). A1 warning behavior changes (singleton-batch exemption + batch D recognition).
- **Developer operational workflow (this change's scope includes a contract):** every coder in a parallel batch works in its OWN worktree; ONE worktree per task; per-worktree reviewer on committed fixed points; orchestrator owns worktree naming + serialized squash-merges; plan presented to developer before implementation starts.

### Not affected

- **Poetry Platform application code:** no TypeScript/Python/Rust application files touched.
- **`architecture.md` (root):** no system architecture changes; the change operates inside the existing opencode-config module boundary.
- **`scripts/` directory:** no dev-infra script changes (worktree lifecycle is already implemented via DIA-100; this change only consumes it via orchestrator contract).
- **Docker/CI:** no container or CI changes.

## Developer operational contract (authoritative; takes precedence where it extends the design)

These are non-negotiable operational requirements from the developer. They are referenced (not restated at length) in design.md and tasks.md:

1. **One worktree per coder lane.** Every coder dispatched as part of a parallel batch must receive a unique git worktree path in its dispatch payload (`WORKTREE: <path>`).
2. **One worktree per task.** A single task must NEVER have multiple worktrees created for it. If a task is re-dispatched, it reuses the same worktree (or a new one replaces the old, but never two simultaneously).
3. **Per-worktree reviewer.** For every worktree created for a coder, a reviewer is later dispatched to review that worktree (not the coder, not the task -- the worktree on a committed fixed point inside it).
4. **Orchestrator-managed worktree naming.** The orchestrator owns the worktree naming convention (aligned with DIA-074 branch naming: `feature/<ticket>-<short-name>`, worktree path derived by `scripts/worktrees.sh`).
5. **Serialized squash-merges.** The orchestrator merges worktrees into the main working branch ONE AT A TIME (serialized squash-merges). Never parallel merges.
6. **Developer approval gate.** When the OpenSpec artifacts are complete, the orchestrator MUST present the final plan to the developer for approval BEFORE implementation starts. (This is an orchestrator-contract requirement for this specific change, not a general rule.)

## Rollback plan

Every artifact added or modified by this change is independently revertable.

| Artifact                                                         | Revert                          |
| ---------------------------------------------------------------- | ------------------------------- |
| `.opencode/plugins/delegation-observer.ts` (batch D + F4 + F5)   | `git checkout` to prior version |
| `.opencode/oh-my-opencode-slim.jsonc` (3 preset edits)           | `git checkout` to prior version |
| `.opencode/oh-my-opencode-slim/orchestrator_append.md` (A1 + A6) | `git checkout` to prior version |
| `.opencode/opencode.jsonc` (F1 + F2)                             | `git checkout` to prior version |
| `.opencode/agents/analyzer-escalated.md` (F1)                    | `git checkout` to prior version |
| `.opencode/agents/conspecter.md` (F3)                            | `git checkout` to prior version |
| `.sdd/opencode-config/architecture.md`                           | Delete file                     |

All rollbacks are `git checkout` to prior versions or file deletions. No data migrations, no side effects on running services, no application-code changes. Rollback restores the pre-change BATCH-DISPATCH behavior (A/B/C only, no batch D), the pre-change sole-writer state (analyzer-escalated can write shelf, conspecter can edit shelf), and the pre-change read-only laxness (code-navigator and observer inherit global bash allow).

## Testing Decisions

> Per `openspec/config.yaml`: "Include a Testing Decisions section that states what makes a good test for this change, which modules will be tested, and the prior art in the codebase."

### What makes a good test here

This is opencode-config -- the test verifies **classification behavior and lockstep invariant enforcement**, not business logic. A good test is one that:

- fails loudly when the plugin misclassifies a batch (unsafe flagged as safe, or safe flagged as unsafe)
- passes quietly when the lockstep surfaces agree (5-surface grep matches expected strings)
- uses real plugin classification calls (not mocked) because the classification depends on the actual Set membership of READ_ONLY_LANES and WRITER_LANES
- exercises the regex-based worktree extraction against realistic task payloads (with and without `WORKTREE: <path>` markers, with duplicates, with missing)

### Test surface (per module)

| Module                                                                                | What is tested                                                                                                            | Test type                                                                                       |
| ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `.opencode/plugins/delegation-observer.ts` (batch classification)                     | predicate A/B/C/D + F4 singleton exemption, with realistic `task()` payload arrays                                        | Behavioral test (plugin's existing test harness, or small standalone test script)               |
| `.opencode/oh-my-opencode-slim.jsonc` (3 preset BATCH-DISPATCH rule texts)            | lockstep grep: architector in batch A + batch D wording present in all 3 preset locations                                 | Grep-based invariant check (via `make test-config` or `scripts/validate-lockstep.sh` if exists) |
| `.opencode/oh-my-opencode-slim/orchestrator_append.md` (A1 + A6)                      | lockstep grep: architector in A1 + A6 item 6 present                                                                      | Same grep-based invariant                                                                       |
| `.opencode/opencode.jsonc` (F1 + F2)                                                  | analyzer-escalated edit block does NOT contain `memory-shelf.yaml`; code-navigator and observer have `bash: deny`         | Config schema validation (existing `make test-config` JSONC validator)                          |
| `.opencode/agents/analyzer-escalated.md` + `.opencode/agents/conspecter.md` (F1 + F3) | agent markdown does NOT instruct self-registration on memory-shelf.yaml; conspecter edit allow list is `knowledge/*` only | Grep-based invariant                                                                            |
| `.sdd/opencode-config/architecture.md`                                                | file exists with 2 ADRs                                                                                                   | File existence + content grep                                                                   |

### Integration verification

- `make test-config` exits 0 (covers JSONC validity + any registered validators).
- Lockstep grep across 5 surfaces: 5/5 matches for (a) `architector` in READ_ONLY_LANES + batch A texts, (b) batch D wording in 3 preset locations, (c) A6 item 6 in orchestrator_append.md.
- Restart smoke: restart OpenCode after changes, dispatch a safe batch A (researcher + architector), verify silent (no A1 warning); dispatch an unsafe batch (two coders WITHOUT worktree assertion), verify A1 warning + `a1_violation` row; dispatch a batch D (two coders WITH disjoint worktree assertions), verify silent.
- Behavioral plugin test: 2 coders WITHOUT worktree assertion flagged UNSAFE; 2 coders WITH separate worktree assertion SAFE; 1 task() + log_decision SAFE (F4 singleton exemption); architector + researcher batch SAFE (F5 batch A).

### Prior art in the codebase

- **Lockstep 5-surface grep pattern:** established by DIA-162/DIA-163 (BATCH-DISPATCH rule text + READ_ONLY_LANES + A1 section of orchestrator_append.md must agree). The validator script (if any) is reused.
- **Plugin behavioral test pattern:** delegation-observer.ts is a hooks-style plugin with no formal test suite today; the restart-smoke approach (dispatch real batches, observe registry.jsonl rows) is the de-facto test. If a lightweight test harness exists, reuse it; otherwise, the restart smoke is the behavioral test.
- **`make test-config` gate:** established by dev-infra config-validators campaign (DIA-111/DIA-112 series). Extended validators are welcome if they catch new invariants cheaply.

### Test risk and mitigation

**Risk:** restart smoke requires a running OpenCode instance with the new plugin loaded. **Mitigation:** the dev container is the test environment (DIA-094 gate: no implementation work without a running docker dev container). `make test-config` runs on the host (no container needed).

**Risk:** lockstep grep may silently drift if the rule text is rephrased without updating all 5 surfaces. **Mitigation:** the grep pattern should match a specific phrase (e.g., "parallel coders" or "WORKTREE: <path>") that is unlikely to be rephrased independently in different surfaces. The DIA-162 lockstep invariant is already enforced; this change extends it to batch D.

**Risk:** plugin signature change (`isSafeTaskBatch`) is internal but might have callers I miss. **Mitigation:** `rg` grep for all callers of `isSafeTaskBatch` before changing signature; only one caller (line 807 per architector design) expected.

### What we explicitly do NOT test

- **Full orchestrator dispatch end-to-end** (orchestrator constructs payload -> plugin classifies -> coder runs in worktree -> reviewer reviews -> squash-merge). This is the developer's operational workflow; tested by adoption, not by this change.
- **Worktree lifecycle itself** (already tested by DIA-100 `worktrees.bats` T1-T16).
- **Cross-model dispatch semantics** (whether the orchestrator chooses batch D over serializing) -- that is an orchestrator decision, not a plugin invariant.
- **Real parallel coder execution** -- out of scope; this change only enables the plugin/prompt surface.

## Blocking questions (up to 3, with recommended answers)

> These are genuine unknowns that could change the spec. Recommended answers provided. If the developer does not override, the recommended answers stand and artifact creation proceeds.

1. **Q: Where does the plugin behavioral test live?** The architector design references "delegation-observer behavioral test" but no formal test harness exists today for this plugin. Recommended answer: add a small standalone script (e.g., `scripts/__tests__/delegation-observer-batch-classification.sh` or inline in an existing bats suite) that invokes the plugin's `isSafeTaskBatch` logic with synthetic payload arrays and asserts SAFE/UNSAFE outcomes. If the plugin exports the function for testing, use it directly; otherwise, reconstruct the minimal classification logic in the test. (Low risk -- the function is pure, no IO dependency for the classification predicate itself.)

2. **Q: Should the worktree regex extraction tolerate multiple `WORKTREE:` markers in a single task payload?** Architect's design says "extract worktree assertion via regex `/WORKTREE:\s*(\S+)/i`" (singular). Recommended answer: the regex captures the FIRST match; if a task payload contains multiple markers, the plugin treats it as a malformed assertion and classifies as UNSAFE (fail-loud). The orchestrator contract is ONE `WORKTREE: <path>` per coder dispatch.

3. **Q: Does the new batch D wording in the 3 presets need to preserve the exact prior BATCH-DISPATCH RULE text, or can it be rewritten for clarity?** Recommended answer: preserve the prior text verbatim and APPEND the batch D clause, so the existing A/B/C wording is not inadvertently altered. This minimizes the diff surface and keeps the lockstep grep pattern stable (DIA-162 invariants remain grep-able).
