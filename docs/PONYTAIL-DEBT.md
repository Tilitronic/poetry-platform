# Ponytail debt ledger

Harvested 2026-08-16 (DIA-183 ponytail-half closure, Variant B) via the
ponytail-debt skill workflow: one row per `ponytail:` comment marker found in
the repo, grouped by file. Rows are read-only records of deliberate shortcuts;
the `/ponytail-debt` command reproduces this scan on demand. Docs and tickets
that merely MENTION the convention (e.g. this ticket, AGENTS.md section 5.1,
lessons.md L880) are excluded per the skill's comment-prefix rule.

Row schema: location - what was deferred. ceiling: the limit named. upgrade:
the trigger to revisit. status: DIA-183 disposition.

## tools/opencode-docker/bin/opencode-docker

- :59 - block workspace=$HOME because a :Z relabel of the home dir fails on
  SELinux. ceiling: $HOME cannot be the docker workspace. upgrade: none named
  (implicit: revisit when SELinux relabel of $HOME works) -> no-trigger.
  status: kept-as-is (content verified accurate).
- :114 - copy gitconfig into .opencode-docker so :Z works (home dir blocks
  relabel). ceiling: gitconfig must be staged into the container dir.
  upgrade: none named (same SELinux ceiling as :59) -> no-trigger.
  status: kept-as-is.
- :120 - mount ponytail plugin from host if present. ceiling: legacy fallback
  path only; canonical install is the project plugin array
  (@dietrichgebert/ponytail, DIA-183). upgrade: drop the host mount when the
  host-side checkout-copy use case is obsolete; MUST stay while
  ssh-agent-forward.bats asserts this source in the allowed mount-source set.
  status: kept-as-is (comment updated by the DIA-183 plugin commit).
- :131 - mount host container socket read-only so docker compose works inside
  the container. ceiling: rootless podman socket exposes only the host user's
  own containers; missing socket -> warn but still launch. upgrade: none
  named -> no-trigger (accepted warn-but-launch behavior). status: kept-as-is.

## tools/opencode-docker/Dockerfile

- :199 - touch pre-creates the bind target because podman cannot create a
  mountpoint on a --read-only rootfs at start. ceiling: placeholder file is
  replaced by the socket bind mount at run time. upgrade: none named ->
  no-trigger (implicit: revisit when podman supports creating mountpoints on
  read-only rootfs). status: kept-as-is.

## tools/opencode-docker/scripts/collect-runtime-deps.sh

- :87 - keep dash in the image for Node.js child_process.spawn. ceiling: dash
  is extra size on top of the base. upgrade: none named -> no-trigger
  (implicit: revisit if the image size budget tightens). status: kept-as-is.

## .opencode/oh-my-opencode-slim/src/ (reference-only, not runtime-loaded)

The vendored OMO source checkout is reference-only (see
.opencode/oh-my-opencode-slim/REFERENCE-ONLY.md): src/ is not loaded at
runtime, the running plugin is the npm-installed package. These rows are
informational; they cannot be actioned here without diverging the vendored
reference (DIA-183 disposition).

- src/hooks/foreground-fallback/index.ts:46 - transient server errors are
  mixed into the retry regex list. ceiling: list grows unboundedly. upgrade:
  rename to isRetryableError and split from rate-limit detection when the
  list grows further (named in the comment). status: reference-only.
- src/tools/preset-manager.ts:220 - clarify that orchestratorPrompt is the
  config key name, not the agent name, in the excluded-fields doc. ceiling:
  field-mapping doc could mislead. upgrade: none named -> no-trigger
  (implicit: revisit on prompt/orchestratorPrompt field mapping change).
  status: reference-only.
- src/multiplexer/session-manager.ts:620 - intent-revealing query wrapper
  around backgroundJobBoard.isRunning. ceiling: thin wrapper, negligible.
  upgrade: none named -> no-trigger (rot risk). status: reference-only.

## apps/author-studio/src/stores/example-store.test.ts

- :1 - TODO(ponytail) variant (not a `ponytail:` marker): template-store
  boilerplate coverage only. ceiling: scaffold test, not real business
  coverage. upgrade: replace once real stores (Orchestrator-backed state)
  exist (named in the comment). status: kept-as-is (genuine test-coverage
  deferral, serviced by /ponytail-debt).

---

Summary: 9 `ponytail:` markers + 1 TODO(ponytail) variant = 10 ledger rows;
7 rows carry no explicit upgrade trigger (no-trigger tags: opencode-docker
:59, :114, :131, Dockerfile :199, collect-runtime-deps.sh :87,
preset-manager.ts :220, session-manager.ts :620). 3 rows name their upgrade
trigger (opencode-docker :120, foreground-fallback :46, example-store :1).
