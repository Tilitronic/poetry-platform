# Preset Switching

Select named agent-model presets per project. A selection applies on the
next launch only: the current process already loaded its agent
configuration, so nothing switches in place.

## Controls

| Command | Description |
|---------|-------------|
| `/preset` | List available presets (highlights the stored one) |
| `/preset <name>` | Save the named preset for the next launch |
| `make preset NAME=<name>` | Save from the host shell (same store) |
| `make preset NAME=none` | Clear the stored selection |

## Where the selection lives

One project-local file, shared by host and container:

`<projectRoot>/.opencode/state/workspace-preset.json`

Schema v2: `{ "version": 2, "preset": "<name>" | null }`. Writes are
atomic (tmp file + rename + readback verify). The project root is the
nearest ancestor containing `.opencode` or `.git`, so a save from any
subdirectory lands in the same file a root launch reads.

## Resolution order (first hit wins)

1. `PRESET` env var (explicit CLI override; unknown names warn loudly and
   degrade to no preset, the launch continues).
2. `OPENCODE_WORKSPACE_PRESET` bridge (deprecated, read-only: honored for
   the transition because `make opencode` still forwards it, never written
   back; reported as source `bridge`).
3. Project-local store (the file above; corrupt or unknown values warn
   loudly and degrade to no preset).
4. Config `preset` field (the declared project default; unknown values warn
   loudly and degrade to no preset).
5. None (no preset).

Every failure names the source, the value, the project root, the store
path, and the available presets. The loader logs one line per launch:

`[oh-my-opencode-slim] Effective preset: <name|no preset> (source: <PRESET override|bridge (deprecated)|stored|config preset|none>)`

The legacy global store (`~/.config/opencode/workspace-presets.json`,
schema v1) is warn-only: a stale entry there is ignored with a hint to
re-save, never applied. This was the DIA-260918-yug6 root cause: `make
preset` used to write the host-global store under the host path identity,
which the container never read.

## Launch-path matrix

| Launch path | How the selection arrives |
|-------------|---------------------------|
| `make opencode` | Host resolves first, forwards the value via env bridge |
| `make shell` then `opencode` | Container reads the project-local store directly |
| `docker exec` then `opencode` | Container reads the project-local store directly |
| Host-direct `opencode` | Host reads the project-local store directly |
| Subdirectory CWD | Walk-up finds the project root config and store |

All five paths converge on the same file, so they agree. Verified
(DIA-260918-yug6 F1 matrix): compose `dev` Up 3h + `postgres` Up 3h;
`make preset NAME=free` wrote hash
`8c6767f3e57bfbee1df7fd679eee938551a328ac7000c031e41b6244cc7b6e80`
identical on host and container; host resolve reported `free (stored)`
from the root and from `apps/author-studio` via walk-up. The stale host
global entry (`promo-union-alpha`, schema v1) explains the old symptom;
the container had no legacy file, as expected; container env was empty
for direct exec, as expected.

## Project default (tier 4)

The workspace config declares `"preset": "muse-balanced"` (project
`.opencode/oh-my-opencode-slim.jsonc` line 3). Before DIA-260918-yug6 this
field was silently ignored, so launches with no stored selection got no
preset. It is now the tier-4 fallback: routing changed from old `none`
to new `muse-balanced` whenever no louder tier selects. Any stored
selection, bridge value, or `PRESET` override still beats it.

## `free` presets: selection vs activation

If `free` resolves correctly (the Effective preset line says `free`) but
models still misbehave, that is an activation problem, not a selection
problem: `*-free` model IDs depend on provider (Zen) auth and
entitlement. Diagnose those as model/auth errors, not preset-resolution
mysteries.

## Example Configuration

```jsonc
{
  "presets": {
    "cheap": {
      "orchestrator": { "model": "anthropic/claude-3.5-haiku" },
      "code-navigator": { "model": "openai/gpt-5.4-mini" }
    },
    "powerful": {
      "orchestrator": { "model": "openai/gpt-5.5" }
    }
  }
}
```

## Supported Fields

The following preset entry fields merge over the base agent config at
launch (root `agents.*` entries still beat preset entries per key):

| Field | Description |
|-------|-------------|
| `model` | Model ID in `provider/model` format. Array form (fallback chains) is resolved to the first entry |
| `temperature` | Inference temperature (0-2) |
| `variant` | Model variant (e.g. `"thinking"`) |
| `options` | Provider-specific options (e.g. thinking budget) |

## Example Output

```
/preset
```

```
Stored selection: cheap
Available presets:
  cheap <- stored
    orchestrator -> anthropic/claude-3.5-haiku
    code-navigator -> openai/gpt-5.4-mini
  powerful
    orchestrator -> openai/gpt-5.5

Usage: /preset <name> to save for the next launch.
```

```
/preset powerful
```

```
Saved preset "powerful" for workspace /path/to/project. It applies on the next launch only.
```

> See [Configuration](configuration.md) for the full preset option reference.
