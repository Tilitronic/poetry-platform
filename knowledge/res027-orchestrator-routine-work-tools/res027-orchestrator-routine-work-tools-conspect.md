# Orchestrator Routine-Work + Artifact-System Tools (DIA-137)

**Ticket:** DIA-137 (Medium, OPEN, opencode-config)
**Date:** 2026-08-14
**Author:** @conspecter
**Sources archived:** 13 (15 files across 12 candidate tools)
**Phase A failures:** 0

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 13
phase-a-failures: 0
shelf-registration: memory-shelf.yaml (shelf.conspects)
-->

## 1. Executive Summary

The honest verdict of this research pass is that the **status-quo toolchain is
correct**: the orchestrator's routine work is already served by the settled
standards `bash` + `jq` + `bats-core`, all of which are wired into the project's
gates (`make test-shell`, `check-host-jq`, vendored bats). Every candidate
surveyed either duplicates existing capability without benefit, introduces an
unwanted background process, or adds a runtime dependency that the current
tooling deliberately avoids.

The single design-worthy finding is **chokidar v5.0.0** (Node in-process file
watcher): it is the *only* candidate that could enable automatic
re-generation of derived views (`messages.jsonl -> messages.md`,
`ticker.json -> ticker.md`) **without spawning a new process** -- it would run
inside the existing delegation-observer plugin process. However, per the
**DIA-086 SCOPE GUARD**, no new tool may be introduced unless a real
requirement is demonstrated, and no consumer of these derived views has
demonstrated a stale-view problem. On-demand render is deterministic and
testable; auto-regeneration is an optional enhancement, not a need.

All 12 candidate tools pass the researcher's Phase A evaluation (0 NOT-ARCHIVED
failures) and are cited below. No sources are excluded.

## 2. Per-Candidate Findings (MLA-cited)

### 2.1 jq -- KEEP (established baseline)

jq is "a lightweight and flexible command-line JSON processor akin to `sed`,
`awk`, `grep`, and friends ... written in portable C" with "zero runtime
dependencies" (jqlang, "jq"). It is the settled JSON processing baseline in the
project's artifact systems: `scripts/session-log`, `scripts/ticker-render.sh`,
and the delegation-observer registry inspection all run through jq (project
reference, `.source-urls.txt`). jq is already adopted, already gated, and
proven. **No change.**

*Citation:* jqlang. "jq." *Official jq README*, github.com/jqlang/jq, MIT
License, archived 2026-08-14 (jq-readme.md).

### 2.2 bats-core -- KEEP (already adopted)

Bats is "a TAP-compliant testing framework for Bash 3.2 or above" that
"provides a simple way to verify that the UNIX programs you write behave as
expected" (bats-core, "bats-core: Bash Automated Testing System"). Each test
case is a function with a description; every command exiting 0 is "an
assertion of truth" (bats-core). Bats is already vendored and wired into
`make test-shell` with a `check-host-jq` gate (project reference,
`.source-urls.txt`). **Already adopted; no change.**

*Citation:* bats-core. "Bats-core: Bash Automated Testing System." *Official
bats-core README*, github.com/bats-core/bats-core, MIT-style License,
archived 2026-08-14 (bats-readme.md).

### 2.3 entr -- CONDITIONAL / defer

entr is "a utility for running arbitrary commands when files change" using
"kqueue(2) or inotify(7) to avoid polling" (Radman, "Event Notify Test
Runner"). Critically, the README warns that "incomplete inotify support on
Windows Subsystem for Linux and Docker for Mac may cause entr to respond
incorrectly" absent the `ENTR_INOTIFY_WORKAROUND` variable (Radman). The man
page confirms the watch-loop semantics: entr "waits for the child process to
finish before responding to subsequent file system events," with a "TTY ...
opened before entering the watch loop" (Radman, entr.1). This is a
**background watch process** -- which is forbidden in this environment, and the
WSL inotify limitation makes it unreliable here. **CONDITIONAL / defer** until
(and unless) auto-regeneration becomes a demonstrated requirement; even then,
in-process chokidar is preferred over an out-of-process watcher.

*Citation:* Radman, Eric. "Event Notify Test Runner." *Official entr README*,
github.com/eradman/entr, archived 2026-08-14 (entr-readme.md).
*Citation:* Radman, Eric. "ENTR 1." *entr man page*, eradman.com, dated
2026-03-02, archived 2026-08-14 (entr-man.md).

### 2.4 watchexec -- REJECT

watchexec is "a simple, standalone tool that watches a path and runs a command
whenever it detects modifications," shipped as a "single Rust binary," capable
of coalescing filesystem events and loading `.gitignore`/`.ignore`
(watchexec, "Watchexec"). It answers the *same* question as entr (watch-and-run)
but as a heavier single-binary tool with no in-process option and no advantage
for this environment, where background processes are forbidden. It does not
pair with the in-process plugin architecture. **REJECT** -- heavier than entr,
same fundamental question, and equally blocked by the no-background-process
rule.

*Citation:* Watchexec project. "Watchexec." *Official watchexec README*,
github.com/watchexec/watchexec, archived 2026-08-14 (watchexec-readme.md).

### 2.5 inotify-tools -- REJECT

inotify-tools is "a package of some commandline utilities relating to inotify"
whose "general purpose ... is to allow inotify's features to be used from
within shell scripts" (inotify-tools project, "inotify-tools"). The README's
own maintenance note recommends enhancing "the Rust version of the codebase
rather than the C/C++ version" (inotify-tools). This is a thin primitive (raw
inotify wrapper) with no event normalization, no cross-platform story, and no
in-process fit. entr/chokidar both layer better semantics on top of the same
kernel facility. **REJECT** -- too thin to justify.

