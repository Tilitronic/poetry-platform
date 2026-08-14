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

---

id: DIA-155
title: "chokidar in-process file-watching harness: deterministic auto-regeneration of derived views + agent-work automation"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
discovered: 2026-08-14
source: fix-lane
date: 2026-08-14
created: 2026-08-14
updated: 2026-08-14

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_fff561f6bffe3vfzs4UU3LMq6L"
lane_id: "cod"
agent: "coder"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: ["docs/dev-infra-audit/tickets/DIA-155-chokidar-in-process-file-watching-harness.md"]
artifacts: []
evidence: ["knowledge/res027-orchestrator-routine-work-tools/res027-orchestrator-routine-work-tools-conspect.md"]

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

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
