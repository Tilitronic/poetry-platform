# Root-cause: host-only `make test-infra` failure in check-compose-config.bats "compose config validation fails -> non-zero exit"

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: finding
evidence-source: scripts/__tests__/check-compose-config.bats:138-181 ; scripts/check-compose-config.sh:29-49 ; scripts/container-engine.sh:44-92
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

Campaign ticket DIA-260926-ch1d. Analysis lane ana-260927-8yqj.

## Verdict (one line)

The test is **non-hermetic against the ambient `COMPOSE_ENGINE`**: it plants a fake
`docker` only, but when the host exports `COMPOSE_ENGINE=podman` the engine resolves to
`podman` through a code path that never consults `PATH`, so the **real host podman**
validates the test's **valid** planted `docker-compose.yml` and exits 0. **H1 confirmed,
H2 rejected. The defect is PRE-EXISTING (introduced at `1a168d77`), not caused by
`3322d57e` or `6a2896a3`.**

---

## Q1. Regression or pre-existing? -> PRE-EXISTING (predates both named commits)

`git log --oneline -- scripts/__tests__/check-compose-config.bats` and
`git log -S install_engine_fakes` give the full lineage of the failing test:

```
f67a97bc  2026-09-22 18:28  impl: container topology audit            <- test BORN, hermetic
1a168d77  2026-09-22 18:46  fix: reviewer findings S1-S6, P1-P8       <- DEFECT introduced
...
3322d57e  2026-09-26 17:44  test(compose): gate host-scoped tests on context (superseded)  <- touched skip only
6a2896a3  2026-09-26 18:01  test(compose): exercise host path hermetically                  <- touched skip only
```

Timeline of the engine-fake mechanism in the failing test:

| commit   | what the failing test did for engine faking                          | hermetic vs `podman`? |
|----------|----------------------------------------------------------------------|-----------------------|
| f67a97bc | `install_engine_fakes` + `FAKE_ENGINE_COMPOSE_CONFIG_FAIL=1`         | **YES** (faked docker AND podman) |
| 1a168d77 | replaced it with an inline **docker-only** fake heredoc (bats:148)   | **NO**  (podman fake dropped)  |
| 3322d57e | unchanged fake; added `is_in_dev_container` skip guard               | (skip only)                    |
| 6a2896a3 | unchanged fake; removed skip, added fake `hostname`                  | (skip only)                    |

- `git blame` confirms the inline docker-only fake heredoc is authored by **`1a168d77`**
  (bats:146-148), while the `run`/`assert_status` lines are `f67a97bc` (bats:177-179).
- `git show f67a97bc:...bats` proves the original `install_engine_fakes` planted BOTH
  a `docker` and a `podman` fake, each honoring `FAKE_ENGINE_COMPOSE_CONFIG_FAIL`.
- `3322d57e` and `6a2896a3` (the two commits the task asked about) **only** changed the
  in-container skip logic; neither touched the engine-faking defect.

Conclusion: the host-only failure is a **latent defect introduced at `1a168d77`** that
predates `3322d57e`/`6a2896a3`. It stays dormant on any host whose engine resolves to
`docker` (the fake intercepts) or where `COMPOSE_ENGINE` is unset; it fires only when the
host exports `COMPOSE_ENGINE=podman` and a real `podman` is on `PATH`.

---

## Q2. Root cause - exact mechanism

### Branch map of `check-compose-config.sh` (which exit is taken)

```
check-compose-config.sh
  L23  is_in_dev_container?  -> hostname=="poetry-dev" ?
        YES -> L25 print host-scoped note, exit 0     (NOT this: fake hostname="test-host")
  L29  engine="$(container-engine.sh select)"          <- ROOT: see engine resolution below
  L40  command -v "$engine" ?  -> NO -> exit 1 "not found on PATH"  (NOT this: status was 0)
  L46  if ! bash container-engine.sh compose config --quiet ; then
        TRUE  -> L47 FAIL "compose config --quiet failed", exit 1   <- EXPECTED (in-container)
        FALSE -> L51 exit 0                                          <- ACTUAL (host)
```

The host took the **L46 FALSE -> L51 exit 0** branch: `compose config` *succeeded*.