*Citation:* inotify-tools project. "inotify-tools." *Official inotify-tools
README*, github.com/inotify-tools/inotify-tools, archived 2026-08-14
(inotify-tools-readme.md).

### 2.6 chokidar v5.0.0 -- CONDITIONAL ADOPT (the only no-new-process mechanism)

chokidar is "a minimal and efficient cross-platform file watching library"
that normalizes `fs.watch`/`fs.watchFile` events -- reporting `add`/`change`/
`unlink` instead of raw `rename`, supporting atomic writes, chunked writes,
recursive watching, and symlinks (Miller, "Chokidar"). The npm registry JSON
confirms **dist-tags.latest = 5.0.0, MIT** (npm registry, "chokidar"). v5 is
ESM-only and requires Node >= 20 (Miller). It runs **in-process** inside the
existing Node plugin runtime (delegation-observer.ts), which is why it is the
*only* mechanism that can auto-regenerate derived views without spawning a new
watch process. **CONDITIONAL ADOPT** -- the design to pick *if and only if*
auto-regeneration of derived views (`messages.jsonl -> messages.md`,
`ticker.json -> ticker.md`) becomes a demonstrated requirement. Per DIA-086
SCOPE GUARD it is not adopted now, because no stale-view consumption problem
has been demonstrated and on-demand render is deterministic and testable.

*Citation:* Miller, Paul. "Chokidar." *Official chokidar README*,
github.com/paulmillr/chokidar, MIT License, archived 2026-08-14
(chokidar-readme.md).
*Citation:* npm registry. "chokidar" (package metadata, dist-tags.latest
5.0.0, MIT). registry.npmjs.org, archived 2026-08-14 (chokidar-npm.json).

### 2.7 yq -- REJECT (zero-runtime-dep is a feature)

yq is "a lightweight and portable command-line YAML, JSON, INI and XML
processor" using jq-like syntax, written in Go (Farah, "yq"). Its Go binary is
"dependency free," but it is a *separate runtime* from jq, and this project's
artifact data is NDJSON/JSON -- which jq already handles natively. The
"zero-runtime-dep" property is a deliberate feature of the bash-only ticket
ledger and jq baseline (project reference, `.source-urls.txt`); adding yq
introduces a second data-processing runtime to solve a problem jq does not
have. If YAML processing is ever genuinely needed, it should be evaluated then
(project-adjacent `.opencode/*.jsonc` is JSONC, not YAML). **REJECT** for the
current routine-work scope.

*Citation:* Farah, Mike. "yq." *Official yq README*, github.com/mikefarah/yq,
MIT License, archived 2026-08-14 (yq-readme.md).

### 2.8 just -- REJECT (make exists)

just is "a handy way to save and run project-specific commands" with a
"command runner, not a build system" philosophy and "many improvements over
make" (Rodarmor, "just"). However, this project already has a `Makefile` with
named targets (`make test-shell`, `make test-config`, `make test-python`,
`make shell`, etc.) that are wired into gates and CI. Introducing just would
add a second command-runner syntax to duplicate existing Makefile targets,
with no demonstrated ergonomic gain for the orchestrator. **REJECT** -- make
exists and is already the convention.

*Citation:* Rodarmor, Casey. "just." *Official just README*,
github.com/casey/just, archived 2026-08-14 (just-readme.md).

### 2.9 mise -- KEEP as-is (version manager)

