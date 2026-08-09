---
name: debugging-workflow
description: 'Language-specific debugging tools, techniques, and best practices for Python, JS/TS, Rust, and C++. Covers interactive debuggers, log-driven diagnosis, structured breakpoints, and the hypothesis-test loop. Invoke when a bug report needs systematic investigation across the full debug cycle.'
compatibility: opencode
metadata:
  audience: developers
  workflow: debugging-and-root-cause-analysis
---

# Debugging Workflow

## Activation

Route to this skill when:
- **Bug report received:** User describes incorrect behavior, crash, or performance issue
- **Test failure:** A test fails and the root cause is not obvious
- **Regression:** A feature that worked previously now breaks
- **Production incident:** Error logs show unexpected failures

## Multi-Agent Debugging Flow

Debugging follows a **6-stage multi-agent pipeline**. Each stage produces output consumed by the next stage:

```
User Bug Report
  │
  ▼
Stage 1 — Reproduce & Capture    (@coder + debugging-workflow skill)
  │  - Create minimal reproduction
  │  - Capture exact inputs, env, versions
  │  - Add structured logging at key points
  │  - Output: annotated bug note + debug artifacts
  ▼
Stage 1.5 — Build a Feedback Loop (@coder + debugging-workflow skill)
  │  - One red-capable, deterministic, fast, agent-runnable command before any theory
  │  - Tighten the loop (faster, sharper signal, more deterministic)
  │  - Output: a command that fails on the bug
  ▼
Stage 2 — Isolate Root Cause      (@coder + debugging-workflow skill)
  │  - Strategic breakpoints at critical junctions
  │  - Binary search on code path
  │  - git bisect for regressions
  │  - Ranked hypotheses before testing
  │  - Output: narrowed scope (file/function/line)
  ▼
Stage 3 — Analyze Causality       (@analyzer)
  │  - Apply 5-Whys or Fishbone to findings
  │  - Trace cause-effect chain
  │  - Output: root cause analysis report
  ▼
Stage 4 — Design Solution          (@architector or council)
  │  - Evaluate fix options
  │  - Consider spec compliance
  │  - Output: fix specification
  ▼
Stage 5 — Implement & Verify      (@coder)
  │  - Apply the minimum fix
  │  - Write regression test
  │  - Verify no regressions; confirm the correct test seam
  │  - Output: fixed code + test
  ▼
Stage 6 — Cleanup + Post-mortem   (@coder)
  │  - Repro no longer reproduces
  │  - All [DEBUG-*] instrumentation removed
  │  - Throwaway prototypes deleted
  │  - Output: post-mortem (what would have prevented this bug?)
```

## Stage 1: Reproduce & Capture

Before any debugging, establish deterministic reproduction.

### Reproduction Checklist
1. **Capture exact input** that triggers the bug — save it as a test case
2. **Record environment:** language version, OS, library versions
3. **If randomness involved:** fix the seed (`random.seed(42)`, `Math.seedrandom(42)`)
4. **Minimize the input:** cut it in half, does the bug persist? Repeat until minimal
5. **Document expected vs actual behavior**

### Structured Logging (All Languages)

Add logging at these 5 points before running interactive debuggers:
1. Function entry (parameters received)
2. First decision point (which branch was taken)
3. Data transformation (input vs output at each step)
4. Loop iteration boundaries (iteration count, values at boundaries)
5. Error handlers (what was caught, re-raised, or swallowed)

## Stage 1.5: Build a Feedback Loop (the discipline)

Before theorising about the cause, you must be able to *observe* the bug. Build a feedback loop first — a way to run the buggy code and see it fail, on demand.

### Construction methods

Pick the cheapest one that gives you a red signal:

- **Failing test** — capture the bug as a test; it fails before the fix, passes after
- **curl script** — a saved command that reproduces the API/server bug
- **CLI invocation** — the exact command with the exact inputs, saved
- **Headless browser** — a Playwright script that drives the UI to the broken state
- **Replay trace** — recorded input/log replay that hits the bug
- **Throwaway harness** — a small script that calls the function with the failing inputs
- **Property/fuzz** — a property-based test or fuzz target that finds counterexamples
- **Bisection harness** — the script `git bisect` will run (exit 0 good / non-zero bad)
- **Differential loop** — run old vs new code on the same input and diff outputs
- **HITL bash script** — a script that pauses for human confirmation at each step

### Tighten-the-loop checklist

Each iteration should make the loop:

- **Faster** — reduce setup, cache dependencies, target one module
- **Sharper signal** — the failure message should point at the root cause, not a generic error
- **More deterministic** — remove randomness, fix seeds, pin versions, remove timing dependence

### Non-deterministic bug strategy

If the bug won't reproduce reliably:

- **Raise the reproduction rate** — loop it, widen the input space, add stress
- **Parallelize** — run many instances; the one that fails is your repro
- **Stress** — increase load, memory pressure, or timing sensitivity

