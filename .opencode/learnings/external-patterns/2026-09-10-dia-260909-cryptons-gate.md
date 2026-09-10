# Learnings: cryptoNs gate (DIA-260909-sazr) - 2026-09-10

Ticket: DIA-260909-sazr (campaign ticket DIA-260909-sazr)
Lane: AGENTS.md section 2.5 step 1 (ai-specialist gate, write-only)
Gate: ai--1, GO-CONDITIONAL
Date: 2026-09-10
Scope: 4-line no-import-assign fix in .opencode/plugins/__tests__/capability.test.mjs

## Target lines

- Line 295:9
- Line 303:11
- Line 331:9
- Line 333:15

Rule: no-import-assign (ESLint import plugin). Test file reassigns the
imported `crypto` namespace object. Fix must remove all 4 writes without
changing test intent.

## Recommended pattern

- Retain the imported `crypto` namespace for the original (read-only) use.
- Introduce a block-local shadow object named `cryptoNs` that receives the
  4 writes (lines 295, 303, 331, 333).
- Route the fallback/invalid-signature path under test through `cryptoNs`
  so the 4 assignments become plain local-object writes, not import writes.
- Keep the diff to one test file only. No helper extraction, no new
  abstraction, no changes to production code.

Why this shape: the failure is assignment-to-import, not logic. A local
shadow object is the smallest change that satisfies the linter while
preserving the existing DI-fake structure. Renaming the import or
rewriting the DI plumbing would widen the blast radius for zero gain.

## Risk notes (do not cross these lines)

1. Do NOT alter `createCapability` DI. The DI signature and fake-injection
   path stay verbatim.
2. Do NOT touch `lib/capability.ts` (or equivalent production module under
   `.opencode/plugins/lib`). This lane is test-only.
3. Keep the fallback invalid-signature assertion. The test must still prove
   the invalid-signature path, just via `cryptoNs`.
4. Loader contract is covered separately. Do not mix loader-guard or
   checksum assertions into this fix.
5. Do NOT delete DI fakes or loader-contract tests in this file. Only the
   4 import-write sites move to the shadow object.

## The 5 conditions (GO-CONDITIONAL)

1. Learnings registered (this file) before implementation starts.
2. Ticket OPEN + poetry-dev Up at implementation time (Docker gate DIA-094;
   pre-commit hook hard-fails when container is down).
3. One-file diff: only `.opencode/plugins/__tests__/capability.test.mjs`
   changes. No production files, no sibling suites.
4. Targeted verification only: targeted `bun test` for capability suite +
   `eslint` on the touched file + `make test-config`. No full-repo sweep
   required for this 4-line lane.
5. Phase 6 ai-auditor review after implementation (AGENTS.md section 2.5
   step 6), against the preservation table (DI fakes intact,
   loader-contract intact, fallback assertion intact).

## Handoff pointer

Implementer applies the 4-line `cryptoNs` shadow fix, attaches bun/eslint/
test-config evidence, then routes to ai-auditor. No stash, no stage, no
commit in the learnings lane.

## Outcome (2026-09-10 re-close): cryptoNs shadow fix applied, CLOSED; verify node 18/18, bun 243/0, eslint 0 errors, test-config 61 PASS; ai-auditor GO-CONDITIONAL advisory residual accepted.
