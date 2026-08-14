# Design: batch-d-parallel-coders

> **Proposal:** `openspec/changes/batch-d-parallel-coders/proposal.md`
> **Ticket:** `docs/dev-infra-audit/tickets/DIA-172-parallel-coders-batch-d-expansion.md`
> **Predecessor tickets:** DIA-159 (analysis), DIA-162/DIA-163 (BATCH-DISPATCH + plugin A1, commits 0697a08 + 7b08e90)
> **Architector design:** approved 2026-08-13 (verbatim in ticket file).
> **Developer operational requirements (authoritative):** one worktree per coder; one worktree per task; per-worktree reviewer on committed fixed points; orchestrator owns worktree naming + serialized squash-merges; plan presented to developer before implementation starts.
> **Scope:** opencode-config only -- no system architecture decisions, no application-code changes, no section 10 architectural escalation required.
> **Governing SDDs:**
>
> - `.sdd/dev-infra/architecture.md` (existing -- worktree lifecycle, ADR 3 squash-merge, ADR 6 conflict escalation, ADR 7 worktree location)
> - `.sdd/opencode-config/architecture.md` (new, authored by this change -- ADR 1 Batch Pattern D, ADR 2 Singleton-Batch Semantic Exemption)

## Context

See proposal.md for motivation. The DIA-162/DIA-163 implementation locked three conflict-free batch patterns (A read-only, B single-writer, C reviewer pair) and established a 5-surface lockstep invariant (plugin READ_ONLY_LANES + 3 preset BATCH-DISPATCH rule texts + orchestrator_append A1 section must agree). This change extends the invariant along two axes:

1. **Batch D (parallel coders):** a new pattern gated by a `WORKTREE: <path>` assertion in the dispatch payload, validated by the plugin as distinct paths (Set size == coder count).
2. **Quick-fixes (F1-F5):** five concrete drift closures surfaced by the DIA-172 pre-work review.

The plugin's current signature (`isSafeTaskBatch(agents: string[]): boolean`) is not sufficient -- batch D needs to see the worktree assertion per coder. The signature change is internal (one caller at line 807) and backward-compatible at the call site (call site constructs the array; we extend it in place).

## Goals / Non-Goals

**Goals:**

- Enable the orchestrator to dispatch multiple `@coder` lanes in a single turn, gated by explicit worktree assertions, without triggering A1 false warnings.
- Close five concrete invariant drifts (F1-F5) surfaced by the DIA-172 review.
- Preserve the 5-surface lockstep invariant: any future change to batch A/B/C/D wording must touch all surfaces (plugin + 3 presets + orchestrator_append A1).
- Encode the developer's operational contract (one worktree per coder, per-worktree reviewer, serialized squash-merges, orchestrator-managed naming) as explicit text in orchestrator_append.md A6 item 6 and coder inline instructions.
- Author the `.sdd/opencode-config/architecture.md` ADRs that govern future batch-pattern changes.

**Non-Goals:**

- Implementing the orchestrator-side dispatch logic (constructing worktree-bearing payloads, creating worktrees, dispatching per-worktree reviewers, performing serialized squash-merges). That is orchestrator behavioral work, consumed by this change's contract but not implemented here.
- Modifying the worktree lifecycle CLI (`scripts/worktrees.sh`) -- that is DIA-100 territory; this change consumes the CLI, does not extend it.
- Writing a formal test suite for the plugin's classification function (the restart-smoke approach + one small behavioral assertion script is sufficient for this change; see Testing Decisions in proposal.md).
- Enforcing disjoint file sets between parallel coders at the plugin level -- the plugin only validates distinct worktree paths. Disjoint file sets are the orchestrator's responsibility (a soft invariant, not a hard gate).

## Decisions

### D1: Extend `isSafeTaskBatch` signature to carry worktree assertions

**Decision:** change signature from `isSafeTaskBatch(agents: string[]): boolean` to `isSafeTaskBatch(tasks: Array<{agent: string, worktree?: string}>): boolean`. Each entry carries the subagent_type and an optional worktree path extracted from the task payload.

**Rationale:** batch D's safety predicate requires knowing both the agent type AND the worktree assertion. Passing a structured array is cleaner than parallel arrays and keeps the function signature self-documenting.

**Alternatives considered:**

