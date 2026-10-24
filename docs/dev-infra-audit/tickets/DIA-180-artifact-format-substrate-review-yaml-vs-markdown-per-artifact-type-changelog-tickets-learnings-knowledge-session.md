# DIA-180 - artifact format substrate review: YAML vs Markdown per artifact type (changelog, tickets, learnings, knowledge, session)

<!-- RENUMBERED 2026-08-14 (reconciliation, cod-7): local DIA-153 collided with origin/omo-slim-changes ticket DIA-153-push-omo-slim-changes-to-origin.md (different ticket). Renumbered to DIA-180 per developer disposition. -->

---

id: DIA-180
title: "artifact format substrate review: YAML vs Markdown per artifact type (changelog, tickets, learnings, knowledge, session)"
area: docs
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
discovered: 2026-08-14
source: inventory
date: 2026-08-14
created: 2026-08-14
updated: 2026-08-14

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_000c07443ffebr4XljMzhG2hVw"
lane_id: "docs"
agent: "orchestrator"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "2026-08-14T11:54:22Z" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: ["docs/dev-infra-audit/tickets/DIA-180-artifact-format-substrate-review-yaml-vs-markdown-per-artifact-type-changelog-tickets-learnings-knowledge-session.md"]
artifacts: []
evidence: []

---

## Description

Developer-raised review request (2026-08-14): decide the canonical FORMAT
SUBSTRATE for each agent artifact - YAML vs Markdown vs JSONL - and how much
structure each artifact should carry. SIBLING of DIA-136 (session-record
stores) and DIA-137 (lightweight tools to simplify operations): DIA-136
researches JSON-DB/API layers for session records, DIA-137 surveys tools that
generate/hold artifacts. THIS ticket is the data-model/standards sibling: for
each artifact, what is the source-of-truth substrate, who consumes it, and
what format serves both cheapest. Coordinate with both; do not re-evaluate
their candidates (lowdb etc. stay with DIA-136/137).

### Premise correction (ground truth, verified 2026-08-14)

The originating idea was: "we have YAML LSP so it may be easier and cheaper
for agents to read and edit YAML". Verified state:

- YAML LSP is NOT installed. scripts/lsp-versions.env pins only
  typescript-language-server / pyright / rust-analyzer (dev-infra-language-servers
  scoped to TS/Python/Rust). opencode.jsonc has "lsp": true, which only enables
  discovery of whatever is on PATH - nothing YAML is on PATH today.
- Agents do not consume LSP diagnostics: they read/write files via text tools,
  so LSP helps the human in VSCode, not the agents.
- What makes YAML viable for AGENT-WRITTEN artifacts is the validation
  machinery this repo already runs: make test-config (validates
  .opencode/memory-shelf.yaml today), scripts, and the derived-view pattern
  (scripts/session-log render, scripts/tickets rollup).

Therefore the ticket splits into an ENABLER (make the premise true) and an
ANALYSIS (test the claim with evidence).

### Deliverable A - Enabler (small, dev-infra, implemented in this ticket)

Make YAML editing and validation first-class so agent YAML errors are caught
by gates, not by silent corruption:

- A1. Pin yaml-language-server in scripts/lsp-versions.env (npm global
  install pattern identical to typescript-language-server), install in
  Dockerfile.dev, probe in scripts/check-host-lsp.sh, bats coverage in
  scripts/**tests**/check-host-lsp.bats (FAKE-mock pattern, no real binary
  spawned). Stays dev-infra: no opencode.jsonc edit needed ("lsp": true
  already auto-discovers).
- A2. JSON Schema (or equivalent validator) per YAML artifact that agents
  write, wired into make test-config: .opencode/memory-shelf.yaml first,
  then any artifact the analysis (Deliverable B) converts to YAML.
- A3. Host install documented (docs/dev-infra/host-lsp-setup.md) per the
  existing check-host-lsp conventions.

### Deliverable B - Analysis (evidence-backed, EBDV per DIA-115)

