---
date: 2026-09-10
topic: Shell redirection write-scope bypass via curl/wget output flags and shell redirect operators
source: ai-specialist phase-1 gate (ai--1, reconciled), DIA-260827-ft3z
ticket: DIA-260827-ft3z
status: decided-not-implemented
---

# Shell Redirection Write-Scope Bypass (curl/wget output flags, redirect operators)

## 1. Bypass mechanism

Edit-scoped lanes look confined but are not. The researcher lane grants
`edit` scoped to `knowledge/*` (deny-all base) while its bash map allows
`curl *`, `wget *`, `trafilatura *`, `crwl *` with arbitrary arguments:

- `.opencode/opencode.jsonc:489-492` - researcher edit scope (`"*": "deny"`, `"knowledge/*": "allow"`)
- `.opencode/opencode.jsonc:493-499` - researcher bash allow-list (`curl *`, `wget *`, `trafilatura *`, `crwl *`)

The resource-manager lane is scoped to the OMO knowledge path with the same
shape of bash allow-list:

- `.opencode/opencode.jsonc:591-594` - resource-manager edit scope (`"*": "deny"`, `".opencode/oh-my-opencode-slim/knowledge/*": "allow"`)
- `.opencode/opencode.jsonc:595-600` - resource-manager bash allow-list (`curl *`, `wget *`, `trafilatura *`)

The escape: OpenCode bash permission patterns glob-match the command-string
prefix (`curl *` matches any invocation starting with `curl` plus arguments;
see 2026-08-13-bash-permission-wildcard-anti-pattern.md). Nothing constrains
ARGUMENTS, so these all pass the gate while writing outside the edit scope:

- `curl -o <any-path> <url>` / `curl --output <any-path> <url>`
- `wget -O <any-path> <url>`
- shell redirection the permission matcher never sees as a write: `... > file`, `... >> file`
- write-via-pipe: `... | tee <any-path>`, `... | tee -a <any-path>`

And the section-10 edit/write gate does not cover bash at all:
delegation-observer covers only `edit`/`write`/`apply_patch` and explicitly
excludes bash (delegation-observer.ts:2169-2179, no bash branch from :1831).
So a lane with `edit: knowledge/*` can write anywhere on disk through its
allowed fetch binaries. No tests cover the redirection escape under
`.opencode/plugins/__tests__/`.

## 2. Fix options considered (with evidence pointers)

- **Option 1 - Tighten bash arg patterns (e.g. deny `-o`/`-O` flags, deny `>`/`>>`/`|` tokens).** Evidence: same glob-prefix semantics as above (`.opencode/opencode.jsonc:493-499`, `:595-600`). REJECTED as primary: glob matchers cannot reliably parse shell syntax (quoting, flag bundling, `--output=`, env indirection), so every new pattern is one evasion away from obsolete. Allow-listing by command prefix is the wrong layer for output-path control.
- **Option 2 - Typed fetch-to-artifact tool/wrapper (URL + artifact dir in, resolved path out).** Evidence: researcher contract already names the intended sink (`knowledge/<resid>-<topic>/sources/` plus `.source-urls.txt` manifest, `.opencode/opencode.jsonc:480-484`). The wrapper resolves the output path itself and enforces containment inside the allocated artifact directory; lanes never name output paths, so there is no flag or redirect to abuse. Durable because the control lives at the path-resolution layer, not the command-string layer.
- **Option 3 - Defense-in-depth protected-path bash gate.** Evidence: the delegation-observer gap (delegation-observer.ts:2169-2179 excludes bash; no bash branch from :1831). A gate on resolved write targets denies writes to workflow-critical paths (`.opencode/*`, `scripts/*`, `AGENTS.md`, git metadata) regardless of which binary or operator performs them. Durable because it protects the paths, not the tools.

## 3. Developer decision (EBDV): Option 2+3, because argument-prefix controls cannot hold

Chosen variant: **Option 2 (primary) + Option 3 (defense-in-depth), plus
remove `curl *` / `wget *` as universal permissions.**

Because-justification: Option 1 fights shell syntax with string prefixes and
loses to the next quoting trick; Options 2+3 move the enforcement to the two
layers the bypass cannot route around - (a) the wrapper owns output-path
resolution and confines it to `knowledge/<allocated-id>/sources/`, and (b)
the bash gate denies protected paths no matter which binary or redirect
operator is used. Removing the universal `curl *` / `wget *` allows closes
the hole for lanes that migrate to the wrapper.

Scope exclusions (explicit developer scoping):

- **coder-interpreter scope is OUT** - broad interpreters (`node *`, `bun *`, `python3 *`, `.opencode/opencode.jsonc:337-342`) are a separate ticket, not this one.
- **This learnings entry is registration only** (AGENTS.md section 2.5 step 1): no `.opencode` config changes, no implementation here.

## 4. Reusable lesson

When a lane's edit scope is narrower than its bash allow-list, the bash
allow-list IS the write scope. Command-prefix glue (`curl *`) permits
arbitrary output flags and shell redirect operators, and an edit/write-only
observer never sees them. Fix at path resolution (typed wrapper owning the
output path) plus protected-path denial, not at command-string matching.

## 5. References

- DIA-260827-ft3z (this ticket - HIGH shell-permissions bypass via curl/wget redirection)
- DIA-260827-wfcx W-H2 (reaudit confirming `curl -o`, `wget -O`, redirection)
- .opencode/opencode.jsonc:337-342 (coder interpreters - OUT of scope, separate ticket)
- .opencode/opencode.jsonc:485-500 (researcher permission block)
- .opencode/opencode.jsonc:586-601 (resource-manager permission block)
- delegation-observer.ts:1831, :2169-2179 (section-10 edit/write-only coverage, bash excluded)
- 2026-08-13-bash-permission-wildcard-anti-pattern.md (glob-prefix semantics of `curl *`)
- 2026-08-20-scoped-write-permission-pattern.md (deny-all + scoped-allow edit pattern this bypass defeats via bash)

## Tags

DIA-260827-ft3z, opencode-config, permissions, bash-allowlist, write-scope-bypass, curl, wget, shell-redirection, delegation-observer, defense-in-depth, S10
