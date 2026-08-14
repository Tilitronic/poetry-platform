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
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty (cross-ref DIA-078 in Description)
discovered: 2026-08-14
source: fix-lane
date: 2026-08-14
created: 2026-08-14
updated: 2026-08-14

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_fffd1d538ffe40t2OLtybsuuFB"
lane_id: "audit"
agent: "ai-auditor"
model: ""
parent_session_id: "ses_fffccfb12ffeYJuZS501HAjN33"
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-154-gigaplan-frontmatter-clobber-hazard.md"]
artifacts: []
evidence: [".opencode/learnings/external-patterns/2026-08-14-code-executor-permission-merge.md"]

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

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
