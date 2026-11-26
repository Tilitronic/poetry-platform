# Analysis: Gemini Neon V2 Teardown Proposal vs Our Measured Migration Plan

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: recommendation
evidence-source: openspec/changes/opencode-v2-migration/design.md
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to memory-manager
-->

Campaign ticket DIA-261112-exon. Adjudication of 16 claims from a third-party
architectural verdict ("Gemini Neon") against this repository's own audited
migration plan, its two archived conspects, and a measured fact sheet produced
by a verification lane on 2026-11-26.

Scope of this lane: read-only analysis. No config, code, ticket, git, or
memory-shelf writes were performed. Every number below is either taken from the
fact sheet (which is authoritative for LOC and file counts) or read from the
cited `file:line`. Where neither source settles a claim, the row says UNVERIFIED
and names the probe that would settle it.

Reference aliases used throughout:

- `MIG` = `knowledge/res-261112-1ima-opencode-version-migration/res-261112-1ima-opencode-version-migration-conspect.md`
- `NAT` = `knowledge/res-261113-hi88-opencode-v2-native-capabilities/res-261113-hi88-opencode-v2-native-capabilities-conspect.md`
- `HANDOFF` = `.opencode/session/handoffs/ses_debc32ccaffeYN9qMw7ThTJ70q.json`
- `PLAN` = `openspec/changes/opencode-v2-migration/{proposal,design,tasks}.md`
- `ADR11` / `ADR15` = `.sdd/dev-infra/architecture.md:94-109` / `:139-155`
- `REGISTER` = `docs/opencode-v2-migration-audit-register.md`

---

## 1. Verdict summary

| Claim | Classification | One-line reason | Worst evidence gap |
|---|---|---|---|
| C1 | DISAGREE | The salvage list is wrong at its core: ticket gate, journal, handoff, routing gate and envelope each have live consumers and are kept by our own audited design. | None on the keep-side (ADR15:143-152, PLAN design D4:116-131). Gemini's "~1500 lines" is 4248 by measurement, so its cost model of the file it wants to delete is off by 2.8x. |
| C2 | PARTIAL | Deleting `needs-input-observer.ts` is right; deleting the ask-timeout watchdog is wrong, because V2 has no permission timeout at all. | Whether a TUI "waiting" badge exists in V2 to replace ticker visibility (NAT:331, NAT:457-458 - UNVERIFIED). |
| C3 | PARTIAL | Deleting the preset guard is right (our task 3.1 does it); "unneeded on 3.0.7" and "one clean preset" are not established. | No probe records OMO 3.0.7 session-model-clobber behaviour; design probe S6 covers plugin/API compat only (PLAN design:293-296). |
| C4 | PARTIAL | Compression direction is defensible; the arithmetic and the keep-list are wrong, and it deletes three mechanically gated policies. | Nothing open on the numbers; the open item is which markers the drift gate must keep (scripts/check-orchestrator-prompt-drift.sh:64-75). |
| C5 | PARTIAL | Two edits are directionally right, but the version comment lives in four files, and REFERENCE-ONLY.md:27 says a bare number bump is the wrong move on an OMO upgrade. | Whether OMO 3.0.7 prompt-file precedence still matches the documented contract (REFERENCE-ONLY.md:27-29). |
| C6 | AGREE | `#csc` / `#js` are dead (no RAG tool exists); the diff-source question is legitimate but already answered inside the repo. | The 4-line read-only bash alternative is not costed against glob-based git write hazards; UNVERIFIED by anyone. |
| C7 | DISAGREE | `analyzer_append.md` carries a live OWNERSHIP TRACKING section and the council lane it describes still exists; REFERENCE-ONLY.md is the target of a live pointer in `coder.md`. | Whether the ownership-tracking section is honoured in practice - not measurable from text alone. |
| C8 | PARTIAL | The typed `tickets` tool is a good idea; the causal story ("bash: deny forced mint_capability and meta_task_bypass") is false. | Whether a V2 file-based `.opencode/tools/*.ts` tool loads at all; our design deletes that directory (PLAN design D8:185). |
| C9 | PARTIAL | The shapes are reasonable, but `target_files` and "## Updates" are not ledger schema, duplicate detection does not exist in the CLI, and a reimplementation creates a second writer. | Cost of full dedup over 448 tickets / 103 OPEN (no measurement; scripts/tickets has no such subcommand). |
| C10 | PARTIAL | "~600 lines of ticket machinery" is fair; a 20-line token check would over-block the two documented bypass paths and the weak-correlation path. | None on policy; UNVERIFIED on whether OMO 3.0.7 still needs any bypass at all. |
| C11 | PARTIAL | The two commands are feasible and something is genuinely lost by the checksum gate, but one shared HANDOFF.md reintroduces the exact clobber DIA-085 slots were built to prevent. | No measurement of how often two sessions actually overlap; 98 slots suggest it happens. |
| C12 | PARTIAL | The boot gate does cost tokens per session; it is not the startup overhead, which is plugin module load plus a 60s timer. | No boot-time measurement exists in the repo. |
| C13 | PARTIAL | The architecture was already frozen by an audited register plus two ADRs; only the reviewer-diff question is genuinely open. | Nothing open; "final 7-agent list" is under-specified (which 7 of 15 live lanes?). |
| C14 | PARTIAL | Most deletion targets match our own D4 list; `envsitter-guard` is the freshest protection in the tree, the second preset is load-bearing for a gate, and "~100-150 lines" cannot coexist with the gates it keeps elsewhere. | What "dead skills" enumerates; candidate class is real (promo-review, git-permissions, console-charting, openspec-explore). |
| C16 | PARTIAL | Two of five lanes it names are already exactly as proposed; the other three flatten ordered fallback arrays and break two explicit model-family invariants. | kimi-k3.1-pro/qwen4-max rows still absent from `knowledge/model-registry.yaml` (learnings 2026-11-25 entry). |

Classification count: AGREE 1, PARTIAL 13, DISAGREE 2, UNVERIFIED 0 as a
standalone row (gaps carried inside PARTIAL rows).

The short form for Gemini: the plan is directionally right about *deleting*,
wrong about *what survives*, wrong by 2-3x on the size of what it deletes, and
wrong about the cause of the gate machinery. Its end state deletes four policy
gates and calls the result a simplification.

---

## 2. Claim-by-claim detail

### C1 - Delete `delegation-observer.ts`, salvage three small pieces

**Claim.** `~1500 lines` + 14 lib modules + 36 tests should be deleted, keeping
only the DIA-105 prettier hook (~40 lines), an optional bash-write-gate (~30
lines), and IMMUTABLE_GIT_ENVELOPE (~60 lines). Bio-signals, registry.jsonl,
messages.jsonl, log_decision, context_usage, mint_capability, handoffs/,
active.json, boot.json, conspect-pending, analysis-pending are "dead weight".

**What the repo says.** Measured size is 4248 lines, not ~1500
(fact sheet; 2.8x understated). The lib count (14) is correct. Tests are 35
`.test.mjs` plus 2 helpers and 4 harness scenarios (41 files, 16587 lines), so
"36" is a fair round of the test-file count and a large understatement of the
test mass that goes with it.

Our own audited design keeps, explicitly and with carriers: journal/registry
(~400 target), handoff (~110), `log_decision` (~160), ticket gate (~330),
reviewer envelope (~70), routing gate (~110), protected-path gate (~55),
`fetch-source` (~250), stall sweep (~60), watchdog (~35) - PLAN design
D4:116-131. ADR15 decision 2 puts the JSONL logs and handoff slots on the
filesystem *because* `ctx.storage` has no CAS (NAT:94-101; ADR15:148-151).

Consumers that make "dead weight" false, in the repo today:

- `scripts/lane-resume:7` reads `registry.jsonl` ("32k+ rows") for triage.
- `scripts/session-query.mjs:6-7` loads both JSONL files.
- `scripts/session-log:4-12` derives `messages.md` from `messages.jsonl`.
- `scripts/ticker-render.sh:5` reads the same stream family.
- `scripts/__tests__/routing-order-gate.test.mjs:9` shows the routing gate
  scanning `messages.jsonl` for the prior ai-specialist dispatch.
- `.opencode/session/active.json:3-5` currently carries this campaign's next
  action in prose; deleting it deletes the only cross-session pointer that is
  not a handoff slot.

What is genuinely dead and our plan also deletes: A1 advisory, context_usage,
adaptive routing, apoptosis/circuit-breaker/paracrine, capability minting, bash
tripwire, compaction snapshot, autocrine warn, pending detectors (PLAN design
D4:129-131, PLAN proposal:45).

