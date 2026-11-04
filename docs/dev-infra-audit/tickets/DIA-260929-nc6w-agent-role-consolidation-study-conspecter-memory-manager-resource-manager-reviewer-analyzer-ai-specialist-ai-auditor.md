# DIA-260929-nc6w - agent-role consolidation study: conspecter+memory-manager, resource-manager, reviewer+analyzer, ai-specialist+ai-auditor

---

id: DIA-260929-nc6w
title: "agent-role consolidation study: conspecter+memory-manager, resource-manager, reviewer+analyzer, ai-specialist+ai-auditor"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-29
source: inventory
date: 2026-09-29
created: 2026-09-29
updated: 2026-10-06

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [".opencode/oh-my-opencode-slim.jsonc", "knowledge/model-registry.yaml", ".opencode/oh-my-opencode-slim/knowledge/ai-assist-sources.yaml", ".opencode/CHANGELOG.yaml", ".opencode/CHANGELOG.md", ".opencode/learnings/external-patterns/2026-10-06-dia-260929-nc6w-observer-vision-routing.md", "docs/dev-infra-audit/tickets/DIA-260929-nc6w-agent-role-consolidation-study-conspecter-memory-manager-resource-manager-reviewer-analyzer-ai-specialist-ai-auditor.md"]
artifacts: []
evidence: ["make test-config exit 0 (post re-route)", "PNG exact-match probe 6/6 'X7-Q42-LM' on opencode-go/qwen3.8-flash; no-image negative control 0/2", "Phase-6 audit advisory PASS", "CHANGELOG entry appended via scripts/changelog-add (Phase 7)"]

---

## Description

Decide the four consolidation questions this study commissioned (conspecter+
memory-manager, resource-manager, reviewer+analyzer, ai-specialist+ai-auditor)
and record the disposition, so the campaign stops showing an OPEN study whose
seven reports are already published.

## Problem

- The study is published but undecided in the ledger. Seven reports under
  `knowledge/ana-260929-*` each cite this ID as their campaign ticket:
  `lmhb` (conspecter+memory-manager, "lane 1 of 4", VERDICT: NO - keep two
  lanes, report:16), `17rl` (resource-manager, "Verdict: merge into
  @researcher", report:23), `lchi` (reviewer+analyzer, "keep both. The merge
  recommendation is declined with evidence"), `inpt` (ai-specialist vs
  ai-auditor, "Recommendation: keep both (status quo)", report:35), plus the
  question-set-2 argument set `23go` / `8t6u` / `lw7b` (3 further
  `knowledge/ana-261006-*` reports also cite this ID as follow-on work). None of
  those verdicts appears in this ticket, which still carries the creation
  template.
- Scope mismatch with the ledger: `.opencode/CHANGELOG.yaml` contains EXACTLY
  ONE entry citing this ID (queried with the per-DIA PyYAML filter) and it is
  not about the study at all:

      date: 2026-10-06
      ticket: DIA-260929-nc6w
      scope: .opencode
      files: [.opencode/oh-my-opencode-slim.jsonc, knowledge/model-registry.yaml, .opencode/oh-my-opencode-slim/knowledge/ai-assist-sources.yaml]
      summary: "Re-route @observer in the active mimo-balanced preset to vision-capable opencode-go/qwen3.8-flash (fallback opencode-go/kimi-k2.7-code); align model-registry lane arrays and ai-assist-sources role_mapping; probe-validated (PNG exact-match 6/6)"
      verification: "make test-config exit 0; PNG exact-match probe 6/6 (no-image control 0/2) on opencode-go/qwen3.8-flash; Phase-6 audit advisory PASS"

### Scope reconciliation - which scope is correct

**The study scope is correct for this ticket; the CHANGELOG entry's `ticket:`
pointer is the error.**

