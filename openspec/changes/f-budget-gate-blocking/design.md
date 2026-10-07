# Design: F budget gate - report-only to blocking

## Context

See proposal.md (Why) for motivation. Current state constraining the approach:

- The F budgets exist only as numbers in the ticket record and the audit
  report (`knowledge/ana-260903-qh9y-plugin-test-debloat-audit/...report.md`
  section 7): A prod net LOC <= 0 vs 5900 (4037 shell + 1863 lib), B no
  test-scaffold duplication (515 LOC baseline, >=3 files fails), C shell LOC
  monotonic vs 4037. Measurement commands are pinned verbatim there
  (`wc -l` on `delegation-observer.ts` + `lib/*.ts`; literal grep for the
  opencode-mock scaffold).
- No gate script exists; nothing distinguishes refactor from feature work.
- Hook surface found by context scan: husky hooks are tracked files pairing
  `.husky/pre-commit` + `.husky/pre-push` with `scripts/verify-pre-commit.sh`
  / `scripts/verify-pre-push.sh`; both source `scripts/guards/home-qualt.sh`
  (host-side guard, sourced not executed); `scripts/worktrees.sh` (~line 299)
  copies `.husky/*` into fresh worktrees or gates silently stop applying.
- Gate-validation precedents: `make test-config` hosts tree-state validate-\*
  gates with env-var fixture overrides (`SLIM_JSONC`, `TICKETS_DIR`);
  `scripts/__tests__/post-push.bats` is the hermetic fixture-repo + hook-copy
  test pattern; jq is an existing `make test-shell` prerequisite.

## Approach

Approach follows `.sdd/opencode-config/architecture.md` (module surface:
OpenCode config, plugins, presets; no new module boundary is created here,
only enforcement over the existing `delegation-observer` plugin tree) and
`.sdd/dev-infra/architecture.md` gate conventions (tracked scripts, Makefile
wiring, bidirectional verification). This design makes no system architecture
decision: it wires an existing committed decision (the ticket's F budget +
promotion approval) into the commit flow.

### Gate invocation and resolution order

Single script, `scripts/check-budget-gate.sh`, two invocation modes:

1. `check-budget-gate.sh <message-file>` (called from `.husky/commit-msg`;
   `$1` is the message file git passes to commit-msg hooks).
2. `check-budget-gate.sh --range <rev-spec>` (called from the pre-push chain;
   one evaluation per commit in the range, always blocking).

Hook-mode resolution order (`specs/commit-budget-gate/spec.md` behaviors):

1. Fast path: staged file list (`git diff --cached --name-only -z`) contains
   no scoped path -> exit 0 without reading the manifest.
2. Parse `Budget-Scope:` / `Budget-Exception:` trailers from the message
   file (strict ASCII `Key: value` lines; last occurrence wins).
3. Load `scripts/budget-baselines.json` with jq. Load failure (missing,
   invalid JSON, schema violation) blocks any commit that reached step 2
   with scope and any commit touching scoped paths (fail closed); the fast
   path never reads the manifest.
4. Resolve scope: absent trailer = feature (A/C skipped, B still evaluated);
   `refactor`/`test-debloat` requires a matching approved campaign entry in
   the manifest, else fail closed.
5. Measure A/C from the staged tree via per-file `git show :<path> | wc -l`
   over the scoped production set; measure B by normalize-then-match over
   the staged tree for scoped test paths.
6. If any budget fails, check `Budget-Exception: DIA-NNN` only after scope
   and manifest have resolved (no rescue); validate the ticket record;
   valid applicability turns block into exit 0 with an exception report
   line.
7. `BUDGET_GATE_MODE=report` (hook mode only): never blocks; prints every
   measurement, every violation, plus the explicit kill-switch warning.

Scoped path sets (from the audit measurement commands):

- Production set: `.opencode/plugins/delegation-observer.ts` +
  `.opencode/plugins/lib/*.ts`.
- Shell set (budget C): `.opencode/plugins/delegation-observer.ts` alone.
- Scoped test paths: `.opencode/plugins/__tests__/**/*.mjs`
  (includes `harness-scenarios/`).

### Baseline manifest (`scripts/budget-baselines.json`)

jq-parsed; single authority for all numbers. Shape:

```json
{
  "prod_ceiling": 5900,
  "shell_ceiling": 4037,
  "patterns": [
    {
      "id": "opencode-mock",
      "canonical": "mock.module(\"@opencode-ai/plugin\",",
      "baseline_count": 1,
      "authorized_site": "plugin-harness.mjs"
    }
  ],
  "campaigns": [{ "ticket": "DIA-260903-o7n0", "scope": "refactor", "status": "approved" }],
  "mode": "blocking"
}
```

