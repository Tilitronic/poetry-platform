# DIA-261103-bxj0 - de-scope console-charting from agent skill lists; fix termatplotlib naming in the skill

---

id: DIA-261103-bxj0
title: "de-scope console-charting from agent skill lists; fix termatplotlib naming in the skill"
area: scripts
severity: Medium
status: FIXED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-11-03
source: inventory
date: 2026-11-03
created: 2026-11-03
updated: 2026-11-03

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [".opencode/oh-my-opencode-slim.jsonc", ".opencode/skills/mermaid-diagramming/SKILL.md", ".opencode/skills/console-charting/SKILL.md", "docs/dev-infra-audit/tickets/DIA-261103-bxj0-de-scope-console-charting-from-agent-skill-lists-fix-termatplotlib-naming-in-the-skill.md", "docs/dev-infra-audit/tickets/README.md"]
artifacts: []
evidence: ["make test-config exit 0 (2026-11-03): 78 PASS lines, no FAIL, ends 'validate-plugin-structure.sh: all structural gates PASS'", "grep -n '!console-charting' .opencode/oh-my-opencode-slim.jsonc: 2 matches (lines 26, 253) - one per preset orchestrator skills array", "grep -rn 'console-charting' .opencode/skills/mermaid-diagramming/SKILL.md: 0 matches (exit 1)", "python3 -c 'import termatplotlib' raises ModuleNotFoundError and 'pip show termatplotlib' reports not found (2026-11-03) - basis for the Optional marker"]

---

## Description

The console-charting skill's chart path is python -c (Rich tables, Plotext
charts, asciichartpy line charts). The deny-first bash map on the analyzer
lanes denies every python -c form (see .opencode/opencode.jsonc analyzer and
analyzer-escalated blocks), so the skill demanded a capability the lanes do
not have. Rather than grant an interpreter, the skill is de-scoped: removed
from the skills arrays of architector, analyzer and analyzer-escalated in
both presets, and negated for the orchestrator, whose wildcard include would
otherwise still load it. The skill directory and SKILL.md are retained on
disk for future reuse. The same change normalizes a three-way library-name
typo (termatplotlib / termtplotlib / termplotlib) and corrects the false
installed claim for that library.

Rationale correction (supersedes the commit message of 25012d89): the
interpreter argument applies to the two analyzer lanes only. Architector had
bash denied already and used the skill's no-interpreter text fallbacks, so
its removal is a deliberate simplification accepted by the developer, not a
permission fix.

## Decision-variants (DIA-261103-bxj0, recorded 2026-11-03)

Context: the deny-first bash map on the analyzer lanes (see
.opencode/opencode.jsonc analyzer and analyzer-escalated blocks) denies every
python -c form, so the console-charting skill's documented chart path cannot
run there. Skill-list precedent: console-charting was previously deleted as a
byte-exact duplicate in the 2026-08-06 skill cleanup
(openspec/changes/archive/2026-08-06-ai-self-improvement-auditor-and-cleanup/design.md),
recovered under DIA-090, and is de-scoped here without deleting the file.

### Variant A: bounded chart helper at one fixed path with a single narrow permission allow

Evidence: the ai-specialist gate recommended exactly this and specified the
helper's refusal set and invocation form. Rejected because it adds a new
script, a skill rewrite and a permission edit for a capability the lanes can
already deliver through markdown tables and Mermaid diagrams [INFERENCE]
(the sufficiency of tables and Mermaid as substitutes is a judgment, not a
measured comparison).

### Variant B: de-scope the skill and keep the deny-first map unchanged (CHOSEN)

Remove the skill from the architector, analyzer and analyzer-escalated skills
arrays in both presets, negate it for the orchestrator wildcard include, and
leave the deny-first map untouched; the skill directory and SKILL.md stay on
disk. Evidence: the openspec/ skill-cleanup design.md cited above shows this
exact skill has been curated out of loaded lists before and recovered later,
so retaining the file is the established pattern.

### Variant C: allow python -c

Evidence: restores the skill's documented invocations verbatim. Rejected
because that is arbitrary code execution and it inverts the intent of the
commit that introduced the deny-first map [INFERENCE] (the security
characterization is a judgment about the map's intent, not a reproduced
exploit).

### Variant D: abort, leave the contradiction in place

Rejected: it leaves a documented workflow that fails at runtime [INFERENCE]
(the failure follows from the deny rule matching every python -c form; no
runtime reproduction was performed).

Chosen: Variant B, because the demand disappears when the skill is not
loaded, no interpreter is granted, and the retained file keeps the option
open - the cheapest option that removes the runtime failure without
weakening the security property.

## Verification

- [x] grep for console-charting in .opencode/oh-my-opencode-slim.jsonc returns zero matches
- [x] both orchestrator skills arrays contain "!console-charting"
- [x] make test-config exits 0
- [x] .opencode/skills/console-charting/SKILL.md names termatplotlib consistently and marks it optional
- [x] .opencode/skills/mermaid-diagramming/SKILL.md contains no reference to console-charting

## Fix

- Commit 25012d89 "fix(config): de-scope console-charting from skill lists and
  fix termatplotlib naming (DIA-261103-bxj0)": removed the skill from the
  architector / analyzer / analyzer-escalated skills arrays in both presets
  and normalized the three-way library-name typo to termatplotlib.
- Follow-up commit (this change), subject "fix(config): stop console-charting
  loading everywhere and align its docs (DIA-261103-bxj0)": appends
  "!console-charting" to both orchestrator skills arrays so the wildcard
  include no longer loads the skill, drops the dead console-charting
  cross-reference from mermaid-diagramming/SKILL.md line 14, flips the
  termatplotlib row in the installed-status table to the Optional marker
  (python3 -c import and pip show both report it missing; Dockerfile.dev
  installs it nowhere), and fills this ticket body.

Rationale correction: the interpreter argument applies to the two analyzer
lanes; architector had bash denied already and used the skill's
no-interpreter text fallbacks, so its removal is a deliberate simplification
accepted by the developer, not a permission fix. This supersedes the
overbroad wording in the 25012d89 commit message ("no longer assigned to any
agent because its chart path requires an interpreter"), which was false as
stated: the orchestrator's wildcard include still loaded the skill until this
follow-up, and architector's removal was a simplification, not a permission
fix.

## Re-verify

Verified 2026-11-03 in the poetry-dev container, after all edits and before
the follow-up commit:

- `grep -n "console-charting" .opencode/oh-my-opencode-slim.jsonc` returns
  only the two negation lines (26 and 253): a plain substring grep also
  matches inside the literal "!console-charting". Zero positive (un-negated)
  assignments remain - `grep -n '"console-charting"'` finds no matches.
- `grep -n "!console-charting" .opencode/oh-my-opencode-slim.jsonc` returns
  exactly 2 matches, one per preset orchestrator skills array, with
  "!openspec-propose" kept ahead of it in both arrays.
- `grep -rn "console-charting" .opencode/skills/mermaid-diagramming/SKILL.md`
  returns no matches (exit 1).
- `make test-config` exits 0 (78 PASS lines, no FAIL, ends "validate-plugin-
  structure.sh: all structural gates PASS").
- `.opencode/skills/console-charting/SKILL.md` uses the termatplotlib
  spelling throughout (no termtplotlib / termplotlib variants remain) and
  the installed-status table marks it Optional with the install-command
  column untouched; `python3 -c "import termatplotlib"` raises
  ModuleNotFoundError and `pip show termatplotlib` reports not found, the
  basis for the Optional marker.
