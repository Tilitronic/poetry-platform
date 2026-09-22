# Interview summary: dia-260909-zeik-scenario-cleanup-dedupe

> **Change:** dia-260909-zeik-scenario-cleanup-dedupe
> **Campaign ticket:** DIA-260909-zeik (parent epic DIA-260903-o7n0, campaign DIA-260901-91qy)
> **Session:** openspec-plan lane ses_f78e2faafffeEJI4S8NwI2lmmO (resumed; Q1-Q4 conducted across resumes)
> **Grilling gate (DIA-104):** stays `skipped` per ticket frontmatter; developer confirmed re-confirmation on resume. Not re-opened by this change.
> **Practice-protected record:** developer ruled the substance; this lane only recorded and structured it.

## Decision table (authoritative)

| ID  | Topic                              | Decision                                                                                                                                                                                                                                                                                | Status |
| --- | ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| Q1  | Mechanism                          | **CONFIRMED** - new `scenario-runner.mjs` wrapper in `harness-scenarios/`, NOT an extension of `helpers/plugin-harness.mjs`. Ticket's original "withCleanup in plugin-harness" suggestion superseded by the fkiy collision ruling.                                                      | Locked |
| Q2  | Runtime contract                   | **CONFIRMED** - scenarios stay native `bun run`; zero test-framework imports in new code. Bats replay contract (`scripts/__tests__/harness-scenario-replay.bats`) stays unedited: same filenames, same exit-code contract (0 pass / 1 fail).                                            | Locked |
| Q3  | Mock ordering                      | **CONFIRMED** - mock-before-import (`mockOpencodePlugin()` before the plugin dynamic import) stays local per scenario. The runner does not wrap or relocate the plugin import.                                                                                                          | Locked |
| Q4  | Error states + acceptance criteria | **ACCEPTED with one clarification:** exactly 4 implementation files = new `scenario-runner.mjs` + the 3 scenario scripts. Ticket / spec / changelog evidence edits do NOT count toward this limit. Error-state semantics as presented (see design.md "Error-state semantics") accepted. | Locked |

## Rest confirmed (carried from earlier questions, re-confirmed on resume)

- `helpers/plugin-harness.mjs` is NOT touched - sibling ticket DIA-260909-fkiy ("extract repeated workspace-cleanup retry loops into helpers plugin-harness") edits that file concurrently; zero file overlap avoids the collision.
- The implementation commit names DIA-260909-zeik and carries a `Budget-Scope` trailer with manifest backing, and passes `scripts/check-budget-gate.sh`.
- Ticket guard honored: independent checksum/parity assertions stay per-scenario; only cleanup mechanics are deduplicated. The 7 extracted production modules, capability-loader guards, and independent checksum logic are untouched.
- 4-export cap respected: `plugin-harness.mjs` keeps its 4 exports (DIA-260903-o7n0 disposition D: "4 exports max not target", no 5th export added); the new runner exports fewer than 4 symbols (design: exactly 1).
- DIA-104 grilling gate stays `skipped` (gate_state on the ticket is not re-litigated by this change).

## Open tension recorded for implementation

The ticket verification line asks for a net LOC delta of -45..-70. The 4-file ruling adds a new runner file whose ~30-40 lines offset the scenario deductions. Resolution agreed: land scenarios aggressively (single-line `fail()` guards, collapsed multi-line `console.error` templates) and keep the runner lean; if the net delta lands outside -45..-70, report the actual number to the developer for disposition - never pad or over-cut to fit the range.
