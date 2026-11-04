#!/usr/bin/env node
/**
 * DIA-260827-ft3z task 1.1: pure destination-policy RED tests (test-author pass).
 *
 * Subject: .opencode/plugins/lib/destination-policy.ts (design.md D3 seam;
 * the implementer lands it in task 2.1). Contract pinned here:
 *   resolveOutputPath(workspaceRoot, outputPath)
 *     -> { ok: true, resolvedPath } | { ok: false, reason }
 *   checkFetchUrl(url)
 *     -> { ok: true } | { ok: false, reason }
 * Two roots only: knowledge/ and .opencode/oh-my-opencode-slim/knowledge/,
 * resolved with a path-separator boundary - `../` escape, absolute-outside
 * and symlink escape all rejected; only http/https URLs accepted.
 *
 * SEAM DECISION: plain Node ESM importing the pure .ts module directly.
 * Node 24.18 (the .mise.toml / Dockerfile.dev pin) strips types natively,
 * the same proven pattern as scripts/__tests__/routing-order-gate.test.mjs
 * importing .opencode/plugins/lib/routing-gate.ts (verified green in this
 * repo, wired into make test-config with no loader flags). No build step,
 * no bun harness, no .mjs module that the TypeScript consumers would then
 * have to import outside the plugin typecheck.
 *
 * EXPECTED RED at this commit: the module does not exist yet, so the suite
 * fails at import with ERR_MODULE_NOT_FOUND. That is the point of task 1.1.
 *
 * Run: node scripts/__tests__/destination-policy.test.mjs
 * Wired into `make test-config`.
 */
import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, rmSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

// Production seam - created by task 2.1 (implementer lane), not by this suite.
import {
  resolveOutputPath,
  checkFetchUrl,
} from '../../.opencode/plugins/lib/destination-policy.ts';

describe('DIA-260827-ft3z destination policy (task 1.1)', () => {
  let base;
  let root;
  let outside;

  before(() => {
    // base/workspace = the workspace root under test; base/outside = a real
    // directory outside both knowledge roots, used by the absolute and
    // symlink escape cases. Roots are pre-created so the suite tests the
    // CONTAINMENT property only, not directory creation.
    base = mkdtempSync(join(tmpdir(), 'dia-260827-ft3z-dest-'));
    root = join(base, 'workspace');
    outside = join(base, 'outside');
    mkdirSync(join(root, 'knowledge', 'res-1', 'sources'), { recursive: true });
    mkdirSync(join(root, '.opencode', 'oh-my-opencode-slim', 'knowledge', 'res-9'), {
      recursive: true,
    });
    mkdirSync(outside, { recursive: true });
    // knowledge/link -> base/outside: a symlink whose target escapes both roots.
    symlinkSync(outside, join(root, 'knowledge', 'link'), 'dir');
  });

  after(() => {
    if (base) rmSync(base, { recursive: true, force: true });
  });

  it('accepts a path under knowledge/', () => {
    const v = resolveOutputPath(root, join('knowledge', 'res-1', 'sources', 'page.md'));
    assert.equal(v.ok, true, 'expected accept, got reject: ' + (v.reason || 'no reason'));
    assert.ok(
      v.resolvedPath.endsWith(join('knowledge', 'res-1', 'sources', 'page.md')),
      'resolvedPath must point at the requested file under knowledge/, got: ' + v.resolvedPath,
    );
  });

  it('accepts a path under .opencode/oh-my-opencode-slim/knowledge/', () => {
    const v = resolveOutputPath(
      root,
      join('.opencode', 'oh-my-opencode-slim', 'knowledge', 'res-9', 'page.md'),
    );
    assert.equal(v.ok, true, 'expected accept, got reject: ' + (v.reason || 'no reason'));
    assert.ok(
      v.resolvedPath.endsWith(
        join('.opencode', 'oh-my-opencode-slim', 'knowledge', 'res-9', 'page.md'),
      ),
      'resolvedPath must point at the requested file under the slim knowledge root, got: ' +
        v.resolvedPath,
    );
  });

  it('rejects a ../ escape outside both roots', () => {
    // Literal string, not path.join: join would normalize the `..` away and
    // the traversal property would never reach the module under test.
    const v = resolveOutputPath(root, 'knowledge/../../escaped.md');
    assert.equal(v.ok, false, 'expected reject for a ../ escape');
    assert.equal(typeof v.reason, 'string', 'rejection must carry a reason');
    assert.ok(v.reason.length > 0, 'rejection reason must not be empty');
    assert.ok(!existsSync(join(base, 'escaped.md')), 'a rejected destination must not be written');
  });

  it('rejects an absolute path outside both roots', () => {
    const absoluteTarget = join(outside, 'absolute.md');
    const v = resolveOutputPath(root, absoluteTarget);
    assert.equal(v.ok, false, 'expected reject for an absolute path outside both roots');
    assert.equal(typeof v.reason, 'string', 'rejection must carry a reason');
    assert.ok(v.reason.length > 0, 'rejection reason must not be empty');
    assert.ok(!existsSync(absoluteTarget), 'a rejected destination must not be written');
  });

  it('rejects a symlink escape', () => {
    const v = resolveOutputPath(root, join('knowledge', 'link', 'payload.md'));
    assert.equal(v.ok, false, 'expected reject when the parent symlink leaves both roots');
    assert.equal(typeof v.reason, 'string', 'rejection must carry a reason');
    assert.ok(v.reason.length > 0, 'rejection reason must not be empty');
    assert.ok(
      !existsSync(join(outside, 'payload.md')),
      'a rejected destination must not be written through the symlink',
    );
  });

  it('rejects a non-http scheme', () => {
    const v = checkFetchUrl('file:///etc/passwd');
    assert.equal(v.ok, false, 'file:// URLs must be rejected');
    assert.equal(typeof v.reason, 'string', 'rejection must carry a reason');
    assert.ok(v.reason.length > 0, 'rejection reason must not be empty');
  });

  // Anti-vacuous guard for the scheme check: a policy that rejects every URL
  // would pass the rejection case above, so the accepted schemes are pinned too.
  it('accepts http and https URLs', () => {
    assert.equal(checkFetchUrl('https://example.com/page').ok, true, 'https must be accepted');
    assert.equal(checkFetchUrl('http://example.com/page').ok, true, 'http must be accepted');
  });
});