- **Parallel arrays (`agents: string[], worktrees: (string | undefined)[]):`** rejected because parallel arrays are error-prone (caller can misalign them) and the function signature becomes less self-documenting.
- **Extending the existing `turnToolCalls` Map value type (add `worktree?: string`):** rejected because the Map carries all tool calls (not just task() calls); filtering and mapping at the call site is cleaner than restructuring the Map.

**Call-site adaptation:** single caller at line 807. The call site currently maps `c.subagent_type ?? ""` into an array. Extended to map into `Array<{agent: string, worktree?: string}>` by also extracting the worktree assertion from the task args via the regex described in D2.

### D2: Extract worktree assertion via regex on task payload

**Decision:** use `/WORKTREE:\s*(\S+)/i` against the concatenation of the task description and prompt. Capture the FIRST match. If a task payload contains multiple markers, treat as malformed (worktree = undefined, which causes batch D to fail for that coder).

**Rationale:** the worktree assertion is a string marker in the task payload, not a structured field. The regex is small, readable, and the case-insensitive flag tolerates orchestrator typos. Capturing the first match only matches the documented contract (ONE marker per coder dispatch); multiple markers are treated as malformed rather than silently picking one.

**Alternatives considered:**

- **Structured field in task args (e.g., `worktree_path` as a named arg):** rejected because the orchestrator constructs the task() call with description+prompt only (no structured worktree field exists today). Adding a structured field would require changes to the task() tool interface, which is out of scope.
- **Parsing the last match instead of the first:** rejected because the first match is the natural "the orchestrator asserted this path"; subsequent markers are more likely to be noise or documentation.

### D3: Batch D predicate -- distinct worktree paths + all-non-coders read-only

**Decision:** predicate D returns true iff (a) every non-coder lane is in READ_ONLY_LANES (after F5, this includes `architector`) AND (b) every coder lane has a defined worktree assertion AND (c) the Set of worktree paths has size equal to the number of coder lanes (distinct paths, no duplicates, no missing).

**Rationale:** the safety of parallel coders rests on two orthogonal invariants -- (a) no non-coder lane in the batch writes project files (otherwise the coder and writer could collide on memory-shelf.yaml or other artifacts) and (b) every coder operates in a distinct worktree (otherwise two coders on the same worktree would clobber each other's index). Both must hold for the batch to be safe.

**Alternatives considered:**

- **Only check worktree distinctness, don't check non-coder read-only:** rejected because a writer in the batch (e.g., analyzer) could conflict with the coders on memory-shelf.yaml registration.
- **Allow duplicate worktree paths if the coders claim disjoint file sets:** rejected because the plugin cannot validate disjoint file sets (it only sees the task payload, not the coder's plan). Fail-loud on duplicate paths forces the orchestrator to prove the invariant via distinct paths.

### D4: F4 -- singleton-batch semantic exemption

**Decision:** classify the batch as SAFE when the turn contains exactly one `task()` call (regardless of other semantic tools like `log_decision` in the same turn). Implementation: the existing `if (input.tool === "task" && calls.length > 1)` guard at line 800 already gates the A1 warning to "task() + at least one other tool in the turn"; extend the check to ALSO require that there are at least 2 task() calls in the turn before invoking `isSafeTaskBatch`. If there is only 1 task() call, the batch is trivially safe -- skip the classification entirely.

**Rationale:** the A1 heuristic was meant to catch "parallel task() batch + other tools" (which historically has been a conflict source). A single task() + log_decision (or other semantic tools) is not a parallel batch at all -- it is a single delegation + a semantic log entry. Classifying it via the batch predicate produces false positives.

**Alternatives considered:**

- **Special-case `log_decision` as always-safe alongside a single task():** rejected because the set of "always-safe" semantic tools is open-ended (log_decision today, something else tomorrow). The simpler rule is "one task() = not a batch = skip classification".
- **Separate turn for log_decision (architect's rejected alternative):** rejected because forcing a separate turn wastes context and adds an extra message cycle for a semantic log entry that is logically part of the same reasoning step.

### D5: F5 -- add `architector` to READ_ONLY_LANES

**Decision:** add `"architector"` to the `READ_ONLY_LANES` Set (line 271-277). Mirror in the 3 preset BATCH-DISPATCH rule texts (lines 26/207/429 of oh-my-opencode-slim.jsonc) and the A1 section of orchestrator_append.md (~156-167).

**Rationale:** the architector is already read-only by config (edit/bash/task deny per opencode.jsonc lines 215-222, confirmed by DIA-172 pre-work). Adding it to READ_ONLY_LANES makes the plugin classification match the config reality. Mirror in the 5 lockstep surfaces preserves the DIA-162 invariant.

**Alternatives considered:** none -- this is a direct correction of an omission.

### D6: F1 -- analyzer-escalated sole-writer invariant

**Decision:**

- `.opencode/opencode.jsonc`: remove `".opencode/memory-shelf.yaml": "allow"` from the analyzer-escalated edit block (~line 257); fix adjacent comment (~244-245) to reflect the corrected invariant.
- `.opencode/agents/analyzer-escalated.md` (~lines 41-42): replace the self-registration instruction with "do NOT write .opencode/memory-shelf.yaml; report artifact paths (memory-manager registers)".

**Rationale:** DIA-162 established memory-manager as the sole writer of memory-shelf.yaml. The analyzer-escalated edit block still grants it write access, creating a direct contradiction. The agent markdown instructs self-registration, creating a behavioral contradiction. Both must be closed.

### D7: F2 -- strict read-only for code-navigator and observer

**Decision:** add `"bash": "deny"` to the permission blocks of code-navigator (~line 320) and observer (~line 340) in `.opencode/opencode.jsonc`.

**Rationale:** code-navigator and observer are classified read-only (in READ_ONLY_LANES) but currently inherit the global bash allow, making them technically write-capable via bash. The explicit bash deny aligns the config reality with the classification. Fail-loud: if a future change needs code-navigator or observer to write via bash, the change must also remove them from READ_ONLY_LANES and update the 5-surface lockstep.

### D8: F3 -- conspecter doc drift

**Decision:** `.opencode/agents/conspecter.md` line 18 and ~lines 82-83: edit allow list = `knowledge/*` only. Remove any mention of memory-shelf.yaml. The conspecter writes to `knowledge/*`; shelf registration is delegated to memory-manager.

**Rationale:** the conspecter's documented edit allow list still mentions memory-shelf.yaml, contradicting DIA-162. The drift is small and localized; closing it aligns the agent markdown with the sole-writer invariant.

### D9: Prompt text (3 presets) -- extend BATCH-DISPATCH RULE

**Decision:** in `.opencode/oh-my-opencode-slim.jsonc` at lines 26/207/429, replace the BATCH-DISPATCH RULE text with the extended version. The new text preserves the existing A/B/C wording verbatim and APPENDS the batch D clause:

> "BATCH-DISPATCH RULE: task() calls MAY share a message ONLY when all dispatched lanes are in the same conflict-free batch. Approved batches: (A) read-only fan-out: researcher/ai-specialist/ai-auditor/code-navigator/observer/architector in any combination; (B) single-writer + readers: one of [analyzer, conspecter, memory-manager] plus any read-only lanes; (C) post-fix review: reviewer + ai-auditor on a committed fixed point; (D) parallel coders: multiple @coder lanes ONLY IF each uses a separate git worktree and the dispatch payload asserts WORKTREE: <path> per coder, with disjoint file sets (plus any read-only lanes). NEVER batch: two analyzers, coder+reviewer (reviewer needs fixed point), or any pair that both write memory-shelf.yaml. When in doubt, serialize."

**Rationale:** the 3 presets must agree verbatim (DIA-162 lockstep invariant). The text preserves existing A/B/C wording (no regression in lockstep grep patterns) and adds D as an additional approved pattern. The "When in doubt, serialize" tail is a safety valve.

**Alternatives considered:**

- **Rewrite the entire rule text for clarity:** rejected because it breaks the existing lockstep grep patterns and risks subtle semantic changes to A/B/C. Append-only is safer.

### D10: Coder inline instructions -- APPEND worktree confinement directive

**Decision:** in the presets where `coder` has existing inline prompts (per DIA-128: coder and analyzer have inline prompts), APPEND the following directive (do not replace existing instructions):

> "If dispatched as part of a parallel batch (batch D), strictly confine your work to the git worktree path specified in your task payload; do not touch the main tree or other worktrees; commit to your assigned branch only."

Plus the standard verification-evidence duty (already documented in AGENTS.md section 2.3.1).

**Rationale:** the coder needs explicit instructions about worktree confinement when running in batch D. APPEND (not replace) preserves the existing inline instructions (DIA-128 contract) and adds the new confinement directive as a batch-D-only conditional.

### D11: Orchestrator append -- A1 extension + A6 item 6

**Decision:**

- **A1 section (~156-167 of orchestrator_append.md):** extend to include `architector` in batch A and the batch D wording (parallel coders with worktree assertion + disjoint file sets). This is the 5th lockstep surface.
- **A6 Serialization Points (new item 6):** "parallel coders -> reviewer: per-worktree reviews MUST operate on committed fixed points inside that worktree; squash-merges to the main branch MUST be serialized (one at a time)."

**Rationale:** the orchestrator_append.md is the orchestrator's behavioral contract. A1 must agree with the plugin's READ_ONLY_LANES and the preset BATCH-DISPATCH rule texts (5-surface lockstep). A6 item 6 encodes the developer's operational contract for parallel coders (per-worktree review + serialized squash-merge) -- this is the authoritative source the orchestrator reads when deciding how to integrate parallel-coder output.

### D12: `.sdd/opencode-config/architecture.md` -- two ADRs

**Decision:** create a new `.sdd/opencode-config/architecture.md` file with two ADRs transcribed verbatim from the architector design:

- **ADR 1 "Batch Pattern D (Parallel Coders)":** Status Accepted; Context: parallel implementation throughput without git conflicts (DIA-172); Decision: parallel @coder dispatches gated by strict `WORKTREE: <path>` payload assertion; Consequences: orchestrator manages worktree lifecycles + serialized squash-merges; Alternatives: parallelizing without worktrees (rejected: git index locks + file contention).
- **ADR 2 "Singleton-Batch Semantic Exemption":** Status Accepted; Context: single task() + semantic tools (log_decision) incorrectly flagged; Decision: classification safe if exactly one task() call; Consequences: no false-positive A1 warnings; Alternatives: separate turn for log_decision (rejected: context waste).

**Rationale:** the project's design authority layer (`architecture.md` + `.sdd/`) should capture these decisions as long-lived ADRs, not just as change-specific artifacts. The opencode-config module did not have an `.sdd/` document; this change creates it with the two ADRs that govern future batch-pattern changes.

**Index update:** `.sdd/README.md` needs an index row pointing to the new `opencode-config/architecture.md` file.

## File-by-file change summary

| File                                                   | Change                                                                                                                                        | Size estimate                        |
| ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------ |
| `.opencode/plugins/delegation-observer.ts`             | D1 (signature change) + D2 (regex extraction) + D3 (batch D predicate) + D4 (F4 singleton exemption) + D5 (F5 architector in READ_ONLY_LANES) | ~40-50 lines modified/added          |
| `.opencode/oh-my-opencode-slim.jsonc`                  | D9 (3 preset BATCH-DISPATCH rule texts, identical edits)                                                                                      | 3 identical edits, ~10-15 lines each |
| `.opencode/oh-my-opencode-slim/orchestrator_append.md` | D11 (A1 extension + A6 item 6)                                                                                                                | ~20-30 lines added                   |
| `.opencode/opencode.jsonc`                             | D6 (F1 analyzer-escalated edit block) + D7 (F2 code-navigator/observer bash deny)                                                             | ~5-10 lines modified                 |
| `.opencode/agents/analyzer-escalated.md`               | D6 (F1 self-registration instruction replacement)                                                                                             | ~2-5 lines modified                  |
| `.opencode/agents/conspecter.md`                       | D8 (F3 edit allow list drift)                                                                                                                 | ~5-10 lines modified                 |
| `.sdd/opencode-config/architecture.md`                 | D12 (new file, 2 ADRs)                                                                                                                        | ~50-70 lines                         |
| `.sdd/README.md`                                       | D12 (index row)                                                                                                                               | 1 line added                         |

## Data flow -- batch D classification

```
orchestrator dispatches N task() calls in one assistant turn, each with:
    subagent_type: "coder" | "researcher" | ...
    description+prompt: may contain "WORKTREE: <path>" marker
    |
    v
[tool.execute.before hook, delegation-observer.ts ~line 795]
    for each task() call:
        extract subagent_type from args
        extract worktree assertion via regex /WORKTREE:\s*(\S+)/i against description+prompt
        push {agent: subagent_type, worktree: <captured or undefined>} into turnToolCalls[sessionID]
    |
    v
[after all task() calls are registered, ~line 800]
    if (input.tool === "task" && taskCallCount > 1):
        // batch D applies (or A/B/C)
        taskPayloads = calls.filter(c => c.tool === "task").map(c => ({
            agent: c.subagent_type,
            worktree: c.worktree  // captured at before-hook time
        }))
        if (!isSafeTaskBatch(taskPayloads)):
            log A1 VIOLATION warning
            append a1_violation row to registry.jsonl
    else if (input.tool === "task" && taskCallCount === 1):
        // F4 singleton exemption: skip classification, silent
        pass
    |
    v
[isSafeTaskBatch signature: (tasks: Array<{agent, worktree?}>) => boolean]
    (A) every task.agent in READ_ONLY_LANES => SAFE (incl. architector after F5)
    (B) writers = tasks.filter(t => WRITER_LANES.has(t.agent));
        writers.length <= 1 && every task in READ_ONLY || WRITER => SAFE
    (C) tasks.length === 2 && includes reviewer && includes ai-auditor => SAFE
    (D) else:
        coders = tasks.filter(t => t.agent === "coder")
        nonCoders = tasks.filter(t => t.agent !== "coder")
        if (coders.length > 1):
            if (nonCoders.every(t => READ_ONLY_LANES.has(t.agent))
                && coders.every(t => t.worktree !== undefined)
                && new Set(coders.map(t => t.worktree)).size === coders.length):
                return true  // batch D: parallel coders with distinct worktrees
            else:
                return false  // batch D fails (missing worktree / duplicate path / non-coder writer)
        else:
            return false  // not A, not B, not C, not D -> UNSAFE
```

## Orchestration contract (developer requirements encoded)

The following operational contract is encoded in orchestrator_append.md A6 item 6 and the coder inline instructions. The orchestrator MUST honor it when dispatching batch D:

1. **One worktree per coder lane.** Every coder in a batch D dispatch receives a unique `WORKTREE: <path>` in its task payload. The path is created via `scripts/worktrees.sh create feature/<ticket>-<short-name>` (DIA-074 naming, DIA-100 lifecycle).
2. **One worktree per task.** A single task is NEVER associated with multiple concurrent worktrees. Re-dispatch of a task reuses the same worktree (or replaces the old one; never two simultaneously).
3. **Per-worktree reviewer.** After a coder completes its work in a worktree, a reviewer is dispatched to review that worktree on a committed fixed point inside it. The reviewer does NOT review the main tree.
4. **Orchestrator-managed naming.** The orchestrator owns the worktree naming convention, aligned with DIA-074 (`feature/<ticket>-<short-name>`) and DIA-100 (`.worktrees/` location, branch slashes mapped to dashes).
5. **Serialized squash-merges.** After per-worktree review passes, the orchestrator squash-merges the worktrees into the main working branch ONE AT A TIME. Never parallel merges. This prevents merge-conflict cascades between parallel-coder output.
6. **Developer approval gate (for this specific change).** When the OpenSpec artifacts are complete, the orchestrator presents the final plan to the developer for approval BEFORE implementation starts.

## Seams

> Per `openspec/config.yaml`: "Include a Seams section listing the pre-agreed public boundaries where tests will live."

| Seam                                                                      | What it is                                                                                                           | Test location                                                                     | Test type                                                                                                                                                                                                                             |
| ------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Plugin classification** (`isSafeTaskBatch` in `delegation-observer.ts`) | Pure function; signature changed to carry worktree assertions; predicate D added; F4 singleton exemption             | Small standalone assertion script OR plugin's existing test harness if one exists | Behavioral: invoke with synthetic payload arrays, assert SAFE/UNSAFE outcomes for (A) read-only incl. architector, (B) single-writer, (C) reviewer+ai-auditor, (D) parallel coders with/without worktrees, F4 singleton, unsafe cases |
| **Lockstep 5-surface invariant**                                          | 5 surfaces must agree on batch A/B/C/D wording                                                                       | Grep-based check (via `make test-config` or dedicated validator)                  | All 5 surfaces contain expected strings for architector-in-A and batch-D wording                                                                                                                                                      |
| **Config schema** (`opencode.jsonc` JSONC validity)                       | analyzer-escalated edit block, code-navigator/observer bash deny                                                     | `make test-config` JSONC validator                                                | JSONC parses; schema constraints hold                                                                                                                                                                                                 |
| **Agent markdown invariants**                                             | analyzer-escalated does NOT instruct memory-shelf self-registration; conspecter edit allow list = `knowledge/*` only | Grep-based check                                                                  | Negative grep: no "memory-shelf.yaml" in analyzer-escalated edit instructions; conspecter allow list does not mention shelf                                                                                                           |
| **`.sdd/opencode-config/architecture.md`**                                | 2 ADRs present, Status Accepted                                                                                      | File existence + content grep                                                     | File exists, 2 ADRs present                                                                                                                                                                                                           |
| **Restart smoke (integration)**                                           | After all changes loaded, orchestrator dispatches representative batches and observes plugin behavior                | Manual or scripted dispatch in the dev container                                  | Batch A (researcher+architector): silent; batch D without worktrees: A1 warning; batch D with disjoint worktrees: silent                                                                                                              |

### New seams vs. existing seams

- **Plugin classification** -- **existing seam extended**. The `isSafeTaskBatch` function already exists; this change extends its signature and adds predicate D. The test surface is extended in place.
- **Lockstep 5-surface grep** -- **existing seam extended**. The DIA-162 lockstep invariant is extended to include batch D wording + architector.
- **Config schema + agent markdown invariants** -- **existing seams**, newly-validated invariants (F1/F2/F3).
- **`.sdd/opencode-config/architecture.md`** -- **new seam** (new file). Justified: the opencode-config module lacked an SDD document; this change authors it with the two ADRs that govern future batch-pattern changes.

## Risks / Trade-offs

- **[Risk: regex fragility]** The `WORKTREE: <path>` regex may not tolerate whitespace or quoting variations in the task payload. -> **Mitigation:** the regex `/WORKTREE:\s*(\S+)/i` is permissive on whitespace between `WORKTREE:` and the path; the path is captured as a single non-whitespace token. The orchestrator contract specifies the exact marker format; drift is a contract violation, not a regex bug.
- **[Risk: call-site signature change breaks other callers]** The `isSafeTaskBatch` signature change could break other callers. -> **Mitigation:** grep-verified single caller at line 807. No other callers exist. The change is localized.
- **[Risk: lockstep drift between 5 surfaces]** Future edits to the batch rule text could update some surfaces but not others. -> **Mitigation:** the existing DIA-162 lockstep grep pattern is preserved and extended (not replaced). The new grep pattern matches "parallel coders" or "WORKTREE: <path>" across all 5 surfaces.
- **[Risk: batch D false positives from malformed worktree assertions]** If the orchestrator forgets the `WORKTREE:` marker, batch D fails and A1 warns. -> **Mitigation:** fail-loud is the correct behavior. The orchestrator must prove the invariant via the marker; silent fallback would mask bugs.
- **[Risk: serialized squash-merge becomes a throughput bottleneck]** If many parallel coders finish concurrently, serialized merges serialize the integration. -> **Mitigation:** accepted trade-off. Parallel merges risk conflict cascades that are worse than sequential merge latency. The developer's operational contract explicitly mandates serialization.
- **[Trade-off: skip the `.sdd/` document]** The ADRs could live only in the change artifacts (proposal+design) instead of being promoted to `.sdd/`. -> **Resolution:** rejected. ADRs that govern future batch-pattern changes must outlive this change. `.sdd/opencode-config/architecture.md` is the long-lived home.
- **[Trade-off: no disjoint-file-set validation at the plugin level]** The plugin validates distinct worktree paths but not disjoint file sets. -> **Resolution:** accepted. The plugin cannot validate what it does not see (the coder's plan). The orchestrator owns the disjoint-file-set invariant as a soft constraint; hard validation would require the plugin to introspect the coder's plan, which is out of scope.

## Migration Plan

No migration. All changes are additive (new ADRs, new batch D predicate) or drift closures (F1-F5). Rollback is `git checkout` per the proposal's rollback table. No data migrations, no API changes, no application-code impact.

Deployment order (within the implementation phase):

1. `.sdd/opencode-config/architecture.md` + `.sdd/README.md` index row (foundation).
2. F1/F2/F3 (config + agent markdown drift closures, independently verifiable).
3. F5 + batch D predicate + F4 (plugin changes, the behavioral core).
4. 3 preset BATCH-DISPATCH rule texts + orchestrator_append.md (A1 + A6) (lockstep surface).
5. Coder inline instructions (APPEND, does not replace).
6. Verification sweep (`make test-config`, lockstep grep, restart smoke).

## Open Questions

None. The architector design is approved; the developer's operational requirements are authoritative; the 3 blocking questions in proposal.md have recommended answers that stand unless overridden.