### Why `compose config` succeeded on the host but not in-container

The decisive branch is in `container_engine_select` (container-engine.sh:44-70):

```
container-engine.sh:45  engine="${COMPOSE_ENGINE:-}"
container-engine.sh:46  if [ -n "$engine" ]; then
container-engine.sh:48    case "$engine" in docker|podman) printf "$engine"; return 0 ;;
                          #  ^^^ EXPLICIT OVERRIDE RETURNS IMMEDIATELY.
                          #      It NEVER runs `command -v docker` / `readlink`,
                          #      so the test's fake `docker` on PATH is bypassed.
container-engine.sh:59  # only reached when COMPOSE_ENGINE is UNSET:
container-engine.sh:59  if command -v docker; then readlink -f ... ; fi   # finds the FAKE docker
container-engine.sh:69  printf "docker"
```

- **In-container** (`COMPOSE_ENGINE` unset, no engine reachable): select falls to the
  autodetect branch (L59), `command -v docker` finds the test's **fake docker** (prepended
  to PATH), returns `docker`; then `container_engine_compose` runs `docker compose config
  --quiet` -> fake -> `exit 1` -> script L46 TRUE -> **exit 1** (assertion satisfied).
- **On the host** (`COMPOSE_ENGINE=podman` exported, real `podman` present): select takes
  the explicit-override branch (L48), returns `podman` **without ever looking at PATH**, so
  the test's fake docker is never consulted. `container_engine_compose` (L91 `"$engine"
  compose "$@"`) runs the **real `podman compose config --quiet`** against the test's
  planted `docker-compose.yml` (bats:43-47) which is a **valid** minimal compose doc, so it
  succeeds -> `exit 0` -> script L46 FALSE -> **exit 0** -> `assert_status 1` fails "got 0".

The fake is planted for `docker` **only** (bats:148, since `1a168d77`); there is no `podman`
fake to intercept the override path. The test's own premise is also fragile: it plants a
**valid** config and relies entirely on the fake to reject it, so ANY real engine that
bypasses the fake will accept it.

### H1 (environment / engine difference) -> CONFIRMED

Yes. The "validation fails" path depends on the fake `docker` intercepting. When a **real
container engine is present on the host** and `COMPOSE_ENGINE` resolves the engine to a
binary the test did not fake (`podman`), the host **accepts the config the test expects
rejected**. In-container the engine is absent and `COMPOSE_ENGINE` unset, so the fake is
always used and the test is green. This is exactly the host-vs-container divergence.

### H2 (bash 3.2 `set -euo pipefail` + `| head` SIGPIPE 141) -> REJECTED

The failure is `expected 1, got 0` (exit 0), the opposite signature of the SIGPIPE class
(which yields 141, a non-zero). Grepping the failure path:

```
grep -nE '\|\s*(head|tail|grep -q)'  scripts/check-compose-config.sh scripts/compose-env.sh
                                     scripts/in-container.sh scripts/container-engine.sh
