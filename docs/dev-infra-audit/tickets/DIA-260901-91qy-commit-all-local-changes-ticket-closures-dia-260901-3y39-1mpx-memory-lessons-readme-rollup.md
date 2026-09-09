# DIA-260901-91qy - Commit all local changes - ticket closures DIA-260901-3y39/1mpx + memory lessons + README rollup

---

id: DIA-260901-91qy
title: "Commit all local changes - ticket closures DIA-260901-3y39/1mpx + memory lessons + README rollup"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-01
source: inventory
date: 2026-09-01
created: 2026-09-01
updated: 2026-09-01

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

Commit the current uncommitted local changes to the working tree.

Expected contents:

1. Ticket file `docs/dev-infra-audit/tickets/DIA-260901-3y39-architecture-check-of-commits-54e2dc16-head-architector-reviewer-audit.md` (CLOSED)
2. Ticket file `docs/dev-infra-audit/tickets/DIA-260901-1mpx-persist-architecture-check-findings-to-memory-dia-260901-3y39-follow-up.md` (CLOSED)
3. `docs/dev-infra-audit/tickets/README.md` rollup updates (severity/status counts + index rows for CLOSED tickets)
4. `.opencode/memory/lessons.md` entries L20260901-004 and L20260901-005 (from @memory-manager persistence)
5. Any other dirty paths in `git status` (include all uncommitted working-tree changes)

Gate: DIA-094 requires docker dev container running before commit; pre-commit hook must pass; NO --no-verify bypass.

Context: Follow-up to DIA-260901-3y39 and DIA-260901-1mpx closures. Commit is a ledger/memo artifact — do not touch code beyond what is already dirty.

## Verification

- [ ] `docker compose ps` shows dev container Up (DIA-094 gate)
- [ ] `git status` is clean after commit (all dirty paths committed)
- [ ] Commit message references DIA-260901-3y39 / DIA-260901-1mpx closures and memory lessons
- [ ] Pre-commit hook passes without --no-verify
- [ ] `git log --oneline -1` shows the commit on the current branch

## Fix

## UPDATE 2026-09-09 - revert + repack of snapshot 9c1d365 (retain/revert manifest, recorded BEFORE history rewrite)

Attribution: task_result on cod-12 ses_f79a1b58effesDYC0jXhsjnxkN was attempted and returned "does not belong to this session", so no verbatim lane content is available. The manifest below is the developer order as received in the dispatch payload.

Context: branch omo-slim-changes is unpushed, history rewrite is declared safe, no push will occur. Soft-reset target 7fa7aae (9c1d365 parent). 1180470 content is rebuilt on top byte-identical.

REVERT no-discussion (restore from 7fa7aae, drop from branch now):
(a) .opencode/opencode.jsonc untagged coder-escalated removal (Kimi K3 model + comment replaced by preset-owned text) - full file restore.
(b) slim untagged ai-auditor model swap (gpt-5.3-codex -> deepseek-v4-pro first fallback) - no conscious-permanent record exists - full file restore (every slim hunk is REVERT or HOLD, net parent state).

HOLD (revert from branch now, re-apply ONLY via separate 2.5 chains):

- slim tp5e preset flip (preset promo -> muse-qwen-balanced) + muse-qwen-balanced block.
- slim oj59 60/75 threshold hunks (opencode-go/cebula/promo/free prompts 15/25 -> 60/75).
- delegation-observer.ts threshold rename (threshold_15/25pct -> 60/75pct + description text).
- NEXT-RUN.md threshold text (15% -> 60%, 25% -> 75% + added handoff-vs-compaction note).
- drift scripts+bats: VERIFIED RED - new checker vs parent slim config FAILs (4 gaps, exit 1); parent checker vs parent config PASSes (3 presets, 0 gaps, exit 0). New scripts cannot live without new config, hold both.
- tp5e CHANGELOG.md entry + CHANGELOG.yaml tp5e entry + 737-line reformatting churn - CHANGELOG.yaml full restore to parent; CHANGELOG.md keeps ONLY the 6mhy line.

KEEP as thematic commits:

- o7n0 memory: .opencode/memory-shelf.yaml + .opencode/memory/lessons.md + .opencode/memory/failures.md.
- 6mhy 1-line Files fix in .opencode/CHANGELOG.md.
- tickets README.md rows for existing OPEN tickets (o7n0/oj59/tp5e rows + counts).

LEAVE AS-IS: 1180470 content (10 files, 1434 insertions) rebuilt on top byte-identical.

Repack: soft-reset to 7fa7aae, two thematic commits (DIA-260903-o7n0 memory / DIA-260901-91qy ledger), rebuild 1180470, prove no content loss via tree diff vs original tip (only intended REVERT/HOLD files may differ).

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## UPDATE 2026-09-09 - RED lane (test-author only): range ticket-status regression battery

Real field bug (blocked push): range mode resolves the campaign ticket in the
CURRENT disk ledger, so historical refactor commit f9ec224 (legitimate when
created - manifest campaign approved, DIA-260903-o7n0 OPEN then) now FAILS
--range because DIA-260903-o7n0 is CLOSED today. Correct rule under test:
range mode reads manifest AND ticket status from the evaluated commit tree
($EVAL_SHA); commit-msg mode keeps the current staged-tree + OPEN-today
requirement. GREEN instance implements the gate change; this lane only adds
the RED regression proof.

