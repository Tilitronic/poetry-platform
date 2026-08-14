# DIA-134 - overnight destructive-command baseline + overnight.sh payload shape validation (DIA-126a ai-auditor suggestions S1/S2)

<!-- UPDATE 2026-08-14 (IMPLEMENTED - S1+S2; restart-verify PENDING; status
     stays OPEN - closure is a separate lane: ai-auditor Phase 6 review +
     developer disposition):
     Section-10 lane (DIA-134 S10-P4, branch omo-slim-changes) applied the
     developer-approved EBDV variant "Baseline A (data+git)".
     S1 - overnight destructive command baseline v1: .opencode/
     opencode-overnight.jsonc now opens with a documented, versioned comment
     block naming "overnight destructive command baseline v1 (DIA-134
     Baseline A, developer-approved 2026-08-14)" listing all 11 rules; the
     permission.bash map below applies all 11 as DENY (5 inherited
     interactive-profile rules + 6 data+git candidates: docker volume rm *,
     docker system prune *, docker system prune -af*, git reset --hard *,
     git clean -fd*, git push --force*). Interactive profile
     .opencode/opencode.jsonc NOT touched - overnight-only.
     S2 - payload shape validation in scripts/overnight.sh: after the JSONC
     tokenizer extraction and the existing non-null permission-block check, a
     node validation step asserts EVERY rule of the OVERNIGHT_DENY_BASELINE
     array (the 11 baseline v1 rules, defined in the script mirroring the
     profile) exists in the extracted payload's permission.bash map AND
     resolves to "deny" BEFORE exporting OPENCODE_PERMISSION and exec'ing
     opencode. Both drift shapes fail closed with a rule-specific error
     (missing key: 'overnight.sh: payload missing deny rule "<rule>" -
     refusing to launch'; softened value: 'overnight.sh: payload deny rule
     "<rule>" is "<value>" (not "deny") - refusing to launch') + exit 1,
     never exec opencode.
     Tests: scripts/__tests__/overnight.bats extended 8 -> 11 (S1
     all-11-deny payload assertion; S2 {} payload exits 1 + no launch; S2
     softened "ask" rule exits 1 naming the rule + no launch; existing
     fail-closed tests kept green).
     Validation: make test-config exit 0 (drift gate 8 markers x 3 presets
     0 gaps), make test-shell exit 0 (overnight.bats 11/11), bash -n
     scripts/overnight.sh clean, manual hermetic drift probes ({} and "ask"
     payloads exit 1 with the rule-specific error, full 11-rule payload
     exits 0 and launches). RESTART-VERIFY PENDING: next opencode launch
     should show all 11 rules resolving to deny via OPENCODE_PERMISSION
     (opencode debug config); deferred per DIA-123 second-boot pattern.
     No CHANGELOG entry added (closure-lane responsibility). -->

<!-- Filed 2026-08-13 by the S10-P6 registration lane for DIA-126 direction (a)
     Option A full. ai-auditor (ai--2) verdict CONFORMANT-WITH-NOTES carried two
     Suggestion-level findings; developer disposition (2026-08-13): DEFER both
     to this follow-up ticket - do NOT implement in the DIA-126(a) lane.

     S1: the overnight deny list is limited to the five rules inherited from
     the interactive profile (rm, rm -rf, rmdir, chmod, chown). Evaluate whether
     an "overnight destructive command baseline" should cover more irreversible
     host-impact commands (docker volume rm, docker system prune, etc.) and get
     developer approval for the final set.

     S2: scripts/overnight.sh validates only that a permission block EXISTS
     (non-null), not that it still carries the deny rules. A drifted payload
     (e.g. `{}` or a permission-less block) would silently un-harden the run. -->

---

id: DIA-134
title: "overnight destructive-command baseline + overnight.sh payload shape validation (DIA-126a ai-auditor suggestions S1/S2)"
area: opencode-config
severity: Low
status: OPEN
blocked_by: [] # no blockers; follows DIA-126 (OPEN)
discovered: 2026-08-13
source: ai-auditor-review
date: 2026-08-13
created: 2026-08-13
updated: 2026-08-14

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

DIA-126 direction (a) Option A full implemented the overnight hardening profile
`.opencode/opencode-overnight.jsonc` (five destructive bash rules flipped to
DENY for overnight runs only) and the fail-closed launcher
`scripts/overnight.sh`. The ai-auditor review (ai--2, CONFORMANT-WITH-NOTES)
raised two Suggestion-level gaps that the developer deferred to this follow-up:

**S1 - "overnight destructive command baseline" is underspecified.** The deny
list is a manual five-rule baseline inherited from the interactive profile
(`rm *`, `rm -rf *`, `rmdir *`, `chmod *`, `chown *`). It does not yet cover
irreversible host-impact commands that an autonomous overnight run could issue
with `--auto` auto-approving every ASK-level rule. Candidate additions to
evaluate (each needs a decision: deny now vs. accepted risk):

- `docker volume rm *` - permanently deletes named volumes (project data lives
  in the `poetry-postgres` volume; accidental removal destroys state).
- `docker system prune *` / `docker system prune -af*` - removes all unused
  containers/images/volumes/build cache, including possibly in-use volumes.
- Other irreversible candidates: `git reset --hard *`, `git clean -fd*`,
  `git push --force*` (partially covered by DIA-096/DIA-117),
  `find ... -delete`, `truncate`, `dd`, `mkfs.*`, `pvremove`/`vgremove`.

Work products: (1) define the authoritative "overnight destructive command
baseline" (a documented, versioned list in or next to
`.opencode/opencode-overnight.jsonc`); (2) get explicit developer approval for
the final set; (3) apply it to the overnight profile (and add bats tests).