- This file was created 2026-09-29 by `9d081d00` ("docs(tickets): add campaign
  ticket files and ana-260929 analysis reports") with the study title, and
  `docs/dev-infra-audit/tickets/README.md:366` still rolls it up as
  "agent-role consolidation study: conspecter+memory-manager, resource-manager,
  reviewer+analyzer, ai-specialist+ai-auditor".
- Observer is not one of the four study questions, so the 2026-10-06 work
  described in the cited entry is out of scope by the ticket's own title.
- The vision work had no ticket of its own: the learning file
  `.opencode/learnings/external-patterns/2026-10-06-dia-260929-nc6w-observer-vision-routing.md:4`
  cites this ID with the title `'Observer lane routed to text-only model
(vision capability gap)'`, and no ticket file with that title exists
  (`ls docs/dev-infra-audit/tickets/ | grep -i observer` shows no such ticket).
  The commit `ad6b78ad` then both appended the `## Update 2026-10-06` section
  here and wrote the CHANGELOG entry under this ID, and this file's frontmatter
  `files_touched` / `evidence` were filled with the vision work
  (slim.jsonc, model-registry.yaml, PNG probe), not with study outputs. That is
  an ID borrow, not a widened scope: neither the title nor the README row was
  changed to make nc6w an umbrella.
- Reading of the alternative (nc6w deliberately became an umbrella for
  observer/agent work) is not supported by any artifact: no text anywhere says
  so, and the umbrella reading would leave the ledger row wrong instead.

## Verification

- [ ] This ticket carries a disposition line per study question, citing the
      report file and its verdict (four primary reports + the set-2 argument
      set).
- [ ] Every `.opencode/CHANGELOG.yaml` entry citing `DIA-260929-nc6w` either
      matches the study scope or has been repointed to a ticket that owns that
      work (query: the per-DIA PyYAML filter returns entries whose `summary`
      subject matches the ticket's title scope).
- [ ] This file's frontmatter `files_touched` / `evidence` either list the study
      artifacts or carry an explicit ID-reuse note explaining the vision work.
- [ ] `bash scripts/validate-changelog.sh` exit 0 and `scripts/changelog-render`
      re-run; `make test-config` exit 0.

## Fix

Smallest concrete change, three moves:

1. Append a dated DECISION block to this ticket recording the four published
   verdicts (keep conspecter+memory-manager; merge resource-manager into
   researcher; keep reviewer+analyzer; keep ai-specialist+ai-auditor), each
   with its report path - the reports already carry the evidence, so this is a
   transcription, not new analysis.
2. Fix the ledger link: create a ticket for the observer vision-routing change
   (`scripts/tickets new --title "observer lane routed to text-only model (vision capability gap)"`)
   and repoint the 2026-10-06 entry's `ticket:` field to it (manual YAML edit is
   the documented fallback - `.opencode/CHANGELOG.yaml` is append/repair edited
   by text, then validated and rendered), or, if the developer explicitly wants
   nc6w as an umbrella ID, record that decision in this ticket AND in the README
   row so the two stop disagreeing.
3. Restore frontmatter scope: keep the vision-work rows only if option 2 keeps
   the borrow, otherwise replace them with the study's artifacts.

Acceptance: a reader of the ticket sees the study's answers; a reader of the
CHANGELOG entry sees the ticket that owns it.

## Re-verify

    python3 -c "import yaml,json; [print(json.dumps(e,indent=1,default=str)) for e in yaml.safe_load(open('.opencode/CHANGELOG.yaml')) if e.get('ticket')=='DIA-260929-nc6w']"
    bash scripts/validate-changelog.sh
    grep -n "agent-role consolidation study" docs/dev-infra-audit/tickets/README.md
    grep -rl "DIA-260929-nc6w" knowledge/ana-260929-*/*.md | wc -l    # expect 7 study reports
    make test-config

## Update 2026-10-06 (observer vision routing, Option C)

- EBDV chosen variant: @observer -> opencode-go/qwen3.8-flash primary +
  opencode-go/kimi-k2.7-code fallback in the active mimo-balanced preset.
  Because: Go-native vision, respects the DIA-260916-7jek no-openai
  invariant, probe-validated.
- Rejected: openai/gpt-5.6-luna inside mimo-balanced (violates the
  DIA-260916-7jek no-openai invariant; plus Go transport caveat).
- Probe verdict PNG_PASS: exact-match PNG string "X7-Q42-LM" read 6/6;
  no-image negative control 0/2; image prompts billed 142-178 tokens vs
  76 without.
- PDF finding: the Go gateway accepts a PDF as an OpenAI `file` part
  (HTTP 200, string read exactly); the docs' "no PDF" limit is NOT
  gateway-enforced (only image_url carrying PDF bytes returns 400).
- Registry/config note: observer removed from the mimo-v2.5 and
  mimo-v2.6-flash lane arrays and added to the qwen3.8-flash lane
  (knowledge/model-registry.yaml); no kimi-k2.7-code registry entry
  exists (only kimi-k3). slim.jsonc mimo-balanced observer model array
  re-routed, line 14 volume-lane comment corrected; line 313
  openai-first-cost-balanced left untouched.