Added 2 tests to scripts/**tests**/budget-gate-range-exemption.bats (the
GREEN-owned range-behavior home; budget-gate.bats RED battery untouched):

1. "range ticket-status (DIA-260901-91qy): OPEN at the historical commit,
   CLOSED today -> range PASSES" - fixture history: ticket record flips to
   CLOSED in a commit AFTER the historical refactor commit H; --range over H
   alone must exit 0 (post-fix). Against current gate code it FAILS with
   exit 1 "Budget-Scope refactor has no approved backing campaign in
   manifest; failing closed (no backing)" (disk ledger CLOSED). RED proven.
2. "range ticket-status (DIA-260901-91qy): CLOSED already at the historical
   commit -> range FAILS" - ticket record is CLOSED in H's own tree, OPEN
   today; --range over H must exit 1 (post-fix). Against current gate code
   it PASSES with exit 0 "ok: scope refactor backed; prod 20/20 shell 10/10"
   (disk ledger OPEN). RED proven.

Fixture seam (deliberate deviation from the obs1 tests in the same file):
the ticket ledger lives INSIDE the fixture repo ($tree/tickets, TICKETS_DIR
pointed there) so each commit tree carries its own ticket status and
disk-today can differ from status-at-commit; the obs1 fixtures keep the
ledger outside the repo and cannot model per-commit status.

Verification (repo workdir, ASCII-only per DIA-079):

- budget-gate-range-exemption.bats: 2 pass / 2 fail, exit 1. Fail-set:
  exactly the two new tests above (RED proof; both RED for the expected
  direction: test 1 fails on a false block, test 2 fails on a false pass).
  Existing obs1 tests (1-2) unaffected: 2/2 pass.
- Commit-msg hook on the test commit: expected fast-path pass (no scoped
  plugin paths, no manifest edit touched); any hook block on backing would
  be reported verbatim, no --no-verify bypass.

Files: scripts/**tests**/budget-gate-range-exemption.bats, this ticket.

ASCII-only per DIA-079 (no em-dashes, no smart quotes, no non-ASCII punctuation).

## UPDATE 2026-09-09 - GREEN lane (implementer): range-mode ticket lookup from the evaluated tree

Implements the RED spec above (d15b36c): range mode resolves campaign-ticket
backing (has_backing) and exception records (try_exception) from the
EVALUATED COMMIT TREE at $EVAL_SHA, never from the current disk ledger.

Change (scripts/check-budget-gate.sh only; no .bats files touched):

- TICKETS_REL: repo-relative ledger path derived from TICKETS_DIR (same
  absolutize-then-prefix-strip pattern as MANIFEST_REL). Empty when the
  ledger lives outside the gated repo -> disk fallback in both modes
  (obs1 fixtures keep the ledger outside the repo and stay green).
- ticket_tree_first <id-prefix>: first sorted ticket path under TICKETS_REL
  in the $EVAL_SHA tree whose basename matches "<prefix>"\*.md (same sorted
  head -1 contract as the disk ls). Range-only.
- ticket_text <ticket-ref>: content indirection so the validation body stays
  mode-blind - tree_show at $EVAL_SHA in range mode with an in-repo ledger,
  plain cat otherwise (disk paths in hook mode and outside-repo ledgers).