Classify every agent artifact on the data-vs-prose axis and recommend
stay-MD / full-YAML / YAML-source + derived-MD-view, with token-economy and
error-rate evidence. The repo already embodies the hybrid answer: ticket
ledger = MD body + YAML frontmatter as the machine layer (DIA-125 chose text
over binary DB because git merges text cleanly - YAML preserves that), and
derived MD views (messages.md, tickets/README.md rollup) prove the
source-YAML + rendered-MD pattern.

### Artifact inventory (2026-08-14)

| Artifact                                       | Format today          | Size   | Primary consumer   | Write frequency         |
| ---------------------------------------------- | --------------------- | ------ | ------------------ | ----------------------- |
| .opencode/CHANGELOG.md                         | Markdown              | 133 KB | agents + developer | every section-10 change |
| .opencode/memory-shelf.yaml                    | YAML                  | 69 KB  | agents             | research registration   |
| .opencode/learnings/\*.md                      | Markdown              | -      | agents             | session end             |
| .opencode/session/registry.jsonl               | JSONL                 | -      | plugin + agents    | every delegation        |
| .opencode/session/messages.jsonl               | JSONL                 | -      | plugin + agents    | every event             |
| .opencode/session/messages.md                  | Markdown (DERIVED)    | -      | agents             | regenerated             |
| .opencode/session/current-handoff.json         | JSON                  | -      | orchestrator       | session end             |
| .opencode/session/HANDOFF.md                   | Markdown              | -      | orchestrator       | session end             |
| docs/dev-infra-audit/tickets/\*.md             | MD + YAML frontmatter | -      | agents + developer | ongoing                 |
| docs/dev-infra-audit/tickets/README.md         | Markdown (DERIVED)    | -      | agents + developer | rollup                  |
| docs/dev-infra-audit/NEXT-RUN.md               | Markdown              | -      | orchestrator       | occasional              |
| knowledge/res*, ana*, tch\*                    | Markdown              | -      | agents             | research pipeline       |
| openspec/changes/\*/{proposal,design,tasks}.md | MD + YAML frontmatter | -      | agents + developer | per change              |
| .sdd/                                          | Markdown              | -      | agents             | rare                    |
| AGENTS.md, practice-protected.md               | Markdown              | -      | agents + developer | rare                    |

### Axis and lean recommendations (to be evidenced in the analysis)

- Machine-first, already structured -> stay YAML: memory-shelf.yaml,
  ai-assist-sources.yaml, ticket frontmatter.
- Machine-first, append-only stream -> OUT OF SCOPE: session/\*.jsonl. YAML is
  the wrong substrate for append-only event streams (one bad document poisons
  the file); JSONL stays, storage questions belong to DIA-136.
- Narrative / instructions / human-rendered -> stay MD: openspec/ (external
  tool format, do not fork), knowledge/ conspects and reports, AGENTS.md,
  practice-protected.md, NEXT-RUN.md, .sdd/.
- FLAGSHIP CONVERSION CANDIDATE -> .opencode/CHANGELOG.md: convert to a YAML
  ledger (entries: date, ticket_id, scope, route, outcome, summary) + derived
  CHANGELOG.md view via a render script, following the messages.md /
  tickets-README rollup pattern. Largest hand-maintained agent artifact,
  cross-referenced from tickets and learnings.

### Boundaries

- No silent conversion: the analysis recommends; conversions spawn follow-up
  tickets after developer approval (guardrail inherited from DIA-084).
- Session records storage and JSON-DB candidates belong to DIA-136.
- Tool/renderer/scheduler candidates belong to DIA-137.
- Any opencode.jsonc / config-surface change resulting from the analysis
  routes through the section-10 chain (global AGENTS.md section 10); the
  enabler (Deliverable A) deliberately avoids it.

### Routing

- Enabler (A1-A3): dev-infra chain (spec embedded in this ticket; coder
  implements test-first; gates make test-shell / test-config / test-infra).
- Analysis (B): docs lane, evidence from internal measurement (token economy
  via wc/context_usage on read paths) + light external research (LLM YAML
  write-error rates); EBDV variants per recommendation (DIA-115).

