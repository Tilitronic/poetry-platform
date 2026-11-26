# DIA-154 - gigaplan.md frontmatter flat bash deny - latent permission clobber hazard (DIA-078 class)

<!-- Filed by the DIA-078 closure lane 2026-08-14 from ai-auditor Phase 6
     note 7 (ses_fffd1d538ffe40t2OLtybsuuFB, CONFORMANT-WITH-NOTES):
     gigaplan.md carries a flat `permission.bash: deny` primitive in its
     frontmatter - the same clobber class that broke code-executor in
     DIA-078. No current breakage (no jsonc bash object for gigaplan exists
     today); this is a LATENT hazard ticket (severity Low). -->

---

id: DIA-154
title: "gigaplan.md frontmatter flat bash deny - latent permission clobber hazard (DIA-078 class)"
area: opencode-config
severity: Low
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty (cross-ref DIA-078 in Description)
discovered: 2026-08-14
source: fix-lane
date: 2026-08-14
created: 2026-08-14
closed: 2026-08-14
updated: 2026-08-14

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_fffd1d538ffe40t2OLtybsuuFB"
lane_id: "audit"
agent: "ai-auditor"
model: ""
parent_session_id: "ses_fffccfb12ffeYJuZS501HAjN33"
attempts: 1
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-154-gigaplan-frontmatter-clobber-hazard.md", "~/.config/opencode/agents/gigaplan.md"]
artifacts: []
evidence: [".opencode/learnings/external-patterns/2026-08-14-code-executor-permission-merge.md", "docs/dev-infra-audit/tickets/DIA-078-coder-snip-wrapper-loop.md", "CLOBBER_PROOF: scratch /tmp/opencode/gigaplan-clobber-test/opencode.jsonc before/after opencode debug agent gigaplan - pre: bash object destroyed to string deny, 0 echo allow; post: bash {echo *: allow, *: deny} merged object, 1 echo allow (see Fix section)"]

---

## Description

`~/.config/opencode/agents/gigaplan.md` frontmatter (L7-10) declares a flat
primitive deny:

    permission:
      edit: deny
      bash: deny

This is the SAME clobber class as DIA-078: OpenCode's config loader merges
`.md` frontmatter LAST (`config.ts` `result.agent = mergeDeep(result.agent ??
{}, ConfigAgent.load(dir))`), and remeda `mergeDeep` REPLACES an object with
an incompatible primitive. If a jsonc agent block for gigaplan ever adds bash
PATTERN rules (e.g. `permission.bash = { "read *": "allow" }` as an object),
the flat frontmatter string `deny` will silently DESTROY the object - the
jsonc rules never take effect, and the effective rule set degrades to the
flat string (all bash denied, or whatever the primitive says).

Impact today: NONE active - no jsonc bash object for gigaplan exists, and
gigaplan is a read-only analysis lane where a flat all-bash deny is arguably
intended. The hazard is STRUCTURAL (future config drift) + a maintenance trap
(an engineer adding a gigaplan bash pattern rule in jsonc will see it
silently not apply, exactly as code-executor's snip denies silently vanished
in DIA-078).

Reference: DIA-078 (same class, empirically proven: code-executor.md flat
`bash: allow` at L10 clobbered the jsonc deny object - 128 rules, 0 snip
denies) + `.opencode/learnings/external-patterns/2026-08-14-code-executor-permission-merge.md`
(merge semantics CONFIRMED, section 3 gotcha 8 explicitly flags gigaplan.md
as vulnerable).

## Verification

1. Confirm the current frontmatter shape: `sed -n '1,12p'
~/.config/opencode/agents/gigaplan.md` shows `permission: bash: deny`
   (flat string).
2. Confirm the effective rule today: `opencode debug agent gigaplan` - bash
   resolves to the flat deny (all bash denied; expected for a read-only
   lane, so this alone is NOT a defect).
3. Prove the clobber: add a throwaway jsonc bash OBJECT rule for gigaplan
   (e.g. `"gigaplan": { "permission": { "bash": { "echo *": "allow" } } }` in
   a scratch config), run `opencode debug agent gigaplan`, confirm the echo
   allow does NOT appear (the flat frontmatter string replaced the object),
   then remove the throwaway. This demonstrates the latent failure without
   touching the live config.
4. Post-fix: repeat step 3 with the frontmatter cleaned (flat primitive
   removed or converted to the canonical nested object syntax) - the jsonc
   object rules must now survive and appear in `opencode debug agent
gigaplan`.

## Fix

FIXED 2026-08-14 (implementation lane, developer-approved section-10 change; research
gate already completed in the DIA-078 closure lane - ai-specialist Phase 1 gate
ses_fffda5947ffew04U3aIH37NkV2, findings in
.opencode/learnings/external-patterns/2026-08-14-code-executor-permission-merge.md).

CHANGE APPLIED to ~/.config/opencode/agents/gigaplan.md frontmatter (L7-10):

- BEFORE (flat primitives - clobber hazard):
  permission:
  edit: deny
  bash: deny
- AFTER (canonical nested-object syntax, learning-file section 2 Variant B):
  permission:
  edit:
  "_": deny
  bash:
  "_": deny
  plus an inline comment documenting the DIA-154/DIA-078 clobber class and why
  the nested form is required (a future jsonc gigaplan agent block with bash
  pattern OBJECT rules now merges key-by-key instead of being replaced by the
  flat string).

