# DIA-260918-mm2u - retire or repoint promo-preset-apply stale promo target plus overcapture

---

id: DIA-260918-mm2u
title: "retire or repoint promo-preset-apply stale promo target plus overcapture"
area: scripts
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-18
source: inventory
date: 2026-09-18
created: 2026-09-18
updated: 2026-09-29

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

- commit 0123f4c5 (git merge-base --is-ancestor 0123f4c5 HEAD = yes)
- scripts/promo-preset-apply:12,16-17,44-46 (retire decision + no-op, no file IO)
- python3 scripts/promo-preset-apply --dry-run/--config/--registry/--help all exit 0
- scripts/**tests**/workspace-preset-selection.bats:29-34 and preset-single-path.bats:40-45 reject free and promo-union-alpha
- make test-config exit 0 at HEAD 8944c0c5 (in-container)
- make test-shell exit 0, 724 ok / 0 not-ok at HEAD 8944c0c5 (in-container)

---

## Description

scripts/promo-preset-apply still targets a `promo` key that no longer exists:
find_preset_block(text, "promo") at line 113 misses, so a run would take the
insert path and INSERT a fresh `promo` block before `free` (line 215 anchor),
resurrecting the removed preset. Worse, find_promo_region lines 121-139 walks
upward over the contiguous hand-written comment stack, so a second run would
delete the hand-written promo provenance comments (s95f Fix block). Retargeting
lines 113/173 to `muse-balanced` is UNSAFE (the generator would overwrite the
live active preset block). Decision needed: retire the generator vs repoint it
to a live target, then fix the overcapture. DO NOT run the script until fixed.

## Verification

- [ ] retire-vs-repoint decision recorded (retire generator or repoint to a live target)
- [ ] do-not-run guard holds until the overcapture fix lands (no script runs in the meantime)
- [ ] make test-config exit 0 after the fix

## Fix

> To be filled at fix time.

## Re-verify

Substantively resolved by the retirement of the promo-preset-apply transform cascade in commit 0123f4c5: the stale literal promo target and its overcapture are gone, the generator is now an explicit no-op reporter that exits 0 for every historical flag, and the removed presets are positively rejected by the strengthened fixture tests. make test-config exit 0 and make test-shell exit 0 in-container (724/724, 0 failures) at HEAD 8944c0c5.

Criterion-by-criterion re-verify (2026-09-29, container poetry-dev, HEAD 8944c0c5):

- retire-vs-repoint decision recorded: MET - scripts/promo-preset-apply:12 "The developer chose to RETIRE rather than repair the anchor on 2026-09-29"; landed in 0123f4c5 (`git merge-base --is-ancestor 0123f4c5 HEAD` = yes).
- do-not-run guard held until the fix landed: MET - no invoker of scripts/promo-preset-apply exists in Makefile, .github, .husky or scripts/\*.sh (grep: no matches outside docs/knowledge/.scratch prose); and the script performs no file IO at all (scripts/promo-preset-apply:16-17, :44-46), so even a stray run mutates nothing.
- make test-config exit 0 after the fix: MET - `make test-config` exit 0 in-container at HEAD 8944c0c5.
- stale literal promo target / overcapture gone: MET - grep for find_preset_block, find_promo_region, ROUTING table and the `free` anchor in scripts/promo-preset-apply matches only the retirement prose at lines 7-11; no transform cascade, no write path remains.
- exits 0 for every historical flag: MET - `python3 scripts/promo-preset-apply --dry-run` -> 0; `--dry-run --config X --registry Y` -> 0; `--help` -> 0; unknown flags still exit 2 via argparse. Mode stays 100644 as before 0123f4c5, so no invocation-mode regression.
- removed presets positively rejected: MET - scripts/**tests**/workspace-preset-selection.bats:29-34 asserts 'Unknown preset "free"' and 'Unknown preset "promo-union-alpha"'; scripts/**tests**/preset-single-path.bats:40-45 asserts the same two names; both green inside make test-shell (724 ok, 0 not-ok).
- make test-shell: MET - exit 0, 724 ok / 0 not-ok (log: .scratch/test-shell.log, "1..724" at line 22).
