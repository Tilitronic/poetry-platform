# Skills-lock extension gate - learnings registration

Date: 2026-09-17
Ticket: campaign ticket DIA-260917-bm5k
Step: AGENTS.md 2.5 step 1 learnings registration (prerequisite before any @coder config-work on skills-lock)

## Source of findings

- Lane: ai-specialist, read-only research lane.
- Lane instance: ai--1 / ses_f50d99b53ffe8l8xORTBXZlqqZ
- Mode: read-only. No config writes performed in that lane.
- Purpose: gate findings for skills-lock extension decision before @coder config-work.

## Inventory summary

- Local git-pinned skills: 24 entries under project skill paths, pinned via git.
  - Note: includes tdd-craftsman collision case - local project copy collides
    with a same-named upstream/bundled skill name; resolution needs explicit
    precedence rule (project-local wins) before any lock extension.
- Remote-locked skills: 1 entry (cli-review).
  - source: greptileai/skills
  - sourceType: github
  - skillPath: cli-review/SKILL.md
  - computedHash (full 64-hex SHA-256):
    1b1fe57c18746de2a85068770ec01fa7ac26471f5c9cb8047553ca433fea1acd
- OMO bundled skills: 14 entries bundled with oh-my-opencode-slim @2.2.19.
- Ponytail skills: 6 entries FLOATING, unpinned (no SHA, no tag pin).
- Builtin skills: 1 entry (opencode builtin).
- skills.urls: empty (no URL-registered skills in inventory).

## v1 schema shape (github-only)

Current `.opencode/oh-my-opencode-slim/skills-lock.json`:

```json
{
  "version": 1,
  "skills": {
    "<name>": {
      "source": "<org>/<repo>",
      "sourceType": "github",
      "skillPath": "<path>/SKILL.md",
      "computedHash": "<sha256-hex>"
    }
  }
}
```

- v1 supports github sourceType only.
- Live example is cli-review (see hash above).
- No fields for local-git SHAs, npm-package versions, npm-plugin refs,
  or builtin markers in v1.

## Key risks

- R1 - Floating ponytail (highest priority): 6 ponytail skills FLOATING
  unpinned; any upstream move changes runtime behavior without detection.
  Pin first before extending lock coverage.
- R2 - Vendored vs running version hash source: vendored checkout is 2.2.11
  while running runtime is 2.2.19; hash source must be the running 2.2.19
  bundle, not the stale vendored tree, else hashes attest the wrong artifact.
- R4 - Unverified hash function: hash computation/verification path for
  computedHash is unconfirmed; do not trust lock enforcement until the
  hash function and verification point are confirmed by code read + test.
- R6 - Unenforced lock unconfirmed: it is unconfirmed whether skills-lock.json
  is actually enforced at load time or advisory-only; confirm enforcement
  hook before claiming supply-chain closure.
- R8 - Orchestrator wildcard: broad orchestrator permissions could bypass
  skill pin guarantees at runtime; scope check needed.

## DIA-003 prior defer rationale

- DIA-003 deferred full skills-lock rollout: v1 github-only coverage left
  local-git, npm, and builtin skills outside the lock.
- Rationale carried forward: do not widen schema until pinning story for
  non-github skills is decided; avoid a v2 schema that locks names without
  verifiable artifacts.

## Decision fork

- Minimal-A (recommended for now): keep v1 github-only.
  - Pin natively without schema change:
    - local-git skills: record git SHA out-of-band (docs or sidecar),
      no lock.json change.
    - OMO bundled 14: pin by package version @2.2.19 (already pinned
      in plugin array / tui.json), no per-skill hash needed.
    - ponytail 6: pin by tag/SHA or vendor snapshot; closes R1 directly.
  - Pros: no architector needed; smallest diff; closes highest risk (R1).
  - Cons: lock.json still covers 1 skill; rest pinned by convention.

- Schema-B (needs architector): v2 with new sourceTypes.
  - Add sourceTypes: local-git, npm-package, npm-plugin, builtin.
  - Define per-type identity + hash semantics (git SHA vs file hash vs
    version string) and enforcement points.
  - Pros: single machine-checkable lock for all 46 skills.
  - Cons: schema + verifier + migration; requires @architector design
    and @ai-auditor review per AGENTS.md 2.5.

## Outcome

TODO-pending-developer-decision: developer selects Minimal-A or Schema-B
in step 2 review; no @coder config-work starts until decision is recorded.
