# Container Setup — Poetry Platform + OmO-slim

## Required System Dependencies

```dockerfile
FROM node:22-bookworm

# === Base utilities ===
# These are needed by OpenCode agents (bash, scripts, etc.)
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# === pnpm (monorepo package manager) ===
# Poetry Platform uses pnpm workspaces + Turborepo.
# OmO-slim tests don't need it, but the monorepo does.
RUN npm install -g pnpm@latest

# === Bun (runtime for oh-my-opencode-slim tests) ===
# OmO-slim uses `bun test`, `bun run`, `bun install`.
# This is NOT optional — all 1367 tests run via bun.
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

# === (Optional) Rust toolchain ===
# Needed for building packages/stress-lang-core (Rust FST → WASM).
# RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
```

> ✅ **Verified working (2026-07-16):** `node v24.18.0`, `npm 11.16.0`, `pnpm 10.33.0`, `bun 1.3.14`, `curl 8.14.1`, `tr` — all tools operational. 1367/1367 tests pass on `omo-slim-changes` branch.

---

## Git Branch State

**Branch:** `omo-slim-changes` (rebased onto `origin/main`)

```
65c266a (HEAD -> omo-slim-changes) docs: add container setup guide
a77e9b9 fix: restore truncated architector/reviewer prompts + DCP config + snip
f11d6ce feat: add 4 skills to OmO-slim
ee2ab02 feat: enhance architector and reviewer prompts
bae57fd refactor: rename OmO-slim agents
a1918d9 feat: agentic workflow v 2.4 before rebasing onto OmO-slim
75b0f81 (origin/main) Refactor architecture and specification processes
```

### What each commit does

1. **65c266a** — Container setup guide with dependency list, Dockerfile, and branch state
2. **a1918d9** — Initial setup: agent workflow config + OmO-slim source import
3. **bae57fd** — Rename `orchestrator` → `boss`, `explorer` → `code-navigator`, etc.
4. **ee2ab02** — Enhanced prompts for architector and reviewer agents + DCP model limits
5. **f11d6ce** — Added 4 custom skills to `custom-skills-registry.ts`
6. **a77e9b9** — Fixed truncated prompts (restored full content), test fixes (orchestrator→boss), DCP limits, snip plugin vendored, opencode.json updated

### Key changed files (vs origin/main)

| Area | Files |
|------|-------|
| Agent prompts | `src/agents/architector.ts`, `src/agents/reviewer.ts` — full 75/71 line prompts |
| Renames | `orchestrator.ts` → `boss.ts`, `explorer.ts` → `code-navigator.ts`, constants, aliases |
| Custom skills | 4 new entries in `custom-skills-registry.ts` + skill dirs |
| Tests fixed | `providers.test.ts` (orchestrator→boss ×10), `config-io.test.ts` (×2) |
| DCP config | `.opencode/dcp.jsonc` — model limits for 21 models |
| Snip plugin | `.opencode/plugins/snip/index.ts` — vendored, SKIP_SNIP extended |
| Project config | `.opencode/opencode.json` — snip path, `.opencode/oh-my-opencode-slim.jsonc` — custom agents |

---

## OpenSpec Status

- **Not installed.** The `openspec-plan` agent is a custom prompt-based agent defined in `oh-my-opencode-slim.jsonc` (lines 414–416), not the actual OpenSpec CLI.
- A project config exists at `openspec/config.yaml` (created 2026-07-13).
- To install: `npm install -g @fission-ai/openspec@latest && cd /workspace && openspec init`
- Or use an OpenCode plugin like `@devcxl/opencode-spec` or `opencode-plugin-openspec`.

---

## After Container Rebuild

```bash
# 1. Verify tools
node --version    # expect 22+
bun --version     # expect 1.3+
pnpm --version    # expect 9+
python3 --version # expect 3.11+

# 2. Install project deps
cd /workspace
pnpm install

# 3. Run OmO-slim tests
cd .opencode/oh-my-opencode-slim
bun install && bun test    # expect 1367 pass, 0 fail

# 4. Check branch
git log --oneline -5
```
