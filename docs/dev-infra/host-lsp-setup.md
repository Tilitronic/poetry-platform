# Host Language Server Setup (dev-infra)

Install and verify the four language servers (TypeScript, YAML, Python, Rust)
on **your host**, outside the dev container. This mirrors what `Dockerfile.dev`
already ships inside the container (see
`openspec/changes/dev-infra-language-servers`; `yaml-language-server` added in
DIA-180 A1) so editors running in host mode (VSCode, opencode-on-host) get the
same LSP intelligence.

Everything below is owner-run. The scripts are deliberately small, bash-only,
and idempotent — they never touch your shell rc files and never use `sudo`.

## Prerequisites

- **bash >= 4** (Linux/macOS host; Windows developers use the dev container).
- **Node.js >= 18** and **npm** on `PATH` — required for the TypeScript, YAML,
  and Python language servers (`typescript-language-server`,
  `yaml-language-server`, `pyright`).
- **rustup** on `PATH` — OPTIONAL, only for `rust-analyzer`. If absent, the
  install script warns and continues (partial install); or skip Rust entirely
  with `SKIP_RUST=1`.
- **jq** on `PATH` — required by `scripts/gen-jsconfig.sh` (the workspace-layout
  → `jsconfig.json` generator). The `scripts/check-host-jq.sh` probe verifies
  both presence and functional correctness (`jq -n '1+1'` returns `2`). No
  version pin.

## jq — generic host dependency

`scripts/gen-jsconfig.sh` invokes `jq` to emit `jsconfig.json` from the
workspace layout. The dev container ships `jq`, but a fresh host may not —
install it with your preferred method. The probe is install-method-agnostic:
it checks the binary on `PATH`, not how it got there.

```bash
# Debian/Ubuntu
sudo apt install jq

# macOS / Linux via Homebrew
brew install jq

# via mise (version manager)
mise install jq
```

Verify:

```bash
bash scripts/check-host-jq.sh     # or: make check-host-jq
```

Expected output on a host with functional `jq`:

```
ok: jq 1.7.1 (host, functional)
summary: 1 ok, 0 fail
```

Exit `0` = present and functional. Exit `1` = missing or broken; the fail line
carries a remediation pointer.

## Step 1 — Install

From the repo root:

```bash
bash scripts/install-host-lsp.sh
```

The script sources the single source of truth `scripts/lsp-versions.env` and
installs:

| Tool                         | Pinned version | Method                                                   |
| ---------------------------- | -------------- | -------------------------------------------------------- |
| `typescript-language-server` | 5.3.0          | `npm install -g --prefix "$HOME/.local"`                 |
| `yaml-language-server`       | 1.24.0         | `npm install -g --prefix "$HOME/.local"`                 |
| `pyright`                    | 1.1.411        | `npm install -g --prefix "$HOME/.local"`                 |
| `rust-analyzer`              | 1.97.1         | `rustup component add rust-analyzer` (if rustup present) |

It is idempotent: re-running emits `already installed: ...` lines and skips.
Exit codes are `0` on full or partial success and `1` only on unrecoverable
errors (see Troubleshooting).

## Step 2 — PATH

npm installs into `$HOME/.local` (prefix is passed per-invocation; your shell
rc is never modified). Add it to `PATH` yourself — pick your shell:

```bash
# bash — add to ~/.bashrc
export PATH="$HOME/.local/bin:$PATH"

# zsh — add to ~/.zshrc
export PATH="$HOME/.local/bin:$PATH"

# fish — add to ~/.config/fish/config.fish
fish_add_path "$HOME/.local/bin"
```

## Step 3 — Verify

```bash
bash scripts/check-host-lsp.sh     # or: make check-host-lsp
```

Expected output on a fully configured host:

```
ok: typescript-language-server 5.3.0 (host, version matches scripts/lsp-versions.env)
ok: yaml-language-server 1.24.0 (host, version matches scripts/lsp-versions.env)
ok: pyright 1.1.411 (host, version matches scripts/lsp-versions.env)
ok: rust-analyzer 1.97.1 (container poetry-dev, version matches scripts/lsp-versions.env)
summary: 4 ok, 0 fail, 0 warn, 0 skip
```

> **rust-analyzer is container-first (DIA-106):** `check-host-lsp` probes
> rust-analyzer THROUGH the dev container (`docker compose exec`), not the
> host PATH. When the dev container is up, the ok-line reads `(container
poetry-dev, ...)`. The host PATH probe runs only as a fallback while the
> container is down (designed drift detection: the host rustup default stays
> 1.83.0, so the host fallback reports `fail:` against the 1.97.1 pin until
> the host toolchain is bumped).