### Completion criterion

Done when you can name **ONE command** you have already run at least once that is:

- **red-capable** — it can fail with this bug
- **deterministic** — same input, same failure
- **fast** — you will run it many times
- **agent-runnable** — it needs no human interaction

### Gate

If you catch yourself reading code to build a theory before this command exists, STOP. Go back and build the loop.

## Stage 2: Isolate Root Cause

### Strategic Breakpoints (All Languages)

Place 2-3 breakpoints at these locations. Do NOT add more until you've inspected variables at these points:
1. **Function entry** — checks parameter values (catches wrong arguments)
2. **Loop initialization** — checks iteration bounds (catches off-by-one)
3. **Conditional branch** — checks which path executes (catches logic errors)

A focused 2-3 breakpoint approach catches 68% of bugs vs random breakpoints.

### Binary Search on Code Path

When you don't know where the bug is:
1. Insert a check (log/breakpoint) at the midpoint of the suspected code region
2. If the state is correct there → the bug is in the second half
3. If the state is already wrong → the bug is in the first half
4. Repeat until localized to a single function or line

### git bisect (Regression Detection)

When a feature worked last week but breaks today:
```bash
git bisect start
git bisect bad           # current commit is broken
git bisect good <tag>    # last known good commit
# git checks out midpoint commit
# Run test → git bisect good or git bisect bad
# Repeat ~6 times for 100 commits
git bisect reset         # exit bisect mode
```

### Hypothesis Discipline

Before testing ANY hypothesis:

1. Generate **3–5 ranked hypotheses** about the root cause — including at least one "the test/repro is wrong" hypothesis.
2. Show the ranked list to the user and get the go-ahead before testing.
3. Test them in rank order; after each test, update confidence and re-rank.

### Instrumentation Convention

When adding temporary logging/breakpoints during isolation:

- Tag every temporary log with `[DEBUG-xxxx]` (a short unique id) so it is trivially findable for removal.
- Track each `[DEBUG-xxxx]` tag in your notes. Everything tagged must be removed before handoff.
- Cleanup rule: all `[DEBUG-*]` instrumentation is removed at the end of debugging — never commit debug code.

## Language-Specific Debugging Tools

### Python

| Tool | Command / Pattern | When to use |
|---|---|---|
| `breakpoint()` | Insert `breakpoint()` in code. Disable: `PYTHONBREAKPOINT=0` | Interactive step-through |
| `python -m pdb script.py` | Run entire script under pdb | Debug from start |
| `pytest --pdb` | Test failure → pdb | Autopsy failed assertions |
| `pdb.post_mortem()` | `except: pdb.post_mortem()` | Inspect exception state |
| `logging` | `logging.debug()`, `logging.exception()` | Production debugging |
| `py-spy` | `py-spy record --pid <PID> --output flame.svg` | Frozen/CPU-bound |
| `cProfile` | `python -m cProfile -s cumulative script.py` | Performance bottlenecks |
| `PYTHONASYNCIODEBUG=1` | `set PYTHONASYNCIODEBUG=1` | Async/silent failures |

**pdb command cheat sheet:**
```
l (list)     — show code around current line
n (next)     — execute next line (don't step into)
s (step)     — step into function call
c (continue) — resume until next breakpoint
p <var>      — print variable value
pp <var>     — pretty-print variable
w (where)    — show call stack
u (up)       — move up stack frame
d (down)     — move down stack frame
b <line>     — set breakpoint at line
b <line>, <condition> — conditional breakpoint
q (quit)     — exit debugger
```

### JavaScript / TypeScript

| Tool | Command / Pattern | When to use |
|---|---|---|
| **Chrome DevTools** | Sources tab → breakpoint → step-through | Browser debugging |
| `node --inspect-brk` | `node --inspect-brk script.js` → visit `chrome://inspect` | Node.js debugging |
| `debugger;` | Place `debugger;` statement in code | Breakpoint in code |
| `console.log()` | `console.log()`, `.table()`, `.trace()`, `.assert()` | Quick inspection |
| **React DevTools** | Browser extension | Component state/props |
| **Bun inspect** | `bun --inspect script.ts` | Bun runtime |

**Node debugging pattern:**
```bash
node --inspect-brk script.js
# Terminal prints: Debugger listening on ws://127.0.0.1:9229/...
# Open Chrome → chrome://inspect → click "Open dedicated DevTools for Node"
```

**console alternatives:**
```javascript
console.log({ variable })              // auto-named object
console.table(array)                   // tabular data
console.trace()                        // stack trace at this point
console.assert(condition, "message")   // conditional logging
console.group("Section") / .groupEnd() // grouped output
```

### Rust

