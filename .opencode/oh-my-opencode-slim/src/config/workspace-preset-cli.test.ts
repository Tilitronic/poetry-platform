import { afterEach, beforeEach, describe, expect, spyOn, test } from 'bun:test';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { readWorkspacePreset } from './workspace-preset';
import { runCli } from './workspace-preset-cli';

describe('workspace-preset-cli', () => {
  let tempDir: string;
  let projectDir: string;
  let originalEnv: typeof process.env;

  beforeEach(() => {
    tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'preset-cli-test-'));
    projectDir = path.join(tempDir, 'project');
    fs.mkdirSync(path.join(projectDir, '.opencode'), { recursive: true });
    fs.writeFileSync(
      path.join(projectDir, '.opencode', 'oh-my-opencode-slim.json'),
      JSON.stringify({
        preset: 'declared',
        presets: {
          cheap: { architector: { model: 'cheap/model' } },
          declared: { architector: { model: 'declared/model' } },
        },
      }),
    );
    originalEnv = { ...process.env };
    delete process.env.OPENCODE_CONFIG_DIR;
    delete process.env.PRESET;
    delete process.env.OPENCODE_WORKSPACE_PRESET;
    process.env.XDG_CONFIG_HOME = path.join(tempDir, 'user-config');
    spyOn(console, 'log').mockImplementation(() => {});
    spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    (console.log as ReturnType<typeof spyOn>).mockRestore();
    (console.error as ReturnType<typeof spyOn>).mockRestore();
    fs.rmSync(tempDir, { recursive: true, force: true });
    process.env = originalEnv;
  });

  test('save then resolve round-trips through the project-local store', () => {
    expect(runCli(['save', projectDir, 'cheap'])).toBe(0);
    expect(readWorkspacePreset(projectDir)).toBe('cheap');
    expect(runCli(['resolve', projectDir, ''])).toBe(0);
  });

  test('save none clears the stored selection', () => {
    expect(runCli(['save', projectDir, 'cheap'])).toBe(0);
    expect(runCli(['save', projectDir, 'none'])).toBe(0);
    expect(readWorkspacePreset(projectDir)).toBeNull();
  });

  test('resolve falls back to the declared default after clear', () => {
    expect(runCli(['save', projectDir, 'none'])).toBe(0);
    expect(runCli(['resolve', projectDir, ''])).toBe(0);
  });

  test('save rejects an unknown preset', () => {
    expect(runCli(['save', projectDir, 'nope'])).toBe(1);
    expect(readWorkspacePreset(projectDir)).toBeNull();
  });

  test('resolve reports a contradictory override instead of exiting 0', () => {
    expect(runCli(['resolve', projectDir, 'nope'])).toBe(1);
  });

  test('unknown command exits 1', () => {
    expect(runCli(['frobnicate', projectDir, 'cheap'])).toBe(1);
  });

  test('missing arguments exits 2', () => {
    expect(runCli(['save'])).toBe(2);
  });
});
