# DIA-260826-ex7w - permanent skills-array reference validator for oh-my-opencode-slim presets

---

id: DIA-260826-ex7w
title: "permanent skills-array reference validator for oh-my-opencode-slim presets"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260821-bqy7
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-26
source: inventory
date: 2026-08-26
created: 2026-08-26
updated: 2026-08-26

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

Add a permanent validator that checks every skills-array entry in
`.opencode/oh-my-opencode-slim.jsonc` presets resolves to a real skill.

## Problem

- No gate validates preset skills arrays in the presets-to-skill direction.
  `make test-skills` runs `.opencode/scripts/validate-skills.sh`, whose
  documented checks (header, lines 9-60) cover SKILL.md frontmatter plus the
  reverse direction only (`presets:` declarations inside a skill file
  resolving to a preset name). Nothing parses the `skills:` arrays inside the
  presets to confirm each entry names a real skill; no
  `scripts/validate-*skills-array*` exists (`ls scripts/validate-*.sh`).
- Dangling refs have shipped silently before:
  `.opencode/learnings/external-patterns/2026-08-28-dia183-ponytail-active-simplify-refs-dangling.md:1`
  records "19 dangling 'simplify' skill refs exist across all presets
  (cosmetic debt, already silently ignored)" while `make test-config` passed.
- The check is therefore done ad hoc by hand each time, e.g.
  DIA-261103-bxj0 used one-off greps to de-scope `console-charting` from two
  orchestrator arrays, with no reusable gate left behind.

## Verification

- [ ] Adding `"__no_such_skill__"` to any preset skills array makes the
      validator exit 1 naming the preset and entry (red test first)
- [ ] `make test-config` (or `make test-skills`) runs the new check and exits 0
      on the current clean tree
- [ ] The check is wired into a Makefile target so it cannot be skipped

## Fix

Extend `.opencode/scripts/validate-skills.sh` (preferred: one validator, one
entry point) or add `scripts/validate-skills-arrays.sh` wired into
`Makefile:257` `test-config`, asserting every non-negated entry of every
preset `skills` array resolves against `.opencode/skills/*/`, the OMO bundled
skill set, and builtin skill names; `"!name"` negations are exempt. Include a
bats fixture with one intentionally dangling entry. Touch:
`.opencode/scripts/validate-skills.sh` (or new script), `Makefile`, one bats
file under `scripts/**tests**/`.

## Re-verify

```bash
bash .opencode/scripts/validate-skills.sh    # exit 0 on clean tree
# red proof: add "bogus-skill-name" to one preset array, re-run -> exit 1
# naming the preset and entry, then revert
grep -n "validate-skills" Makefile            # target wired into test-config
make test-config                              # exit 0
```

## References

- `.opencode/scripts/validate-skills.sh:1-60` (current scope: frontmatter + skill-to-preset COMPAT classes)
- `Makefile:224-229` (`test-skills`), `Makefile:257` (`test-config` prerequisites)
- `.opencode/learnings/external-patterns/2026-08-28-dia183-ponytail-active-simplify-refs-dangling.md:1` (historical silent dangling refs)
