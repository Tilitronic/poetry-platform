## 1. Persisted workspace selection

- [ ] 1.1 Deliver the `/preset NAME` selection slice with RED seam tests written by a separate test-author instance before GREEN implementation. It accepts one exact configured name, persists only the canonical workspace selection through a verified durable write, reports the name/key/next-launch effect, and never changes current-session model routing. Acceptance: an isolated user-config test proves a new process reads the selection, symlinked paths share it, separate canonical paths do not, and write failures never report `Saved`. Depends on: none. Boundary dependency: `.sdd/opencode-config/architecture.md`.

- [ ] 1.2 Deliver the terminal `make preset NAME=NAME` slice using the same persisted-selection behavior. Acceptance: exactly one valid name produces the same verified next-launch selection and success details as `/preset`; missing name reports stored selection or `none` plus usage; extra or invalid input writes nothing. Depends on: 1.1. Boundary dependency: `.sdd/opencode-config/architecture.md`, `.sdd/dev-infra/architecture.md` ADR 8.

## 2. Deterministic launch resolution

- [ ] 2.1 Deliver startup resolution with RED seam tests written by a separate test-author instance before GREEN implementation. It resolves exact `PRESET=NAME`, then a valid workspace selection, then no preset before agent setup, and prints the effective preset/no-preset state and source. Acceptance: an isolated launch test proves one-run override precedence and that it does not change persisted selection. Depends on: 1.1. Boundary dependency: `.sdd/opencode-config/architecture.md`, `.sdd/dev-infra/architecture.md` ADR 8.

- [ ] 2.2 Deliver the fail-closed startup slice. Acceptance: unknown explicit values and stale, malformed, corrupt, or unknown stored values abort before agent setup, preserve stored data where applicable, and name the invalid value, canonical workspace key, and available exact names; absent selection starts with no preset. Depends on: 2.1. Boundary dependency: `.sdd/opencode-config/architecture.md`.

## 3. Public integration and verification

- [ ] 3.1 Update the documented preset controls and startup behavior to state next-launch-only selection, exact-name validation, precedence, no-preset default, fail-closed errors, and rollback behavior. Acceptance: documentation contains no claim of live switching and gives the three approved surfaces: `/preset NAME`, `make preset NAME=NAME`, and `make opencode PRESET=NAME`. Depends on: 1.2, 2.2.

- [ ] 3.2 Run the configured OMO, shell, and configuration gates plus the focused selector and startup seam tests. Acceptance: all tests pass, including isolated user-config persistence, project separation, override precedence, fail-closed-before-agent-setup behavior, truthful write failure, and startup source reporting. Depends on: 3.1.
