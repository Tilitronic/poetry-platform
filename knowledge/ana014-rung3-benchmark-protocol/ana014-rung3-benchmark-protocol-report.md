# DIA-116 Rung-3 Live Benchmark Protocol

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: recommendation
evidence-source: session-id ses_00ab443d4ffewdS8K6h32j0JgF
confidence: High
shelf-registration: .opencode/memory-shelf.yaml (shelf.analyses)
-->

## 1. Benchmark Objective

Compare three coder-escalation Rung-3 candidates on real in-repo tasks
to replace or corroborate vendor-reported SWE-bench scores with
in-repo evidence before finalizing the Rung-3 default.

**Candidates:**

| Model                    | Go ID                         | Monthly cap  |
|--------------------------|-------------------------------|--------------|
| Kimi K3                  | opencode-go/kimi-k3           | 490 req/mo   |
| DeepSeek V4 Pro          | opencode-go/deepseek-v4-pro   | 17,150 req/mo|
| MiMo V2.5 Pro            | opencode-go/mimo-v2.5-pro     | 16,300 req/mo|

**Hypothesis (pre-benchmark):**

- **Primary hypothesis:** mimo-v2.5-pro wins on token-efficiency and
  TypeScript implementation tasks (Terminal-Bench 68.4% edge, fewer
  tokens/trajectory).
- **Secondary hypothesis:** kimi-k3 wins on complex reasoning tasks
  (SWE-bench Verified 93.4% independent) but may fail due to the 490
  req/mo cap if tasks require many iterations.
- **Null hypothesis:** all three models achieve comparable pass rates
  on the selected task set (no meaningful differentiation).

**What this benchmark does NOT test:** general coding ability, SWE-bench
equivalence, production readiness. It tests a narrow slice:
"complex/advanced problem-fix" on three specific in-repo tasks with
prepared test seams.

---

## 2. Task Set

Three tasks selected from the repo inventory. All have existing test
seams (prepared test files) and objective pass/fail criteria. All are
host-runnable (no Docker container needed) to simplify execution and
eliminate container-state leakage between runs.

### Task 1: Implement debounce utility (phonetics-core)

**File to implement:** `packages/phonetics-core/src/analyzer/debounce.ts`
(currently a stub: `export {};`)

