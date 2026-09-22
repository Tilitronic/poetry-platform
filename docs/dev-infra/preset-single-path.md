# Preset single path: `make opencode PRESET=<name>`

One supported way to launch opencode in the container with a chosen preset.
The override is one-way and one-run: it is validated, forwarded, and
forgotten. Nothing is persisted. (Campaign ticket DIA-260918-vsq8.)

## The one way

List names, then launch:

    make presets
    make opencode PRESET=free
    make opencode PRESET=muse-balanced

`make presets` prints the sorted keys of `presets` in
`.opencode/oh-my-opencode-slim.jsonc` (python3 stdlib only, no new
dependency). `make opencode PRESET=<name>` validates the name against that
registry before any container setup: an unknown name aborts loudly with the
available list (make exit 2), and nothing is launched. The launch prints
`Effective preset: <name> (source: <where>)` so the choice is always visible.

## Exit / change / relaunch flow

PRESET is a one-run override, not stored state:

1. `make opencode PRESET=free` (uses `free` for this session only)
2. Exit opencode.
3. `make opencode PRESET=muse-balanced` (next session uses `muse-balanced`)

No file is written, so there is nothing to clear between switches. A bare
`make opencode` (no PRESET) forwards no override and the runtime `preset`
field declared in `.opencode/oh-my-opencode-slim.jsonc` applies; the launch
prints `Effective preset: no override (source: none; ...)` so the fallback
is always visible.

## Deprecated: `make preset NAME=...`

`make preset` writes nothing. It exits 2 and prints:

    make preset is deprecated: Use 'make opencode PRESET=<name>' instead (list names with 'make presets').

The stored-selection path was removed because a persisted value could
diverge from the explicit PRESET flag depending on which tier ran first.
There is no store file anymore and nothing in the repo writes one.

## Troubleshooting

There is no second path: the `opencode` recipe reads only make-level
`PRESET` and forwards only `-e OH_MY_OPENCODE_SLIM_PRESET=<name>` into the
container (the sole preset env the 2.2.19 dist bundle reads; a bare `-e
PRESET=` is never read by the runtime). A stale
`OPENCODE_WORKSPACE_PRESET` export lingering in your interactive shell from
an old session is never read and never forwarded, so it cannot affect the
launch. Clear it once to avoid confusion:

    unset OPENCODE_WORKSPACE_PRESET

Unknown-name failure looks like this (make exit 2, no container started):

    Unknown preset "typo". Available presets: free,
    muse-balanced, openai-first-cost-balanced, promo-union-alpha

## Slash preset (out of scope)

Do not use a slash preset inside opencode. It is outside the
single-path contract and keeps the old unchanged behavior.
To choose a preset, exit and use `make opencode PRESET=<name>` instead.
