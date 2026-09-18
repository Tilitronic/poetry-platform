## 1. UID/GID Injection (docker-compose.yml + .env.example)

- [ ] 1.1 Add `USER_UID` and `USER_GID` to `.env.example` with a comment instructing developers to run `id -u` / `id -g` to find their UID/GID. Default value: `1000`.
- [ ] 1.2 Add `build.args` to `docker-compose.yml` `services.dev.build` section to forward `USER_UID: ${USER_UID:-1000}` and `USER_GID: ${USER_GID:-1000}` to `Dockerfile.dev`.
- [ ] 1.3 Verify that `docker-compose.yml` is valid YAML and `make test-config` passes.

**File ownership**: `.env.example`, `docker-compose.yml`. No overlap with other slices.
**Blocking edges**: none (can start immediately).
**Acceptance criteria**: `docker compose config` succeeds; `.env.example` contains `USER_UID=1000` and `USER_GID=1000` with comments.

## 2. Entrypoint Ownership Migration (dev-entrypoint.sh)

- [ ] 2.1 Extend the existing chown block in `dev-entrypoint.sh` (currently at L72, scoped to `/home/dev/.local/share/opencode`) to also chown `/workspace/.git`, `/workspace/node_modules`, `/home/dev/.local/share`, and `/home/dev/.cache` to `dev:dev`. Use `|| true` to prevent failures from blocking the entrypoint.
- [ ] 2.2 Verify that `dev-entrypoint.sh` is syntactically valid (`bash -n dev-entrypoint.sh`) and `make test-shell` passes.

**File ownership**: `dev-entrypoint.sh`. No overlap with other slices.
**Blocking edges**: none (can start immediately).
**Acceptance criteria**: `bash -n dev-entrypoint.sh` exits 0; chown block covers all four paths; `|| true` is present on each chown.

## 3. Bats Unit Test (scripts/**tests**/)

- [ ] 3.1 Create a new bats test file `scripts/__tests__/verify-pre-commit-uid-mismatch.bats` that:
  - Creates a temporary workspace with a mock `.git/` directory.
  - Sets `POETRY_WORKSPACE` to the temp workspace.
  - Mocks `lint-staged` to attempt writing to `.git/index`.
  - Runs `verify-pre-commit.sh` and verifies it succeeds (no permission errors).
- [ ] 3.2 Verify that `make test-shell` passes and the new bats test is discovered and executed.

**File ownership**: `scripts/__tests__/verify-pre-commit-uid-mismatch.bats` (new file). No overlap with other slices.
**Blocking edges**: none (can start immediately, but logically depends on slice 2 for the chown behavior being tested).
**Acceptance criteria**: `make test-shell` exits 0; new bats test file exists and passes.

## 4. Troubleshooting Documentation (docs/docker-dev.md)

- [ ] 4.1 Add a "Troubleshooting" section to `docs/docker-dev.md` documenting:
  - Symptom: `lint-staged` fails with `could not write index` when committing from the dev container.
  - Cause: UID mismatch between host and container.
  - Fix: add `USER_UID=$(id -u)` and `USER_GID=$(id -g)` to `.env`, then run `make clean && make up`.
  - Warning: `make clean` wipes volumes, including postgres data.
- [ ] 4.2 Verify that the documentation is clear and follows the existing style of `docs/docker-dev.md`.

**File ownership**: `docs/docker-dev.md`. No overlap with other slices.
**Blocking edges**: none (can start immediately).
**Acceptance criteria**: `docs/docker-dev.md` contains a troubleshooting section with the symptom, cause, fix, and warning.

## 5. Manual Verification (end-to-end)

- [ ] 5.1 After slices 1-4 are complete, perform manual verification:
  - Add `USER_UID=$(id -u)` and `USER_GID=$(id -g)` to `.env`.
  - Run `make clean && make up` to rebuild the image.
  - Run `make shell` to enter the dev container.
  - Verify that `git status` succeeds (no permission errors).
  - Verify that `touch .git/test-write && rm .git/test-write` succeeds (write access to `.git/`).
  - Run `git commit --allow-empty -m "test"` and verify the pre-commit hook passes.
- [ ] 5.2 Document the verification results (exit codes, output snippets) in the DIA-260821-m7vk ticket.

**File ownership**: none (manual verification only).
**Blocking edges**: depends on slices 1, 2, 3, 4 (all must be complete).
**Acceptance criteria**: manual verification succeeds; pre-commit hook passes; ticket is updated with evidence.

## Implementation Sequencing

**Parallel-safe slices** (no file overlap, can run concurrently):

- Slice 1 (docker-compose.yml + .env.example)
- Slice 2 (dev-entrypoint.sh)
- Slice 3 (bats test)
- Slice 4 (docs/docker-dev.md)

**Sequential dependency**:

- Slice 5 (manual verification) depends on slices 1-4.

**Recommended order**:

1. Dispatch slices 1-4 in parallel (or sequentially if preferred).
2. After all four slices are complete, perform slice 5 (manual verification).
3. Update the DIA-260821-m7vk ticket with verification evidence.