Seed values: ceilings stay 5900/4037 (net <= 0 vs baseline, not vs current
5814); per-pattern baseline counts are re-measured from the post-D4 tree at
manifest authoring time (the D4 helper work already collapsed the 515 LOC
baseline); each entry is ticket-bound back to DIA-260903-o7n0. The manifest
init commit carries the normal pure-refactor trailer + matching ticket (Q3
3b-i), and manifest-edit commits are checked against the manifest content as
staged in that same commit.

### Duplication detector (budget B)

Per staged test file: `git show :<path>` -> strip all whitespace
(`tr -d '[:space:]'`) -> fold every quote byte (`'`, `"`, backtick) to one
marker -> `grep -F` the identically normalized canonical literal from each
approved pattern. The authorized site's own occurrence never counts.
Violation = matched-file count strictly above the pattern's `baseline_count`.
No regex, no similarity scoring anywhere in this path.

```bash
# ponytail: literal match only; string-concat splitting ("@opencode-ai" +
# "/plugin") and identifier renaming evade this detector. Upgrade path: AST
# call-shape match. Trigger: an observed real bypass, not a hypothetical one.
```

### Exception ticket record (machine-checkable)

`Budget-Exception: DIA-NNN` resolves the ticket by filename prefix
(`docs/dev-infra-audit/tickets/DIA-<id>*.md`, both sequential and datetime ID
formats) and requires frontmatter `status: OPEN` plus all four literal lines
in the ticket body (exact ASCII prefixes):

```text
Exception-Reason: <free text, one line>
Exception-Delta: <budget letter and LOC, e.g. "A +120">
Exception-Paths: <space-separated scoped paths>
Exception-Applicability: commit <sha-prefix> | expiry <YYYY-MM-DD>
```

Applicability `commit` covers the single commit; `expiry` covers commits until
the date (inclusive). Any missing line = malformed record = block.

## Sequence: commit-msg evaluation

```mermaid
sequenceDiagram
    participant H as .husky/commit-msg
    participant G as check-budget-gate.sh
    participant S as staged tree (git show)
    participant M as budget-baselines.json
    participant T as ticket ledger
    H->>G: message file path ($1)
    G->>G: list staged paths; no scoped path? exit 0
    G->>G: parse Budget-Scope / Budget-Exception trailers
    G->>M: load + schema-check (jq); fail = block
    G->>M: refactor/test-debloat? require campaign entry; none = block
    G->>S: wc -l production + shell sets (A/C); normalize+match test set (B)
    alt budget fail
        G->>T: exception trailer + scope + manifest resolved? validate record
        alt record complete and applicable
            G-->>H: exit 0 (exception noted)
        else
            G-->>H: exit 1 (FAIL lines to stderr)
        end
    else budgets pass
        G-->>H: exit 0 (ok line to stdout)
    end
```

## Decisions

- **commit-msg hook, not pre-commit** (developer ruling Q4a, interview): only
  the commit-msg hook receives the message file; pre-commit cannot see
  trailers. Pre-commit and `make test-config` stay untouched. Alternative
  (pre-commit with a guessed message) rejected: it cannot exist yet.
- **Staged measurement via `git show :<path>`** (Q4b): measures exactly what
  becomes history. Alternative (working tree `wc -l`) rejected: a dirty tree
  both falsely blocks and falsely passes; the scoped set is small and fixed,
  so per-file `git show` is cheap.
- **Manifest in JSON parsed with jq** (Q6a): jq is already a test-shell
  prerequisite; Python/YAML would drag a second runtime into a commit hook.
- **Unconditional B / scope-gated A+C** (Q2 Reading 2): copying a scaffold
  into new test files is scope-independent damage; production-LOC growth is
  the feature-blocking risk the approval constrains.
- **Exception never rescues scope/manifest state** (Q3): one bypass-shaped
  trailer covering two failure classes would silently redefine what the
  ticket approved.
- **Range mode always blocking, switch-ignoring** (Q6c): `git commit
--no-verify` skips hooks entirely; the pushed-range re-check closes that
  hole at push time.

## Goals / Non-Goals

Goals: one script + one manifest + one hook enforcing the transcript's
contract with bidirectional test proof and a bounded rollback path.
Non-Goals: AST or similarity-based detection; scope auto-classification;
touching the plugin code under audit; new dependencies; changing any
existing gate, ticket schema, or ledger tooling.

## Seams

Pre-agreed public boundaries where the bats suite lives (proposed; the
implementing lane confirms with the developer before writing tests):

1. **commit-msg hook seam** (.husky/commit-msg + message file + staged
   tree): trailer-existence variants, fail-closed verdicts, warning output.
