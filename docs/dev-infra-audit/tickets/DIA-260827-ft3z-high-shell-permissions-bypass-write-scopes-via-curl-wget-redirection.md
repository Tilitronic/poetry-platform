# DIA-260827-ft3z - [HIGH] Shell permissions bypass write scopes via curl/wget redirection

---

id: DIA-260827-ft3z
title: "[HIGH] Shell permissions bypass write scopes via curl/wget redirection"
area: opencode-config
severity: High
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: inventory
date: 2026-08-27
created: 2026-08-27
updated: 2026-08-27

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
evidence:

- .opencode/opencode.jsonc:485-500,586-601

---

## Description

Reaudit (DIA-260827-wfcx, 2026-08-31; W-H2) confirms researcher/resource-manager can curl -o, wget -O, and redirect (opencode.jsonc:493-500,595-601); coder has node _, bun _, python3 _ (:337-342); the section-2.5 edit gate does not intercept bash (delegation-observer.ts:3114-3124). Impact: a lane with edit: knowledge/_ can write anywhere; coder can change .opencode/ and bypass the AI-specialist gate. Correct fix: path-validating fetch/write adapters, a protected-path shell gate, and removal of broad interpreters where unneeded.

## Verification

Verify a narrow edit-scoped lane cannot write outside its directory via curl/wget/redirection; coder loses broad interpreters unless required.

## Fix

Detail: researcher/resource-manager edit scopes are narrow, but allowed curl/wget/shell commands can write anywhere through output flags or redirection. Impact: externally influenced lanes can overwrite config or source outside their artifact directories.

Fix: use path-validating fetch wrappers or non-shell fetch plus scoped edit.

## Re-verify

> To be filled at re-verify time.

## UPDATE 2026-09-10 - learnings registration lane (AGENTS.md 2.5 step 1)

- Registered: `.opencode/learnings/external-patterns/2026-09-10-shell-redirection-write-scope-bypass.md` (status: decided-not-implemented).
- Developer decision (EBDV, explicit): Option 2+3 durable. Primary control is a typed fetch-to-artifact tool/wrapper taking URL + artifact dir and enforcing the resolved output path inside `knowledge/<allocated-id>/sources/`; defense-in-depth is a protected-path bash gate for `.opencode/*`, `scripts/*`, AGENTS.md, git metadata, and workflow-critical paths; remove `curl *` / `wget *` as universal permissions. Option 1 (tighter bash arg patterns) rejected as primary: glob matchers cannot reliably parse shell syntax.
- Developer scoping notes: coder-interpreter scope (`node *`, `bun *`, `python3 *`, opencode.jsonc:337-342) is OUT - separate ticket. No status/frontmatter change; no implementation in this lane.

## UPDATE 2026-11-04 - G1/G2/G3 gate requirements (AGENTS.md 2.3 persistence)

The independent review of 9cfe295e found this ticket body described only the
curl/wget/redirection runtime class and none of the config gates built under
it, so the gate work had no artifact to diff against. The requirements below
are recorded from that review as explicit requirements with acceptance lines.
Implemented by 5dbc2f2 `fix(config): close the gate predicate and test coverage
holes`; the checks live in `.opencode/scripts/lib/jsonc-parse.js` (`--lockstep`
= G1, `--doc-drift` = G2/G3) wired through
`.opencode/scripts/validate-opencode-config.sh`.

### G1 - non-vacuous permission lockstep

- Pair members required: both members of each pair (`coder`/`coder-escalated`,
  `analyzer`/`analyzer-escalated`) must be configured. ACCEPTANCE: removing a
  member exits 1 naming `missing member "<name>"`, never a green zero-key line.
- Empty maps rejected: no permission object, an empty permission object, or no
  keys left after the pair's exemptions each fail naming the member.
  ACCEPTANCE: `permission: {}` and a task-only coder map each exit 1.
- Zero leaf rules rejected: every key of the post-exemption map must carry at
  least one leaf rule. ACCEPTANCE: `{"bash": {}}` exits 1 with
  `member "<name>" has 0 leaf rules`, never a green `1 keys, 0 rules`.