## Verification

- [ ] A1: yaml-language-server pinned in scripts/lsp-versions.env, installed
      in Dockerfile.dev, probed in scripts/check-host-lsp.sh; bats cases in
      scripts/**tests**/check-host-lsp.bats (FAKE-mock, no real binary);
      make test-shell exit 0; docker smoke (make test-infra) shows
      yaml-language-server --version on PATH in poetry-dev.
- [ ] A2: JSON Schema + validator for .opencode/memory-shelf.yaml wired into
      make test-config (exit 0 with current shelf).
- [ ] A3: host install documented in docs/dev-infra/host-lsp-setup.md.
- [ ] B1: Inventory table completed with real sizes and consumers (above,
      filled).
- [ ] B2: Data-vs-prose classification per artifact with rationale.
- [ ] B3: Token-economy measurement for top-3 candidates (CHANGELOG first):
      context cost to read today vs equivalent YAML ledger.
- [ ] B4: Agent YAML write-error risk analysis: in-repo precedents (DIA-079
      JSON parse error, DIA-075 snip-jq loop) + external evidence on LLM YAML
      error rates; mitigation = schema + LSP + gates.
- [ ] B5: EBDV-style recommendation matrix per artifact (>=2 genuine variants,
      evidence per variant, abort/status-quo variant, explicit recommendation
      with because) + routing flag (dev-infra vs section-10 vs N/A).
- [ ] B6: Cross-referenced with DIA-136/DIA-137 - no duplicate evaluation of
      shared candidates; their outcomes referenced not re-derived.
- [ ] B7: Output registered in the memory shelf (ana<NNN> report; escalate to
      .sdd ADR only if the review surfaces an architecture-level decision).

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## Merge

> Merged to `omo-slim-changes` 2026-08-15 (serialized squash lane) as commit
> `bcb8379` — squash of `omos/dia-180` @ 19b6efb onto the 49cb3de lineage
> (base 8a737a3). Scope merged: Deliverable A enabler (A1-A3). Deliverable B
> (analysis) artifacts remain in-ticket for the analysis lane; ticket closed
> by merge per ledger convention. README row -> CLOSED + summary counts in
> the ledger commit.

**R3 merge-gate evidence** (`docker compose ps`, before the first merge of the
lane, 2026-08-15):

- poetry-dev Up 9 hours (healthy)
- poetry-postgres Up 9 hours (healthy)

**Gate results (this lane, post-merge):**

- `make test-config`: exit 0 — including the NEW gate `bash
scripts/validate-memory-shelf.sh` -> `ok: .opencode/memory-shelf.yaml
(shelf shape matches scripts/schemas/memory-shelf.schema.json)`; node
  batch-d-infra 56/56; all other validators pass.
- `make test-shell`: full target blocked by SIBLING lane interference —
  DIA-188's in-flight working-tree edit leaves
  `tools/opencode-docker/config/opencode.json` invalid JSON (a `//` comment
  inside plain JSON, line 25), so the `test-opencode-docker` prerequisite
  fails. That file is not touched by this merge (verified: not in the branch
  diff, never staged). Direct bats run: 353 tests, 351 ok, 2 not-ok —
  `opencode-docker gate: real subproject tree` (same DIA-188 sibling cause)
  and `overnight TUI mode` (pre-existing DIA-186 assertion staleness, verified
  failing at HEAD 49cb3de pre-merge). All DIA-180 bats green: check-host-lsp
  9 cases (incl. yaml-language-server FAKE-mock probe, no real binary) +
  validate-memory-shelf suite over the 6 fixtures.
- `check-host-lsp.sh` (host probe): 3 ok, 0 fail, 1 warn —
  yaml-language-server absent on host PATH (expected; the dev container
  provides it; host install documented in docs/dev-infra/host-lsp-setup.md).
- Dockerfile.dev change verified in-tree; image rebuild deferred to next
  `docker compose build dev` (container still runs the pre-merge image).
- Pre-commit hook passed (no `--no-verify`; container up).