2. **Gate CLI seam** (`check-budget-gate.sh <msg>` and `--range <revs>`):
   exit codes, `ok:`/`FAIL:`/`warn:` stream contract, range verdicts.
3. **Manifest seam** (`scripts/budget-baselines.json` + `BUDGET_MANIFEST`
   override): seeded ceilings/counts, malformed-manifest fail-closed.
4. **Ticket-ledger seam** (`docs/dev-infra-audit/tickets/` +
   `TICKETS_DIR` override): ticket resolution, approval-record field checks,
   applicability handling.

## Test strategy

`scripts/__tests__/budget-gate.bats`, auto-discovered by `make test-shell`,
hermetic fixture repo per `post-push.bats` (init repo under
`$BATS_TEST_TMPDIR`, copy gate + hooks in, drive real commits through the
commit-msg hook) with env overrides `BUDGET_MANIFEST`, `TICKETS_DIR`, and a
plugin-root override so fixtures stay small. Coverage maps 1:1 to
`specs/commit-budget-gate/spec.md` scenarios:

- Mandated battery: (a) manifest-backed refactor + LOC growth -> block;
  (b) feature growth -> exit 0 + report; (c) complete exception record ->
  exit 0 + exception line; (d) re-indented/quote-flipped/line-split duplicate
  -> counted + blocked.
- Fail-closed edges: trailer without backing; malformed manifest;
  exception without scope; exception record missing any field; expiry past.
- Boundary edges: counts exactly at baseline pass; untouched-path commit
  exits 0 without manifest reads; unstaged drift ignored.
- Kill-switch: `BUDGET_GATE_MODE=report` allows + warns; `--range` mode
  ignores it.
- Wiring assertions (precedent: check-orchestrator-prompt-drift.bats):
  `.husky/commit-msg` invokes the gate; `verify-pre-push.sh` invokes range
  mode; `scripts/worktrees.sh` copy list includes commit-msg.
- Every sub-gate proven both directions (injected FAIL + real PASS) per the
  ticket's R-B acceptance; full run via `make test-shell`.

## Migration plan and rollback

Rollout (dev-infra rule: spec, implement, test gate, review, persist):

1. Land order in one change: manifest + gate script + bats proof, then the
   `.husky/commit-msg` wiring + `verify-pre-push.sh` range line +
   `worktrees.sh` copy-list addition. The wired hook is the only behavior
   change; everything before it is inert.
2. Seed the manifest from the post-D4 measured tree; manifest init commit
   carries the normal refactor trailer + DIA-260903-o7n0 reference (never
   Budget-Exception as bootstrap).
3. `make test-shell` + `make test-config` green, reviewer pass, then push
   (the pre-push range line defends `--no-verify` from day one).

Blast radius (`.husky/` + worktrees): new tracked `.husky/commit-msg` must
source `scripts/guards/home-qualt.sh` like the sibling hooks and must be
added to the `scripts/worktrees.sh` hook-copy list, or fresh worktrees
silently lose the gate (the DIA-094 bypass class). Reverted state: hook file
plus two one-line wirings.

Rollback:

1. Emergency (instant, machine-local): `BUDGET_GATE_MODE=report` - measures
   and warns, never blocks; cannot switch the gate off; pre-push/CI ignore it.
2. Persistent downgrade: manifest `mode` edit through the normal ticket flow.
3. Full removal: revert the wiring commit (hook file + pre-push line); gate
   script and manifest are inert without callers.

## Risks / Trade-offs

- [Risk] Trauma of partial staging: `git show` per path measures the index,
  which is exactly what commits - documented as the fix, not the risk. ->
  Behavior covered by the unstaged-drift scenario.
- [Risk] Trailers are human-attested; scope can be lied about (refactor work
  committed trailer-less evades A/C). -> Accepted asymmetry: the gate fails
  safe toward NOT blocking features; B still catches test-side copying;
  dishonest scope is a review matter, same as the ticket-gate today.
- [Risk] Strict approval-record syntax rejects a substantively approved but
  misformatted ticket. -> Deliberate: exact ASCII prefixes are cheaper to
  fix than an ambiguous approval is to audit; failure message names the
  missing line.
- [Risk] Hook does not run where hooks are absent (fresh worktrees before
  this change, `--no-verify`). -> worktrees.sh copy-list addition +
  pre-push range mode as the backstop.
- [Risk] Literal detector ceiling (concat-split, renaming). -> Documented
  `ponytail:` ceiling in the script; AST upgrade only on observed bypass.

## Open Questions

None - all spec-shaping decisions were resolved in the interview transcript
(Q1-Q6); the two surviving elaborations (manifest seed values measured at
authoring time; exact record line prefixes above) are design detail that does
not change any spec requirement.