- has_backing: range + in-repo ledger -> resolve via ticket_tree_first and
  require '^status: \*OPEN' in the tree record (authoritative, no disk
  fallback: CLOSED-at-commit cannot pass on today's OPEN). Hook mode and
  outside-repo ledgers keep the disk OPEN requirement unchanged.
- try_exception: same split for record resolution; all content checks
  (status, Exception-Reason/Delta/Paths/Applicability, applicability parsing
  incl. the range commit-sha check) now read through ticket_text, so range
  mode validates the record exactly as committed at $EVAL_SHA.
- obs5 comment rewritten to describe the mode split instead of the former
  blanket "disk never tree" asymmetry.

Semantics preserved: commit-msg hook mode is byte-for-byte the pre-fix disk
ledger path (staged manifest + OPEN-today on disk); obs1 pre-manifest
skip-with-warn unchanged; outside-repo ledger (TICKETS_REL empty) falls back
to disk in range mode, keeping hermetic obs1 fixture behavior.

Verification (inside poetry-dev container, exit codes captured):

- budget-gate-range-exemption.bats: 4/4 pass (exit 0) - obs1 tests 1-2 plus
  the two new RED-turned-GREEN ticket-status tests.
- budget-gate.bats full RED battery: 34/34 pass (exit 0), 0 not ok.
- make test-shell (bats-wrapper full suite): exit 0, 1..636 all ok.
- make test-config: exit 0 (validate-opencode-config + agent-names +
  output-contracts + reviewer-sections + decision-variants + grilling-gate +
  plugin-structure all PASS).
- bash -n scripts/check-budget-gate.sh: SYNTAX_OK.
- bats-wrapper.sh --quick (the lint-staged gate for staged \*.sh): exit 0.
- Pre-commit: run via git commit with hooks, no --no-verify (see below).

Commit-msg hook on this commit: fast-path (no scoped plugin paths staged),
expected pass; no --no-verify bypass anywhere.

Files: scripts/check-budget-gate.sh, this ticket.

ASCII-only per DIA-079 (no em-dashes, no smart quotes, no non-ASCII punctuation).

## UPDATE 2026-09-09 - GREEN completion lane (re-review fixes for 123d982): expiry-at-EVAL_SHA, out-of-repo fallback warn, comment accuracy, expiry regression test

Campaign ticket DIA-260901-91qy. GREEN-owned scope only:
scripts/check-budget-gate.sh + scripts/**tests**/budget-gate-range-exemption.bats + this ticket.
No .opencode config touched, no tp5e work, no budget-gate.bats edits.

Re-review of 123d982 (rev-4) verified F-01 closed but filed F-1/F-3/OBS-A/OBS-B/OBS-C.
This lane closes the re-review findings per developer direction:

F-1 [Major] try_exception expiry compares committed expiry date to wall-clock
TODAY even in range mode -> historical exception valid at commit time gets
retroactively blocked (same bug class, time axis). Fix: in range mode evaluate
expiry against the committer date of $EVAL_SHA (git log -1 --format=%ci
$EVAL_SHA, date portion), hook mode keeps today. Fallback to today if git log
fails or date malformed. Message now reports "before $eval_date" (commit date
in range, today in hook).

F-3 [Minor, auditor REJECT point] range mode with out-of-repo TICKETS_DIR
silently fell back to disk ledger (pre-fix bug live under that config, no
warn). Fix: range_mode emits one warn: line per run when TICKETS_REL empty:
"budget gate: TICKETS_DIR outside gated repo ($TICKETS_DIR); range mode
falling back to disk ledger (historical ticket status not per-commit; no warn
per commit)" - M1 precedent (explicit override is loud).

OBS-A: try_exception range branch had no regression test. Added ONE test to
the companion file (GREEN-owned range-behavior home):
"range exception expiry (F-01) and out-of-repo fallback warn (F-3): valid at
H, expired today -> range PASSES" - fixture commits a Budget-Exception trailer
whose exception record is valid+OPEN at historical commit H (expiry 2026-02-01
after H's committer date 2026-01-01) but expired today (2026-09-09) -> range
PASSES (hook would block). Plus assert F-3 warn fires on out-of-repo fallback
(mandatory warn: line per run when range mode takes disk fallback). 5/5 green.

F-2/OBS-B/OBS-C: ticket notes only (fail-closed existence drift accepted;
comment accuracy). Updated misleading comments to match actual behavior:

- 97-103 obs5 header: now states hook uses wall-clock today, range uses
  committer date, and range emits one-time fallback warn.
- 189-190 ticket_tree_first: was "same sorted head -1 contract as the disk ls",
  now "Mirrors the disk fallback (ls -1 ... | sort | head -1) in sorted head -1
  selection but sources from git ls-tree, so only in-repo ledgers apply."
- 508 try_exception missing-record message: was blanket "in $TICKETS_DIR",
  now mode-aware: tree $TICKETS_REL at $EVAL_SHA in range with in-repo ledger,
  else disk $TICKETS_DIR.

Changes:

- scripts/check-budget-gate.sh: expiry eval_date branch, range fallback warn,
  comment rewrites, TRY_EXCEPTION_LINE mode-aware.
- scripts/**tests**/budget-gate-range-exemption.bats: added 1 test (now 5/5).
- this ticket: this section.

Verification (inside poetry-dev container, ASCII-only per DIA-079):

- companion file green: 5/5 pass (exit 0) - obs1 2 + ticket-status 2 + expiry+F-3 1.
- budget battery 34/34 pass (exit 0) via bats-wrapper filtered budget-gate tests.
- make test-shell (bats-wrapper full suite): exit 0, 636 all ok (extended run 636).
- make test-config: exit 0 (validate-opencode-config + agent-names + output-contracts + reviewer-sections + decision-variants + grilling-gate + plugin-structure all PASS).
- bash -n scripts/check-budget-gate.sh: SYNTAX_OK (exit 0).
- bats-wrapper.sh --quick: exit 0.
- verify-pre-push guards: checked separately (see below).
- pre-commit: no --no-verify (hook passed on commit).

Files: scripts/check-budget-gate.sh, scripts/**tests**/budget-gate-range-exemption.bats, this ticket.

ASCII-only per DIA-079 (no em-dashes, no smart quotes, no non-ASCII punctuation).

## UPDATE 2026-09-09 - test split fix (DIA-175 same-session): compound F-01/F-3 case -> two isolated tests, added missing assert_status

Ponytail audit found compound test phase 2 missing assert_status caused false-pass risk; split into (A) F-01 expiry valid-at-H PASSES and (B) F-03 out-of-repo warn, each with own run + assert_status 0 + content asserts. Verified 6/6 pass, mutation checks fail-closed, make test-config 0, bash -n OK, no production code change.