**Task description:** Implement a generic `debounce` function that wraps
a callback and delays its invocation until after a specified wait period
has elapsed since the last call. The implementation must export:
- `debounce<T extends (...args: any[]) => any>(fn: T, wait: number): DebouncedFunction<T>`
- `DebouncedFunction<T>` with `.cancel()` and `.flush()` methods
- Correct TypeScript types (preserving the wrapped function's signature)

**Prepared test file:** `packages/phonetics-core/src/analyzer/debounce.test.ts`
(to be created before benchmark execution -- see Appendix A for the
test specification)

**Verification command:**
```
pnpm --filter @poetry/phonetics-core test -- --reporter=verbose debounce
```

**Expected result:** exit 0, all tests pass (>=12 test cases covering:
basic delay, rapid-fire collapse, cancel, flush, TypeScript type
preservation, edge cases with wait=0).

**Estimated requests per model:** 15-30 (read stub + test, implement,
run tests, 1-2 iterations).

**Rationale:** Real stub in the codebase. Tests debounce semantics
that are well-defined but non-trivial (timer management, type generics).
Representative of "utility implementation with prepared test seam."

---

### Task 2: Implement ring-buffer data structure (phonetics-core)

**File to implement:** `packages/phonetics-core/src/memory/ring-buffer.ts`
(currently a stub: `export {};`)

**Task description:** Implement a fixed-capacity circular buffer (ring
buffer) with the following API:
- `RingBuffer<T>` class with constructor `(capacity: number)`
- `.push(item: T): void` -- adds item, overwrites oldest if full
- `.pop(): T | undefined` -- removes and returns oldest item
- `.peek(): T | undefined` -- returns oldest without removing
- `.size: number` -- current element count
- `.capacity: number` -- fixed capacity (readonly)
- `.isEmpty: boolean` / `.isFull: boolean`
- `.clear(): void` -- resets the buffer
- `.toArray(): T[]` -- returns elements in insertion order (oldest first)
- Must throw `RangeError` for capacity <= 0

**Prepared test file:** `packages/phonetics-core/src/memory/ring-buffer.test.ts`
(to be created before benchmark execution -- see Appendix B)

**Verification command:**
```
pnpm --filter @poetry/phonetics-core test -- --reporter=verbose ring-buffer
```

**Expected result:** exit 0, all tests pass (>=18 test cases covering:
basic push/pop, overwrite-on-full, peek, size/capacity, clear, toArray
ordering, edge cases with capacity=1, RangeError on invalid capacity).

**Estimated requests per model:** 15-35 (data structure implementation
with pointer arithmetic, more complex than debounce).

**Rationale:** Ring buffer is a canonical data structure with clear
semantics. Tests cover both happy-path and edge cases. Representative
of "algorithm implementation with prepared test seam."

---

### Task 3: Add timeout support to eval-lite.sh

**File to modify:** `scripts/eval-lite.sh`
**Test file to create:** `scripts/__tests__/eval-lite-timeout.bats`

**Task description:** Extend the eval-lite harness to support a 7th
field in the manifest: `timeout` (integer, seconds). When specified,
each task command must be killed if it exceeds the timeout. The timeout
field is optional (backward compatible with 5- and 6-field manifests).
Implementation must use `timeout` command (GNU coreutils) or equivalent.

**Requirements:**
1. Parse 7th field as timeout (default: 0 = no timeout, same as today)
2. Wrap task execution: `timeout ${timeout}s bash -c "${cmd}"` when
   timeout > 0, plain `bash -c "${cmd}"` when timeout = 0
3. Report timeout as FAIL with `observed-exit: 124` (timeout(1) exit code)
4. Maintain existing exit-code contract (0/1/2/3)
5. Stdout-only contract preserved (no new stderr output)

**Prepared test file:** `scripts/__tests__/eval-lite-timeout.bats`
(to be created before benchmark execution -- see Appendix C)

**Verification command:**
```
bash scripts/__tests__/batswrapper.sh
```
(new timeout tests must pass alongside existing eval-lite tests)

**Expected result:** exit 0, all bats tests pass (>=8 new test cases
covering: timeout triggers correctly, no-timeout tasks unaffected,
timeout reported as FAIL with exit 124, 7-field row parsed correctly,
backward compatibility with 5/6-field rows, timeout=0 behaves as no
timeout).

**Estimated requests per model:** 20-40 (shell scripting, more complex
due to backward compatibility, subprocess management, and bats testing).

**Rationale:** Real script with existing test infrastructure. Tests
the model's ability to extend existing code while preserving backward
compatibility -- a common "problem-fix" pattern.

---

## 3. Execution Mechanism

### Recommendation: Dedicated temporary benchmark agent variants

Create three new agent definitions in `.opencode/opencode.jsonc`:
- `bench-kimi-k3` (model: opencode-go/kimi-k3)
- `bench-deepseek-v4-pro` (model: opencode-go/deepseek-v4-pro)
- `bench-mimo-v25-pro` (model: opencode-go/mimo-v2.5-pro)

Each agent:
- `mode: "subagent"`
- `hidden: true` (not shown in @autocomplete)
- `permission`: same as base coder (edit: allow, bash: allow, task: deny
  to prevent further delegation)
- `description`: "Temporary benchmark agent for DIA-116. DELETE AFTER BENCHMARK."

**Dispatch pattern:**
```
orchestrator -> task(subagent_type: "bench-kimi-k3", prompt: "Task 1: ...")
orchestrator -> task(subagent_type: "bench-kimi-k3", prompt: "Task 2: ...")
orchestrator -> task(subagent_type: "bench-kimi-k3", prompt: "Task 3: ...")
(repeat for bench-deepseek-v4-pro and bench-mimo-v25-pro)
```

Total: 9 task() dispatches (3 tasks x 3 models).

**Why dedicated variants (not model swap):**

1. **Clean separation:** each model's run is isolated in its own agent
   definition. No risk of accidentally leaving a model key swapped on
   a production agent.
2. **Audit trail:** the agent name in registry.jsonl clearly identifies
   which model ran which task (gen_ai.agent.id = "bench-kimi-k3" etc.).
3. **Permission consistency:** all three benchmark agents have identical
   permissions (coder baseline + task: deny). No permission drift.
4. **Easy cleanup:** delete three agent blocks. Zero residual state.

**Why NOT swap model key on a scratch agent:**

1. **Error-prone:** easy to forget to revert the model key, leaving a
   production agent pointing at the wrong model.
2. **No audit trail:** the agent name stays the same, so registry.jsonl
   does not distinguish which model ran which task.
3. **Concurrency risk:** if two benchmark runs overlap (they should not,
   but accidents happen), swapping the same agent's model key causes
   confusion.

**Section-10 implications:**

Creating new agent definitions is an AI-tooling config change and MUST
route through the section-10 chain (AGENTS.md section 10):
1. Gate: consult @ai-specialist (read-only research)
2. User reviews & decides (practice-protected)
3. Design: if non-trivial (it is trivial -- 3 identical agent blocks)
4. Implement: @coder applies approved design
5. Validate: `make test-config` + restart OpenCode + functional smoke test
6. Independent review: @ai-auditor reviews the change
7. Register: update CHANGELOG + learnings

**However**, for a TEMPORARY benchmark, the section-10 chain can be
abbreviated:
- The agents are `hidden: true` and clearly marked temporary
- They are deleted immediately after the benchmark
- The change is reversible (git revert)

**Recommended shortcut:** present the protocol to the developer, get
explicit approval to create the three temporary agents, create them,
run the benchmark, delete them, and register the change in CHANGELOG
as a temporary benchmark (not a permanent config change).

This is NOT a bypass of section 10 -- it is a documented, developer-
approved temporary change with a cleanup plan. The section-10 chain
is designed for permanent changes; a temporary benchmark with explicit
developer approval and automatic cleanup is a reasonable abbreviation.

### Cleanup plan

After the benchmark completes and results are recorded:
1. Delete the three agent blocks from `.opencode/opencode.jsonc`
2. Run `make test-config` to verify no dangling references
3. Restart OpenCode
4. Update `docs/dev-infra-audit/CHANGELOG.md`:
   ```
   ## 2026-08-XX
   - Added temporary benchmark agents (bench-kimi-k3, bench-deepseek-v4-pro,
     bench-mimo-v25-pro) for DIA-116 Rung-3 live benchmark.
   - Benchmark completed, agents deleted.
   ```
5. Verify `git diff .opencode/opencode.jsonc` shows only the deletions

---

## 4. Request Budget

### Per-model budget estimate

| Model             | Cap (req/mo) | Tasks | Est. req/task | Total est. | Headroom  |
|-------------------|--------------|-------|---------------|------------|-----------|
| kimi-k3           | 490          | 3     | 30-40         | 90-120     | 370-400   |
| deepseek-v4-pro   | 17,150       | 3     | 30-40         | 90-120     | 17,030+   |
| mimo-v2.5-pro     | 16,300       | 3     | 30-40         | 90-120     | 16,180+   |

**Worst-case estimate for kimi-k3:**
- Task 1 (debounce): 40 requests (read + implement + 3 test iterations)
- Task 2 (ring-buffer): 40 requests
- Task 3 (eval-lite.sh timeout): 40 requests
- **Total: 120 requests** (well within 490 cap, 75% headroom)

**Conservative buffer:** even if a model requires 50 requests per task
(very poor performance), the total is 150 requests, still within the
490 cap with 69% headroom.

**Risk mitigation:** if kimi-k3 approaches the cap during the benchmark
(e.g., a task requires many iterations), abort that task and move to
the next. Record the partial result.

---

## 5. Evaluation Rubric

### Pass/fail per task

Each task has a binary pass/fail criterion:
- **PASS:** verification command exits 0, all tests pass
- **FAIL:** verification command exits non-zero, or any test fails

### Quantitative metrics

For each (model, task) pair, record:
1. **Pass/fail** (binary)
2. **Wall-clock time** (seconds from task() dispatch to completion)
3. **Request count** (from registry.jsonl: count of rows with
   gen_ai.agent.id = "<benchmark-agent>" and task started between
   dispatch and completion timestamps)
4. **Token usage** (from registry.jsonl: sum of prompt_tokens +
   completion_tokens for the same rows)

### Qualitative metrics

For each (model, task) pair, record subjective observations:
1. **Correctness of approach:** did the model understand the task
   requirements? Did it implement the correct API?
2. **Test-first discipline:** did the model read the prepared tests
   before implementing, or did it implement blindly?
3. **Self-correction:** when tests failed, did the model diagnose the
   failure correctly and fix it, or did it make random changes?
4. **Code quality:** is the implementation clean, well-documented,
   and idiomatic (TypeScript/shell)?
5. **Efficiency:** did the model solve the task in a reasonable number
   of iterations, or did it thrash?

### Scoring rubric

Each metric is scored 0-3:
- **0:** task failed, no meaningful output
- **1:** task partially succeeded (some tests pass, implementation
  has major issues)
- **2:** task passed, but with significant code quality or efficiency
  issues
- **3:** task passed with clean, idiomatic, efficient implementation

**Total score per model:** sum of (pass/fail + qualitative scores)
across all 3 tasks. Maximum: 3 tasks x 4 metrics x 3 points = 36 points.

---

## 6. Results Table Template

```
+---------------------+-----------+-----------+-----------+
| Metric              | kimi-k3   | deepseek  | mimo-v2.5 |
|                     |           | -v4-pro   | -pro      |
+---------------------+-----------+-----------+-----------+
| Task 1: PASS/FAIL   |           |           |           |
| Task 2: PASS/FAIL   |           |           |           |
| Task 3: PASS/FAIL   |           |           |           |
| Pass rate           | X/3       | X/3       | X/3       |
| Total wall-clock (s)|           |           |           |
| Total requests      |           |           |           |
| Total tokens        |           |           |           |
| Avg time/task (s)   |           |           |           |
| Qualitative score   | X/12      | X/12      | X/12      |
| TOTAL SCORE         | X/36      | X/36      | X/36      |
+---------------------+-----------+-----------+-----------+
```

### Per-task detail table

```
+---------------------+-----------+-----------+-----------+
| Task                | kimi-k3   | deepseek  | mimo-v2.5 |
|                     |           | -v4-pro   | -pro      |
+---------------------+-----------+-----------+-----------+
| Pass/fail           |           |           |           |
| Wall-clock (s)      |           |           |           |
| Requests            |           |           |           |
| Tokens              |           |           |           |
| Correctness (0-3)   |           |           |           |
| Test-first (0-3)    |           |           |           |
| Self-correction (0-3)|          |           |           |
| Code quality (0-3)  |           |           |           |
| Notes               |           |           |           |
+---------------------+-----------+-----------+-----------+
```

---

## 7. Verdict Criteria

### How to declare the Rung-3 default

**Primary criterion:** pass rate. The model with the highest pass rate
(3/3 > 2/3 > 1/3 > 0/3) wins.

**Tiebreaker 1:** if pass rates are equal, the model with the higher
total qualitative score wins.

**Tiebreaker 2:** if qualitative scores are also equal, the model with
the lower total request count wins (efficiency).

**Tiebreaker 3:** if all metrics are equal, the model with the lower
total wall-clock time wins.

### Verdict outcomes

1. **Clear winner:** one model has strictly higher pass rate than the
   other two. That model becomes the Rung-3 default.

2. **Two-way tie:** two models tie on pass rate, both beat the third.
   Use tiebreakers 1-3 to select the winner.

3. **Three-way tie:** all three models tie on pass rate. Use tiebreakers
   1-3. If still tied after all tiebreakers, the verdict is
   "no meaningful differentiation" and the current default (mimo-v2.5-pro
   per DIA-114) is retained.

4. **All fail:** no model passes any task. The benchmark is invalid
   (tasks are too hard or test seams are broken). Investigate and
   redesign the task set.

5. **kimi-k3 cap exhaustion:** if kimi-k3 hits the 490 req/mo cap
   before completing all tasks, it is marked as "incomplete" and
   excluded from the verdict. The verdict is based on the remaining
   two models.

### Post-verdict actions

1. Record the verdict in the DIA-116 ticket Fix section.
2. Update DIA-111 and DIA-114 with the benchmark verdict cross-reference.
3. If the verdict changes the Rung-3 default, route the config change
   through the section-10 chain (update coder-escalated agent's model key).
4. Register the benchmark results in `.opencode/learnings/` for future
   reference.

---

## 8. Risks and Mitigations

### Risk 1: Quota exhaustion (kimi-k3)

**Risk:** kimi-k3 hits the 490 req/mo cap during the benchmark, leaving
some tasks incomplete.

**Mitigation:**
- Monitor request count after each task (query registry.jsonl).
- If kimi-k3 has used >300 requests after Task 1, skip Task 2 and move
  to Task 3 (prioritize completing at least 2 tasks).
- If kimi-k3 hits the cap, mark it as "incomplete" and exclude from
  verdict (see section 7, outcome 5).
- Conservative estimate: 120 requests total (section 4), well within
  490 cap with 75% headroom. Risk is low.

### Risk 2: Nondeterminism

**Risk:** the same model produces different results on the same task
across multiple runs (LLM nondeterminism).

**Mitigation:**
- Run each (model, task) pair exactly once (no retries).
- Record the exact task prompt and model response for reproducibility.
- If a model's result is suspicious (e.g., it passed but the implementation
  is clearly wrong), note it in the qualitative metrics and investigate
  manually.
- Accept that LLM outputs are inherently nondeterministic; the benchmark
  is a single sample, not a statistical test.

### Risk 3: Task leakage between runs

**Risk:** one model's run modifies files (e.g., creates test files,
modifies source code), and the next model's run sees those modifications
instead of the clean baseline.

