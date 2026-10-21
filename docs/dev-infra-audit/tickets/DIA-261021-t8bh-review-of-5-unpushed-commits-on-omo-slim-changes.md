# DIA-261021-t8bh - review of 5 unpushed commits on omo-slim-changes

---

id: DIA-261021-t8bh
title: "review of 5 unpushed commits on omo-slim-changes"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-10-21
source: inventory
date: 2026-10-21
created: 2026-10-21
updated: 2026-10-21

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched:

- .opencode/plugins/delegation-observer.ts
- .opencode/scripts/validate-skills.sh
- .opencode/plugins/`__tests__`/parallel-handoff.test.mjs
- scripts/`__tests__`/validate-skills.bats
- .opencode/plugins/`__tests__`/handoff-slot-identity.test.mjs
- .opencode/plugins/`__tests__`/handoff-archive-collision.test.mjs
- .opencode/learnings/external-patterns/2026-10-21-dia-261021-t8bh-config-gate-verdict.md
- .opencode/learnings/index.md
- docs/dev-infra-audit/tickets/DIA-260827-5blh-medium-handoff-identity-permits-path-traversal.md
- docs/dev-infra-audit/tickets/DIA-260831-n9o0-book-rag-skill-references-at-rag-instead-of-rag.md
- docs/dev-infra-audit/tickets/DIA-260927-hwl9-turbo-add-package-json-to-the-test-task-inputs-stale-green-fix.md
- .opencode/CHANGELOG.yaml
  artifacts: []
  evidence:

- .opencode/plugins/delegation-observer.ts#next_action-slot-landed-gate
- .opencode/scripts/validate-skills.sh#body-command-reference
- scripts/`__tests__`/validate-skills.bats#DIA-261021-t8bh
- .opencode/plugins/`__tests__`/parallel-handoff.test.mjs#DIA-261021-t8bh

---

## Description

Post-hoc review of the 5 unpushed commits on omo-slim-changes (2c3ce945..aae39879, HEAD aae39879). Outcome: two Majors and one intentional non-defect. (1) MAJOR - delegation-observer.ts wrote the DIA-211 stigmergic active.json even when the handoff slot write was SKIPPED (missing runtime context.sessionID) or returned ok:false, producing the L20260817-010 split-brain (routing hint + stale context.session_id with no handoffs/<sid>.json). (2) MAJOR - validate-skills.sh body command-reference validation was imprecise in both directions: false positives on fenced examples, indented fences, built-in commands (/init), and plain single-segment path prose; false negatives on multi-token inline code spans and at-sign references. (3) NON-DEFECT - the lib/handoff.ts containment helper is unreachable-but-correct; its throw-vs-return contract is intentional, no change made. RED regression tests were authored by a separate instance (DIA-175); this GREEN lane implemented the minimum production fixes plus bookkeeping (stale contract comments, verdict learnings record, ticket evidence-path repairs, changelog registration).

## Verification

- [x] bun test parallel-handoff.test.mjs: 16/16 pass (incl. the positive control: a landed slot still writes active.json)
- [x] bats validate-skills.bats: 48/48 pass
- [x] bash .opencode/scripts/validate-skills.sh on the real repo: exit 0 (26 passed, 0 failed; no SKILL.md edited)
- [x] make test-config: exit 0 (includes changelog schema validation)
- [x] make test-shell: exit 0
- [x] node --test scripts/`__tests__`/batch-d-infra.test.mjs: exit 0
- [x] active.json invariant: updated only when the handoff slot write succeeded; skip path logs one error line naming the reason

## Fix

delegation-observer.ts: captured whether the slot landed (writer called AND returned ok===true) and gated the ENTIRE next_action/active.json block on it; a not-landed slot now skips the block and emits one error-level ctx.client.app.log line naming the reason (with .catch(() => {}) promise hygiene, also added to the two neighbouring app.log calls that lacked it); the stale invariant comment now states the enforced rule. validate-skills.sh: built ONE fence-stripping awk body (leading-whitespace-tolerant) feeding both extraction streams; backticked spans are the HARD class (first whitespace-delimited token, slash prefix, manifest union allow-list); plain-text and at-sign references are the WARN class (never exit-status-changing); the allow-list (OpenCode built-ins + ponytail family) lives in one commented block; the contract header documents check 12.

## Re-verify

All gates green (see Verification). Bookkeeping: stale contract comments fixed in handoff-slot-identity.test.mjs and handoff-archive-collision.test.mjs; verdict recorded at .opencode/learnings/external-patterns/2026-10-21-dia-261021-t8bh-config-gate-verdict.md and indexed; `__tests__` evidence paths repaired in DIA-260827-5blh, DIA-260831-n9o0, DIA-260927-hwl9 (files_touched filled, n9o0 Verification rewritten to the true HARD/WARN scope); changelog entries added for DIA-260827-5blh, DIA-260831-n9o0, and this ticket. Status: CLOSED.