mise is a CLI for "dev tools, env vars, and tasks in one" `mise.toml`, used to
install and switch between dev tools like node and python (jdx, "mise-en-place").
It is **already in the toolchain as a version manager** (project reference,
`.source-urls.txt`) -- e.g. via the `uv tool install` container-strategy
decision (ana001) and the `mise` availability analysis. Its task-runner and
env features overlap with the Makefile and are not needed by the orchestrator's
routine work. **KEEP as-is** -- retain its current version-manager role; do not
expand it into a task runner.

*Citation:* jdx. "mise-en-place." *Official mise README*, github.com/jdx/mise,
archived 2026-08-14 (mise-readme.md).

### 2.10 duckdb -- REJECT for routine work (jq suffices)

DuckDB is "a high-performance analytical database system" with a "rich SQL
dialect" and direct CSV/Parquet/JSON import (DuckDB, "DuckDB"). Its README
emphasizes SQL-on-DataFrame/file analytics and a standalone CLI. While DuckDB
*could* run SQL rollups over JSONL, the orchestrator's artifact inspection is
already served by jq for light filtering and aggregation; introducing a full
analytical SQL engine for routine work is disproportionate. (Cross-reference:
res026 evaluated DuckDB as a *second* engine for a JSON-DB read layer and
already preferred `node:sqlite` in-memory for that separate scope; this conspect
does not re-litigate res026.) **REJECT for routine work** -- jq suffices; the
JSONL rollup case is not demonstrated as a requirement.

*Citation:* DuckDB. "DuckDB." *Official duckdb README*,
github.com/duckdb/duckdb, archived 2026-08-14 (duckdb-readme.md).

### 2.11 fx -- REJECT (human TUI, not agent)

fx is an interactive terminal JSON viewer (antonmedv, "f(x)"), with npm
dist-tags.latest = 39.2.0, MIT (npm registry, "fx"). It is explicitly an
*interactive TUI* for human inspection. The orchestrator's artifact inspection
is performed by the AI agent via jq/filtered reads, not by a human staring at
a TUI; an interactive viewer is orthogonal to the agent's routine work and adds
a runtime with no agent-facing value. **REJECT** -- human TUI, not an agent
tool.

*Citation:* Medvedev, Anton. "f(x)." *Official fx README*, github.com/antonmedv/fx,
MIT License, archived 2026-08-14 (fx-readme.md).
*Citation:* npm registry. "fx" (package metadata, dist-tags.latest 39.2.0, MIT).
registry.npmjs.org, archived 2026-08-14 (fx-npm.json).

### 2.12 todo.txt-cli -- REJECT (the DIA ledger IS the task store)

todo.txt-cli is "a simple and extensible shell script for managing your
todo.txt file," with `todo.sh` actions like `add "THING I NEED TO DO +project
@context"` (todo.txt org, "todo.txt-cli"). It is file-based, lightweight, and
MIT/GPL. However, the project's task store is the **git-backed DIA ticket
ledger** (`docs/dev-infra-audit/tickets/DIA-NNN-slug.md`), which DIA-125
settled as keep-local and which is already enforced by the delegation-observer
ticket gate (res021, DIA-125). Introducing a parallel todo.txt store would
create a second task source of truth with no gate integration. **REJECT** --
the DIA ledger IS the task store; todo.txt adds a conflicting parallel store.

*Citation:* todo.txt org. "todo.txt-cli." *Official todo.txt-cli README*,
github.com/todotxt/todo.txt-cli, GPL v3, archived 2026-08-14
(todotxt-readme.md).

## 3. EBDV Decision Variants

**Decision class:** Policy (tool-selection / artifact-system). **Routing:**
section-10 flag noted per variant; only a chokidar-in-plugin adoption would
route through the AI-Devtools workflow.

| | **A. Status-quo (RECOMMENDED)** | **B. chokidar-in-plugin (conditional)** | **C. entr/watchexec background** |
|---|---|---|---|
| **Change** | No tool change; keep bash + jq + bats; keep on-demand derived-view render | Add chokidar v5 in-process to delegation-observer to auto-regen `messages.md`/`ticker.md` on source write | Spawn entr or watchexec watch process to trigger re-render on file change |
| **Evidence** | res027 §2.1/§2.2; jq/bats already wired into gates; DIA-086 SCOPE GUARD (no demonstrated stale-view need) | chokidar README + npm JSON (v5.0.0, MIT, ESM, in-process, atomic/awaitWriteFinish) (Miller; npm) | entr README WSL inotify-incomplete + TTY watch-loop (Radman); watchexec single-binary watch tool (watchexec) |
| **Pros** | Zero new runtime; deterministic + testable on-demand render; no background process; no gate rework | Only no-new-process mechanism; leverages existing plugin process; normalized events; no extra service | Simple watch-and-run primitive; off-the-shelf |
| **Cons** | Derived views can be stale between renders (accepted: no consumer needs freshness) | Adds a Node dependency to the plugin; v5 ESM-only (Node >= 20) affects toolchain; scope-guard gate | **Background process forbidden**; WSL inotify unreliable (entr) or heavyweight single-binary (watchexec); new process to manage |
| **Effort** | None | Medium (~2-4h plugin change + gate) | Low install, but high operational risk |
| **Section-10 flag** | No (no AI-tooling change) | **Yes** (plugin edit; must route through AI-Devtools workflow, gate via @ai-specialist) | **Yes** (new tooling/process) |

