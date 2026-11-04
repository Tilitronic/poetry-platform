---
name: data-reducer
description: Use when a worker lane must analyze a large data blob — reduce raw input over ~100 KB / ~2000 lines in a worker process (python3 / jq / rg / project script) before its compact result enters the model context.
compatibility: opencode
metadata:
  audience: worker-lanes
  workflow: context-economy
license: AGPL-3.0
---

Use when a worker lane must analyze a large data blob (multi-thousand-line
logs, the full `registry.jsonl` / `messages.jsonl`, big generated files):
reduce the raw input in a worker process FIRST, and only the compact result
enters the model context. Never paste the whole blob.

This skill formalizes the "Recursive Language Model" (RLM) pattern adopted
for this project (DIA-181): a worker process filters / searches / aggregates
/ extracts the data, and only the small result returns to the main agent.
It is the instruction layer; `scripts/data-reduce.sh` is the measurement
layer that makes the savings visible.

## Size threshold rule

Raw input over **~100 KB / ~2000 lines** MUST be reduced in a worker process
before its result is read into the model context. Below the threshold,
reading the data directly is fine.

Pre-flight recipe: check the size before deciding —
`wc -c < FILE` (for stdin, pipe it: `... | wc -c`); if the byte count
exceeds ~100000 (~100 KB), reduce it before reading. Two routes, split by
reducer type: `scripts/data-reduce.sh` meters jq/rg/wc-class reducers
(allowlist: jq, rg, wc, head, tail, cut, tr, uniq — anything else is
rejected with exit 2); interpreter reducers (`python3 -c` or a reducer
script file) run directly on lanes that have interpreter access, never
through the script.

## Worker options (chosen per data shape)

For a lane whose grant holds no interpreter and no project-script command
(the narrow shape analyzer / analyzer-escalated carried under DIA-260826-6mhy)
only these options are usable — and since DIA-260827-ft3z those two lanes hold
no shell at all, so they run neither these nor the wrapper:

- `jq` — JSON / JSONL shapes: projection, selection, aggregation.
- `rg` — line-oriented logs: filtering, counting, context extraction.
- `wc` — the size probe (`wc -c < FILE`) and a bare count reduction.
- `scripts/data-reduce.sh` — the wrapper above, which meters any of the
  three and prints the savings line.

**Where reduction happens now:** a no-shell lane never reduces itself. A
bash-allow lane (coder / coder-escalated) runs the reduction and passes only
the compact result to the analyzer lane.

Lanes WITH interpreter / project-script access (coder and other bash-allow
lanes — explicitly NOT the analyzer lanes, which have no shell at all, so
these do not apply there):

- `python3` — aggregation, filtering, JSON/CSV parsing, statistics. Use
  `python3 -c '...'` reading `sys.stdin`, or a reducer script file
  (`.scratch/reducer.py` per DIA-175) that reads `sys.stdin` — do NOT use
  `python3 - <<PY` heredocs, because stdin carries the data, not the script.
- Project scripts (coder-only) — `.opencode/scripts/jsonl-stats.sh` for the
  orchestrator session logs, `scripts/session-log` for message-log views —
  use the purpose-built tool when one already matches the data shape.

> Note (deviation from the DIA-181 ticket): the ticket listed a `python3
> heredoc` worker option. This skill narrows it to `python3 -c` / a script
> file because `python3 - <<PY` feeds the SCRIPT via stdin, which collides
> with the data also needing stdin — the data and the script cannot share
> the same stream. Like the python3 bullet above, this is an
> interpreter-lane option and does not apply to the analyzer lanes — they
> hold no interpreter, and after DIA-260827-ft3z no shell at all.

## Output contract

- Compact structured result: target **< ~5 KB** when possible.
- Savings line: `input N KB -> result M KB (saved P%, ~Q tokens)`.
- Empty input: `input 0 KB -> result N KB (no data to reduce)` — no
  percentage (avoids a division-by-zero).
- Token estimate: **heuristic ~4 chars / token** — an estimate for context
  planning, NOT a billable or vendor-accurate number.

## Measuring the savings (scripts/data-reduce.sh)

`scripts/data-reduce.sh` runs an ALLOWLISTED reducer over a file or stdin,
measures input vs output bytes, and prints the savings line. The reducer's
first element must be a bare name from jq, rg, wc, head, tail, cut, tr, uniq;
anything else — including python3 and slash-qualified names — exits 2. So the
split is plain: the script meters jq/rg/wc-class reducers, while interpreter
reducers (`python3 -c` / a reducer script file) run directly on lanes that
have interpreter access, outside the script:

    bash scripts/data-reduce.sh logs.txt -- rg -c 'ERROR'
    # stdout: the reduction result (pure — pipe it onward)
    # stderr: input 420 KB -> result 0 KB (saved 100%, ~107500 tokens)

The reduction result stays on stdout; the savings line goes to stderr so the
result stream is never polluted. Merge with `2>&1` when both belong in one
capture.

## Applicability (which lanes)

Worker lanes for this skill: **coder / coder-escalated** - exactly those two,
and they are now wired to the skill in every preset block that configures them
(DIA-260827-ft3z). No other lane runs a reducer, and no lane receives a
reduction except through one of these two:

- The orchestrator has bash denied, so it routes an oversized input to
  coder / coder-escalated for reduction before dispatching the compact result.
- analyzer / analyzer-escalated lost their shell outright (DIA-260827-ft3z:
  jq, rg, wc and the wrapper are all gone), so they RECEIVE a reduction, they
  do not run one.
- code-navigator has no bash at all, and researcher's bash is allow-listed to
  curl / wget / trafilatura / crwl only - neither is a worker lane here.
