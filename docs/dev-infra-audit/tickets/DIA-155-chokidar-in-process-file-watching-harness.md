# DIA-155 - chokidar in-process file-watching harness: deterministic auto-regeneration of derived views + agent-work automation

<!-- Filed by the DIA-137 closure lane 2026-08-14 from the developer
     decision on the DIA-137 research (res027): status-quo adopted for
     routine-work tools, but the broader chokidar harness application is
     filed here as a follow-up. Research res-2
     (ses_fff9d53fcffeUQplpIM8kMJFfs) + conspect res027
     (ses_fff7be694fferIVahm5Bg7PRee) identified chokidar v5.0.0 as the
     ONLY design-worthy candidate - the only no-new-process mechanism for
     auto-regeneration of derived views. DIA-086 SCOPE GUARD applies:
     chokidar must EARN its place - no consumer has demonstrated a
     stale-view problem today, so this is an optional enhancement, not a
     need. -->

<!-- UPDATE 2026-08-15 (CLOSED - closure lane):
     CLOSED 2026-08-15. Documentation-only closure - the section-10 chain
     terminated at 'developer decide' (no design/implementation phase ran,
     so no @ai-auditor review was needed):
     (1) ai--2 section-10 Phase 1 gate (2026-08-15): DIA-086 SCOPE GUARD
     NOT MET - no consumer of the derived views (messages.md, ticker.md)
     demonstrated a stale-view problem; on-demand render is deterministic
     and testable; chokidar v5 (ESM-only, Node>=20.19) would add a runtime
     dependency to a Bun-based plugin to solve a non-problem; for surface 1
     the plugin's existing hooks could do synchronous render-in-hook with
     ZERO new dependencies (strictly better than a watcher). Findings kept
     and registered in .opencode/learnings/external-patterns/
     2026-08-15-chokidar-bun-esm-render-in-hook.md (section-10 Phase 1
     requirement).
     (2) Developer EBDV decision 2026-08-15 (binding): Variant A status-quo
     adopted - close DIA-155; the conditional-design knowledge (res027
     sections 2.6 + 3) is preserved via the learnings entry, so no
     information is lost by closing.
     (3) Closure lane: Fix section filled (DIA-086 verdict + EBDV variant
     table + chosen variant), status OPEN -> CLOSED, closed 2026-08-15,
     updated 2026-08-15, attempts +1, files_touched + evidence updated.
     No implementation landed -> nothing to diff -> @ai-auditor not
     dispatched (section-10 chain terminates at developer decide for a
     status-quo verdict). -->

---

id: DIA-155
title: "chokidar in-process file-watching harness: deterministic auto-regeneration of derived views + agent-work automation"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
discovered: 2026-08-14
source: fix-lane
date: 2026-08-14
created: 2026-08-14
updated: 2026-08-15
closed: 2026-08-15

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_fff561f6bffe3vfzs4UU3LMq6L"
lane_id: "cod"
agent: "coder"
model: ""
parent_session_id: ""
attempts: 1
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: ["docs/dev-infra-audit/tickets/DIA-155-chokidar-in-process-file-watching-harness.md", ".opencode/learnings/external-patterns/2026-08-15-chokidar-bun-esm-render-in-hook.md"]
artifacts: []
evidence: ["knowledge/res027-orchestrator-routine-work-tools/res027-orchestrator-routine-work-tools-conspect.md", ".opencode/learnings/external-patterns/2026-08-15-chokidar-bun-esm-render-in-hook.md"]

---

## Description

Broader chokidar application (v5.0.0, MIT, npm, in-process Node watcher
inside the delegation-observer plugin - NO new background process) to
strengthen harness determinism and automate agent work. Derived from the
DIA-137 research verdict: chokidar is the only candidate that can watch
files and re-generate derived views WITHOUT spawning a new process,
because it runs inside the existing plugin process.

