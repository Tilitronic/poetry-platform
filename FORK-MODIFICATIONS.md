# Fork Modifications

This project includes modified versions of two upstream projects. This document tracks what was changed and why.

---

## 1. opencode-docker

- **Original**: [pkhamre/opencode-docker](https://github.com/pkhamre/opencode-docker)
- **Location**: `tools/opencode-docker/`
- **License**: MIT

### Modifications

| What | Why |
|------|-----|
| Custom Dockerfile | Added Bun, pnpm, Python3, Rust toolchain for monorepo build |
| `bootstrap.py` | Pre-installs oh-my-opencode-slim plugin, OMO project configs |
| `config/` + `plugins/` + `skills/` | Project-specific agent configs, custom skills, Snip plugin |
| `scripts/` | Poetry Platform-specific setup scripts |
| Container entrypoint | Pre-configured with poetry-platform-monorepo workspace |
| Security: `TODO.md` | Unresolved security concerns from upstream (seccomp, volume mounts) |

---

## 2. oh-my-opencode-slim (OmO-Slim)

- **Original**: [oh-my-opencode](https://github.com/anomalyco/oh-my-opencode)
- **Location**: `.opencode/oh-my-opencode-slim/`
- **License**: MIT
- **Note**: "a slimmed-down fork of oh-my-opencode" (per package.json)

### Modifications (project-level config — plugin source unchanged)

| File | What | Why |
|------|------|-----|
| `oh-my-opencode-slim.jsonc` | Custom agent presets, models, orchestratorPrompts | Poetry Platform agent topology (boss, architector, reviewer, coder, etc.) |
| `boss_append.md` | Context budgets + escalation rules for boss | Project-specific orchestration workflow |
| Agent renames | oracle→architector, fixer→coder, code-reviewer→reviewer | Consistent naming across config files |
| Custom agents | memory-manager added to OMO Slim presets + agents section | Project needs persistent knowledge management |

### Plugin source modifications

The plugin TypeScript source in `.opencode/oh-my-opencode-slim/src/` is **unchanged** from the upstream fork. All customizations are in the project-level JSONC configuration and `.md` append files.

---

## 3. Related: poetry-platform-monorepo

- **Original**: [Tilitronic/poetry-platform](https://github.com/Tilitronic/poetry-platform)
- This is the main application repository, not a fork.

---

*Last updated: 2026-07-17*
