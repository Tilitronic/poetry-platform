# Console free-tier gate rejects -free models (2026-09-21)

Campaign ticket: DIA-260921-6o4i. Analysis: ana-260921-0f9i
(`knowledge/ana-260921-0f9i-free-tier-gate/ana-260921-0f9i-free-tier-gate-report.md`).
Registered per AGENTS.md 2.5 step 1 (ai-specialist gate findings persistence).

## ai-specialist findings F1-F6 (campaign record)

F1-F6 are the read-only config-surface findings from the ai-specialist lane on
this campaign. The finding on record in the analyzer report is the citation of
`preset-model-guard.ts:28,117-156` as mapping `free` to rejected. Discrepancy
(status: recorded unresolved per session handoff ses_f3bd5682effeyfyv9ePp6Hpg33):
that file is ABSENT from the current tree (only
`.opencode/oh-my-opencode-slim/src/utils/guards.ts`, a 6-line `isRecord` type
guard, exists), and provider receipt of the exact `-free` model string proves
no client pre-rejection fired. Disposition: UNVERIFIED / stale reference, NOT
the active cause. Remaining F-items are not restated here (no verbatim source
on hand in this lane; see campaign session record, do not fabricate).

## Analyzer verdict table outcome (ana-260921-0f9i Sec 6)

- Root cause is provider-side console gate on `providerID=opencode`, onset
  ~09-18: ACCEPTED, High, Tier-1.
- Client launch (`make opencode PRESET=free`) is correct: ACCEPTED, High, Tier-1.
- Fresh reconnect failure exonerates auth hygiene: ACCEPTED, High, Tier-1.
- OMO 2.2.22 caused the break: REJECTED, High, Tier-1 (onset precedes publish).
- preset-model-guard.ts actively rejects free: UNVERIFIED / REJECTED as active
  cause (file absent; provider receipt proves no pre-rejection).
- UA/entrypoint is the gate mechanism: PLAUSIBLE INFERENCE, Low, Tier-3.
- Fix by client reinstall / re-auth loop: NOT RECOMMENDED (already falsified).
- Recommended routing V1 (use `opencode-go/*` equivalents): RECOMMENDED, High.

## Researcher corroboration res-1 (external URLs)

- anomalyco/opencode issue 42029: UA gate corroboration.
- anomalyco/opencode issues 45744 / 44847: same-account 500-vs-200 split.
- anomalyco/opencode issue 33318: intentional-gate comment.
- Negative result: the verbatim error string
  (`OpenCode's free tier can only be used from within OpenCode`) was NOT found
  in any public report; corroboration is behavioral, not textual.

## Routing

V1 Go-equivalent routing recommended, pending developer approval. Do NOT run
further client-side fix loops (reinstall, re-auth, preset rewiring) on `-free`.
Ticket DIA-260921-6o4i stays OPEN.
