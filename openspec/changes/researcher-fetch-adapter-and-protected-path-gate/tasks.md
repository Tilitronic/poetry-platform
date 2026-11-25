# Tasks: researcher fetch adapter and protected-path gate

> Proposal: `openspec/changes/researcher-fetch-adapter-and-protected-path-gate/proposal.md`
> Design: `openspec/changes/researcher-fetch-adapter-and-protected-path-gate/design.md`
> Spec: `openspec/changes/researcher-fetch-adapter-and-protected-path-gate/specs/write-scope-enforcement/spec.md`
> Source ticket: DIA-260827-ft3z

## 1. Red tests and tool registration

- [ ] 1.1 Write the failing pure destination-policy tests. **Acceptance:**
      the suite fails for the right reason and covers: path under `knowledge/`
      accepted; path under `.opencode/oh-my-opencode-slim/knowledge/`
      accepted; `../` escape rejected; absolute path outside the roots
      rejected; symlink escape rejected; non-http scheme rejected. **Blocks:**
      none. **Boundary:** pure module, no plugin imports, runs under Node in
      `make test-config`.
- [ ] 1.2 Write the failing tripwire-classifier tests. **Acceptance:** the
      suite fails for the right reason and covers: redirection to `.git/`
      blocked; `tee` to the ticket ledger blocked; `curl -o` to a protected
      path blocked; ordinary `pnpm test` allowed; a lane other than coder is
      out of scope. **Blocks:** none. **Boundary:** pure classifier, no plugin
      imports.
- [ ] 1.3 Write the config-gate negative test for the former hole.
      **Acceptance:** a bats case feeds the literal former commands
      `curl -o /workspace/anything http://x`,
      `wget -O /workspace/anything http://x`,
      `trafilatura -o /workspace/anything http://x`, and
      `crwl -o /workspace/anything http://x` through the config resolver
      against the real config and asserts deny; a second case builds a fixture
      that re-adds `curl *` to `researcher` and asserts the gate fails. The
      first case is RED on the current tree and MUST fail if the former hole
      is ever restored. **Blocks:** none.
- [ ] 1.4 Register the tool skeleton and pin the runtime facts.
      **Acceptance:** `.opencode/tools/fetch-source.ts` exists with the
      `{url, output_path}` argument schema and the agent guard; the GLOBAL
      permission block carries flat `"fetch-source": "deny"` and the
      `researcher` map carries `"fetch-source": "allow"` (agent rules append
      last, so the allow wins for researcher and the tool is hidden from every
      other lane); `opencode debug agent researcher` reports the tool and the
      flat-deny bash; `opencode debug agent coder` shows `fetch-source` is NOT
      in coder's tool surface; both outputs are recorded in the change notes.
      **Blocks:** none.

## 2. Typed fetch boundary

- [ ] 2.1 Implement the pure destination policy. **Acceptance:** all cases in
      1.1 pass; the module resolves against the workspace root, canonicalizes
      the parent after creating it, and rejects anything outside the two roots
      with a path-separator boundary. **Blocks:** 1.1.
- [ ] 2.2 Implement the tool handler and tier chain. **Acceptance:** the tool
      validates the destination before fetching, fetches with an argv array
      (no shell), publishes through a temp sibling and rename, returns
      `{status, tier, bytes, resolved_path}`, and rejects every caller except
      `researcher`. **Blocks:** 1.4, 2.1.
- [ ] 2.3 Confirm tier 3 presence and degradation. **Acceptance:** inside the
      dev container `crwl --version` is recorded; if absent, a fetch that
      exhausts earlier tiers returns a failed status with tier 3 marked
      unavailable and does not throw. **Blocks:** 2.2.

## 3. Config migration and gate extension

- [ ] 3.1 Migrate the permission maps. **Acceptance:** `researcher.bash` is
      the flat string `"deny"`; `designer.bash` is `"deny"`;
      `memory-manager.bash` is deny-first with only `git log *`,
      `git diff *`, `git show *`, `git status *`, and
      `bash scripts/validate-memory-shelf.sh *` (the whole-command pattern,
      with the trailing ` *` that also matches the bare form); the global
      block keeps flat `"fetch-source": "deny"` and `researcher` keeps
      `"fetch-source": "allow"`; `memory-manager`'s agent document prescribes
      exactly `bash scripts/validate-memory-shelf.sh` instead of inline
      `python3 -c`; `researcher` and `memory-manager` are removed from
      `EXEMPT_EDIT_BASH`. **Blocks:** 2.2.
- [ ] 3.2 Extend the config gate and turn 1.3 green. **Acceptance:** the four
      reproduced shapes are in `DANGEROUS_EXECUTION_SHAPES`; the doc-drift
      `FORBIDDEN` list covers the shell-claim spellings; the former-hole case
      resolves to deny and the re-added-`curl *` fixture fails
      `make test-config`. **Blocks:** 1.3, 3.1.

## 4. Protected-path tripwire

- [ ] 4.1 Implement the pure tripwire classifier. **Acceptance:** all cases in
      1.2 pass; the classifier reads only the explicit form set, applies the
      fixed protected set (`.git/`, `.opencode/session/`,
      `docs/dev-infra-audit/tickets/`), and never classifies an unknown form
      as safe-by-rule. **Blocks:** 1.2.
- [ ] 4.2 Wire the tripwire into `tool.execute.before`. **Acceptance:** the
      bash branch reads `output.args.command`, resolves the lane from
      `childSessionAgent.get(id) ?? sessionAgent.get(id)`, applies only to
      `coder` and `coder-escalated`, throws before execution, and appends a
      denial row. **Blocks:** 4.1.
- [ ] 4.3 Add the best-effort agent backfill. **Acceptance:** the plugin
      populates a `sessionAgent` map from the `session.created` event
      (`info.agent`, precedent
      `.opencode/plugins/needs-input-observer.ts:1407-1416`), and a test shows
      a session created after plugin load resolves without a parsed task id.
      This is a coverage widening, not a boundary: pre-restart and
      `task_revive` sessions remain out of scope. **Blocks:** 4.2.
- [ ] 4.4 Drive the real hook in the plugin harness. **Acceptance:** a test
      calls the real `tool.execute.before` with `output.args.command` set to a
      protected-path redirection and asserts a throw, and with an ordinary
      build command and asserts no throw. **Blocks:** 4.3.

## 5. Documentation and eligibility text

- [ ] 5.1 Update the researcher surfaces. **Acceptance:**
      `.opencode/agents/researcher.md`, the researcher `orchestratorPrompt` in
      `.opencode/oh-my-opencode-slim.jsonc`, and
      `.opencode/skills/research-pipeline/SKILL.md` describe the typed tool and
      the tier order, and contain no claim that the lane has a shell.
      **Blocks:** 3.1.
- [ ] 5.2 Update the changelog-lookup eligibility text. **Acceptance:**
      `.opencode/oh-my-opencode-slim/orchestrator_append.md` states that
      `designer` and `memory-manager` remain ineligible because their explicit
      deny-scoped maps admit no `python3`, and the "until their maps are
      closed" clause is removed. **Blocks:** 3.1.

## 6. Integrated verification

- [ ] 6.1 Run the full verification and review. **Acceptance:**
      `make test-config` exits 0 with the new cases; the plugin harness tests
      pass; after an OpenCode restart, one permitted fetch writes only under a
      knowledge root and one protected-path command is denied; the ai-auditor
      review is dispositioned; the changelog entry is added and validated.
      **Blocks:** 3.2, 4.4, 5.1, 5.2.