| Tool | Command / Pattern | When to use |
|---|---|---|
| `dbg!()` | `dbg!(expr)` — prints file:line:expr=value AND returns value | Ad-hoc value inspection |
| `rust-gdb` / `rust-lldb` | `rust-gdb ./target/debug/binary` | Full step-through debugger |
| **CodeLLDB** (VS Code) | F5 with launch config | Visual debugging |
| `RUST_BACKTRACE=1` | `set RUST_BACKTRACE=1` (add to `.cargo/config.toml`) | Panic call stack |
| `cargo-flamegraph` | `cargo flamegraph` | CPU profiling |
| `tokio-console` | `tokio-console` | Async task inspection |

**Key Rust debugging idioms:**
- `#[derive(Debug)]` is required for `dbg!()` — add it to all types
- `debug_assert!(condition)` — checked in debug builds, compiled out of release
- Integer overflow panics in debug builds but wraps silently in release
- Clippy lint `#![deny(clippy::dbg_macro)]` catches stray `dbg!()` in commits
- `$env:RUST_BACKTRACE=1` in PowerShell, `export RUST_BACKTRACE=1` on Linux

### C++

| Tool | Command / Pattern | When to use |
|---|---|---|
| **GDB** | `gdb ./binary` → `break`, `run`, `next`, `step`, `print`, `backtrace` | Full debugging |
| **LLDB** | `lldb ./binary` | LLVM/macOS debugging |
| **Valgrind** | `valgrind --leak-check=full ./binary` | Memory leaks, use-after-free |
| **AddressSanitizer** | Compile `-fsanitize=address` | Memory safety (2x overhead) |
| **ThreadSanitizer** | Compile `-fsanitize=thread` | Data races in multithreaded code |
| **UBSan** | Compile `-fsanitize=undefined` | Undefined behavior |

**GDB essential commands:**
```
break <file>:<line>   — set breakpoint
run                   — start program
next                  — next line (step over)
step                  — step into function
print <expr>          — evaluate expression
backtrace             — show call stack
info locals           — show all local variables
frame <N>             — select stack frame N
continue              — resume execution
quit                  — exit GDB
```

**Sanitizers in CMake:**
```cmake
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -fsanitize=address -fsanitize=undefined -fno-omit-frame-pointer")
set(CMAKE_LINKER_FLAGS_DEBUG "${CMAKE_LINKER_FLAGS_DEBUG} -fsanitize=address -fsanitize=undefined")
```

## Debugging Anti-Patterns

1. **Shotgun debugging** — changing random things hoping the bug goes away. Instead: form one specific hypothesis before each code change.
2. **Confirmation bias** — looking only for evidence supporting your theory. Actively try to disprove your hypothesis.
3. **Stopping at the first "why"** — the first answer is usually a symptom. Keep asking "why" until you reach a systemic cause.
4. **Print-only debugging** — `print()` / `console.log()` / `println!()` scatter. Use interactive debuggers for complex bugs.
5. **Committing debug code** — `pdb.set_trace()`, `dbg!()`, stray `console.log()`. Use `PYTHONBREAKPOINT=0`, Clippy lint, or ESLint to catch these.
6. **Debugging without a reproducer** — if you can't reproduce it deterministically, you can't fix it. Spend the first 10 minutes building a minimal reproducer.
7. **Fixing symptoms, not root causes** — if the same bug recurs, you need RCA (5-Whys / Fishbone) to find the systemic cause.

## After Debugging

1. **Remove all debug code** — breakpoints, dbg!(), temporary logging, debugger statements
2. **Write a regression test** — it should fail without the fix and pass with it
3. **Document the root cause** — what was the bug, what was the fix, how was it found
4. **Notify the @analyzer** if the root cause reveals a systemic issue — RCA may prevent future bugs

## Stage 5: Implement & Verify

Apply the minimum fix, write the regression test, and verify no regressions.

### The correct test seam

When verifying, check that the regression test sits at a **meaningful seam** — the public boundary at which the buggy behaviour is observable. If the only available test seam is too shallow (you have to reach into internals, mock the unit under test, or the test can't express the original failure), **that itself is the finding**: the architecture lacks an observable boundary, and the fix should include creating one. Do not paper over it with an invasive test.

## Stage 6: Cleanup + Post-mortem

Before declaring the fix done:

1. **Original repro no longer reproduces** — run the Stage 1.5 feedback-loop command and confirm it is now green.
2. **All `[DEBUG-*]` instrumentation removed** — every tagged log/breakpoint from Stage 2 is gone. Grep for `DEBUG-` to confirm.
3. **Throwaway prototypes deleted** — harnesses, scratch scripts, and temp files created during debugging are removed (or moved to a clearly-labelled scratch area if genuinely reusable).
4. **Post-mortem** — write down what would have prevented this bug: a missing test? a missing invariant? a tooling gap? If the root cause reveals a systemic issue, notify @analyzer for RCA.
