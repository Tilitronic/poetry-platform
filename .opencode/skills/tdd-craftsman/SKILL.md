---
name: tdd-craftsman
description: Polyglot RED-GREEN-REFACTOR TDD cycle for Python/Rust/C/C++/TS monorepos (Turborepo), with explicit ownership safeguards for AI-assisted development
compatibility: opencode
metadata:
  audience: developers
  workflow: testing
---

## What I Do

When invoked to implement a feature using TDD, I execute the full
**RED → GREEN → REFACTOR** cycle, language-agnostically, across this
monorepo's Python, Rust, C/C++, and TypeScript packages. I write failing
tests first, implement the minimal code to pass them, then optimize for
performance and readability without breaking tests — orchestrated through
Turborepo so the same gate sequence applies regardless of which package
the change lives in.

When asked only to create tests,
execute only the RED phase and stop.

This skill is also an **ownership safeguard**, not just a speed tool. See
"Ownership Protocol" below — it is not optional and is not satisfied by
passing tests alone.

## Activation Triggers

Route to this skill if ANY of the following are true:

1. **Explicit:** The prompt contains `#tdd` or explicitly says "TDD",
   "test-first", or "write tests first".
2. **Implicit:** The user asks to implement a new function/feature/module
   in a package that has an existing test suite.
3. **Bug-fix with regression risk:** The user reports a bug in logic that
   has no covering test — write the regression test first, then fix.

**Do NOT activate** for: quick scripts, exploratory/throwaway prototypes,
or when the user explicitly says "skip tests" / "just make it work".

---

## 0. Ownership Protocol (applies to every phase)

Two failure modes are equally dangerous in AI-assisted TDD and this skill
treats both as first-class gates, not afterthoughts:

**Failure mode A — opaque tests.** A test that passes but that the
developer who owns this package couldn't explain or defend in review is a
liability, not an asset. It will be deleted or ignored the first time it's
inconvenient.