**Tolerant gate (DIA-071):** a MISSING host tool emits `warn:` and does NOT
fail the gate — the dev container provides all four language servers, so an
unconfigured host is expected and harmless (`make test-shell`/`make test-infra`
exit 0). Version DRIFT on a present tool still fails (drift detection is the
gate's purpose). Set `CHECK_HOST_LSP_STRICT=1` to restore the pre-DIA-071
hard-fail on missing tools (hosts that must have full LSP parity, e.g. CI):

```bash
CHECK_HOST_LSP_STRICT=1 bash scripts/check-host-lsp.sh
```

Exit `0` = all good (warns are not failures). Exit `1` = at least one failure;
the script lists every failing tool before exiting.

## Escape hatches

- **`SKIP_RUST=1`** — skip `rust-analyzer` entirely (install emits
  `skip: rust-analyzer (SKIP_RUST=1)`; the probe reports `skip:` and does not
  fail). Use when Rust is not needed for your work, or when rustup is absent
  and you don't want the warning. TS/Python/YAML are NOT skippable.
- **`CHECK_HOST_LSP_STRICT=1`** — restore the pre-DIA-071 hard gate: a missing
  host tool becomes a `fail:` (exit 1) instead of a tolerant `warn:`. Use on
  hosts that must have full LSP parity (CI, shared dev machines).
- **`NPM_PREFIX=/path`** — use a non-standard npm global prefix:
  `NPM_PREFIX=/custom/prefix bash scripts/install-host-lsp.sh` (and add
  `/custom/prefix/bin` to PATH yourself). The scripts default to
  `$HOME/.local`.

## Verification (T11 — manual UX checklist)

After install + probe pass, confirm the language servers actually work in your
editor of choice (VSCode, opencode-in-container, or opencode-on-host): go-to
definition, hover type info, and diagnostics on `.ts` / `.rs` / `.py` files.

The checklist lives in the change archive:
`openspec/changes/dev-infra-language-servers/verification-T11.md`.
Open each file type, run the listed checks, and tick them off. Record which
client you used and the date/initials.

## Troubleshooting

### `make test-shell` shows `warn:` lines at `check-host-lsp` on an unconfigured host

**Expected on hosts that have not run the install yet** — this is the DIA-071
tolerant-gate behavior, not a bug. `make test-shell` runs `check-host-lsp` as a
prerequisite before any bats test, and on a fresh host the four LS binaries
are absent. Because the dev container provides all four language servers, the
gate WARNS and exits 0 — the bats suite still runs:

```
warn: typescript-language-server — not found on host PATH. The dev container provides it; install on the host only for host-mode editors: scripts/install-host-lsp.sh (see docs/dev-infra/host-lsp-setup.md)
summary: 3 ok, 0 fail, 1 warn, 0 skip
```

To turn the warns into `ok:` lines, run `bash scripts/install-host-lsp.sh` once
(Step 1). To turn missing tools back into hard failures (pre-DIA-071
behavior), set `CHECK_HOST_LSP_STRICT=1`:

### `make test-shell` fails at `check-host-jq` on an unconfigured host

**Expected on hosts that have not installed `jq` yet** — this is the Gate B
live-state consequence (Q7a), not a bug. `make test-shell` runs
`check-host-jq` as a prerequisite before any bats test, and on a host without
`jq` the probe fails with a remediation pointer:

```
fail: jq — not found on PATH. Install jq (e.g. sudo apt install jq, brew install jq, or mise install jq) — see docs/dev-infra/host-lsp-setup.md
summary: 0 ok, 1 fail — see above
```

Fix: run one of the install pointers in the `jq — generic host dependency`
section above; post-install, `make test-shell` passes. The bats suite (Gate A)
still runs once `jq` is present — the probe only gates on host tool presence.

### EACCES during npm install

The install script writes to `$HOME/.local` by default and never uses `sudo`.
If npm reports `EACCES`:

- Check `$HOME/.local` ownership/permissions — it must be writable by your
  user: `ls -ld "$HOME/.local"`.
- Fix ownership if a previous root/sudo install took it over:
  `sudo chown -R "$USER":"$(id -gn)" "$HOME/.local"` (one-time fix, not a
  script behavior).
- Or use a prefix you control: `NPM_PREFIX="$HOME/.npm-global"` + add
  `$HOME/.npm-global/bin` to PATH.

Do NOT run the install script with `sudo` — it would write to root-owned
paths and leave the host in a worse state.

### Version mismatch (`fail: <tool> — <actual> on PATH, expected <pinned>`)

The probe compares the `--version` output of the binary on `PATH` against
`scripts/lsp-versions.env`. Causes and fixes:

- **Stale install** — run `bash scripts/install-host-lsp.sh` again (it
  reinstalls when the on-PATH version differs from the pin).
- **Wrong binary on PATH** — another copy of the tool (e.g. a distro package)
  shadows the npm/rustup install. Check `command -v <tool>` and adjust PATH so
  the intended install wins (see Step 2).
- **Pin updated upstream** — bump the version in `scripts/lsp-versions.env`
  and re-run the install. `rust-analyzer` tracks your active rustup toolchain:
  if your host toolchain is newer than the pin, either pin
  `RUST_ANALYZER_VERSION` to your `rustc --version` release or set
  `SKIP_RUST=1`. `yaml-language-server` follows the same pin/bump flow as
  `typescript-language-server` (DIA-180 A1).

### YAML editing: LSP + the memory-shelf schema gate

`yaml-language-server` gives YAML intelligence (syntax, schema hints) in
editors, but agents do not consume LSP diagnostics — the machine-enforced
safety net for agent-written YAML is the repo gate
`scripts/validate-memory-shelf.sh` (wired into `make test-config`), which
validates `.opencode/memory-shelf.yaml` against
`scripts/schemas/memory-shelf.schema.json` (DIA-180 A2). YAML files outside
the shelf that agents write get a schema per DIA-180 A2 as the analysis
(Deliverable B) identifies them.

### rustup not found (install warning)

```
warning: rustup not found; rust-analyzer not installed. Install from https://rustup.rs or set SKIP_RUST=1 to suppress.
```

This is a warning, not an error — the script exits `0` (partial install).
Install rustup from <https://rustup.rs> and re-run, or set `SKIP_RUST=1` to
skip Rust analysis. The probe detects rust-analyzer regardless of install
method (rustup or `apt install rust-analyzer`).

### Partial-install recovery

The install script exits `0` on partial installs (rust-analyzer skipped).
To complete a partial install later: re-run `bash scripts/install-host-lsp.sh`
after installing rustup / unsetting `SKIP_RUST`. To undo host installs:
`npm uninstall -g typescript-language-server pyright` and
`rustup component remove rust-analyzer` (see the change rollback plan in
`proposal.md`).