**Recommendation:** Variant A (status-quo). Variant B (chokidar-in-plugin) is
the *design to pick* if auto-regeneration of derived views becomes a real,
demonstrated requirement -- it is the only candidate that avoids a new
background process. Variant C is rejected outright because background watch
processes are forbidden in this environment.

## 4. DIA-086 SCOPE GUARD Note

No new tool may be introduced unless a real requirement is demonstrated. In
this pass, **no consumer of the derived views** (`messages.md`, `ticker.md`)
has demonstrated a stale-view consumption problem: on-demand render is
deterministic, jq-based, and testable, and all current consumers read the
canonical JSONL sources directly or trigger render on demand. Auto-regeneration
is therefore an *optional enhancement*, not a need. Accordingly, chokidar is
held as a conditional design (Variant B), not adopted.

## 5. Recommendation

**Adopt Variant A (status-quo).** Retain `bash` + `jq` + `bats-core` as the
settled routine-work standards. Do **not** add yq, just, duckdb (for routine
work), fx, or todo.txt-cli. Keep mise as-is (version manager). Defer entr. If
and when auto-regeneration of derived views is ever genuinely required, select
**Variant B: chokidar v5.0.0 in-process** in the delegation-observer plugin
(the only no-new-process mechanism), routed through the section-10
AI-Devtools workflow. Do not adopt Variant C (entr/watchexec background
process) under any condition -- background processes are forbidden.

## 6. Sources Cited

All 13 archived sources (15 files) pass the researcher's Phase A evaluation;
**12 tools cited, 0 excluded.**

1. jqlang. "jq." *Official jq README*, github.com/jqlang/jq, MIT. (jq-readme.md)
2. bats-core. "Bats-core: Bash Automated Testing System." *Official bats-core README*, github.com/bats-core/bats-core, MIT-style. (bats-readme.md)
3. Radman, Eric. "Event Notify Test Runner." *Official entr README*, github.com/eradman/entr. (entr-readme.md)
4. Radman, Eric. "ENTR 1." *entr man page*, dated 2026-03-02. (entr-man.md)
5. Watchexec project. "Watchexec." *Official watchexec README*, github.com/watchexec/watchexec. (watchexec-readme.md)
6. inotify-tools project. "inotify-tools." *Official inotify-tools README*, github.com/inotify-tools/inotify-tools. (inotify-tools-readme.md)
7. Miller, Paul. "Chokidar." *Official chokidar README*, github.com/paulmillr/chokidar, MIT. (chokidar-readme.md)
8. npm registry. "chokidar" (dist-tags.latest 5.0.0, MIT). registry.npmjs.org. (chokidar-npm.json)
9. Farah, Mike. "yq." *Official yq README*, github.com/mikefarah/yq, MIT. (yq-readme.md)
10. Rodarmor, Casey. "just." *Official just README*, github.com/casey/just. (just-readme.md)
11. jdx. "mise-en-place." *Official mise README*, github.com/jdx/mise. (mise-readme.md)
12. DuckDB. "DuckDB." *Official duckdb README*, github.com/duckdb/duckdb. (duckdb-readme.md)
13. Medvedev, Anton. "f(x)." *Official fx README*, github.com/antonmedv/fx, MIT. (fx-readme.md)
14. npm registry. "fx" (dist-tags.latest 39.2.0, MIT). registry.npmjs.org. (fx-npm.json)
15. todo.txt org. "todo.txt-cli." *Official todo.txt-cli README*, github.com/todotxt/todo.txt-cli, GPL v3. (todotxt-readme.md)

*Project-internal references (not external sources):* delegation-observer.ts
plugin; `scripts/session-log`; `scripts/tickets`; `scripts/ticker-render.sh`;
`Makefile test-shell`; res018/res021 (DIA-125 ticket automation); res026
(DIA-136 JSON-DB sibling).

## 7. Unarchived / Excluded

**None.** All 13 sources (15 files) were archived with 0 Phase A failures and
pass the researcher's evaluation. No source is excluded, and no source was
dropped under the DIA-072 archival rules.