```

- `check-compose-config.sh`, `compose-env.sh`, `in-container.sh`: **no pipes at all** in the
  select+compose-config path.
- `container-engine.sh` pipes are only L111 / L138 (`... | grep -qx "dev"`) inside
  `container_engine_dev_running` / `container_engine_gate` - **not on the path this test
  exercises** (test runs `select` + `compose config`). And `grep -qx` reads its input to
  EOF, so it cannot trigger the `head`-style SIGPIPE 141.

H2 is a different, already-fixed failure class (commit `a9f4e20d`) and does not apply here.

---

## Q3. Proposed fix (minimal, concrete - NOT implemented)

**Primary (one line, matches the established idiom in this very file):** pin the engine to
the fake the test actually plants. `3322d57e`/test-3 already use `run env COMPOSE_ENGINE=...`
(bats:126). Apply the same to the failing test at bats:177:

```
# bats:177  current:
run bash "$tree/scripts/check-compose-config.sh"
# proposed:
run env COMPOSE_ENGINE=docker bash "$tree/scripts/check-compose-config.sh"
```

Forcing `COMPOSE_ENGINE=docker` makes `container_engine_select` return `docker` via the
explicit branch, which then hits the test's fake `docker` (exit 1) regardless of the host's
ambient `COMPOSE_ENGINE`. Deterministic on docker hosts, podman hosts, and in-container.

**Defense-in-depth (optional, addresses the fragile premise):** plant an **invalid**
`docker-compose.yml` in the failing test (e.g. `services: [`) instead of a valid one, so the
assertion holds even if a real engine is ever reached. The original `install_engine_fakes`
(f67a97bc) faked both engines; if a broader fix is wanted, restore a `podman` fake that
honors the same fail switch. But the minimal, sufficient change is the `COMPOSE_ENGINE=docker`
pin.

Do NOT fix in `check-compose-config.sh`/`container-engine.sh`: honoring an explicit
`COMPOSE_ENGINE` override is correct production behavior; the bug is purely test hermeticity.

---

## Q4. Evidence

### Static references
- Failing assertion: `scripts/__tests__/check-compose-config.bats:177` (`run`) and `:179` (`assert_status 1`).
- Docker-only fake heredoc: `scripts/__tests__/check-compose-config.bats:148` (blame `1a168d77`).
- Valid planted config the real engine accepts: `scripts/__tests__/check-compose-config.bats:43-47`.
- Engine override bypasses PATH: `scripts/container-engine.sh:45-50` (vs autodetect `:59-70`).
- Engine invocation: `scripts/container-engine.sh:91` (`"$engine" compose "$@"`).
- Success branch that returns 0: `scripts/check-compose-config.sh:46` -> `:51`.
- Established pin idiom: `scripts/__tests__/check-compose-config.bats:126`.

### Reproduction (host condition simulated; no repo files modified)
1. Container-like (fake docker, `COMPOSE_ENGINE` unset) -> **exit 1** (correct):
   ```
   $ PATH="$fakebin:$PATH" bash .../check-compose-config.sh ; echo $?
   FAIL: docker compose config --quiet failed. ...
   EXIT=1
   ```
2. BSD/`macOS` `readlink` stub (`-f` unsupported) alone -> still **exit 1** (docker path
   unaffected; isolates that readlink is NOT the trigger):
   ```
   $ PATH="$bsd:$PATH" bash container-engine.sh select   -> docker  (select_exit=0)
   ```
3. `COMPOSE_ENGINE=podman` + real-podman stand-in (valid file -> exit 0) -> **exit 0**
   (reproduces the host symptom):
   ```
   $ env -u COMPOSE_ENGINE PATH="$b:$PATH" bash .../check-compose-config.sh ; echo $?  -> EXIT=1
   $ env    COMPOSE_ENGINE=podman PATH="$b:$PATH" bash .../check-compose-config.sh ; echo $?  -> EXIT=0
   ```
4. Under the **real vendored bats**, exporting `COMPOSE_ENGINE=podman` with a podman
   stand-in on ambient PATH flips exactly the failing test:
   ```
   $ COMPOSE_ENGINE=podman PATH="$sysbin:$PATH" bats scripts/__tests__/check-compose-config.bats
   ok 1 ...
   ok 2 ...
   ok 3 ...
   not ok 4 check-compose-config: compose config validation fails -> non-zero exit   # expected 1, got 0
   ok 5 ...
   ```
   This matches the reported host failure precisely (test 4 red, others green).

### Environment sanity
- Current (container) env: `COMPOSE_ENGINE=<unset>`, `COMPOSE_FILE=<unset>` -> suite green,
  consistent with the host-only diagnosis.

---

## Summary matrix

| Dimension            | In-container (GREEN)                          | Host macOS (RED)                                |
|----------------------|-----------------------------------------------|-------------------------------------------------|
| ambient COMPOSE_ENGINE | unset                                       | `podman` exported (documented podman-host config) |
| engine select branch | autodetect L59 -> fake `docker` on PATH       | explicit override L48 -> `podman` (PATH ignored) |
| binary invoked       | test's fake `docker` (exit 1 on compose config) | **real `podman`** (no fake planted)             |
| planted compose file | ignored by fake                               | **valid** -> real podman accepts (exit 0)       |
| script exit          | 1 (L47 FAIL branch)                           | 0 (L51 success branch)                          |
| assert_status 1      | pass                                          | **fail: expected 1, got 0**                     |