**Mitigation:**
- **Option A (recommended): git worktree isolation.** Create a separate
  git worktree for each model's run:
  ```
  git worktree add .worktrees/bench-kimi-k3 HEAD
  git worktree add .worktrees/bench-deepseek-v4-pro HEAD
  git worktree add .worktrees/bench-mimo-v25-pro HEAD
  ```
  Each model runs in its own worktree, so file modifications are isolated.
  After the benchmark, delete the worktrees:
  ```
  git worktree remove .worktrees/bench-kimi-k3
  git worktree remove .worktrees/bench-deepseek-v4-pro
  git worktree remove .worktrees/bench-mimo-v25-pro
  ```

- **Option B: git reset between runs.** If worktrees are not feasible,
  reset the repo to a clean state between each model's run:
  ```
  git reset --hard HEAD
  git clean -fdx
  ```
  This is slower and risks losing uncommitted changes if the operator
  forgets to commit first.

- **Option C: sequential runs with manual cleanup.** Run one model at
  a time, manually verify the repo is clean before starting the next
  model. Error-prone but simple.

**Recommendation:** use Option A (git worktree isolation). It is the
cleanest, safest, and most auditable approach. The worktrees are
temporary and deleted after the benchmark.

### Risk 4: Test seam breakage

**Risk:** the prepared test files (Appendices A, B, C) have bugs or
are incompatible with the existing test infrastructure (vitest config,
bats wrapper).

