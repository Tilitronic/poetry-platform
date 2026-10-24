# DIA-260911-4y5v - Memory shelf and AI documentation hygiene: stale content inventory, deprecation, archival

---

id: DIA-260911-4y5v
title: "Memory shelf and AI documentation hygiene: stale content inventory, deprecation, archival"
area: docs
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-11
source: inventory
date: 2026-09-11
created: 2026-09-11
updated: 2026-09-11

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence: []

---

## Description

The repository has accumulated knowledge and instruction artifacts whose claims
can outlive the configuration, workflow, or model routing they describe. Existing
audits DIA-178 and DIA-260826-7qmt are historical snapshots, not a recurring
current-state reconciliation. Recent evidence in
.opencode/learnings/BOTTLENECK-ANALYSIS-2026-09-10.md identifies stale shelf
content and supersession notes that are not consistently surfaced or cleaned up.

Audit the current, tracked knowledge and instruction surfaces:

- .opencode/memory-shelf.yaml and its referenced knowledge/ artifacts;
- .opencode/memory/{lessons,failures,adr,repo}.md;
- .opencode/learnings/ and its index;
- agent descriptions, workflow documentation, and active OpenCode config comments
  that make time-sensitive claims about models, providers, permissions, or routes.

Classify every finding as KEEP, REFRESH, DEPRECATE, SUPERSEDE, ARCHIVE, MERGE,
or DELETE. A deletion is allowed only when the artifact is a verified duplicate
or fully recoverable from a canonical source; otherwise preserve provenance with
a deterministic deprecation or supersession marker naming its replacement.
Do not change runtime behavior, agent permissions, model routing, ticket status,
or generated changelog records in this ticket. Route any such discovery to its
own ticket.

## Verification

- [ ] Produce a versioned inventory that maps every reviewed artifact to one
      classification and records the evidence for non-KEEP decisions.
- [ ] Validate all memory-shelf YAML and resolve every retained shelf path.
- [ ] Ensure every DEPRECATED or SUPERSEDED artifact names the reason, date, and
      canonical replacement; search/index behavior must not silently prefer it.
- [ ] Record each archive, merge, or deletion with source and destination paths
      so a future maintainer can reconstruct provenance.
- [ ] Register or explicitly defer orphaned knowledge directories with an owner
      ticket; warnings alone are not closure evidence.
- [x] Run the relevant hygiene validator plus make test-config after the changes;
      preserve existing form-warning behavior unless a separate ticket changes it.
      Evidence: make test-config PASS, suites 8, tests 57, pass 57, exit 0
      (re-run 2026-09-12 to confirm prior lane result); git diff --check PASS
      (exit 0); scripts/validate-changelog.sh exit 0 (1 passed, 0 failed);
      scripts/changelog-render exit 0 (145 entries written).
- [ ] Obtain independent review of the classification sample and verify that no
      active routing, permission, or workflow contract was altered accidentally.

NOTE: only the test-config/validator checkbox above is marked done, because
only it has executed evidence. All other checkboxes remain open.

PENDING next lane: OpenCode restart + functional smoke test (config comment
changes in orchestrator_append.md, SKILL.md, analyzer.md, researcher.md take
effect at runtime load). Not run in this lane per dispatch constraints.

## Guardrails

- Prefer DEPRECATE or SUPERSEDE over deletion.
- Do not bulk-delete by age, filename, or model name.
- Do not rewrite historical ticket evidence merely because it is old; add a
  current-state correction or supersession reference instead.
- Keep the audit and remediation commits reviewable; split unrelated artifact
  families where a single diff would obscure provenance.

## Fix

Fixed paths (datetime artifact-ID examples, doubled-slug path correction):

1. .opencode/oh-my-opencode-slim/orchestrator_append.md:55 (diff hunk @@ -52):
   before: "Write to knowledge/res<NN>-<topic>/sources/"
   after: "Write to knowledge/<returned-id>/sources/"
   Reason: scripts/allocate-id returns the full datetime ID including the slug
   (format res-YYMMDD-<rand4>-<slug>), so appending another -<topic> suffix
   doubles the slug. Use the returned ID verbatim.