**Failure mode B — implementation outpacing comprehension.** If GREEN
produces a working implementation before the developer has actually
processed the RED phase (what's being tested and why), the developer is
now maintaining code they didn't really write.

**Concrete countermeasures, mandatory for every cycle:**

- **One test, one named behavior.** Every `it`/`fn test_`/`def test_`
  name must state a single behavioral claim a human can verify by reading
  the name alone — no `test_handles_all_cases`, no multi-assert god-tests.
- **No implementation without a one-line rationale comment at the GREEN
  commit.** Not "what" (the diff shows that) — "why this approach,"
  especially for any non-obvious algorithmic choice. If you can't write
  one sentence justifying the approach, you don't understand it well
  enough to commit it.
- **Stop after RED and summarize the test plan in plain language** before
  writing implementation, when the feature touches more than one file or
  introduces a new public API. This creates a checkpoint where the human
  can object *before* GREEN exists, not after.
- **Never auto-generate a batch of tests for unrelated functions in one
  pass.** Test-implementation pairs are reviewed and owned one behavior
  at a time. Bulk-generated test suites are exactly the "nobody owns
  this" failure mode.

---

## 1. RED Phase — Write Failing Tests

### Test Design (AAA)

Structure every test around **Arrange-Act-Assert**:

- **Happy Path** — standard successful execution with valid inputs.
- **Edge Cases** — empty inputs, boundaries, duplicates, extreme values.
- **Error Handling** — invalid inputs, missing resources, invariant
  violations.

### Naming Conventions (per language)

| Language | Suite | Case |
|---|---|---|
| TypeScript (Vitest) | `describe('moduleName — scenario', ...)` | `it('blocks double space when typing space after space', ...)` |
| Python (pytest) | `class TestModuleName:` or flat module | `def test_given_condition_when_action_then_expected():` |
| Rust | `mod tests { ... }` in-file, or `tests/` integration dir | `fn blocks_double_space_when_typing_space_after_space()` |
| C/C++ (GoogleTest) | `TEST(ModuleName, Scenario)` | `TEST(InputFilter, BlocksDoubleSpaceOnLiveTyping)` |

The naming *style* differs per ecosystem idiom, but the rule is universal:
the name alone must state one behavioral claim — no exceptions per language.

### Isolation

- No shared state between tests. Each test creates its own fixtures.
- Use factory functions for reusable setup (e.g., `createState`,
  `insertAt`, pytest fixtures, Rust `#[fixture]` or builder helpers).

**Unit tests (default):** No external dependencies (DB, network,
filesystem, hardware). Mock/stub everything that crosses a process or I/O
boundary.

**Integration tests (explicit, separate suite/target):** When the unit
under test *is* the I/O boundary itself (a DB adapter, a file-watcher, a
serial/sensor driver, an FFI boundary), write a separate suite that uses
the real dependency against a disposable fixture (temp dir, in-memory DB,
test database, mocked hardware where available). Never silently
substitute mocks for code whose entire job is talking to that
dependency — that tests nothing. Mark these clearly so they can be run
separately from fast unit suites:
- TS/Vitest: `*.integration.test.ts`
- Python/pytest: `@pytest.mark.integration`
- Rust: `tests/` directory (separate from `#[cfg(test)]` unit tests)
- C/C++: separate CTest label or GoogleTest filter (`--gtest_filter=*Integration*`)

### Tooling per language

| Language | Unit framework | Property-based | Notes |
|---|---|---|---|
| TypeScript | Vitest | `fast-check` | For CM6 extension tests: create `EditorState` directly with the extension. Use Playwright ONLY when DOM/browser interaction is essential. |
| Python | pytest | `hypothesis` | Use `pytest-benchmark` for perf gates. NumPy array tests use `np.testing.assert_array_equal` / `assert_allclose`, never `==`. |
| Rust | built-in `#[test]` / `cargo test` | `proptest` or `quickcheck` | `cargo bench` (criterion.rs) for perf gates. Prefer `Result<(), E>`-returning tests over `.unwrap()` chains where failure context matters. |
| C/C++ | GoogleTest | `rapidcheck` (GTest integration) or `fuzztest` | Use `ASSERT_*` for fatal preconditions, `EXPECT_*` for the actual behavioral checks so one failure doesn't hide the next. AddressSanitizer/UBSan enabled in the test build config — see Memory Safety Gate below. |

### RED Gate (mandatory before GREEN)

Run the new test and inspect *why* it fails:

- ✅ **Correct RED:** fails on the assertion (`expected X, got Y`).
- ❌ **False RED:** fails on a syntax/compile error, import error, missing
  symbol, or (C/C++) a linker error — this is not a real RED state. Fix
  the scaffolding first, re-run, confirm the test fails for the
  *intended* reason before writing any implementation.

Never proceed to GREEN on a test whose failure reason you haven't read.

**For non-trivial or multi-file features:** before writing GREEN, state
the test plan in 2-4 plain-language bullets (what's covered, what
deliberately isn't yet). This is the ownership checkpoint from section 0.

---

## 2. GREEN Phase — Minimal Passing Implementation

### Constraints

- Write the MINIMUM code to pass the tests. No speculative features.
- Prefer simple conditionals over abstraction.
- If the test passes with a trivial implementation, that's fine —
  optimization comes in REFACTOR.

### Language-specific GREEN discipline

- **Rust:** resist reaching for `unsafe`, `.clone()`-everywhere, or
  `unwrap()` to get green fast. If the borrow checker is fighting the
  design, that's signal to revisit the design, not to clone your way past
  it — flag this explicitly rather than silently working around it.
- **C/C++:** minimal implementation still means no raw `new`/`delete` or
  manual buffer management if RAII/smart-pointer equivalents exist in the
  codebase's conventions. "Minimal" applies to scope, not to safety
  shortcuts.
- **Python:** prefer explicit types (type hints) even at GREEN; don't
  defer typing to REFACTOR — `mypy`/`pyright` gate (see Verification
  Gates) will fail otherwise and the rework cost is higher later.

### Commit Often

After all tests pass, commit with a message describing WHAT was fixed
(e.g., `fix(editor): block double space on live typing`), including the
package scope per Turborepo convention.

This is **commit #1 of 2** for the cycle: RED+GREEN together as one
commit (the test and the minimal implementation that satisfies it).
REFACTOR gets its own commit afterward. Don't squash the two — keeping
them separate preserves "this is what made it pass" vs "this is what
made it clean" in history, which matters for review and for blame/bisect
later.

Per the Ownership Protocol: the commit body includes the one-line
rationale for any non-obvious approach.

---

## 3. REFACTOR Phase — Optimize Without Breaking Tests

### Safety Net

- Run the full test suite before and after each refactoring step:
  `turbo run test --filter=<package>`.
- Never refactor without a passing test suite first.

### Performance First

Optimize in order of impact (language-specific tactics in parens):

1. **Hot-path allocation elimination** — avoid heap allocation on the hot
   path. (TS: avoid arrays/objects per call; Rust: prefer borrows/slices
   over `Vec`/`String` clones; C/C++: stack allocation or arena/pool
   reuse over `malloc`/`new` per call; Python: avoid list comprehensions
   inside tight loops, prefer generators/NumPy vectorization.)
2. **Lazy computation** — defer expensive operations until actually
   needed. Move expensive string/array operations inside the branches
   that need them.
3. **Pre-compile constants** — move regexes, lookup tables, and compiled
   patterns to module/file scope (or `static`/`const` in Rust/C++) so
   they're built once, not per call.
4. **Quick-exit patterns** — exit early when no work is needed (guard
   clauses before the expensive path).
5. **Avoid duplicate work** — compute normalization/parsing once and
   reuse; cache repeated conversions (`toString()`, `str()`, `.to_string()`).

### Readability

After performance optimization, refactor for clarity:
- Extract named helper functions.
- Name variables by intent.
- Remove dead code and unused constants/imports.
- Comments explain WHY, not WHAT.

This is **commit #2 of 2**: `refactor(<package>): <what was optimized/clarified>`,
made only after the verification gates in section 4 pass.

---

## 3a. Scientific Code Verification (For Numerical/Mathematical Code)

**Activation threshold — apply this section only when the code under
test has at least one of:**
- A mathematical invariant that must hold across arbitrary inputs
  (idempotence, conservation, monotonicity, conservation of mass/energy
  in simulation code) — not just "returns a number".
- Performance characteristics that are part of the spec (real-time
  processing, hot-path numerical kernels, large-N algorithmic complexity
  requirements).
- Typed-array / raw-buffer memory layout that affects correctness
  (row-major vs column-major consumers, SIMD alignment, FFI ABI
  boundaries).
- Cross-language numerical boundaries (e.g., a Rust/C++ kernel called
  from Python via FFI/pybind11/PyO3) — these need contract tests on both
  sides of the boundary.

A plain aggregate like `calculate_average(numbers)` does **not**
qualify — normal unit tests (happy path, empty input, single element)
are sufficient. This section is for simulation kernels, numerical
solvers, signal-processing pipelines, and similarly structural code.

When implementing qualifying code, add these steps after the standard
REFACTOR phase:

### Property-based testing

Verify mathematical invariants across a wide range of inputs.

**TypeScript (fast-check):**
```typescript
import fc from 'fast-check';

it('conversion is idempotent for valid inputs', () => {
  fc.assert(
    fc.property(fc.string({ minLength: 1 }), (input) => {
      fc.pre(isValid(input));
      expect(convert(convert(input))).toBe(convert(input));
    })
  );
});
```

**Python (hypothesis):**
```python
from hypothesis import given, strategies as st

@given(st.lists(st.floats(allow_nan=False, allow_infinity=False)))
def test_normalization_sums_to_one(values):
    if not values:
        return
    result = normalize(values)
    assert abs(sum(result) - 1.0) < 1e-9
```

**Rust (proptest):**
```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn ring_buffer_never_loses_data_within_capacity(
        items in prop::collection::vec(any::<i32>(), 0..1000),
        capacity in 1usize..1000,
    ) {
        let mut buf = RingBuffer::new(capacity);
        for item in items.iter().take(capacity) {
            buf.write(*item);
        }
        let read = buf.read_all();
        prop_assert!(read.len() <= capacity);
    }
}
```

**C++ (GoogleTest + rapidcheck):**
```cpp
#include <rapidcheck/gtest.h>

RC_GTEST_PROP(RingBufferTest, NeverLosesDataWithinCapacity,
              (std::vector<int> items, std::size_t capacity)) {
  RC_PRE(capacity > 0 && capacity < 1000);
  RingBuffer buf(capacity);
  for (std::size_t i = 0; i < std::min(items.size(), capacity); ++i) {
    buf.write(items[i]);
  }
  RC_ASSERT(buf.read_all().size() <= capacity);
}
```

### Benchmark regression gates

Run via Turborepo so each language's native bench tool is invoked
uniformly: `turbo run bench --filter=<package>`.

- **TS:** `vitest bench`
- **Python:** `pytest-benchmark` (`pytest --benchmark-only`)
- **Rust:** `cargo bench` (criterion.rs gives statistical regression
  detection out of the box — prefer it over raw `cargo bench` timing)
- **C++:** Google Benchmark (`benchmark::RegisterBenchmark`)

**Calibrate against a measured baseline, not a guessed constant.**
Absolute time thresholds don't port across CI runners or developer
machines. Prefer a relative regression gate — fail if >15% slower than
the last committed baseline — over an absolute ceiling like "must be
under 1μs," which is almost always either too loose or unreproducible.

### Memory layout & memory safety verification

For typed arrays / raw buffers, verify layout explicitly:

```python
# NumPy — F-contiguous as required by architecture.md
assert np.isfortran(matrix)
# or C-contiguous
assert matrix.flags['C_CONTIGUOUS']
```

```cpp
// Verify alignment for SIMD-sensitive structures
static_assert(alignof(Vec4) == 16, "Vec4 must be 16-byte aligned for SIMD");
```

**C/C++ Memory Safety Gate (mandatory for numerical/buffer code):**
Run the unit test suite under AddressSanitizer + UndefinedBehaviorSanitizer
at least once per cycle, not just at CI time:
```bash
turbo run test:asan --filter=<package>
```
A test suite that passes without sanitizers but has buffer overruns or
UB is not actually GREEN — it's a gate that hasn't been checked yet.

### Statistical correctness (for analysis/ML code)

```python
def test_stress_distribution_stays_in_range():
    results = analyze_corpus(test_corpus)
    for metrics in results.values():
        assert 0.0 <= metrics.stress_density <= 1.0
```

---

## 4. Verification Gates

Before considering the cycle complete, run via Turborepo so the same
sequence applies regardless of package language:

```bash
turbo run test --filter=<package>       # unit + property-based
turbo run bench --filter=<package>      # if 3a applies
turbo run typecheck --filter=<package>  # tsc / mypy / cargo check / -Wall -Werror build
turbo run lint --filter=<package>       # eslint / ruff / clippy / clang-tidy
turbo run build --filter=<package>
```

| Gate | TS | Python | Rust | C/C++ |
|---|---|---|---|---|
| Unit tests | `vitest run` | `pytest` | `cargo test` | `ctest` / gtest binary |
| Type/static check | `tsc --noEmit` | `mypy` or `pyright` | `cargo check` (clippy includes this) | `-Wall -Wextra -Werror` build |
| Lint | `eslint .` | `ruff check` | `cargo clippy -- -D warnings` | `clang-tidy` |
| Build | `turbo run build` | n/a or packaging build | `cargo build --release` | CMake/Make release build |
| Memory safety (if 3a) | n/a | n/a | (memory-safe by construction; `cargo test` under Miri for `unsafe` blocks) | ASan/UBSan run |

1. ✅ **Unit tests pass** — zero failures
2. ✅ **Property-based tests pass** — no shrinking failures (if 3a applies)
3. ✅ **Benchmarks pass** — within calibrated threshold (if 3a applies)
4. ✅ **Type/static checks pass** — zero errors
5. ✅ **Lint passes** — zero errors
6. ✅ **Build succeeds** for every affected package (`turbo run build` resolves the dependency graph)
7. ✅ **Memory safety check passes** — ASan/UBSan clean, or Miri clean for `unsafe` Rust (if 3a applies)
8. ✅ **Commit message** describes the change in imperative mood, scoped to package
9. ✅ **Ownership checkpoint passed** — test names are self-explanatory, rationale comment present, no bulk-generated unrelated tests (section 0)

### On gate failure

A failed gate routes back to a phase — it is never a signal to suppress
the error:

- **Gate 1–2 fail** → back to GREEN: the implementation is incomplete or wrong.
- **Gate 3 fails (benchmark regression)** → back to REFACTOR: revisit
  the performance optimizations in section 3, don't relax the threshold
  to pass.
- **Gate 4 fails (type/static check)** → fix the actual type/contract.
  Never silence with `as any`, `# type: ignore`, `unwrap_or_default()`
  used purely to dodge a Result, or `(void)` casts to suppress a
  warning. If the error reveals a real design issue, that's a return to
  GREEN, not a type-system workaround.
- **Gate 5 fails (lint)** → fix in place; don't disable the rule unless
  it's a documented project-wide exception with a comment explaining why.
- **Gate 6 fails (build)** → in a Turborepo monorepo this is often a
  cross-package dependency issue — check `turbo.json` task dependencies
  before assuming it's local to your package.
- **Gate 7 fails (ASan/UBSan/Miri)** → this is a real bug regardless of
  whether the unit tests passed. Treat it as RED, not as a REFACTOR
  cleanup item.
- **Gate 9 fails (ownership checkpoint)** → stop and have the human
  review before continuing, even if gates 1-8 are green. This gate
  exists specifically because passing tests don't guarantee the team
  understands or owns the change.

Gates are sequential checkpoints, not independent boxes — don't move
forward while one is red.

---

## 5. Workflow Summary

```ascii
RED:      write failing test (unit + property)     ──→  turbo run test  →  FAIL (correct reason)
                                                     │
          [if multi-file/new API: state test plan, pause for ownership checkpoint]
                                                     │
GREEN:    implement minimum, rationale comment      ──→  turbo run test  →  PASS  →  commit (1/2)
                                                     │
REFACTOR: optimize + clean                          ──→  turbo run test     → PASS
                                                          turbo run bench    → PASS (if 3a)
                                                          turbo run typecheck → PASS
                                                          turbo run lint      → PASS
                                                          turbo run build     → PASS
                                                          ASan/UBSan/Miri     → PASS (if 3a)
                                                          ownership checkpoint → PASS
                                                          commit (2/2)
```

For scientific/numerical code (section 3a applies), also run:
```bash
turbo run bench --filter=<package>     # regression check vs committed baseline
turbo run test:asan --filter=<package> # C/C++ only
```