- Honest success line: reports top-level keys, leaf rules, the exemption note
  (singular/plural correct) and both compared agent names. ACCEPTANCE: the real
  config prints `ok: analyzer/analyzer-escalated permission lockstep (3 keys,
26 rules: analyzer, analyzer-escalated)`.

### G2 - semantic scope and the edit/bash invariant

- Restriction resolves by last-match-wins over probe commands, not key
  position: deny-by-default requires BOTH restriction probes to resolve deny
  under `findLast`. ACCEPTANCE: `{"jq *":"allow","*":"allow"}` is not
  restricted while `{"*":"deny","jq *":"allow"}` is, whatever key order tells.
- Dangerous execution shapes disqualify a map: if any of `python3 -c 'x'`,
  `python -c 'x'`, `bash -c 'x'`, `sh -c 'x'`, `node -e '0'`, `perl -e '0'`,
  `ruby -e '0'` resolves to allow, the map is unrestricted even when both
  probes deny, and the invariant failure names the allowed shape. ACCEPTANCE:
  `{"*":"deny","python3 *":"allow"}` exits 1 naming `python3 -c 'x'`; the real
  analyzer map (only `python3 .opencode/scripts/query_rag.py *` allowed) stays
  green because that anchor matches no dangerous shape.
- Edit deny-scoping resolves with path-shaped probes (a bare name plus a
  nested path; at least one resolves deny, neither resolves allow), so
  path-only glob maps are recognised and key position stays irrelevant.
  ACCEPTANCE: `{"**/*":"deny","knowledge/**":"allow"}` and
  `{"knowledge/*":"allow","*":"deny"}` both count as deny-scoped; the real
  `{"*":"deny","knowledge/*":"allow"}` still counts.
- Invariant: deny-scoped edit implies restricted bash, with the one explicit
  `memory-manager` exemption tracked by DIA-260827-ld2l `memory-manager and
designer over-granted permissions`. ACCEPTANCE: a deny-scoped-edit agent on
  flat or `python3 *` bash exits 1 naming the agent; memory-manager does not.

### G3 - doc-drift tripwire

- Scanned surfaces: `.opencode/agents/<name>.md`; in
  `oh-my-opencode-slim.jsonc` the `agents.<name>.orchestratorPrompt`,
  `agents.<name>.prompt`, `presets.<p>.<name>.orchestratorPrompt` and
  `presets.<p>.<name>.prompt` fields; and the live prompt-override files
  `.opencode/oh-my-opencode-slim/<name>.md` / `<name>_append.md`.
  ACCEPTANCE: a hit in each surface class exits 1 reporting its location.
- Phrase list with a paraphrase ceiling: `bash: allow`, `bash: fully allowed`,
  `bash (allow)`, `bash is allowed`, `Mermaid CLI`, `mmdc` - verbatim
  spellings only; other paraphrases ("shell is open") are a KNOWN ceiling,
  deliberately out of scope until seen. False positives are suppressed by a
  word boundary after `allow`, same-line negation (`not ` / `never` /
  `don't` / `do not`) and cross-agent line attribution (a prompt line naming a
  different configured agent and not the subject is not attributed to it).
  ACCEPTANCE: `bash: allow-list` and a routing-table line about another lane
  do not fire; every remaining occurrence on a line is reported.
- Analyzer positive marker: `deny-first` is REQUIRED in
  `agents/analyzer.md` and `agents/analyzer-escalated.md`; absence of either
  file is a failure naming the missing path (negative phrase scans stay
  skip-on-absent). ACCEPTANCE: deleting the file exits 1 with
  `required agent document missing`; a non-analyzer in-scope agent whose
  markdown lacks the marker passes, so the check stays scoped to the pair.

### Not delivered by this gate work - do not conflate

The runtime acceptance under Verification above - a narrow edit-scoped lane
cannot write outside its directory via curl/wget/redirection - is NOT
delivered by the G1/G2/G3 gate work: those gates are static config/doc checks
that fail on config drift, they never intercept a live shell command.
Redirection and command substitution remain open at runtime, held only behind
the plugin-level write-target gate. Closing this ticket's runtime acceptance
still needs the Fix-section work (path-validating fetch/write adapters and a
protected-path shell gate), not another config gate.
