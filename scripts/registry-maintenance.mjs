#!/usr/bin/env node
/**
 * Explicit, operator-only registry maintenance boundary (DIA-260914-tqor).
 *
 * The production registry adapter is TypeScript. This small Node entrypoint
 * delegates to it through Bun (the project's runtime) so health/rotation do
 * not grow a second persistence implementation. No command is the safe
 * default: maintenance is never implicit.
 */
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const registryModule = resolve(repoRoot, '.opencode/plugins/lib/registry.ts');

function usageError(message) {
  console.error(`error: ${message}`);
  console.error(
    'usage: registry-maintenance.mjs <health|rotate> --registry <path> --messages <path> --archive-dir <path> [--inject-failure <stage>] [--json]',
  );
  process.exit(2);
}

const argv = process.argv.slice(2);
const command = argv[0];
if (command !== 'health' && command !== 'rotate')
  usageError('explicit command required: health or rotate');

const values = { command, registry: null, messages: null, archiveDir: null, injectFailure: null };
for (let i = 1; i < argv.length; i += 1) {
  const arg = argv[i];
  if (arg === '--json') continue;
  if (
    arg === '--registry' ||
    arg === '--messages' ||
    arg === '--archive-dir' ||
    arg === '--inject-failure'
  ) {
    if (i + 1 >= argv.length) usageError(`${arg} requires a value`);
    const value = argv[++i];
    if (arg === '--registry') values.registry = value;
    if (arg === '--messages') values.messages = value;
    if (arg === '--archive-dir') values.archiveDir = value;
    if (arg === '--inject-failure') values.injectFailure = value;
    continue;
  }
  usageError(`unknown option: ${arg}`);
}
if (!values.registry || !values.messages || !values.archiveDir) {
  usageError('--registry, --messages, and --archive-dir are required');
}

const input = JSON.stringify({ module: registryModule, ...values });
const runner = `
  import { createRegistry } from ${JSON.stringify(registryModule)};
  const input = JSON.parse(process.env.TQOR_MAINTENANCE_INPUT);
  const registry = createRegistry({
    directory: process.cwd(),
    registryPath: input.registry,
    messagesPath: input.messages,
    archiveDir: input.archiveDir,
    injectFailure: input.injectFailure || undefined,
  });
  const started = Date.now();
  const result = input.command === "health"
    ? { ok: true, ...registry.getDiagnostics() }
    : registry.rotateRegistry();
  if (input.command === "rotate" && result.ok) result.elapsedMs = Date.now() - started;
  console.log(JSON.stringify(result));
  process.exit(result.ok ? 0 : 1);
`;
const child = spawnSync('bun', ['--eval', runner], {
  cwd: repoRoot,
  env: { ...process.env, TQOR_MAINTENANCE_INPUT: input },
  encoding: 'utf8',
});
if (child.stdout) process.stdout.write(child.stdout);
if (child.stderr) process.stderr.write(child.stderr);
if (child.error) {
  console.log(JSON.stringify({ ok: false, stage: 'runtime', error: child.error.message }));
  process.exit(1);
}
process.exit(child.status ?? 1);