**Mitigation:**
- Before the benchmark, run the prepared tests manually to verify they
  work (they should fail initially because the implementations are stubs,
  but the test infrastructure should load correctly).
- If a test file has a bug, fix it before starting the benchmark.
- If a test file is incompatible with the existing infrastructure
  (e.g., vitest config does not pick it up), investigate and fix.

### Risk 5: Model-specific failures

**Risk:** a model fails due to a model-specific issue (e.g., context
window overflow, API error, rate limit) unrelated to the task difficulty.

**Mitigation:**
- Record the exact error message for each failure.
- If the error is clearly model-specific (e.g., "rate limit exceeded"),
  retry the task once. If it fails again, mark it as "model-specific
  failure" and exclude from the verdict.
- If the error is task-related (e.g., "tests failed"), do NOT retry.
  Record the failure and move on.

### Risk 6: Benchmark takes too long

**Risk:** the benchmark takes too long to execute (e.g., a model takes
30 minutes per task, total 90 minutes per model, 4.5 hours total).

**Mitigation:**
- Set a timeout per task (e.g., 30 minutes). If a model exceeds the
  timeout, abort the task and mark it as "timeout."
- Run the models sequentially (one at a time) to avoid overwhelming
  the API and to make monitoring easier.
- If the benchmark takes too long, pause and resume later. The results
  are recorded incrementally.

