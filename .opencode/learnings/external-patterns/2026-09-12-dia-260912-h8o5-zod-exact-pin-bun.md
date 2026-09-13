# Bun exact-pin for zod devDependency with caret peer range (DIA-260912-h8o5)

## Finding

For `.opencode/oh-my-opencode-slim/package.json`:

- `devDependencies.zod` must be exact `4.3.6` (no `^` prefix).
- `peerDependencies.zod` remains `^4.0.0` (caret range, unchanged).

Rationale: exact dev pin gives a reproducible local runtime for the
undeclared-zod-import investigation, while the caret peer range preserves
consumer flexibility per npm peerDependencies guidance. No `overrides`
field, no hand-edits to `package.json` or `bun.lock`.

## Commands

Regenerate (writes `package.json` + `bun.lock` together):

```sh
bun add zod@4.3.6 --dev --exact --lockfile-only
```

Verify (read-only, no scripts):

```sh
bun install --frozen-lockfile --dry-run --ignore-scripts
```

Commit together:

```sh
git add .opencode/oh-my-opencode-slim/package.json .opencode/oh-my-opencode-slim/bun.lock
git commit -m "DIA-260912-h8o5: exact-pin zod devDependency"
```

## NOT to do

- Do not add an `overrides` / `resolutions` entry for zod.
- Do not hand-edit version strings in `package.json` or `bun.lock`.
- Do not change the peer range to exact.
- Do not commit `package.json` without the regenerated `bun.lock`.

## Source pointers

- Bun install CLI (`--frozen-lockfile`, `--dry-run`, `--ignore-scripts`):
  https://bun.sh/docs/cli/install (accessed 2026-09-12)
- Bun lockfiles (`bun.lock`, lockfile-only updates):
  https://bun.sh/docs/install/lockfile (accessed 2026-09-12)
- Bun add (`--dev`, `--exact`, `--lockfile-only`, `pkg@version`):
  https://bun.sh/docs/cli/add (accessed 2026-09-12)
- npm package.json peerDependencies guidance (caret range for peers):
  https://docs.npmjs.com/cli/v10/configuring-npm/package-json#peerdependencies (accessed 2026-09-12)

## Confidence

High (0.95) -- direct Bun CLI contract plus npm peer-range convention; no
inference gap on the pin/peer split. Lockfile byte-level outcome not
re-verified in this learnings-only lane (GREEN work belongs to DIA-260912-h8o5,
explicitly out of scope here).

## Scope limiter

Applies to Bun-managed `oh-my-opencode-slim` zod pin only. Not a general
exact-pin policy, not an OpenCode config change, and not GREEN
implementation for DIA-260912-h8o5 or DIA-260827-95fv.
