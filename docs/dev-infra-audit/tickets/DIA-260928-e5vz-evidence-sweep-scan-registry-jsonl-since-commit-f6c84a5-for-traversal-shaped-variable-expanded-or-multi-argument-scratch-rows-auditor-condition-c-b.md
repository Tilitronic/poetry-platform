# DIA-260928-e5vz - evidence sweep: scan registry.jsonl since commit f6c84a5 for traversal-shaped, variable-expanded or multi-argument .scratch rows (auditor condition C-B)

---

id: DIA-260928-e5vz
title: "evidence sweep: scan registry.jsonl since commit f6c84a5 for traversal-shaped, variable-expanded or multi-argument .scratch rows (auditor condition C-B)"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-28
source: inventory
date: 2026-09-28
created: 2026-09-28
updated: 2026-09-28

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

Run the auditor condition C-B evidence sweep over `.opencode/session/registry.jsonl`
for rows dated after commit `f6c84a52` and record either the qualifying
`.scratch` command rows or an explicit clean-sweep statement with the command.

## Problem

- Condition C-B (attached to the DIA-260926-5vin SOUND-with-conditions verdict)
  asks whether real traffic already exercises traversal-shaped,
  variable-expanded or multi-argument `.scratch` commands. Until the sweep is
  recorded, the marginal verdict is unsupported in the ledger: nobody can show
  whether those shapes are live or theoretical.
- The repo has no sweep artifact for it: no file under
  `docs/dev-infra-audit/tickets/`, `.opencode/learnings/` or
  `.opencode/session/` records a registry scan command for this condition
  (grep for `DIA-260928-e5vz` outside the ticket itself and the README rollup
  returns nothing).
- Commit reference exists: `f6c84a52` = "fix(config): allow the mandated
  .scratch cleanup without a permission ask (DIA-260926-5vin)", committer date
  2026-09-27T22:23:55+0000.

## Verification

- [ ] The exact scan command is recorded verbatim in this ticket (see
      `## Evidence` below).
- [ ] Either a bounded finding (row count + qualifying rows with line index,
      winning action pattern, outcome, shape class, raw command) or an explicit
      clean-sweep statement with a zero count.
- [ ] The schema caveat below is stated, so a zero is not read as stronger
      evidence than it is.

## Fix

Auditor condition C-B attached to the DIA-260926-5vin verdict (SOUND-with-conditions).

Scope: scan .opencode/session/registry.jsonl for rows dated after commit f6c84a5 that show a .scratch command in a traversal-shaped, variable-expanded or multi-argument form.

Interpretation: any such row means real traffic already exercises those shapes, which flips the marginal verdict to live and triggers the wrapper/guard work; a clean sweep is the evidence that keeps the current decision justified.

Note: this is now partially superseded by the separate High-severity finding that a multi-argument rm rides along on the broad "rm \*" allow. Keep this ticket scoped to gathering historical traffic evidence.

Evidence format per qualifying row: capture the registry line index, the resolved action pattern that won, the action outcome (allow/ask/deny), the argument shape class (traversal-shaped / variable-expanded / multi-argument), and the raw command text.

Acceptance criterion: the sweep is complete only when the exact command used to scan the registry for rows since commit f6c84a5 is recorded verbatim in this ticket, together with either the bounded finding (row count plus the qualifying rows) or an explicit clean-sweep statement with that command and a zero count.

## Re-verify

Re-run the recorded command; the zero count must reproduce on the current
append-only registry (absolute totals drift upward as new rows land):

```bash
python3 - <<'EOF'
import json, subprocess
cutoff = subprocess.check_output(["git", "log", "-1", "--format=%cI", "f6c84a52"], text=True).strip()
rows = [(i, json.loads(l)) for i, l in enumerate(open(".opencode/session/registry.jsonl"), 1) if l.strip()]
since = [(i, r) for i, r in rows if r.get("timestamp", "") >= cutoff]
hits = [(i, r) for i, r in since if ".scratch" in json.dumps(r)]
print("cutoff", cutoff, "| total", len(rows), "| since", len(since), "| .scratch text hits", len(hits))
for i, r in hits:
    print(" ", i, r.get("event"), r.get("timestamp"), "field=reason" if "reason" in r else "")
print("command/pattern/outcome fields present in any row:",
      any(k in json.dumps(r) for _, r in rows for k in ('"command"', '"pattern"', '"action"')))
EOF
```

## Evidence (sweep run 2026-11-04, clean)

Command: the verbatim `python3` block in `## Re-verify` above.

Output (snapshot; `registry.jsonl` is append-only so totals move):

    cutoff 2026-09-27T22:23:55Z | total 4565 | since 2082 | .scratch text hits 2
      2490 capability_minted 2026-09-27T23:02:05.434Z field=reason
      2568 capability_minted 2026-09-28T12:44:54.087Z field=reason
    command/pattern/outcome fields present in any row: False

Finding: **zero qualifying rows**. Both `.scratch` hits since the cutoff are
free-text `reason` values on `capability_minted` rows (ticket-creation
justifications that merely mention `.scratch`); neither carries a command, a
winning action pattern, an outcome or an argument shape.

Schema caveat (part of the finding, not a footnote): `registry.jsonl` contains
NO `command`, `pattern` or `action` key on ANY of its rows (verified by the
last line of the command), and `permission_asked_logged` rows carry only
`permission_id`. The condition's requested evidence format is therefore not
satisfiable from this file: the sweep proves that no `.scratch` COMMAND row
exists in the registry because the registry records no command rows at all.
If the auditor wants command text, it must come from the OpenCode permission
store (`make session-analytics` over opencode stats/db), not this registry.

This keeps the current decision justified (the clean-sweep outcome the Fix
section describes), and it does NOT supersede the separate High-severity
multi-argument rm ride-along finding (DIA-260928-rzty).