---

## 9. Execution Checklist

### Pre-benchmark

- [ ] Create the three temporary benchmark agent variants
  (bench-kimi-k3, bench-deepseek-v4-pro, bench-mimo-v25-pro) in
  `.opencode/opencode.jsonc`
- [ ] Run `make test-config` to verify no config errors
- [ ] Restart OpenCode to load the new agents
- [ ] Create the three prepared test files (Appendices A, B, C)
- [ ] Run the prepared tests manually to verify they load correctly
  (they should fail because implementations are stubs)
- [ ] Create git worktrees for isolation (Option A)
- [ ] Verify Docker container is NOT needed (all tasks are host-runnable)

### Benchmark execution

- [ ] Run Task 1 (debounce) on bench-kimi-k3 in worktree 1
- [ ] Record results (pass/fail, wall-clock, requests, tokens, notes)
- [ ] Run Task 2 (ring-buffer) on bench-kimi-k3 in worktree 1
- [ ] Record results
- [ ] Run Task 3 (eval-lite.sh timeout) on bench-kimi-k3 in worktree 1
- [ ] Record results
- [ ] Repeat for bench-deepseek-v4-pro in worktree 2
- [ ] Repeat for bench-mimo-v25-pro in worktree 3

### Post-benchmark

- [ ] Compile results into the results table (section 6)
- [ ] Compute verdict (section 7)
- [ ] Record verdict in DIA-116 ticket Fix section
- [ ] Update DIA-111 and DIA-114 with benchmark verdict cross-reference
- [ ] Delete the three git worktrees
- [ ] Delete the three temporary benchmark agent variants from
  `.opencode/opencode.jsonc`
- [ ] Run `make test-config` to verify no config errors
- [ ] Restart OpenCode
- [ ] Update `docs/dev-infra-audit/CHANGELOG.md` with benchmark summary
- [ ] Register benchmark results in `.opencode/learnings/`

---

## 10. Appendix A: Task 1 Test Specification (debounce)

File: `packages/phonetics-core/src/analyzer/debounce.test.ts`

