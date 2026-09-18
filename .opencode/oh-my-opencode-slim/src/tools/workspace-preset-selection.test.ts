import {
  afterEach,
  beforeEach,
  describe,
  expect,
  mock,
  spyOn,
  test,
} from 'bun:test';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import type { PluginConfig } from '../config';
import {
  getActiveRuntimePreset,
  setActiveRuntimePreset,
} from '../config/runtime-preset';
import {
  getWorkspacePresetStorePath,
  readWorkspacePreset,
  saveWorkspacePreset,
} from '../config/workspace-preset';
import { readTuiSnapshot, recordTuiAgentModels } from '../tui-state';
import { createPresetManager } from './preset-manager';

function createContext(directory: string) {
  return {
    client: {
      config: { update: mock(async () => ({})) },
      instance: { dispose: mock(async () => ({})) },
    },
    directory,
  } as any;
}

function createOutput() {
  return { parts: [] as Array<{ type: string; text?: string }> };
}

function outputText(output: ReturnType<typeof createOutput>): string {
  return output.parts
    .filter((part) => part.type === 'text')
    .map((part) => part.text ?? '')
    .join('\n');
}

const config: PluginConfig = {
  presets: {
    cheap: { orchestrator: { model: 'cheap/model' } },
    durable: { orchestrator: { model: 'durable/model' } },
  },
};

describe('project-local preset selection', () => {
  let tempDir: string;
  let originalEnv: typeof process.env;

  beforeEach(() => {
    tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'workspace-preset-'));
    originalEnv = { ...process.env };
    delete process.env.OPENCODE_CONFIG_DIR;
    process.env.XDG_CONFIG_HOME = path.join(tempDir, 'user-config');
    process.env.XDG_DATA_HOME = path.join(tempDir, 'user-data');
    setActiveRuntimePreset(null);
  });

  afterEach(() => {
    process.env = originalEnv;
    setActiveRuntimePreset(null);
    fs.rmSync(tempDir, { recursive: true, force: true });
  });

  test('persists by canonical workspace and re-reads through a symlink without live switching', async () => {
    const workspace = path.join(tempDir, 'workspace');
    const symlink = path.join(tempDir, 'workspace-link');
    const otherWorkspace = path.join(tempDir, 'other-workspace');
    fs.mkdirSync(workspace);
    fs.mkdirSync(otherWorkspace);
    fs.symlinkSync(workspace, symlink, 'dir');

    recordTuiAgentModels({ agentModels: { orchestrator: 'baseline/model' } });
    const before = readTuiSnapshot();
    const manager = createPresetManager(createContext(workspace), config);
    const saved = createOutput();

    await manager.handleCommandExecuteBefore(
      { command: 'preset', sessionID: 's1', arguments: 'cheap' },
      saved,
    );

    const savedText = outputText(saved);
    expect(savedText).toContain('cheap');
    expect(savedText).toContain(fs.realpathSync(workspace));
    expect(savedText).toContain('next launch');
    expect(getActiveRuntimePreset()).toBeNull();
    expect(readTuiSnapshot().agentModels).toEqual(before.agentModels);

    setActiveRuntimePreset(null);
    const fromSymlink = createOutput();
    await createPresetManager(
      createContext(symlink),
      config,
    ).handleCommandExecuteBefore(
      { command: 'preset', sessionID: 's2', arguments: '' },
      fromSymlink,
    );
    expect(outputText(fromSymlink)).toContain('Stored selection: cheap');

    const fromOtherWorkspace = createOutput();
    await createPresetManager(
      createContext(otherWorkspace),
      config,
    ).handleCommandExecuteBefore(
      { command: 'preset', sessionID: 's3', arguments: '' },
      fromOtherWorkspace,
    );
    expect(outputText(fromOtherWorkspace)).toContain('Stored selection: none');
  });

  test('does not save a preset when the atomic replacement fails', async () => {
    const workspace = path.join(tempDir, 'workspace');
    fs.mkdirSync(workspace);
    recordTuiAgentModels({ agentModels: { orchestrator: 'baseline/model' } });
    const before = readTuiSnapshot();
    const rename = spyOn(fs, 'renameSync').mockImplementation(() => {
      throw new Error('atomic replacement blocked');
    });

    try {
      const output = createOutput();
      await createPresetManager(
        createContext(workspace),
        config,
      ).handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'durable' },
        output,
      );

      const text = outputText(output);
      expect(text).toContain('failed');
      expect(text).not.toContain('Saved');
      expect(getActiveRuntimePreset()).toBeNull();
      expect(readTuiSnapshot().agentModels).toEqual(before.agentModels);
    } finally {
      rename.mockRestore();
    }
  });

  test('does not acknowledge a selection when verification re-read differs', async () => {
    const workspace = path.join(tempDir, 'workspace');
    fs.mkdirSync(workspace);
    saveWorkspacePreset(workspace, 'cheap');
    const storePath = getWorkspacePresetStorePath(workspace);
    const originalRead = fs.readFileSync.bind(fs) as (...args: any[]) => any;
    let storeReads = 0;
    const read = spyOn(fs, 'readFileSync').mockImplementation(((
      filePath: any,
      options?: any,
    ) => {
      const value = originalRead(filePath, options);
      // Save no longer pre-reads (self-heal): the readback verify is the
      // first store read, so poison it to simulate a torn write.
      if (String(filePath) === storePath && storeReads++ === 0) {
        return JSON.stringify({ version: 2, preset: 'cheap' });
      }
      return value;
    }) as any);

    try {
      const output = createOutput();
      await createPresetManager(
        createContext(workspace),
        config,
      ).handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'durable' },
        output,
      );

      expect(outputText(output)).toContain('failed');
      expect(outputText(output)).not.toContain('Saved');
    } finally {
      read.mockRestore();
    }
    expect(readWorkspacePreset(workspace)).toBe('durable');
  });

  test('shares one project-local store between the root and a subdirectory', async () => {
    const project = path.join(tempDir, 'project');
    const subdir = path.join(project, 'packages', 'nested');
    fs.mkdirSync(subdir, { recursive: true });
    fs.mkdirSync(path.join(project, '.opencode'));

    const manager = createPresetManager(createContext(project), config);
    const saved = createOutput();
    await manager.handleCommandExecuteBefore(
      { command: 'preset', sessionID: 's1', arguments: 'durable' },
      saved,
    );
    expect(outputText(saved)).toContain('durable');

    const fromSubdir = createOutput();
    await createPresetManager(
      createContext(subdir),
      config,
    ).handleCommandExecuteBefore(
      { command: 'preset', sessionID: 's2', arguments: '' },
      fromSubdir,
    );
    expect(outputText(fromSubdir)).toContain('Stored selection: durable');
    expect(getWorkspacePresetStorePath(subdir)).toBe(
      getWorkspacePresetStorePath(project),
    );
  });

  test('rejects an unknown slash-command preset without changing session state', async () => {
    const workspace = path.join(tempDir, 'workspace');
    fs.mkdirSync(workspace);
    recordTuiAgentModels({ agentModels: { orchestrator: 'baseline/model' } });
    const before = readTuiSnapshot();
    const output = createOutput();

    await createPresetManager(
      createContext(workspace),
      config,
    ).handleCommandExecuteBefore(
      { command: 'preset', sessionID: 's1', arguments: 'CHEAP' },
      output,
    );

    const text = outputText(output);
    expect(text).toContain('not found');
    expect(text).not.toContain('Saved');
    expect(getActiveRuntimePreset()).toBeNull();
    expect(readTuiSnapshot().agentModels).toEqual(before.agentModels);
  });
});