2. .opencode/skills/research-pipeline/SKILL.md:14 (Phase 1):
   before: "Write to knowledge/<returned-id>-<topic>/sources/"
   after: "Write to knowledge/<returned-id>/sources/"
   Same doubled-slug reason; Phase 2 generic res<id> prose is an intentional
   template, not a literal path, and is kept.
3. .opencode/agents/analyzer.md:38:
   before: "preallocates your ana<NN> ID"
   after: "preallocates your ana-260911-ab12-capability-gap-matrix ID"
   Reason: datetime-ID example form with the required multi-word topic;
   generic ana<id> elsewhere is an intentional template, not a literal.
4. .opencode/agents/researcher.md (Role paragraph, appended sentence):
   "Allocated IDs use datetime form <type>-YYMMDD-<random4>-<slug> per
   scripts/allocate-id; the returned ID already includes the slug, so use it
   verbatim without appending another suffix."
   Gate reference: ai-specialist gate ses_f6a9ca102ffegIOd2kg8cjOpJ8.
   Generic res<id>-<topic> prose elsewhere is an intentional template;
   datetime-ID from scripts/allocate-id is used verbatim, no double suffix.

CHANGELOG scope fix (.opencode/CHANGELOG.yaml, DIA-260911-4y5v entry):
before: scope: s (single-char scope rendered in the view as
"DIA-260911-4y5v: s")
after: scope: datetime artifact ID examples and doubled-slug path
correction
Validated via scripts/validate-changelog.sh exit 0 (1 passed, 0 failed)
and scripts/changelog-render exit 0 (145 entries).

COMMIT ISOLATION NOTE: the working tree is dirty with foreign changes that
must NOT be committed with 4y5v. Staged: .opencode/oh-my-opencode-slim/
bun.lock + package.json (zod/RED-B lane). Unstaged: memory-shelf.yaml,
memory/{failures,lessons,repo}.md, oh-my-opencode-slim.jsonc (OpenAI preset
lane), DIA-260827-aa5i ticket, tickets README, CHANGELOG.md render output.
Untracked: 95fv return-channel learnings (x2), h8o5 zod-exact-pin learning,
dean openai-first-preset learning, DIA-260911-cz0y / DIA-260912-dean /
DIA-260912-h8o5 / DIA-260912-y2uo tickets, "Independent inventory verdict.md",
hygiene-decisions.md, sjtk reflow hunks, RED-B work, openspec/changes/
(dia-260911-4y5v-_, dia-260912-h8o5-_, task-return-channel-\*). The 4y5v commit
must isolate only: orchestrator_append.md, research-pipeline SKILL.md,
agents/analyzer.md, agents/researcher.md, .opencode/CHANGELOG.yaml (+ rendered
CHANGELOG.md), and this ticket file.

## Re-verify

- git diff --check: PASS (exit 0), run 2026-09-12 in this lane.
- make test-config: PASS, suites 8, tests 57, pass 57, exit 0, re-run
  2026-09-12 to confirm the prior-lane 57/57 result.
- scripts/validate-changelog.sh: exit 0 (1 passed, 0 failed).
- scripts/changelog-render: exit 0 (145 entries written).
- Fixed-line spot check 2026-09-14: orchestrator_append.md line 55 shows
  "Write to knowledge/<returned-id>/sources/"; SKILL.md line 14 shows the
  same verbatim-ID path; analyzer.md line 38 shows the
  ana-260911-ab12-capability-gap-matrix datetime example.
- OpenCode restart/reload: DONE 2026-09-14. `opencode debug agent`,
  `opencode debug skill`, and `opencode debug config` loaded the corrected
  guidance; the restarted TUI showed the configured OpenAI orchestrator and a
  non-empty OpenAI functional smoke response.
- Scope disposition: this evidence completes only the datetime artifact-ID
  correction slice. The broader memory/documentation hygiene inventory and its
  remaining six acceptance items stay OPEN under this ticket.
