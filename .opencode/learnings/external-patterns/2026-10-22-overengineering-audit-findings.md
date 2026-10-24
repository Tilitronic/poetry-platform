# Over-engineering audit findings - repository tree and open-ticket plans (2026-10-22)

Governing ticket: DIA-261022-5n2v. Source: read-only audit lane
(knowledge/ana-261022-v0z7-repo-overengineering-audit/) plus verification probes.
Developer disposition: the simplification set below is accepted and applied;
the falsified claims are recorded so they are never re-proposed.

## (a) Repository-tree cuts (top findings)

- Vendored .opencode/oh-my-opencode-slim/** checkout: reference-only tree kept
  in-repo while the runtime loads the npm pin; Audit A DEFERRED by developer.
- Dead phonetic-atlas loader chain (packages/phonetics-core): dead code path,
  Audit A DEFERRED by developer - do not touch.
- 718-line budget gate: oversized relative to the decisions it encodes.
- Derived CHANGELOG.md: prose view duplicates the YAML ledger (source of truth).
- Tickets README rollup: static snapshot that drifts; scripts/tickets is live.
- scripts/promo-preset-apply: 50-line argparse no-op stub (commit 0123f4c5),
  zero live callers - deleted this pass (S7).
- opsx command duplication and JSONL reader duplicates: repeated logic across
  command/helper surfaces.
- JSONC stripper x9: nine near-copies of JSONC comment-stripping logic.
- Quasar i18n/demo residue: leftover demo/i18n scaffolding in the app tree.

## (b) Open-ticket plan findings

- Stale "remaining work" class (bodies still list shipped work as owed):
  DIA-260928-nm2u, DIA-260928-gpcc, DIA-260929-5c6m, DIA-260929-wjir.
  nm2u trimmed to probe-only scope this pass (S1).
- Validator/flag sprawl: DIA-260926-40bb, DIA-260926-6339, DIA-260928-gpcc -
  overlapping validators and flags whose scope should shrink, not grow.
- Micro-ticket ceremony: DIA m6l8/mho5/zjci - tickets too small to justify the
  full spec->implement->review chain.
- Template-body class: DIA bgnw/6339/yanz/nc6w - unfilled template sections
  (Description/Verification placeholders) that never carried real content.

## (c) Audit claims FALSIFIED by verification (do not re-propose)

- S10 / DIA-261021-cs3v: the dispatch-payload mention-hygiene rule has SEVEN
  boot-loaded copies and IS load-bearing at every one. Do NOT deduplicate.
- S6 / DIA-260928-rzty: only the six two-argument ask lines (.scratch rm/rmdir)
  are falsified as ineffective; the EIGHT single-target allow lines work and
  removing them would regress interactive .scratch cleanup.
- S2 / DIA-260928-gpcc [SUPERSEDED 2026-10-22, claim as originally written]:
  the plugin per-file tsc baseline is ALREADY red with 3 real registry.ts type
  errors; wiring test-typecheck into test-config now would turn the gate red.
  Wiring stays deferred until the baseline is fixed.
- Correction 2026-10-22 (supersedes the claim above): commit 0a4caf7a (13:02:47Z) fixed the three registry.ts errors;
  `make test-typecheck` is exit 0 today and registry.ts is clean; the six bare per-file tsc diagnostics are
  compiler-flag artifacts (exit 0 under project flags), not real errors - gpcc's wiring is UNBLOCKED: adding
  test-typecheck as a test-config prerequisite would be GREEN today, and the "defer" classification has expired.