**Delta.** Gemini treats the whole file as one artefact. Our design splits it
into a delete set (~3000+ lines) and a port set (~1580 target). The port set is
not optional: each item is the carrier for a policy that has no V2 native
equivalent (NAT:413-423 for the ticket domain; NAT:429-433 for handoff).

**Consequence if adopted as written.** The ticket gate, the reviewer fixed
point, the routing order gate and the handoff contract all disappear in one
commit. Nothing in V2 replaces them: the `policies` action enum is closed and
there is no ticket/handoff/API surface (NAT:138-145, NAT:415-419). The migration
would land a runtime with no mechanical protection for AGENTS.md section 2.3.

Two numbers in the salvage list are also wrong: the DIA-105 hook is
`lib/formatter.ts` (258 lines) plus its call site and ignore-set, not ~40; the
envelope work is `lib/envelope-gate.ts` (37) plus the reviewer block at
`delegation-observer.ts:1835-2000` (~165), not ~60.

---

### C2 - Delete or compress `needs-input-observer.ts` to ~30 lines

**Claim.** ~750 lines; ticker.json, WSL PowerShell toast, session renaming,
5-minute auto-reject watchdog and stallEnvelopeGuard are not worth keeping; a
~25-line `ctx.client.tui.showToast` hook suffices for notifications.

**What the repo says.** 1728 lines, not ~750 (fact sheet; 2.3x understated).
The notification split is already documented at
`needs-input-observer.ts:29-34`: primary is `ctx.client.tui.showToast()`, the
PowerShell path is the desktop fallback. So the "~25-line toast hook" is not a
replacement for the file - it is one of the two channels the file already uses.

The watchdog is the part that must survive. V2 has **no permission-ask timeout,
no auto-deny and no unattended env flag** (NAT:316-331, NAT:471-473); a stale
ask stays pending until replied to or the location reloads. Our ADR15 explicitly
retains "a ~30-40 LOC in-plugin permission-ask timeout watchdog" and deletes
everything else in the tier (ADR15:151; PLAN design D5:135-146). Reject
semantics are session-wide, which the watchdog must document (NAT:130-132).

`stallEnvelopeGuard` is not a needs-input concern in V2 terms: stall detection
lives in `lib/stall-sweep.ts` (349 lines) and is separately retained at ~60
lines (PLAN design D4:127).

**Delta.** Gemini's "delete or compress to ~30 lines" accidentally lands on the
right size (30-40) but names the wrong survivor: it keeps notifications and
drops the timeout. The timeout is the only guard V2 does not provide natively.

**Consequence if adopted as written.** An unattended or overnight run hits a
permission ask and hangs forever, with no expiry, no notification if the toast
is missed, and no ticker for the developer to notice. This is the exact failure
class DIA-098 was opened for.

---

### C3 - Delete `preset-model-guard.ts` entirely

**Claim.** ~220 lines; a workaround for OMO 2.2.19 preset bugs, unneeded on OMO
3.0.7 with one clean preset.

**What the repo says.** 275 lines (fact sheet; ~20 percent understated). The
file states its own basis: it exists because OMO 2.2.19 carries no `--model`
marker on `session.created` payloads, so a divergent newborn session cannot be
exempted and is force-switched (`preset-model-guard.ts:13-24`). It reads the
env intent carrier rather than re-implementing OMO merge logic
(`preset-model-guard.ts:4-7`).

Deletion is already in our plan: PLAN tasks 3.1 ("delete the preset guard and
its three suites") and design D4:131. ADR15 names preserving all three plugins
as the rejected alternative (ADR15:155). So on the action, we agree.

The justification is where it diverges: our plan deletes it because the
survivor set is one plugin with one `ctx.storage` namespace (ADR15:152), not
because 3.0.7 is proven to hold the preset. The config still carries two
presets (`.opencode/oh-my-opencode-slim.jsonc:15`, `:200`), and the comment at
`:11` warns the preset pointer mechanism "is not reliable enough to carry the
fix" and that `OH_MY_OPENCODE_SLIM_PRESET` overrides it. "One clean preset" is
not our state and is not established as the guard's replacement.

**Delta.** Action: agree. Reason: unverified. Scope: Gemini adds a
second-preset deletion we do not have.

**Consequence if adopted as written.** Deleting the guard is safe *if* one
preset and one preset source remain. Deleting the second preset to satisfy
"one clean preset" would also require editing
`scripts/check-orchestrator-prompt-drift.sh:60` (PRESETS list) and its bats
fixtures, or `make test-config` fails. If OMO 3.0.7 has not fixed the session
model clobber, the guard's loss shows up as agents silently running on the
wrong model - a failure mode with no test.

---

### C4 - Cut `orchestrator_append.md` ~4x to ~100 lines

**Claim.** ~450 lines; two thirds describes fighting our own plugins; keep only
role, Context Budgets, Escalation Rules, Interview-First + Fast-Path, DIA-175
instance separation, and dispatch templates.

**What the repo says.** 572 lines, not ~450 (fact sheet; 21 percent
understated), so the proposed cut is 5.7x, not 4x. Measured section spans:
Role 2, Context Budgets 15, Escalation 12, Interview 12, Research pre-gate 11,
Conspect gate 23, Fast-Path 36, Verification 36, Mandatory final 8, Change
Routing 10, A1-A8 139, Batch-Approval 66, Truncated protocol 63, Dispatch
contract 74, Changelog 57, Batch-D 52.

Plugin-coupled content is roughly 283-320 lines (A1, boot gate, truncated
protocol, dispatch contract, changelog, plus the conspect gate's mechanical
trigger) = 49-56 percent, not two thirds. The direction holds; the magnitude
is overstated by about 10 points.

The keep-list is where it fails. Three of the items Gemini drops are mechanical
gates with policy behind them:

- The conspect gate (`orchestrator_append.md:62-84`) enforces DIA-057 / DIA-058
  / DIA-260819-qibv and is driven by `conspect-pending.json`.
- The truncated-result protocol (`:324-386`) is DIA-099 - the only documented
  response to a silent subagent failure.
- The dispatch payload contract (`:388-461`) is DIA-261021-cs3v - the fixed
  point gate and the verification-only marker.

Also unaccounted for: the active preset carries a second orchestrator prompt
inline at `.opencode/oh-my-opencode-slim.jsonc:32` (byte-identical intent), and
`scripts/check-orchestrator-prompt-drift.sh:64-75` requires eight markers
including `batch-approval`, `DIA-133`, `READ-SCOPE`, `EBDV`, `threshold-15-25`
and `todowrite-discipline`. Compressing one file without the other leaves the
inline prompt carrying deleted rules; compressing both without updating MARKERS
fails `make test-config`.

**Delta.** Right diagnosis (the prompt is long because it compensates for
plugin behaviour), wrong prescription (delete the behaviour-specific text
before the behaviour is gone). The correct order is: delete the mechanism, then
delete its prompt section, then re-point the drift gate.

**Consequence if adopted as written.** Deleting the dispatch contract text
alone does not disable the gate - the plugin still throws - it just makes the
orchestrator hit avoidable hard-throws. Deleting the DIA-099 protocol removes
the only written recovery path for empty results, and the recovery skill it
points at (`resume-truncated-lane`) loses its entry point.

---

### C5 - `coder.md` / `coder_append.md` stay, bump 2.2.19 -> 3.0.7

**Claim.** Almost unchanged; bump the version comment and drop the batch-D
mention if parallel worktrees are unused.

**What the repo says.** `coder.md` is 57 lines and its only version reference
is line 2 ("oh-my-opencode-slim@2.2.19"), which also points at
`REFERENCE-ONLY.md` for precedence notes (line 3). `coder_append.md` is 9 lines
and its batch-D rule is line 7.

Three problems with "bump the comment":

1. The same stale number appears in four places, not one:
   `coder.md:2`, `analyzer_append.md:8`, `REFERENCE-ONLY.md:6`,
   `REFERENCE-ONLY.md:20`. A single-file bump leaves three lies.
2. The live pin is already 3.0.7 (`.opencode/opencode.jsonc:696`), so this is a
   doc-truth fix, not a config change - which makes it cheap and worth doing.
3. `REFERENCE-ONLY.md:27` is an instruction, not prose: "ON ANY OMO UPGRADE:
   re-verify prompt precedence semantics (inline vs file)". Changing the number
   without the re-verification converts a live warning into a false assertion.
   The 2.2.19-era failure it guards against is documented in
   `analyzer_append.md:7-13` (inline prompt plus file override produced an
   override warning and divergent runtimes).

Batch-D: `.worktrees/` is currently empty, so "unused today" is true
(transient). But the worktree model is binding (ADR1/ADR2, ADR11 decision 3),
`scripts/__tests__/batch-d-infra.test.mjs` exists, and A1 batch D is the
documented parallel-coder contract. Dropping the rule because no worktree is
checked out right now is a snapshot applied to a policy.

**Delta.** Add three more edit sites and keep the upgrade warning; treat batch-D
as dormant, not dead.

**Consequence if adopted as written.** Coder.md asserts a runtime version that
the tree does not run, with no pending re-verification flag - the exact drift
class DIA-045 describes.

---

### C6 - `reviewer.md`: drop dead RAG section, decide the diff source

**Claim.** Two edits: remove the dead RAG GROUNDING section (`query #csc`,
`query #js`) and decide where the diff comes from.

**What the repo says.** AGREE on the first edit. `reviewer.md:49-51` is the only
live mention of `#csc` / `#js`; a repo-wide grep finds only a historical
learnings reference (`2026-07-12-opencode-config-review.md:12`) and no RAG tool,
server, or permission in `.opencode/opencode.jsonc`. The section is dead text.

The second edit is a non-question in our repo. The diff source is already
decided three ways: `reviewer.md:5` ("No bash, no git"), `reviewer.md:8`
(envelope is the ONLY evidence), the active preset orchestratorPrompt
(`oh-my-opencode-slim.jsonc:275`, same contract), and ADR15 Layer 3
(ADR15:147). DIA-261021-cs3v hardened it: exactly one `FIXED_POINT:` line, a
duplication guard (`lib/envelope-gate.ts:20-36`), and a hard throw at
`delegation-observer.ts:1852-1895`.

The "4-line read-only bash" alternative Gemini floats is a real option, and the
repo contains the counter-argument: read-only git is not expressible as safe
globs. The project's own bash maps needed about 40 deny patterns just to keep
`git push`, `git clean`, `git checkout .`, `git restore` and worktree-forced
removal from being reachable through broad allows
(`.opencode/opencode.jsonc:46-137`). A reviewer allowed `git diff *` would also
be allowed `git diff --output=<file>`.

**Delta.** Edit one: do it. Edit two: already decided; if it is to be
re-opened, it must re-open ADR15 Layer 3, not just a prompt line.

**Consequence if adopted as written.** Removing the RAG section is a free win.
"Deciding the diff source" without citing ADR15 would silently invalidate the
envelope tests (`reviewer-immutable-git-envelope.test.mjs`,
`envelope-gate.test.mjs`) and reopen a settled reviewer-integrity decision.

---

### C7 - Delete `analyzer_append.md` and `REFERENCE-ONLY.md`

**Claim.** Only a 17-line OMO 2.2.19 comment and a dead COUNCIL DELEGATION
section remain.

**What the repo says.** `analyzer_append.md` is 44 lines with three parts:

- lines 1-18: the 2.2.19 dual-runtime comment (stale number, live warning);
- lines 20-22: OWNERSHIP TRACKING - who authored practice-protected-zone
  artifacts, flagged as its own finding. This is live: it is restated in the
  analyzer's own operating contract and in `.opencode/agents/analyzer.md` (76
  lines);
