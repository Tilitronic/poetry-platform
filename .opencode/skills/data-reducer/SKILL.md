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
exceeds ~100000 (~100 KB), route the blob through `scripts/data-reduce.sh`.

## Worker options (chosen per data shape)

- `python3` — aggregation, filtering, JSON/CSV parsing, statistics. Use
  `python3 -c '...'` reading `sys.stdin`, or a reducer script file
  (`.scratch/reducer.py` per DIA-175) that reads `sys.stdin` — do NOT use
  `python3 - <<PY` heredocs, because stdin carries the data, not the script.
- `jq` — JSON / JSONL shapes: projection, selection, aggregation.
- `rg` — line-oriented logs: filtering, counting, context extraction.
- Project scripts — `.opencode/scripts/jsonl-stats.sh` for the orchestrator
  session logs, `scripts/session-log` for message-log views — use the
  purpose-built tool when one already matches the data shape.

> Note (deviation from the DIA-181 ticket): the ticket listed a `python3
> heredoc` worker option. This skill narrows it to `python3 -c` / a script
> file because `python3 - <<PY` feeds the SCRIPT via stdin, which collides
> with the data also needing stdin — the data and the script cannot share
> the same stream.

## Output contract

- Compact structured result: target **< ~5 KB** when possible.
- Savings line: `input N KB -> result M KB (saved P%, ~Q tokens)`.
- Empty input: `input 0 KB -> result N KB (no data to reduce)` — no
  percentage (avoids a division-by-zero).
- Token estimate: **heuristic ~4 chars / token** — an estimate for context
  planning, NOT a billable or vendor-accurate number.

## Measuring the savings (scripts/data-reduce.sh)

`scripts/data-reduce.sh` runs any reduction command over a file or stdin,
measures input vs output bytes, and prints the savings line:

    bash scripts/data-reduce.sh logs.txt -- rg -c 'ERROR'
    # stdout: the reduction result (pure — pipe it onward)
    # stderr: input 420 KB -> result 0 KB (saved 100%, ~107500 tokens)

The reduction result stays on stdout; the savings line goes to stderr so the
result stream is never polluted. Merge with `2>&1` when both belong in one
capture.

## Applicability (which lanes)

Worker lanes: **coder / analyzer / code-navigator / researcher**. The
reduction runs IN the worker (the orchestrator has bash denied) and only the
small result returns to the orchestrator.