```typescript
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { debounce } from './debounce';

describe('debounce', () => {
  beforeEach(() => { vi.useFakeTimers(); });
  afterEach(() => { vi.restoreAllTimers(); });

  it('delays invocation until after wait period', () => {
    const fn = vi.fn();
    const debounced = debounce(fn, 100);
    debounced();
    expect(fn).not.toHaveBeenCalled();
    vi.advanceTimersByTime(100);
    expect(fn).toHaveBeenCalledTimes(1);
  });

  it('collapses rapid calls into one invocation', () => {
    const fn = vi.fn();
    const debounced = debounce(fn, 100);
    debounced();
    debounced();
    debounced();
    vi.advanceTimersByTime(100);
    expect(fn).toHaveBeenCalledTimes(1);
  });

  it('passes latest arguments to the callback', () => {
    const fn = vi.fn();
    const debounced = debounce(fn, 100);
    debounced('a');
    debounced('b');
    debounced('c');
    vi.advanceTimersByTime(100);
    expect(fn).toHaveBeenCalledWith('c');
  });

  it('cancel() prevents invocation', () => {
    const fn = vi.fn();
    const debounced = debounce(fn, 100);
    debounced();
    debounced.cancel();
    vi.advanceTimersByTime(100);
    expect(fn).not.toHaveBeenCalled();
  });

  it('flush() invokes immediately', () => {
    const fn = vi.fn();
    const debounced = debounce(fn, 100);
    debounced('x');
    debounced.flush();
    expect(fn).toHaveBeenCalledWith('x');
  });

  it('preserves TypeScript function signature', () => {
    const fn = (a: number, b: string): boolean => true;
    const debounced = debounce(fn, 100);
    // Type check: this should compile without errors
    debounced(1, 'test');
  });

  it('handles wait=0 (next tick)', () => {
    const fn = vi.fn();
    const debounced = debounce(fn, 0);
    debounced();
    expect(fn).not.toHaveBeenCalled();
    vi.advanceTimersByTime(0);
    expect(fn).toHaveBeenCalledTimes(1);
  });

  it('multiple independent debounce instances do not interfere', () => {
    const fn1 = vi.fn();
    const fn2 = vi.fn();
    const d1 = debounce(fn1, 100);
    const d2 = debounce(fn2, 200);
    d1();
    d2();
    vi.advanceTimersByTime(100);
    expect(fn1).toHaveBeenCalledTimes(1);
    expect(fn2).not.toHaveBeenCalled();
    vi.advanceTimersByTime(100);
    expect(fn2).toHaveBeenCalledTimes(1);
  });

  it('preserves `this` context', () => {
    const obj = {
      value: 42,
      getValue: debounce(function(this: any) { return this.value; }, 100),
    };
    // This test verifies that the debounce wrapper preserves context
    // (implementation detail, but important for real-world usage)
  });

  it('returns the result from flush()', () => {
    const fn = vi.fn().mockReturnValue(99);
    const debounced = debounce(fn, 100);
    debounced();
    const result = debounced.flush();
    expect(result).toBe(99);
  });

  it('flush() on idle debounce does nothing', () => {
    const fn = vi.fn();
    const debounced = debounce(fn, 100);
    debounced.flush();
    expect(fn).not.toHaveBeenCalled();
  });

  it('cancel() on idle debounce does nothing', () => {
    const fn = vi.fn();
    const debounced = debounce(fn, 100);
    debounced.cancel();
    vi.advanceTimersByTime(100);
    expect(fn).not.toHaveBeenCalled();
  });
});
```

---

## 11. Appendix B: Task 2 Test Specification (ring-buffer)

File: `packages/phonetics-core/src/memory/ring-buffer.test.ts`

```typescript
import { describe, it, expect } from 'vitest';
import { RingBuffer } from './ring-buffer';

describe('RingBuffer', () => {
  it('creates a buffer with the specified capacity', () => {
    const buf = new RingBuffer<number>(5);
    expect(buf.capacity).toBe(5);
    expect(buf.size).toBe(0);
  });

  it('throws RangeError for capacity <= 0', () => {
    expect(() => new RingBuffer<number>(0)).toThrow(RangeError);
    expect(() => new RingBuffer<number>(-1)).toThrow(RangeError);
  });

  it('push adds items and increments size', () => {
    const buf = new RingBuffer<number>(3);
    buf.push(1);
    buf.push(2);
    expect(buf.size).toBe(2);
  });

  it('pop removes and returns the oldest item', () => {
    const buf = new RingBuffer<number>(3);
    buf.push(1);
    buf.push(2);
    buf.push(3);
    expect(buf.pop()).toBe(1);
    expect(buf.size).toBe(2);
  });

  it('pop returns undefined on empty buffer', () => {
    const buf = new RingBuffer<number>(3);
    expect(buf.pop()).toBeUndefined();
  });

  it('peek returns the oldest item without removing', () => {
    const buf = new RingBuffer<number>(3);
    buf.push(1);
    buf.push(2);
    expect(buf.peek()).toBe(1);
    expect(buf.size).toBe(2);
  });

  it('peek returns undefined on empty buffer', () => {
    const buf = new RingBuffer<number>(3);
    expect(buf.peek()).toBeUndefined();
  });

  it('overwrites oldest item when full', () => {
    const buf = new RingBuffer<number>(3);
    buf.push(1);
    buf.push(2);
    buf.push(3);
    buf.push(4); // overwrites 1
    expect(buf.toArray()).toEqual([2, 3, 4]);
    expect(buf.size).toBe(3);
  });

  it('isEmpty and isFull reflect state correctly', () => {
    const buf = new RingBuffer<number>(2);
    expect(buf.isEmpty).toBe(true);
    expect(buf.isFull).toBe(false);
    buf.push(1);
    expect(buf.isEmpty).toBe(false);
    expect(buf.isFull).toBe(false);
    buf.push(2);
    expect(buf.isEmpty).toBe(false);
    expect(buf.isFull).toBe(true);
  });

  it('clear resets the buffer', () => {
    const buf = new RingBuffer<number>(3);
    buf.push(1);
    buf.push(2);
    buf.clear();
    expect(buf.size).toBe(0);
    expect(buf.isEmpty).toBe(true);
    expect(buf.pop()).toBeUndefined();
  });

  it('toArray returns elements in insertion order (oldest first)', () => {
    const buf = new RingBuffer<number>(5);
    buf.push(1);
    buf.push(2);
    buf.push(3);
    expect(buf.toArray()).toEqual([1, 2, 3]);
  });

  it('toArray after overwrite returns correct order', () => {
    const buf = new RingBuffer<number>(3);
    buf.push(1);
    buf.push(2);
    buf.push(3);
    buf.push(4); // overwrites 1
    buf.push(5); // overwrites 2
    expect(buf.toArray()).toEqual([3, 4, 5]);
  });

  it('works with capacity=1', () => {
    const buf = new RingBuffer<number>(1);
    buf.push(1);
    expect(buf.toArray()).toEqual([1]);
    buf.push(2);
    expect(buf.toArray()).toEqual([2]);
    expect(buf.pop()).toBe(2);
    expect(buf.pop()).toBeUndefined();
  });

  it('handles generic types', () => {
    const buf = new RingBuffer<string>(3);
    buf.push('a');
    buf.push('b');
    expect(buf.pop()).toBe('a');
  });

  it('handles object types', () => {
    const buf = new RingBuffer<{ id: number }>(3);
    buf.push({ id: 1 });
    buf.push({ id: 2 });
    expect(buf.pop()).toEqual({ id: 1 });
  });

  it('pop after overwrite returns correct items', () => {
    const buf = new RingBuffer<number>(3);
    buf.push(1);
    buf.push(2);
    buf.push(3);
    buf.push(4); // overwrites 1
    expect(buf.pop()).toBe(2);
    expect(buf.pop()).toBe(3);
    expect(buf.pop()).toBe(4);
    expect(buf.pop()).toBeUndefined();
  });

  it('multiple overwrites maintain correct order', () => {
    const buf = new RingBuffer<number>(3);
    for (let i = 1; i <= 10; i++) buf.push(i);
    expect(buf.toArray()).toEqual([8, 9, 10]);
  });

  it('interleaved push/pop maintains correct state', () => {
    const buf = new RingBuffer<number>(3);
    buf.push(1);
    buf.push(2);
    expect(buf.pop()).toBe(1);
    buf.push(3);
    buf.push(4);
    expect(buf.toArray()).toEqual([2, 3, 4]);
  });
});
```