Reference: DIA-137 (CLOSED 2026-08-14, status-quo adopted for routine-work
tools) + conspect res027
(knowledge/res027-orchestrator-routine-work-tools/
res027-orchestrator-routine-work-tools-conspect.md, sections 2.6 + 3:
Variant B chokidar-in-plugin is the design to pick IF auto-regeneration of
derived views becomes a real, demonstrated requirement).

### Candidate application surfaces

1. **Auto-regenerate derived views on write** - watch
   `.opencode/session/messages.jsonl` -> `messages.md` and
   `ticker.json` -> `ticker.md` on source write, with atomic
   tmp+rename + `awaitWriteFinish` (chokidar-native: normalized
   add/change/unlink events, atomic-write detection, chunked-write
   handling). Today these renders are ON-DEMAND via
   `scripts/session-log render` / `scripts/ticker-render.sh`; auto-regen
   would remove the stale-window between writes and renders.
2. **Watch tickets/ for gate-relevant changes** - detect ticket
   frontmatter edits (status flips, lease/claim changes) and trigger
   the ticket-gate checks or rollup as appropriate.
3. **Watch config files for change-triggered validation** - run
   `make test-config` (or the relevant sub-gates) when
   `.opencode/opencode.jsonc` / `oh-my-opencode-slim.jsonc` /
   `.opencode/agents/*.md` change, giving immediate drift feedback.
4. **Any other automation identified during design** - the design phase
   (interview-first via @openspec-plan or @architector) owns the final
   scope; this ticket does not pre-commit to all four surfaces.

### Constraints

- **DIA-086 SCOPE GUARD:** chokidar must EARN its place. No consumer of
  the derived views (messages.md, ticker.md) has demonstrated a stale-view
  consumption problem today; on-demand render is deterministic and
  testable. The design MUST demonstrate the real requirement before any
  implementation lands - otherwise the recommendation is to keep status-quo
  on-demand rendering.
- **Section-10 plugin change:** chokidar-in-plugin is an AI-tooling change
  (delegation-observer.ts is a plugin) - the full section-10 chain applies:
  Phase 1 gate via @ai-specialist -> developer decide -> design ->
  implementation -> validate -> @ai-auditor.
- **No new background process:** chokidar runs IN-PROCESS inside the
  existing plugin runtime; it must not spawn or require a separate watch
  daemon (background processes are forbidden per DIA-137 res027).
- **v5 toolchain fact:** chokidar v5.0.0 is ESM-only and requires Node >=
  20 - the design must verify the plugin runtime satisfies this.
- **Determinism + testability:** any auto-regeneration must remain
  deterministic and testable (bats for script surfaces, plugin tests for
  the watcher) - auto-regen must not regress the deterministic on-demand
  renders it supplements.
- **ASCII-only (DIA-079).**

## Verification

1. Design artifact with EBDV variants (>=2 genuine options + abort/
   status-quo, per DIA-115): e.g. (A) status-quo on-demand render (abort),
   (B) chokidar auto-regen of derived views only, (C) broader harness
   (auto-regen + ticket/config watch surfaces) - each with evidence,
   pros/cons, effort, section-10 routing flag.
2. Section-10 Phase 1 gate: @ai-specialist research registered in
   `.opencode/learnings/external-patterns/` before any config change.
3. Implementation + validation: `make test-config` exit 0; plugin change
   `node --experimental-strip-types --check` + tsc clean; restart-verify
   per the DIA-123 second-boot pattern (live watcher fires on a real
   write, atomic tmp+rename + awaitWriteFinish confirmed, no stale-view
   window).
4. DIA-086 gate: the demonstrated requirement (stale-view consumer or
   agent-work automation win) documented in the Fix section before the
   plugin lands.

## Fix

> CLOSED 2026-08-15 (documentation-only closure). The section-10 chain ran
> Phase 1 (ai--2 gate) and terminated at the developer decision - no
> design or implementation phase executed, so there is nothing to diff and
> no @ai-auditor review was required.

**DIA-086 SCOPE GUARD VERDICT (2026-08-15): NOT MET - status-quo retained.**
No consumer of the derived views (messages.md, ticker.md) demonstrated a
stale-view problem:

