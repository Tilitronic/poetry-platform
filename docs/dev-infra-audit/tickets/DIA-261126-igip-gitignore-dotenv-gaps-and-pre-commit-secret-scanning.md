# DIA-261126-igip - gitignore dotenv gaps and pre-commit secret scanning

---

id: DIA-261126-igip
title: "gitignore dotenv gaps and pre-commit secret scanning"
area: secrets
severity: Critical
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-261112-exon
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-11-26
source: inventory
date: 2026-11-26
created: 2026-11-26
updated: 2026-11-26

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
evidence: [".opencode/learnings/external-patterns/2026-11-26-dia-261112-exon-envsitter-guard-v2-capability-gaps.md"]

---

## Description

Two repo-side gaps found by the DIA-261112-exon envsitter-guard capability
gate. Neither is closed by the envsitter-guard plugin, on V1 or V2, so both
need native fixes.

### Gap (a) - .gitignore does not cover every dotenv file name

`.gitignore` lines 26-28 ignore `.env`, `.env.local` and `.env.*.local` only.
It does NOT ignore `.env.production`, `.env.staging`, `api.env`, `config.env`
or any other `*.env`-named file, so a real dotenv file carrying live values
can be committed without any ignore rule firing.

### Gap (b) - no secret scanning in the pre-commit path

`scripts/verify-pre-commit.sh` performs lint-staged autofix and a `/home/qualt`
path-pollution check only. There is no secret scanner anywhere in the
pre-commit or pre-push path: no gitleaks, no trufflehog, no entropy check.
A secret that is already tracked, or added under a name the ignore rules miss,
passes the hook unchallenged.

### Candidate fixes (do not implement here)

- Broaden the dotenv ignore patterns to cover `*.env` while keeping
  `.env.example` tracked (it already is; `*.env` does not match it, but a
  broader `.env*`-style pattern would need an explicit `!.env.example`).
- Add a secret scanner to the pre-commit path.
- NOTE: a scanner choice is a dependency decision and needs its own gate
  (AGENTS.md section 2.5 / section 2.4 routing) before any dependency is added.

### Links

- Campaign ticket: DIA-261112-exon
  'opencode-version-migration-breaking-change-inventory-blockers-and-remove-or-adapt-rating'.
- Analysis: `.opencode/learnings/external-patterns/2026-11-26-dia-261112-exon-envsitter-guard-v2-capability-gaps.md`
  (gap list measured against repo-native guards; the pre-commit finding
  corrects a widely-held assumption that a scanner was already present).
- Related permission-side follow-up: close `.env` read/edit and bash/grep
  exposure with native deny rules (tracked under DIA-261112-exon tasks).

## Verification

- [ ] `.gitignore` ignores `.env.production`, `.env.staging`, `api.env` and
      `config.env` (for example `git check-ignore -v .env.production` resolves
      to a gitignore rule) while `.env.example` stays visible to git
      (`git check-ignore .env.example` exits 1).
- [ ] A secret scanner runs in `scripts/verify-pre-commit.sh` (or the pre-push
      path) and a seeded fake secret in a staged file fails the hook.
- [ ] `make test-shell` exits 0 (any hook change carries its bats coverage).
- [ ] Scanner dependency choice is recorded through its own gate before the
      dependency lands.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