WHY Variant B (nested object), not Variant A (remove entry): Variant A was the
DIA-078 code-executor fix because a jsonc agent block already existed there to
govern the pattern rules. gigaplan has NO jsonc agent block today (verified:
no gigaplan key in project .opencode/opencode.jsonc, .opencode/oh-my-opencode-
slim.jsonc, or global ~/.config/opencode/opencode.jsonc - the only global refs
at L38-40/L54 are task-dispatch allowlists in the build/plan agent blocks).
Removing the frontmatter deny would therefore flip gigaplan bash to the global
"\*": "allow" default - a behavior regression for a read-only lane. The nested
object preserves the deny-all intent AND eliminates the clobber class, which is
exactly the ticket's fix direction ("remove the flat primitive or convert it to
the canonical nested-object syntax").

CLOBBER PROOF (ticket Verification steps 3-4, throwaway scratch config):

1. Scratch config /tmp/opencode/gigaplan-clobber-test/opencode.jsonc:
   { "agent": { "gigaplan": { "color": "accent",
   "permission": { "bash": { "echo \*": "allow" } } } } }
   (color: accent is the load-control probe - it survives the merge, proving the
   scratch config was actually read.)
2. BEFORE fix, `opencode debug agent gigaplan` from the scratch dir: merged
   config showed `"bash": "deny"` (flat string) - the echo-object was DESTROYED;
   effective rules: 0 echo allow rules. Clobber reproduced.
3. AFTER fix, same scratch config: merged config showed
   `"bash": { "echo *": "allow", "*": "deny" }` - BOTH rules coexist; effective
   rules: 1 echo allow rule (`allow 'echo *'`) alongside the frontmatter
   `*: deny`. Clobber eliminated.
4. Scratch config removed; live project context re-verified:
   `opencode debug agent gigaplan` = 126 effective rules (unchanged from
   pre-fix), bash `*` deny + edit `*` deny both present, 0 echo rules (no
   scratch). No behavior change for the live read-only lane.

GATES: make test-config exit 0 (25 config tests passed, 0 failed; agent-name
lockstep 24 passed, 0 failed; validate-decision-variants 109/109; validate-
grilling-gate 109/109; validate-handoff 5/5; test-ticket-gate PASS; tool-
coverage audit 0 gaps). Restart required for permission changes to take effect
in the running OpenCode session (learning-file gotcha 5) - safe here because
the effective rules are unchanged (deny-all preserved both before and after).

## Re-verify

RE-VERIFIED 2026-08-14 (closure lane): ai-auditor independent review
(CONFORMANT-WITH-NOTES) - the fix is sound, no new active hazards.

- ai-auditor verdict: CONFORMANT-WITH-NOTES, 1 Suggestion finding (finding 3:
  document the future-allow-exceptions escape hatch in the gigaplan.md
  comment block).
- Developer disposition 2026-08-14 (binding): ACCEPT the Suggestion; applied
  by the closure lane (see UPDATE block below).
- No new active hazards: the clobber class is eliminated (nested objects
  merge key-by-key; scratch-config proof in Fix), and no jsonc gigaplan
  permission object exists today that could still be clobbered.
- Mechanical gates: make test-config exit 0 (25 config tests passed, 0
  failed; agent-name lockstep 24 passed, 0 failed; validate-decision-variants
  109/109; validate-grilling-gate 109/109; validate-handoff 5/5;
  test-ticket-gate PASS; tool-coverage audit 0 gaps).
- Restart-verify DEFERRED per the DIA-123 second-boot pattern: the permission
  change takes effect on next OpenCode restart; effective rules are unchanged
  (deny-all preserved before and after), so no live behavior delta is
  expected. Verify in a POST-change session with `opencode debug agent
gigaplan` (bash `*` deny + edit `*` deny, 0 echo rules) and, if an allow
  exception is ever needed, follow the new comment guidance.

> Pre-closure state: "To be filled at re-verify time." (implementation lane
> filled Fix + GATES evidence 2026-08-14; closure lane filled this section).

<!-- UPDATE 2026-08-14 (CLOSED - closure lane):
     CLOSED 2026-08-14. Full chain complete:
     (1) cod-5 implementation lane - nested-object fix applied to
     ~/.config/opencode/agents/gigaplan.md frontmatter (flat edit/bash deny
     -> nested {"*": deny} objects) with inline DIA-154/DIA-078 clobber-class
     comment; scratch-config CLOBBER PROOF before/after; make test-config
     exit 0 (see Fix).
     (2) ai-auditor independent review (ai--1) verdict: CONFORMANT-WITH-NOTES
     - fix sound, 1 Suggestion finding (finding 3: document the future-allow-
     exceptions escape hatch in the comment block).
     (3) Developer disposition 2026-08-14 (binding): ACCEPT the Suggestion,
     apply + close.
     (4) This closure lane applied the accepted note (one sentence appended
     to the gigaplan.md DIA-154 comment block), filled Re-verify with the
     ai-auditor verdict, set status OPEN -> CLOSED + closed 2026-08-14.
     README.md index row DEFERRED - protected concurrent-session file under
     the DIA-153 lease; row flip lands when the lease holder commits.
     DIA-154 carries NO gate_state markers (predates the DIA-104 gate_state
     schema; grandfather no-backfill rule - legacy tickets warn, not fail,
     in validate-grilling-gate). -->
