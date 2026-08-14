# DIA-134 - overnight destructive-command baseline + overnight.sh payload shape validation (DIA-126a ai-auditor suggestions S1/S2)

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
updated: 2026-08-13

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

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