- Consumers are all on-demand: orchestrator boot read, human inspection,
  handoff presentation - each reads a freshly rendered view.
- The delegation-observer plugin NEVER regenerates .md views - verified
  in .opencode/plugins/delegation-observer.ts: only silent appendFileSync
  jsonl write paths exist (registry.jsonl, messages.jsonl), no .md write
  path at all.
- On-demand render (scripts/session-log render, scripts/ticker-render.sh)
  is deterministic and gate-tested.
- chokidar v5 (ESM-only, Node >= 20.19) would add a runtime dependency to
  a Bun-based plugin to solve a problem that does not exist.

**EBDV variant table (DIA-115; ai--2 findings 2026-08-15):**

| Variant                                  | Evidence                                                                                                                    | Pros                                                               | Cons                                                                                                                | Effort | Section-10 flag       |
| ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------- | ------ | --------------------- |
| A - status-quo on-demand render (CHOSEN) | DIA-086: no stale-view consumer demonstrated; plugin writes no .md views; all consumers on-demand                           | zero deps, zero lifecycle, deterministic, gate-tested              | stale-window between write and render remains (never demonstrated to matter)                                        | None   | N/A (no change)       |
| B - chokidar auto-regen of derived views | chokidar v5.0.0 release notes (ESM-only, Node>=20.19, readdirp v5); res027 sections 2.6 + 3 (only no-new-process candidate) | in-process, no background process, atomic-write + awaitWriteFinish | watcher lifecycle + tuning, new ESM dep via .opencode/package.json (own tree, not root pnpm) to solve a non-problem | Medium | full section-10 chain |
| C - synchronous render-in-hook           | delegation-observer.ts hook handlers already write .jsonl (tool.execute.after -> appendFileSync, L855/L1006)                | same-tick determinism, ZERO new deps, unit-testable                | render cost per write tick; covers only plugin-written surfaces                                                     | Low    | full section-10 chain |
| D - abort (drop harness entirely)        | DIA-137 already produced the verdict + res027                                                                               | closes without any upkeep                                          | discards conditional-design knowledge (res027 2.6/3) and ai--2 findings                                             | None   | N/A                   |

**CHOSEN: Variant A - status-quo adopted.** Developer decision 2026-08-15
(binding). Because: the DIA-086 scope guard is not met (no demonstrated
requirement - no consumer proved a stale-view problem), so any change
would fail the ticket's own gate. Variant C (render-in-hook) is recorded
as the preferred future mechanism over Variant B (chokidar) if a real
consumer ever emerges - the plugin's existing hooks are strictly better
than a watcher for the plugin-written surfaces. Variant D loses the
research value for no gain. The section-10 chain therefore terminated at
'developer decide' - no implementation landed, nothing to diff, no
@ai-auditor review needed.

**Learnings registration (section-10 Phase 1 requirement):** ai--2 gate
findings registered in `.opencode/learnings/external-patterns/
2026-08-15-chokidar-bun-esm-render-in-hook.md` (Bun-runtime FACT,
render-in-hook PATTERN, DIA-086 verdict, dated Tier-2 sources; cites
DIA-155 + DIA-137 + res027).

**Verification disposition:** item 1 (EBDV design artifact) = this Fix
table; item 2 (section-10 Phase 1 gate registered) = the learnings entry;
item 4 (DIA-086 gate) = verdict above (not met, hence closed). Item 3
(implementation + validation) = N/A - no implementation landed.

## Re-verify

> RE-VERIFIED 2026-08-15 (closure lane): status-quo verdict consistent
> with the ai--2 gate findings - no stale-view consumer exists, the plugin
> has no .md write path, on-demand render is deterministic and gate-tested
> (evidence in .opencode/learnings/external-patterns/
> 2026-08-15-chokidar-bun-esm-render-in-hook.md). No implementation
> landed, so there is no code to re-verify. Revisit if a real stale-view
> consumer ever emerges - per the learnings entry, prefer render-in-hook
> over chokidar.