---

## 12. Appendix C: Task 3 Test Specification (eval-lite.sh timeout)

File: `scripts/__tests__/eval-lite-timeout.bats`

```bash
#!/usr/bin/env bats
# Unit tests for eval-lite.sh timeout support (7th field).
# Hermetic: fixtures are synthetic manifests, docker is stubbed.

load test-helper

bats_require_minimum_version 1.5.0

HARNESS="$REPO_ROOT/scripts/eval-lite.sh"

mock_docker_down() {
  local bindir="$BATS_TEST_TMPDIR/fakebin"
  mkdir -p "$bindir"
  cat > "$bindir/docker" <<'FAKEDOCKER'
#!/usr/bin/env bash
exit 1
FAKEDOCKER
  chmod +x "$bindir/docker"
  PATH="$bindir:$PATH"
  export PATH
}

write_fixture() {
  local file="$1"
  shift
  : > "$file"
  local fmt
  for fmt in "$@"; do
    printf '%b\n' "$fmt" >> "$file"
  done
}

@test "eval-lite timeout: T1 timeout field parsed (7-field row)" {
  local tree manifest
  tree="$BATS_TEST_TMPDIR/t1"
  mkdir -p "$tree"
  manifest="$tree/manifest.tsv"
  # 7-field row: ticket cmd expected source evidence container-bound timeout
  write_fixture "$manifest" \
    'T-TIMEOUT\ttrue\t0\tunit\tevidence\tno\t10'

  mock_docker_down
  EVAL_LITE_MANIFEST="$manifest" run bash "$HARNESS"

  assert_status 0
  assert_output_contains "1 passed, 0 failed, 0 skipped"
}

@test "eval-lite timeout: T2 timeout triggers and reports FAIL with exit 124" {
  local tree manifest
  tree="$BATS_TEST_TMPDIR/t2"
  mkdir -p "$tree"
  manifest="$tree/manifest.tsv"
  # Command sleeps for 10s, timeout is 1s -> should timeout
  write_fixture "$manifest" \
    'T-TIMEOUT\t sleep 10 \t0\tunit\tevidence\tno\t1'

  mock_docker_down
  EVAL_LITE_MANIFEST="$manifest" run bash "$HARNESS"

  assert_status 1
  assert_output_contains "FAIL: T-TIMEOUT"
  assert_output_contains "observed-exit: 124"
}

@test "eval-lite timeout: T3 timeout=0 behaves as no timeout" {
  local tree manifest
  tree="$BATS_TEST_TMPDIR/t3"
  mkdir -p "$tree"
  manifest="$tree/manifest.tsv"
  # timeout=0 means no timeout
  write_fixture "$manifest" \
    'T-NO-TIMEOUT\ttrue\t0\tunit\tevidence\tno\t0'

  mock_docker_down
  EVAL_LITE_MANIFEST="$manifest" run bash "$HARNESS"

  assert_status 0
  assert_output_contains "1 passed, 0 failed, 0 skipped"
}

@test "eval-lite timeout: T4 backward compatibility with 6-field row" {
  local tree manifest
  tree="$BATS_TEST_TMPDIR/t4"
  mkdir -p "$tree"
  manifest="$tree/manifest.tsv"
  # 6-field row (no timeout field) should still work
  write_fixture "$manifest" \
    'T-LEGACY\ttrue\t0\tunit\tevidence\tno'

  mock_docker_down
  EVAL_LITE_MANIFEST="$manifest" run bash "$HARNESS"

  assert_status 0
  assert_output_contains "1 passed, 0 failed, 0 skipped"
}

@test "eval-lite timeout: T5 backward compatibility with 5-field row" {
  local tree manifest
  tree="$BATS_TEST_TMPDIR/t5"
  mkdir -p "$tree"
  manifest="$tree/manifest.tsv"
  # 5-field row (no container-bound, no timeout) should still work
  write_fixture "$manifest" \
    'T-LEGACY5\ttrue\t0\tunit\tevidence'

  mock_docker_down
  EVAL_LITE_MANIFEST="$manifest" run bash "$HARNESS"

  assert_status 0
  assert_output_contains "1 passed, 0 failed, 0 skipped"
}

@test "eval-lite timeout: T6 command completes before timeout" {
  local tree manifest
  tree="$BATS_TEST_TMPDIR/t6"
  mkdir -p "$tree"
  manifest="$tree/manifest.tsv"
  # Command completes in <1s, timeout is 5s -> should pass
  write_fixture "$manifest" \
    'T-FAST\ttrue\t0\tunit\tevidence\tno\t5'

  mock_docker_down
  EVAL_LITE_MANIFEST="$manifest" run bash "$HARNESS"

  assert_status 0
  assert_output_contains "1 passed, 0 failed, 0 skipped"
}

@test "eval-lite timeout: T7 non-numeric timeout is skipped with WARN" {
  local tree manifest
  tree="$BATS_TEST_TMPDIR/t7"
  mkdir -p "$tree"
  manifest="$tree/manifest.tsv"
  # Non-numeric timeout should be skipped
  write_fixture "$manifest" \
    'T-BAD-TIMEOUT\ttrue\t0\tunit\tevidence\tno\tabc'

  mock_docker_down
  EVAL_LITE_MANIFEST="$manifest" run bash "$HARNESS"

  assert_status 0
  assert_output_contains "WARN"
  assert_output_contains "0 passed, 0 failed, 1 skipped"
}

@test "eval-lite timeout: T8 mixed timeout and no-timeout tasks" {
  local tree manifest
  tree="$BATS_TEST_TMPDIR/t8"
  mkdir -p "$tree"
  manifest="$tree/manifest.tsv"
  write_fixture "$manifest" \
    'T-NO-TIMEOUT\ttrue\t0\tunit\tevidence\tno' \
    'T-TIMEOUT\ttrue\t0\tunit\tevidence\tno\t10'

  mock_docker_down
  EVAL_LITE_MANIFEST="$manifest" run bash "$HARNESS"

  assert_status 0
  assert_output_contains "2 passed, 0 failed, 0 skipped"
}
```

---

## 13. Summary

This protocol designs a minimal, focused benchmark to compare three
Rung-3 candidates (kimi-k3, deepseek-v4-pro, mimo-v2.5-pro) on three
real in-repo tasks with prepared test seams. The benchmark is designed
to stay well within kimi-k3's 490 req/mo cap (estimated 120 requests,
75% headroom), uses git worktree isolation to prevent task leakage,
and has clear pass/fail criteria and verdict rules.

The execution mechanism recommends creating three temporary benchmark
agent variants (hidden, clearly marked, easy to delete) rather than
swapping model keys on production agents. This is a temporary change
with explicit developer approval and automatic cleanup, not a bypass
of the section-10 chain.

The benchmark tasks are:
1. Implement debounce utility (TypeScript, phonetics-core)
2. Implement ring-buffer data structure (TypeScript, phonetics-core)
3. Add timeout support to eval-lite.sh (shell scripting)

All tasks are host-runnable (no Docker needed), have prepared test
files, and represent "complex/advanced problem-fix" work.

---

**Artifact path:** `knowledge/ana014-rung3-benchmark-protocol/ana014-rung3-benchmark-protocol-report.md`

**Created:** 2026-08-12