**S2 - overnight.sh does not validate the payload SHAPE, only its existence.**
The launcher checks `PERMISSION_JSON` is non-empty and not `null` - it never
asserts that the payload still contains the expected deny keys and deny values.
If the profile ever drifts (e.g. a regenerated/edited
`opencode-overnight.jsonc` whose `permission` block is `{}`, or whose deny
rules were reverted to `ask`), the run launches "hardened" but is actually
un-hardened - the exact failure the fail-closed design must prevent.

Work products: (1) extend the launcher's validation to assert the required
keys exist AND resolve to `deny` (e.g. every entry of the baseline map
`permission.bash.<pattern>` == `"deny"`) before exporting
`OPENCODE_PERMISSION` and exec'ing opencode; (2) fail closed with a specific
error naming the missing/softened rule; (3) add bats tests for a `{}` payload
and a softened (`"ask"`) payload - both must exit 1 and never launch.

## Verification

Current state (before fix):

1. `bash -n scripts/overnight.sh` clean; `make test-shell` exit 0 (overnight.bats
   8 tests, incl. the fail-closed tests added by the S10-P6 registration lane).
2. S1 gap probe: grep the overnight profile for deny rules - only the five
   interactive-profile rules are present; `docker volume rm *` / `docker system
prune *` are NOT denied (and would be auto-approved under `--auto`).
3. S2 gap probe: with a profile whose `permission.bash` is `{}` (or whose rules
   say `"ask"`), `scripts/overnight.sh` currently exits 0 and launches - prove
   the drift is silently accepted.

After fix:

1. `opencode debug config` (via `OPENCODE_PERMISSION` from the launcher) shows
   the full baseline resolving to deny.
2. `{}` / softened payloads exit 1 with a rule-specific error, no launch.
3. New bats tests pass; `make test-shell` exit 0.

## Fix

Implemented 2026-08-14 (DIA-134 S10-P4 section-10 lane, branch
omo-slim-changes; EBDV variant "Baseline A (data+git)" as developer-approved).

### S1 - overnight destructive command baseline v1 (Baseline A, data+git)

Authoritative baseline: a documented, versioned comment block at the TOP of
`.opencode/opencode-overnight.jsonc` naming "overnight destructive command
baseline v1 (DIA-134 Baseline A, developer-approved 2026-08-14)" and listing
all 11 rules (before the DIA-126 header comment). The same 11 rules are
mirrored 1:1 in (a) the `permission.bash` map below the comment and (b) the
`OVERNIGHT_DENY_BASELINE` array in scripts/overnight.sh - the three sources
diff line-by-line, and the launcher enforces the baseline mechanically.

Baseline v1 - 11 rules, all DENY in the overnight permission block:

1. `rm *`
2. `rm -rf *`
3. `rmdir *`
4. `chmod *`
5. `chown *`
6. `docker volume rm *`
7. `docker system prune *`
8. `docker system prune -af*`
9. `git reset --hard *`
10. `git clean -fd*`
11. `git push --force*`

Applied as DENY in `.opencode/opencode-overnight.jsonc` `permission.bash`
(rules 1-5 are the inherited interactive-profile rules flipped ask -> deny;
rules 6-11 are the data+git additions - docker volume rm / docker system
prune destroy project data, git reset --hard / git clean -fd / git push
--force destroy work). The interactive profile `.opencode/opencode.jsonc`
was NOT changed - overnight-only hardening. git rules 9-11 are already DENY
interactively; re-asserting them keeps the overnight payload self-contained.

### S2 - payload shape validation in scripts/overnight.sh

Mechanism: after the existing JSONC tokenizer extraction and the non-null
permission-block check, a node validation step asserts EVERY rule of the
`OVERNIGHT_DENY_BASELINE` array (the 11 baseline v1 rules, defined in the
script as the expected contract mirroring the profile) exists in the
extracted payload's `permission.bash` map AND resolves to "deny". Only a
fully-hardened payload reaches `export OPENCODE_PERMISSION` and the opencode
exec. A profile edit that removes or softens a deny rule is caught: the
payload no longer matches the array.

Error format (both drift shapes fail closed - exit 1, never exec opencode):

- missing key: `overnight.sh: payload missing deny rule "<rule>" - refusing
to launch` (e.g. a `{}` payload names the first baseline rule `rm *`)
- softened value: `overnight.sh: payload deny rule "<rule>" is "<value>"
(not "deny") - refusing to launch`
- a generic context line follows both: `error: overnight permission payload
failed DIA-134 baseline v1 shape validation; refusing to launch opencode`

### Tests

`scripts/__tests__/overnight.bats` extended 8 -> 11 tests:

- `overnight: DIA-134 S1 - all 11 baseline v1 deny rules resolve to deny in
the exported payload`
- `overnight: DIA-134 S2 - empty permission.bash payload ({}) exits 1 and
never launches`
- `overnight: DIA-134 S2 - softened deny rule (ask) exits 1 naming the rule
and never launches`

Existing 8 tests kept green, including all fail-closed tests; the TUI-mode
payload assertion was updated to the 11-rule map.

### Verification (2026-08-14)

- `make test-config` exit 0 (drift gate 8 markers x 3 presets 0 gaps)
- `make test-shell` exit 0 (overnight.bats 11/11)
- `bash -n scripts/overnight.sh` clean
- Manual hermetic drift probes (fake opencode on PATH): `{}` payload and
  softened (`ask`) payload both exit 1 with the rule-specific error and no
  launch; the full 11-rule payload exits 0 and launches.
- RESTART-VERIFY PENDING: next opencode launch - `opencode debug config`
  (or a probe run via OPENCODE_PERMISSION) should show all 11 rules
  resolving to deny in the merged permission (DIA-123 second-boot pattern).

## Re-verify

> To be filled at re-verify time.