- lines 24-44: COUNCIL DELEGATION, user-opt-in. The council lane still exists
  with 6 councillor permissions (`opencode.jsonc:263-269`, 11 council hits) and
  a full seat block (`oh-my-opencode-slim.jsonc:281-310`). It is not dead.

`REFERENCE-ONLY.md` (29 lines) is not just a version comment: it is the target
of two live pointers (`coder.md:2-3`, `analyzer_append.md:11`) and it holds the
"one format per file, do not re-add an inline prompt" invariant. Deleting it
without editing those pointers leaves dangling references.

**Delta.** The stale 2.2.19 numbers should be corrected (see C5), not deleted.
The council section becomes dead only if the council lane is deleted - which is
in our plan (PLAN proposal:50) and is a developer decision, not an analyzer
cleanup.

**Consequence if adopted as written.** Ownership tracking, which is the one
mechanism that catches an agent authoring a practice-protected zone, disappears
from the analyzer's prompt with nothing replacing it; and `make test-config`'s
doc-drift contract (`validate-opencode-config.sh:46-57`) loses one of the files
it cross-checks.

---

### C8 - `bash: deny` forced the gate machinery; replace it with a typed `tickets` tool

**Claim.** The orchestrator's `bash: deny` forced `mint_capability`,
`meta_task_bypass` and ~400 lines of gate machinery. In v2, one typed
`.opencode/tools/tickets.ts` (~80 lines) replaces it, with a global
`"tickets": "deny"` plus `"tickets": "allow"` in the orchestrator block and an
internal `context.agent === "orchestrator"` check.

**What the repo says.**

- The `tickets` tool does not exist and is not permission-declared (fact sheet;
  verified against `opencode.jsonc` - no `tickets` key anywhere).
- `bash: deny` is real (`opencode.jsonc:188`).
- The causes of the two bypasses are documented in the plugin itself and are
  **not** bash: "the native task tool schema cannot carry project extension
  fields" (`delegation-observer.ts:2153-2154`), and the meta-task carve-out
  exists because a new ticket's random-suffix ID cannot be cited by the
  dispatch that creates it (`delegation-observer.ts:2108-2123`).
- `mint_capability` is an HMAC token for the section-10 *config-path* gate
  (`delegation-observer.ts:4179-4185`, `lib/capability.ts:52-69`), and its
  bypass of the DIA-217 block is one consumer (`:2090-2105`).
- The 600-line figure is fair: `lib/ticket-gate.ts` 383 + `lib/capability.ts`
  136 plus the DIA-217 resolution block (`~2100-2200`) is about 600-700 lines.

So: right about the pain, wrong about the cause. What `bash: deny` actually
forced is verification delegation, the changelog lookup delegation
(`orchestrator_append.md:470-497`) and the lane-0 checksum dispatch
(`:280-296`) - all of which a tickets tool does nothing about.

The tool design itself is sound in principle and matches the repo's existing
pattern: `fetch-source.ts:12-21` documents exactly the two-layer control Gemini
proposes (global deny hides the schema; `context.agent` guard is the runtime
control). One important caveat it omits: custom tools are **not**
permission-gated at execute time (`fetch-source.ts:15-17`), so a write-capable
tickets tool becomes a new unchecked write path into
`docs/dev-infra-audit/tickets/` unless it carries its own path confinement.

**Delta.** Adopt the tool; drop the causal claim; keep the ticket gate as a
dispatch gate (they solve different problems - the tool is for the orchestrator
creating tickets, the gate is for lanes starting work).

**Consequence if adopted as written.** Believing the tool replaces the gate
would remove the only enforcement that a lane has an OPEN ticket. The tool
makes *creation* possible for a bash-less lane; it does nothing about
*ticketless dispatch*.

---

### C9 - The tool's intended surface

**Claim.** `search(query)` / `list(status)`; `create({title, severity, reason,
plan, target_files})` with duplicate detection across OPEN tickets by keyword
and file overlap returning `{status:"duplicate_found", matches:[...]}` unless
`force:true`; `update({id, note, status, target_files})` appending under an
"## Updates" heading and bumping `updated_at`.

**What the repo says.**

- `search`, `list`, `show`, `stats`, `frontier`, `rollup`, `new`, `update` all
  exist as `scripts/tickets` subcommands (`scripts/tickets:1044`, `:1269`,
  `:1395`, `:1494`, `:1604`, `:1865`). Fact sheet confirms; duplicate detection
  is NOT a subcommand.
- The ticket frontmatter has `files_touched: []`, `artifacts: []`,
  `evidence: []`, `updated:` (`_TEMPLATE.md:42`, `:53-55`). There is no
  `target_files` field, so Gemini's schema adds a field the ledger does not
  have.
- `update` today supports `--status`, `--evidence` (deduplicated),
  `--fix-file`, `--reverify-file` - not a free-text `note`
  (`scripts/tickets:1866-1898`).
- "## Updates" is not the ledger convention; it appears in exactly one ticket
  (`DIA-210-pre-commit-root-ownership-flip.md:47`). The convention is an UPDATE
  block.
- Keyword correlation already exists as reusable logic:
  `lib/ticket-gate.ts:84-98` (`keywordsCorrelate`, stopwords). File-overlap
  detection does not exist anywhere.

**Delta.** Feasible, but "~80 lines" assumes pure in-memory work. Parsing
frontmatter, allocating IDs, inserting the README row and recomputing rollups
is what `scripts/tickets` needs 1969 lines for; a reimplementation will drift
from the CLI. The cheap correct shape is a thin tool that shells out to
`scripts/tickets` (plugins may spawn processes; only the V1 `$` helper is gone,
MIG:194), which would also honour DIA-229 ("create tickets ONLY via
`scripts/tickets new`", `orchestrator_append.md:530-531`).

**Consequence if adopted as written.** Two writers to one ledger, with no
Makefile rollup gate (grep: `Makefile` has no `tickets`/`rollup` target) and a
README that is already stale. Duplicate IDs or a silently stale README are the
likely first failures, and `validate-changelog`/ticket parsers downstream would
read the wrong shape.

---

### C10 - Result: one tool call, no coder lane, no gate machinery, 20-line safeguard

**Claim.** The orchestrator checks duplicates, creates and updates tickets in
one tool call - no coder lane, no mint_capability, no meta_task_bypass, no ~600
lines of gate logic. A ~20-line `tool.execute.before` hook checks for a DIA
token and an existing OPEN ticket file.

**What the repo says.** The "no coder lane" part is a real win: today the
orchestrator cannot create a ticket at all, because it has no shell and no
tickets tool, so creation is delegated or carved out. The 600-line figure is
fair (see C8).

The 20-line safeguard is the weak part. The current gate is not a token check;
it is three resolved paths plus two audited bypasses:

1. explicit `campaign ticket DIA-NNN` -> resolve ID -> must be OPEN;
2. no ID -> session-owned or keyword-correlated OPEN ticket, otherwise warn and
   allow (`orchestrator_append.md:527-539`);
3. chicken-and-egg carve-out for `scripts/tickets new` with strict procedural
   shape, emitting an audit row (`delegation-observer.ts:2108-2151`);
4. capability token path for closed-ticket bookkeeping (`:2090-2105`).

A 20-line "token + file exists" check rejects paths 2 and 3 outright. Every
rejected dispatch costs a re-dispatch cycle, which is far more expensive than
the ~100 lines it saves.

**Consequence if adopted as written.** Legitimate id-less bookkeeping
dispatches hard-block; the two AUDIT rows (`capability_used`,
`meta_task_bypass`) stop existing, so the only record of a bypass disappears
exactly when a bypass happens.

---

### C11 - Handoff needs no plugin; two slash commands suffice

**Claim.** The orchestrator may already read and edit `.opencode/session/*`;
`make-handoff` writes a structured `HANDOFF.md` (active tickets + status, work
done with commit hashes, branch/uncommitted state, blockers, next step;
overwrite or archive by date; no SHA256, no lane-0 verifier); `read-handoff`
reads it, re-validates tickets, shows 5-10 lines, asks for confirmation.

**What the repo says.** The capability claim is TRUE: the orchestrator has
`read` allow on `.opencode/session/*` (`opencode.jsonc:202`) and `edit` allow
on `.opencode/session/*` (`:229`). `HANDOFF.md` does not exist and neither
command does (fact sheet; `.opencode/commands/` has 9 files, 155 lines).

What a single `HANDOFF.md` loses, argued from the repo's own sources:

- Parallel slot identity. NEXT-RUN.md:316-324 states slot filenames are
  session-unique so parallel writes never clobber, and that the pointer is
  last-writer-wins by design while slots are the source of truth. A single
  file is a single slot: two sessions in one directory overwrite each other.
  There are 98 files in `handoffs/` (97 slots + `active.json`), so this is not
  hypothetical.
- Archive rotation on every write (`.opencode/plugins/lib/handoff.ts:128-140`
  renames the prior slot into `archive/` with an ISO timestamp and UUID).
  "Archive by date" reproduces the intent but not the collision handling.
- Atomicity: tmp -> fsync -> rename -> fsync-dir (`handoff.ts:142-151`). An
  agent writing a Markdown file gets no equivalent guarantee.
- The `.reconciled` sidecar (NEXT-RUN.md:395-400) that stops the boot gate
  re-presenting the same prognosis.
- DIA-124's mechanical write path: the handoff is written by `log_decision`, and
  a missing handoff at boot is a detectable finding (NEXT-RUN.md:337-340).
- The checksum. `computeChecksum` is a top-level-sorted SHA256 of the prognosis
  (`handoff.ts:30-36`), and the fresh re-read at comparison time exists to catch
  a mid-boot rewrite (`NEXT-RUN.md:349-355`, DIA-120 secondary finding 1). This
  is an integrity check, not a signature: the writer could recompute it. It is
  therefore droppable if writes stay atomic and single-writer - and dropping it
  also drops the lane-0 coder dispatch, which is a genuine per-session saving.
  What is not droppable is slot identity plus archive.

**Delta.** Adopt: two commands, no checksum, no lane-0. Reject: single
`HANDOFF.md` as the only store while parallel sessions are possible. Keep JSON
slots (or a per-session file) and have `make-handoff` write one.

**Consequence if adopted as written.** The first overlapping pair of sessions
silently loses one handoff - the precise failure DIA-085 was opened to fix,
reintroduced by a simplification.

---

### C12 - Zero startup overhead

**Claim.** Normal sessions open instantly with no automatic Batch-Approval Boot
Gate.

**What the repo says.** The boot gate is prompt discipline plus tool calls, not
a startup hook: it is item 1 of the inline orchestrator prompt
(`oh-my-opencode-slim.jsonc:32`) and `orchestrator_append.md:235-300`. It costs
tokens and one present-and-confirm exchange per session, and it dispatches
lane-0.

Startup cost lives elsewhere: loading 17 plugin source files (10078 lines),
`needs-input-observer` seeding `ticker.json` on boot
(`needs-input-observer.ts:258-292`), `delegation-observer` writing `boot.json`
(`delegation-observer.ts:445-446`, `:711`), and a 60s stall sweep interval
(`lib/stall-sweep.ts:24`). Deleting the boot gate does not change any of that;
deleting the plugins does.

**Delta.** PARTIAL. The gate is a real per-session cost and a legitimate target
for compression once the handoff surface is simplified. The "instantly" framing
is unsupported: there is no boot-time measurement in the repo, and the gate is
not on the startup path.

**Consequence if adopted as written.** Removing the gate without a replacement
drops the only point at which a successor session re-approves campaign state;
the C5 check (blocking ticket unresolved) also lives there (NEXT-RUN.md:368-369).

---

### C13 - Phase 1: freeze the architecture with a new audit

**Claim.** Run an audit brief through architector + analyzer + ai-auditor;
approve the final 7-agent list, the fate of the reviewer git diff (4-line
read-only bash vs 60-line plugin), and the deletion list; output one agreed ADR
/ OpenSpec v2-clean-slate.

**What the repo says.** This phase is already complete and its output is
binding:

- `REGISTER` records 16 findings (4 BLOCKER, 6 MAJOR, 4 MINOR, 2 NOTE) plus 8
  architecture verdicts (ACCEPT 0, ACCEPT-WITH-CHANGES 5, REJECT 3).
- ADR11 was amended 2026-11-19 (ADR11:94-109); ADR15 was added and accepted
  (ADR15:139-155).
- `PLAN` is revision 2, post-audit, with 24 register IDs plus 4 execution
  conditions dispositioned, 0 unclosed (`PLAN design:298-333`).
- The reviewer-diff question is the one genuinely open item, and it is open
  only as a cost/security trade (C6), not as an architecture unknown.

Redoing Phase 1 as a "clean slate" would discard a reviewed audit register and
re-open settled decisions (gate layering, durability split, single plugin id).
A "final 7-agent list" is also under-specified: the tree has 15 live agent keys
plus council seats (fact sheet). Dropping to 7 removes, at minimum, some of
`designer`, `observer`, `conspecter`, `council`, `ai-specialist`,
`code-navigator`, `memory-manager`, `openspec-plan` - and each of those has a
policy behind it (openspec-plan = AGENTS section 2.2 interview gate;
memory-manager = sole memory-shelf writer DIA-143; ai-specialist = section 2.5
gate; conspecter = research pipeline DIA-057/058).

**Delta.** Do not re-audit. If the ticket gate is to be re-scoped, amend ADR15
with the comparison and a supersede note - that is the only place a gate can be
legitimately retired.

**Consequence if adopted as written.** A second audit cycle plus a "clean
slate" ADR would invalidate the register that the current plan's traceability
table depends on, and would reopen three decisions the developer already
locked.

---

### C14 - Phase 2: delete everything, then two mini-plugins

**Claim.** Delete the three plugins, the 14 lib modules, old tests,
envsitter-guard from `opencode.jsonc`, ollama, council, dead skills, and the
second openai-first-cost-balanced preset; then write 2 mini-plugins totalling
~100 lines. Plugin code drops from "~3000+" to ~100-150.

**What the repo says.** Per item:

- Three plugins, lib, old tests: agree in substance (PLAN design D4:116-131),
  but the deletion set is smaller than "everything" - the port set is ~1580
  target lines (D4 table sums to 400+110+160+330+70+110+55+250+60+35 = 1580).
- `envsitter-guard`: DISAGREE on today's tree. The current pin is 0.1.1
  (`opencode.jsonc:702`), fixed in commit d3594ad6 because 0.0.4 was a
  V1-contract plugin that V2 rejected, leaving the container with **no dotenv
  protection while the config looked correct** (HANDOFF:9). The design's
  D10-C9 row still names 0.0.4 and is stale (PLAN design:212). The policies
  floor added at `opencode.jsonc:141-146` is the floor if the plugin fails, and
  its smoke test is still pending (HANDOFF:11).
- ollama: agree (PLAN proposal:50).
- council: agree with our plan, but this is a user-facing lane (6 seats, opt-in)
  and therefore developer disposition, not a cleanup.
- dead skills: plausible and unmeasured. Candidates with no `skills:` reference
  anywhere: `promo-review`, `git-permissions`, `openspec-explore`;
  `console-charting` is explicitly excluded from both orchestrator prompts
  (`oh-my-opencode-slim.jsonc:26`, `:205`). 22 `SKILL.md` files exist. Deleting
  needs an inventory pass (what would settle it: cross-reference each skill dir
  against every `skills:` array in both presets plus the agent docs, which the
  repo does not currently machine-check).
- second preset: NOT in our plan, and load-bearing for a gate:
  `scripts/check-orchestrator-prompt-drift.sh:60` audits exactly
  `mimo-balanced openai-first-cost-balanced`; deleting one requires editing
  that script, `:55-59` comment contract, and its bats fixtures. It is also the
  only non-`opencode-go` profile - the routing hedge if the provider is
  unavailable.
- "~100-150 lines total": arithmetically incompatible with the gates Gemini
  keeps elsewhere. Ticket gate + envelope + routing + journal + handoff +
  `log_decision` + stall + watchdog is ~1580 by our own design, and the ticket
  domain has no V2 native replacement (NAT:413-423). "~100-150" is only
  reachable by deleting all of them.
- "~3000+ lines" current: measured 10078 source lines (fact sheet), so the
  baseline is understated by ~70 percent - which makes the "reduction" look
  far larger than it is.

**Consequence if adopted as written.** The tree loses its dotenv protection
(again), `make test-config` fails on the drift gate, and the end state silently
deletes four policy gates to reach a line count.

---

### C15 - Phase 3: `tickets.ts`, two commands, narrow the config validator

**Claim.** Implement `.opencode/tools/tickets.ts` (auto-dedup + create/update/
search) and the two commands; update `validate-opencode-config.sh` to check
only the live v2 schema.

**What the repo says.** See C8/C9 for the tool. Two additions:

- `validate-opencode-config.sh` is not a schema validator. It is a JSONC syntax
  tokenizer over four files (`:17-24`) plus a deny-first doc-drift contract
  (`:46-57`). "Check only the live v2 schema" has no referent here; the real V2
  shape gates are four validators that currently hard-fail on V2 keys, all
  enumerated in PLAN design D10:204-221 (AUD-B4). Narrowing this script instead
  of repairing those four would produce a green gate over broken config.
- `.opencode/tools/*.ts` is V1-shaped in this tree: `fetch-source.ts:39`
  imports `@opencode-ai/plugin`, and our design deletes the directory because
  V2 auto-loads it as V1-shaped tools (PLAN design D8:185). Whether V2 still
  supports a file-based tools directory with the new package import is
  UNVERIFIED (the conspects do not state removal; only the `$` helper is
  explicitly removed, MIG:194). What would settle it: the V2 tools docs page
  plus a load probe in `dev-v2`.

**Consequence if adopted as written.** A green `validate-opencode-config.sh`
plus four still-broken validators, and a tool file that may not load.

---

### C16 - Phase 4: prompts, routing, smoke test

**Claim.** Move long procedures into `.opencode/agents/*.md`, compress
`orchestrator_append.md` (~100) and `AGENTS.md` (~80-100), set routing
(coder -> mimo-v2.6-flash, reviewer/ai-auditor/orchestrator ->
deepseek-v4.1-flash, analyzer -> mimo-v2.6-pro, architector -> gemini-4-argon),
smoke-test in dev-v2.

**What the repo says.** Routing is compared lane by lane in section 7. Two of
five proposals are already true; three flatten ordered fallback arrays and
break explicit invariants. The prompt-compression target for AGENTS.md is not
addressed by our plan at all (AGENTS.md is 298 lines, fact sheet) - it is a
policy document whose sections are cited by gates, so compressing it is a
policy change, not a cleanup.

**Consequence if adopted as written.** Same as C4 plus a routing regression on
the reviewer and auditor lanes.

---

## 3. LOC arithmetic reality check

**Claim under test:** "about 90 percent of the .opencode volume serves one
plugin."

Measured denominators (fact sheet):

| Measure | Lines | Files |
|---|---:|---:|
| Plugin source (3 entry files) | 6251 | 3 |
| Plugin source + lib | 10078 | 17 |
| Plugin tests | 16587 | 41 |
| Plugin source + tests | 26665 | 58 |
| Whole `.opencode/` (excl. session/, node_modules, .scratch, dist) | 65676 | 328 |
| Whole `.opencode/` excl. CHANGELOG.* | 58800 | - |

Ratios:

| Ratio | Value |
|---|---:|
| plugin source / whole tree | 15.3 percent |
| plugin source+tests / whole tree | 40.6 percent |
| plugin source / whole tree without CHANGELOG | 17.1 percent |
| plugin source+tests / whole tree without CHANGELOG | 45.3 percent |
| plugin source / (whole tree without CHANGELOG and without plugin tests) | 23.9 percent |
| prompts (orchestrator_append 572, AGENTS 298, coder 57, coder_append 9, reviewer 61, analyzer_append 44, REFERENCE-ONLY 29, `.opencode/agents/*.md` 359) / whole tree | 2.2 percent |

Residual: 58800 - 26665 - 1429 = 30706 lines (52.2 percent) is neither plugin
nor prompt. That is `.opencode/skills/` (22 SKILL.md plus references),
`.opencode/scripts/`, `.opencode/commands/` (155), config files, and knowledge
artefacts under `.opencode/`.

**Verdict: the 90 percent claim does not survive measurement as a source
claim.** The highest defensible statement is "the plugin plus its tests is
about 41-45 percent of authored `.opencode` source". To reach 90 percent one
must include the runtime data the plugin writes: `registry.jsonl` is documented
at "32k+ rows" (`scripts/lane-resume:7`), `messages.jsonl` is comparable, and
neither is in the 328-file measure because `session/` is excluded. Even under
that reading the total is roughly 65k data lines against ~59k source lines -
about 50 percent, not 90. The exact `messages.jsonl` count is not in the fact
sheet (UNVERIFIED); it would not change the conclusion by enough to rescue the
claim.

**Numbers in the claims that were understated:**

| Claim | Claimed | Measured | Error |
|---|---:|---:|---|
| delegation-observer.ts | ~1500 | 4248 | 65 percent low |
| needs-input-observer.ts | ~750 | 1728 | 57 percent low |
| preset-model-guard.ts | ~220 | 275 | 20 percent low |
| orchestrator_append.md | ~450 | 572 | 21 percent low |
| plugin code, current | ~3000+ | 10078 | 70 percent low |
| reviewer envelope salvage | ~60 | ~200 (37 + ~165) | ~70 percent low |
| DIA-105 formatter salvage | ~40 | 258 + call site | ~85 percent low |
| bash-write-gate salvage | ~30 | 289 | ~90 percent low |

**Numbers that were overstated:**

| Claim | Claimed | Measured | Error |
|---|---:|---:|---|
| share of `.opencode` | ~90 percent | 15-45 percent source; ~50 percent if data rows counted | 2-6x high |
| two thirds of orchestrator_append | 67 percent | 49-56 percent | ~10 points high |
| "36 tests" | 36 | 35 `.test.mjs` (+ helpers/scenarios) | 1 high |

**The decisive number:** the proposed end state of "~100-150 plugin lines"
compares against a port set of ~1580 target lines (PLAN design D4) and against
10078 current source lines. A 100-150 line end state is not a simplification of
the same system - it is a different system with four gates removed.

---

## 4. Risk register for the deletions

"Reversible?" means: can a `git revert` on the migration branch restore the
mechanism and its state, given that the V1 tree and V1 volumes are retained
until cutover (PLAN rollback:144-163). State loss is called out separately.

| Mechanism | What silently breaks if deleted today | Covering ticket / gate / test | Severity | Reversible? |
|---|---|---|---|---|
| Ticket gate (DIA-217 / DIA-063, `mint_capability`, `meta_task_bypass`) | Any `task()` dispatch proceeds without a governing OPEN ticket; config-work correlation is lost; the two bypass audit rows (`capability_used`, `meta_task_bypass`) disappear - exactly when a bypass happens. | `lib/ticket-gate.ts` 383; `delegation-observer.ts:2108-2151`, `:2153-2200`; tests `ticket-gate.test.mjs`, `dia217-ticket-gate.test.mjs`, `dia-ticket-id-parser.test.mjs`; policy AGENTS section 2.3, `orchestrator_append.md:527-539`. | Blocker (policy) | Code yes. Audit rows for past bypasses are in `registry.jsonl` (retained if the journal stays). |
| DIA-099 truncated/empty-result detection | A subagent that returns an empty or near-empty `<task_result>` is accepted as success; the D1/D2/D5 signals (session_complete + no edits + fast; MAXIMUM STEPS; stall with no terminal) stop being emitted, so the orchestrator has no mechanical prompt to re-dispatch. | `orchestrator_append.md:324-386`; `delegation-observer.ts:1548` (SILENT_FAILURE), `:3335-3354` (`empty_result_detected`); tests `empty-result-detection.test.mjs`, `integration-regressions.test.mjs`. | Critical | Yes (code + prompt). |
| Handoff slots + DIA-061 checksum + DIA-093 lane-0 + DIA-085 resolution chain + DIA-120 atomic write | Parallel sessions clobber a single slot; no archive of prior prognoses; no pointer to disambiguate; no detection of a missing handoff (DIA-124 self-check); a partial or mid-boot rewrite becomes invisible. Lane-0's coder dispatch is a cost, not a protection, so dropping it is a win. | `lib/handoff.ts:30-36`, `:104-189`; NEXT-RUN.md:310-400; tests `handoff.test.mjs`, `handoff-slot-identity.test.mjs`, `handoff-archive-collision.test.mjs`, `parallel-handoff.test.mjs`, `active-lifecycle-index.test.mjs`. | Critical | Code yes; state loss bounded to 98 existing slots (no new writes after removal). |
| IMMUTABLE_GIT_ENVELOPE / DIA-261021-cs3v fixed point | Reviewer either trusts live repo state (amended commits between dispatch and review become invisible) or gains a bash surface broad enough for git writes; the exactly-one-marker contract and the duplication guard stop being enforced. | `lib/envelope-gate.ts:20-36`; `delegation-observer.ts:1835-2000`; tests `reviewer-immutable-git-envelope.test.mjs`, `envelope-gate.test.mjs`; ADR15 Layer 3; `.opencode/opencode.jsonc:318-325` (reviewer has no bash). | Critical (review integrity) | Yes. |
| DIA-105 edit-time formatter | Diffs arrive unformatted; damage is bounded because the husky pre-commit path still runs prettier + eslint (`delegation-observer.ts:256-278`; AGENTS section 6 Edit-time formatting). The larger loss is documenting a behaviour that no longer exists. | `lib/formatter.ts` 258; test `formatter.test.mjs`; AGENTS section 6. | Minor | Yes. Note: our plan deletes it while AGENTS documents it - fix the doc in the same commit. |
| conspect-pending / analysis-pending research gates | Under V1 today: the mechanical trigger for DIA-057 / DIA-058 / DIA-260819-qibv disappears, so a `PERSISTENCE_RECOMMENDED: true` result can be closed without a conspect. Under V2: the detector cannot work at all, because `execute.after` never sees the child's result (PLAN design D7:174-177; REGISTER AUD-B3). Both flags are present in the tree now. | `delegation-observer.ts:2930-3066`; `orchestrator_append.md:62-84`; `research-pipeline` skill. No plugin test named for it (UNVERIFIED). | Major | Yes (code); the *gate* needs a replacement trigger (event.subscribe + explicit orchestrator check) or it is lost by design. |
| Registry / journal (quota guard DIA-133, session analytics DIA-182) | `scripts/lane-resume` triage, `scripts/session-query.mjs`, `scripts/session-log render` and ticker rendering lose their data source; dispatch cross-reference (ticket <-> lane <-> session <-> artifacts) and the A3/A4 audit rows stop. **Correction to Gemini's framing:** DIA-133 is a procedural quota guard (NEXT-RUN section 2 + `knowledge/model-registry.yaml`) and DIA-182 reads native `opencode stats`/`opencode db` (`scripts/session-analytics.sh:3-17`, `:152-209`), not the JSONL. Neither depends on `registry.jsonl`. | `lib/registry.ts` 1209, `lib/journal-persistence.ts` 242; tests `registry.test.mjs`, `active-lifecycle-index.test.mjs`, `delegation-observer.stale-boot-sweep.test.mjs`. | Major | Yes; ~32k+ registry rows of history become orphaned. |
| Stall sweep (DIA-098) | A child that dies silently is never re-dispatched; the orchestrator waits indefinitely. Made worse in V2 because the subagent tool returns immediately and completion must be inferred from events (PLAN design D7:172-178). | `lib/stall-sweep.ts` 349; `delegation-observer.ts:1579-1635`; test `stall-sweep.test.mjs`. | Major | Yes. |
| Permission fast-resolve (DIA-098 family) | Unattended runs prompt on every ask; headless can substitute `opencode run --auto` (NAT:26, NAT:335-337), in-TUI cannot. | `lib/permission-fast-resolve.ts` 216; test `needs-input-observer.fast-resolve.test.mjs`; ADR15:151 deletes it. | Medium | Yes. |
| Routing gate (DIA-230) | A coder dispatch naming a config path reaches the lane with no prior ai-specialist gate, so a section-2.5 config change proceeds unaudited. It must be repaired, not deleted: `lib/routing-gate.ts:84-90` reads paracrine rows that our own S2.2 deletes, so the repair is in the same commit (PLAN design:133). | `lib/routing-gate.ts` 152; test `routing-order-gate.test.mjs`; `delegation-observer.ts:2479`; `orchestrator_append.md:404-408`. | Major | Yes. |
| `active.json` (session) + `boot.json` | The cross-session "where we are" pointer disappears (`.opencode/session/active.json:3-5` currently carries the next action in prose), and the stale-instance/reload detection loses its marker (DIA-123). | `delegation-observer.ts:445-446`, `:665-684`, `:711`; `delegation-observer.stale-boot-sweep.test.mjs`. | Major | Yes (code); the current pointer text is lost unless migrated. |

---

## 5. The handoff claim, argued from sources

**Claim.** One `HANDOFF.md` plus `make-handoff` / `read-handoff` replaces the
plugin handoff, the JSONL streams, the checksum and the lane-0 verifier.

**What is actually lost, mechanism by mechanism.**

1. **Slot identity.** NEXT-RUN.md:316-324: "slot filenames are session-unique,
   so parallel writes never clobber each other... The pointer is
   last-writer-wins by design and is NOT a data-loss vector: slots are the
   source of truth, the pointer is an optimization." One Markdown file is one
   slot. With 97 slots already on disk and a worktree-based parallel model
   (ADR1, ADR11 decision 3), this is a regression to the pre-DIA-085 state.
2. **Archive rotation.** `handoff.ts:128-140` renames the prior slot into
   `archive/` with an ISO timestamp and a UUID before writing the new one. An
   overwrite-by-date scheme reproduces the intent but not the collision
   handling (two writes in the same second).
3. **Atomicity.** `handoff.ts:142-151` writes tmp, fsyncs, renames, fsyncs the
   directory. A tool/command writing Markdown has no such guarantee, and a
   truncated handoff is worse than no handoff because the successor reads it as
   authoritative.
4. **The `.reconciled` sidecar.** NEXT-RUN.md:395-400: approval of a slot is
   recorded so the boot gate does not re-present the same prognosis on every
   boot. Without it, either the gate re-presents (noise) or it stops presenting
   (silent resume).
5. **The DIA-124 detection signal.** NEXT-RUN.md:337-340: a missing handoff at
   boot is evidence the prior session failed the rule. With a manual command,
   "no handoff" becomes indistinguishable from "we do not use the gate".
6. **The checksum (droppable) and lane-0 (droppable).** `computeChecksum` is a
   sorted-key SHA256 of the prognosis (`handoff.ts:30-36`); the fresh re-read
   exists because the file may be rewritten between boot read and comparison
   (`NEXT-RUN.md:349-355`). It detects corruption or out-of-band edits. It does
   not authenticate: the same agent that could edit the file could recompute
   the hash. Because the write path is already atomic, the *engineering* value
   is modest. The lane-0 dispatch it drives is a pure cost paid every session.
   Dropping both is defensible; dropping them is the strongest part of
   Gemini's claim.

**What audit evidence disappears with the JSONL streams.**

- `registry.jsonl` rows: dispatch lifecycle (`dispatch_state`), ticket/lane/
  session cross-reference, `artifacts[]` (A4 gate), dangling `result_ref`
  alerts (A3), `stall_detected` / `session_assumed_dead_after_60_min` (DIA-098),
  `empty_result_detected` (DIA-099), `capability_used` and `meta_task_bypass`
  (DIA-217 bypass audit).
- `messages.jsonl` rows: decision events with `content_ref` and
  `resolution_status` (handoff-detected, batch-approval-complete,
  checksum-mismatch, checksum-verified), which are rendered into `messages.md`
  by `scripts/session-log`.
- Downstream readers that stop working: `scripts/lane-resume` (triage of a
  truncated lane), `scripts/session-query.mjs` (ad-hoc audit), `scripts/session-log`
  (derived view), `scripts/ticker-render.sh`.

**Verdict on C11: PARTIAL.** The two commands are a good idea and the checksum
gate is over-engineered for a single-writer atomic file. A single `HANDOFF.md`
is not: it deletes the concurrency-safe part of the handoff to remove the
verification-heavy part. Recommended middle path: keep per-session JSON slots +
archive + `.reconciled`; drop the checksum and lane-0; expose `make-handoff` /
`read-handoff` commands that write and read the slots through a small tool.

---

## 6. Phase-sequence critique

**Claimed order.** (1) audit and freeze architecture; (2) delete everything,
then write 2 mini-plugins; (3) tickets tool + commands + validator narrowing;
(4) prompt compression, routing, smoke test in dev-v2.

**Our actual state.** Branch `migration/DIA-261112-exon`, HEAD `43e3d2fd`
(HANDOFF:10). Already done: envsitter-guard pinned to 0.1.1 (d3594ad6), root
`policies` floor with two denies and two lifts (aa047399, 43e3d2fd),
`make test-config` exit 0 with 78 pass, working tree clean (HANDOFF:12).
Pending and ordered: the four-step policies smoke test in `poetry-dev-v2` on
2.3.2 **before** any bump (HANDOFF:11,13). Not started: the 2.4.2 bump, plus a
developer decision on extending the floor to `read:*.env*` and `secrets/*`.
`PLAN tasks.md` shows only task 1.4 checked - the task file is not maintained
against campaign reality, which matters because any new phase plan that trusts
it will re-plan completed work.

**Why the claimed order fails against this state.**

1. **Phase 2 deletes before any V2 proof, and the containment is weaker than
   the plan assumes.** The 2026-11-25 amendment moved `dev-v2` to the
   repository root (PLAN proposal:21, design D1a amendment:70). Both services
   now read `/workspace/.opencode`. Deletions are therefore visible to the live
   V1 binary the moment they land; the only containment left is "do not start
   V1 while doing this" (HANDOFF:13, "Never run two opencode sessions that
   write git against this one checkout"). Deleting the plugins first, on this
   tree, reproduces AUD-B1 through a different door.
2. **Deletion precedes the probes that justify the replacement.** Our spine is
   S0 -> S1.1 -> S6 (probes) -> S2 (deletions) (PLAN design D3:104-106),
   precisely because OMO 3.0.7 / Ponytail / envsitter compatibility and V2
   discovery behaviour are unproven. Gemini's phase 2 deletes the preset guard
   and envsitter before the compatibility probe exists.
3. **Smoke test last is backwards.** Its phase 4 is the first runtime proof, so
   every deletion in phase 2 is unverifiable until the end - and if the V2
   runtime fails, the deletions are already committed.
4. **Phase 1 duplicates a completed audit** (section 2, C13) and its "clean
   slate" would invalidate the register the plan is traceable to.
5. **It ignores the branch/version baseline.** The pending policies smoke test
   is developer-only and must run on 2.3.2 *before* any bump; a plan that
   starts with plugin deletion can easily precede it and destroy its baseline.

**Corrected order (minimum change to our existing spine).**

0. Developer runs the four-step policies smoke test in `poetry-dev-v2` on
   2.3.2 and records the result (HANDOFF:11,13). No code change.
1. Gate: `make test-config` exit 0 (already 78 pass at 43e3d2fd) plus the
   smoke-test record. **This is the gate that must pass before any deletion.**
2. Probes (our S6): OMO 3.0.7 + Ponytail + envsitter-guard 0.1.1 under V2,
   `cancel_task` / `wait_for_user` registration, V2 discovery behaviour for
   `plugins/lib/` and `__tests__/`, and V2 file-based tools support.
3. Deletions on the migration branch (our S2-S4): the D4 delete set only -
   preset guard and its three suites, capability, context_usage, tripwire, A1,
   adaptive routing, circuit breaker/paracrine, compaction snapshot, autocrine,
   pending detectors (the last with a documented replacement trigger).
4. Port the surviving core (our S9) and prove it on `dev-v2` (S10a) - this is
   the first point at which a 100-150 line plugin claim could be tested, and it
   will fail, because the port set is ~1580.
5. Only now compress `orchestrator_append.md`, the inline preset prompt, and
   (if approved) `AGENTS.md`, updating
   `scripts/check-orchestrator-prompt-drift.sh` MARKERS in the same commit.
6. Config conversion (our S7-S8), then cutover (S10b).
7. The 2.4.2 bump stays after the smoke test, and only on the dev-v2 side of
   the version plumbing (HANDOFF:13) - it is orthogonal to the teardown and
   must not be bundled with it.

---

## 7. Routing proposal critique

Actual active preset: `mimo-balanced` (`.opencode/oh-my-opencode-slim.jsonc:3`,
`:15`). Lane-by-lane comparison:

| Lane | Actual (file:line) | Gemini proposal | Verdict |
|---|---|---|---|
| orchestrator | deepseek-v4.1-flash + mimo-v2.6-flash fallback, variant high (`:17-21`) | deepseek-v4.1-flash | NO CHANGE (already true) |
| architector | gemini-4-argon + mimo-v2.6-flash fallback, variant high (`:35-39`) | gemini-4-argon | NO CHANGE (already true) |
| coder | deepseek-v4.1-flash + mimo-v2.6-flash fallback, variant high (`:70-74`) | mimo-v2.6-flash | CHANGE: demotes the implementer from the reasoning tier to the volume tier and drops the fallback |
| reviewer | kimi-k3.1-pro + qwen4-max fallback, variant high (`:89-93`) | deepseek-v4.1-flash | CHANGE: collides with coder/orchestrator family; the preset explicitly requires a different family from coder (`:275`, "intentionally different model family than coder for review diversity. Do NOT collapse same family") |
| ai-auditor | gemini-4-argon variant medium + longcat-2.5 + minimax-m3 fallbacks (`:151-155`) | deepseek-v4.1-flash | CHANGE: puts the independent config auditor on the same model as the orchestrator whose config it audits, drops both fallbacks, and removes the two-family independence property the preset comment calls out against ai-specialist (`:14`) |
| analyzer | deepseek-v4.1-flash + mimo-v2.6-flash fallback (`:101-105`) | mimo-v2.6-pro | CHANGE: collides with ai-specialist (`:141-144`, mimo-v2.6-pro), drops the fallback |
| openspec-plan | deepseek-v4.1-flash + mimo fallback (`:54-57`) | not mentioned | untouched |
| designer | deepseek-v4.1-flash + mimo fallback (`:114-117`) | not mentioned | untouched |
| researcher, conspecter, memory-manager, code-navigator | mimo-v2.6-flash (`:126`, `:164`, `:174`, `:182`) | not mentioned | untouched; three of these are already single-element arrays where a string change would be harmless |
| observer | qwen3.8-flash + kimi-k2.7-code (`:133-135`) | not mentioned | untouched |

**Mismatches that matter.**

1. **Five lanes named, two already correct.** The proposal reads as a diff when
   it is mostly a no-op; only coder, reviewer, ai-auditor and analyzer change.
2. **Array semantics.** Every multi-element `model` array is an ordered
   fallback chain. The campaign just repaired dead fallback IDs (HANDOFF:9;
   learnings 2026-11-25 "the routing diff reduced invalid IDs 6 -> 5"). Writing
   single strings removes failover for the four lanes it changes - i.e. the
   proposal re-introduces the failure class the campaign just fixed.
3. **Invariants broken, not just preferences.** Reviewer-vs-coder family
   diversity is written into the reviewer prompt
   (`oh-my-opencode-slim.jsonc:275`); ai-auditor-vs-ai-specialist family
   independence is recorded in `knowledge/model-registry.yaml` (referenced at
   `:14`). The proposal breaks the first by putting reviewer on the coder's
   former model and the second only partially (auditor->deepseek, specialist
   stays mimo), while creating a new and worse overlap: auditor on the
   orchestrator's model.
4. **One genuine upside it does not claim.** Moving ai-auditor off
   `gemini-4-argon` would remove a non-ZDR lane (`:14` records the waiver as
   pending re-confirmation). If privacy is the goal, say so - that is a better
   argument than routing.
5. **Reasoning-effort options are ignored.** architector and ai-auditor carry
   `options.reasoningEffort: high` and thinking blocks (`:46-51`); changing
   model without re-checking variant legality would silently drop the options
   (the 2026-11-25 gate found variant "high" is a free string but only a real
   rung on some models).

**Minimum correct routing change for this campaign:** none. The active preset
passes the live-catalog gate for the IDs it actually dispatches; only dead
fallback IDs were repaired. If a change is wanted, the defensible one is
ai-auditor -> a non-gemini, non-deepseek family (privacy wins, independence
held); everything else in C16 is churn.

---

## 8. Recommendation

**Verdict: ADOPT WITH MODIFICATIONS.** Do not adopt the teardown as a program.
Adopt its correct subset inside the existing audited spine, and reject the four
claims that delete policy gates under a line-count banner.

Reason, in one sentence: our plan already deletes ~3000+ lines for the same
reasons, but keeps a ~1580-line integrity core that V2 has no replacement for;
Gemini's version deletes that core too, and gets there by understating current
sizes 2-3x and overstating the plugin's share of the tree 2-6x.

**Five highest-value actions, ranked by risk removed per hour.**

1. **Close the baseline (developer, ~15 min, highest ratio).** Run the
   four-step policies smoke test in `poetry-dev-v2` on 2.3.2 and record the
   result; decide the `read:*.env*` / `secrets/*` floor extension. Everything
   else in either plan rests on this floor being real (HANDOFF:11-13).
   Risk removed: the whole dotenv floor is currently unverified behaviour.
2. **Reconcile `PLAN tasks.md` with reality (~1 hour).** Mark the completed
   container/pin/policies work, record that the branch is
   `migration/DIA-261112-exon` (not the `feature/...` name in task 0.1), and
   re-state the spine. Risk removed: any new phase plan (Gemini's or ours)
   will otherwise re-plan finished work and mis-order the pending smoke test.
3. **Execute the D4 delete set that both plans agree on, inside groups 3-5
   (~1-2 days).** Preset guard + 3 suites, capability, context_usage, tripwire,
   A1 advisory, adaptive routing, circuit breaker/paracrine, compaction
   snapshot, autocrine warn, pending detectors (with a named replacement
   trigger). Risk removed: ~3000-4000 lines of unmaintained surface with zero
   policy loss. Keep envsitter-guard 0.1.1 and the policies floor.
4. **Build the thin `tickets` tool that shells out to `scripts/tickets`
   (~half day).** `create` -> `scripts/tickets new`, `update` ->
   `scripts/tickets update`, `search`/`list` -> the existing subcommands;
   duplicate detection via `scripts/tickets search` plus the existing
   `keywordsCorrelate` logic, no second writer, no new schema fields. This is
   the part of Gemini's proposal that removes a real capability gap (the
   orchestrator cannot create tickets today). Risk removed: ticket creation is
   currently a bypass or a delegation, both audited as exceptions.
5. **Port the surviving core per ADR15 and compress prompts last (~1-2 weeks;
   the actual migration).** Journal, handoff, `log_decision`, ticket gate,
   envelope, routing gate, protected-path gate, `fetch-source`, stall sweep,
   watchdog. Only after the port is proven on `dev-v2` should
   `orchestrator_append.md` lose its mechanism-specific sections - and the
   inline preset prompt and `check-orchestrator-prompt-drift.sh` MARKERS must
   change in the same commit. Risk removed: the V1 -> V2 break itself.

**Policy-class items requiring developer disposition (do not apply silently):**

- Deleting or re-scoping the ticket gate (AGENTS section 2.3, DIA-063/DIA-217),
  including both bypass paths.
- Changing the reviewer diff source (ADR15 Layer 3; `reviewer.md` lane
  contract).
- Deleting the handoff slot/checksum contract (DIA-061/085/093/120/124).
- Deleting the research and conspect gates (DIA-057/058/260819-qibv) and the
  DIA-099 truncated-result protocol.
- Any agent-roster change, including "7 agents", deleting council, or deleting
  designer/observer/conspecter/ai-specialist.
- Any model-routing change (arrays, families, privacy waiver lanes).
- Deleting the second preset (it is gate-visible via
  `check-orchestrator-prompt-drift.sh:60`).
- Compressing `AGENTS.md` (it is the policy source gates cite).
- Deleting envsitter-guard (a protection the campaign restored 2 days ago and
  has not yet smoke-tested).

---

## 9. UNVERIFIED on my side

1. **Whether OMO 3.0.7 fixes the preset/session-model clobber** that
   `preset-model-guard.ts:13-24` exists for. Would settle: probe S6 extended to
   launch a divergent `--model` session on 3.0.7 with two presets and observe
   `session.created` / model resolution.
2. **Whether OMO 3.0.7 prompt-file precedence still matches REFERENCE-ONLY.md's
   contract.** Would settle: `opencode debug` of the resolved prompts, or a
   startup without override warnings with an inline prompt present.
3. **Whether V2 supports file-based `.opencode/tools/*.ts` with the new
   package import.** Would settle: a load probe in `dev-v2` with
   `@opencode/plugin` plus the tools docs page.
4. **`messages.jsonl` line count** (fact sheet gives registry as 32k+ via
   `scripts/lane-resume:7`, not messages). Would settle: `wc -l`.
5. **Which skills are actually dead.** Candidates with no `skills:` reference:
   `promo-review`, `git-permissions`, `openspec-explore`;
   `console-charting` is excluded by both orchestrator prompts. 22 `SKILL.md`
   files exist. Would settle: a per-skill cross-reference against both presets
   and every `.opencode/agents/*.md`, which no current gate performs.
6. **Whether task 1.4's checked state is the only task actually done, or
   `tasks.md` is simply unmaintained.** Campaign reality (HANDOFF) suggests the
   latter. Would settle: a commit-by-commit reconciliation of the branch against
   tasks 0-3.
7. **Whether two sessions ever overlap in one working directory in practice**
   (the strongest argument against a single `HANDOFF.md`). 97 slots and
   NEXT-RUN:316-324 imply it, but no measurement exists. Would settle: slot
   mtime/ownership analysis over `handoffs/`.
8. **Boot-time cost of the plugin surface.** No measurement in the repo. Would
   settle: instrument plugin load in `dev-v2` and compare a session with and
   without `delegation-observer` registered.
9. **`kimi-k3.1-pro` / `qwen4-max` rows in `knowledge/model-registry.yaml`**
   (learnings 2026-11-25 records them as absent). Would settle: read of the
   registry, which would also confirm whether the reviewer's fallback is
   dependency-legal.
10. **Whether the V2 TUI shows a per-session "waiting" indicator** that could
    replace ticker visibility. NAT:331 and NAT:457-458 both record this as
    unverified. Would settle: two sessions, one pending ask, inspect the session
    list.

---

## Appendix: five sentences that survive contact with the fact sheet

1. The plugin plus its tests is 41-45 percent of authored `.opencode` source
   (26665 of 58800 lines without CHANGELOG), not 90 percent.
2. `delegation-observer.ts` is 4248 lines, not ~1500 - almost 3x the claimed
   size, which is why "salvage 130 lines" reads cheaper than it is.
3. The ticket gate is ~600 lines and has no V2 native replacement (NAT:413-423,
   NAT:138-145); a 20-line replacement deletes two documented bypass paths and
   both bypass audit rows.
4. V2 has no permission timeout (NAT:316-331), so the ~30-40 line ask-timeout
   watchdog is the one thing in `needs-input-observer.ts` that must survive
   verbatim in spirit.
5. A single `HANDOFF.md` reintroduces the parallel-clobber failure DIA-085 slots
   were built to prevent; the checksum and lane-0 are the droppable half, not
   the slot model.
