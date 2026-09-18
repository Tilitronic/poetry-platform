import { afterEach, beforeEach, describe, expect, mock, test } from 'bun:test';
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

function createMockContext() {
  const configUpdate = mock(async () => ({}));
  const instanceDispose = mock(async () => ({}));
  return {
    client: {
      config: {
        update: configUpdate,
      },
      instance: {
        dispose: instanceDispose,
      },
    },
    directory: tempDir,
  } as any;
}

function createOutput() {
  return { parts: [] as Array<{ type: string; text?: string }> };
}

function getOutputText(output: ReturnType<typeof createOutput>): string {
  return output.parts
    .filter((p) => p.type === 'text')
    .map((p) => p.text ?? '')
    .join('\n');
}

let previousXdgDataHome: string | undefined;
let previousXdgConfigHome: string | undefined;
let previousOpenCodeConfigDir: string | undefined;
let tempDir: string;

beforeEach(() => {
  previousXdgDataHome = process.env.XDG_DATA_HOME;
  previousXdgConfigHome = process.env.XDG_CONFIG_HOME;
  previousOpenCodeConfigDir = process.env.OPENCODE_CONFIG_DIR;
  tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'omos-preset-manager-'));
  process.env.XDG_DATA_HOME = tempDir;
  process.env.XDG_CONFIG_HOME = path.join(tempDir, 'xdg-config');
  delete process.env.OPENCODE_CONFIG_DIR;
  setActiveRuntimePreset(null);
});

afterEach(() => {
  if (previousXdgDataHome === undefined) {
    delete process.env.XDG_DATA_HOME;
  } else {
    process.env.XDG_DATA_HOME = previousXdgDataHome;
  }

  if (previousXdgConfigHome === undefined) {
    delete process.env.XDG_CONFIG_HOME;
  } else {
    process.env.XDG_CONFIG_HOME = previousXdgConfigHome;
  }

  if (previousOpenCodeConfigDir === undefined) {
    delete process.env.OPENCODE_CONFIG_DIR;
  } else {
    process.env.OPENCODE_CONFIG_DIR = previousOpenCodeConfigDir;
  }

  fs.rmSync(tempDir, { recursive: true, force: true });
  setActiveRuntimePreset(null);
});

describe('createPresetManager', () => {
  describe('handleCommandExecuteBefore', () => {
    test('ignores non-preset commands', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {};
      const manager = createPresetManager(ctx, config);
      const output = createOutput();

      await manager.handleCommandExecuteBefore(
        { command: 'unknown-command', sessionID: 's1', arguments: 'on' },
        output,
      );

      expect(output.parts).toHaveLength(0);
      expect(ctx.client.config.update).not.toHaveBeenCalled();
    });

    test('lists available presets when no argument given', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {
        presets: {
          cheap: {
            orchestrator: { model: 'anthropic/claude-3.5-haiku' },
          },
          powerful: {
            orchestrator: { model: 'openai/gpt-5.5' },
          },
        },
      };
      const manager = createPresetManager(ctx, config);
      const output = createOutput();

      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: '' },
        output,
      );

      const text = getOutputText(output);
      expect(text).toContain('cheap');
      expect(text).toContain('powerful');
      expect(ctx.client.config.update).not.toHaveBeenCalled();
    });

    test('lists the stored preset with a stored marker', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {
        preset: 'cheap',
        presets: {
          cheap: { orchestrator: { model: 'anthropic/claude-3.5-haiku' } },
          powerful: { orchestrator: { model: 'openai/gpt-5.5' } },
        },
      };
      saveWorkspacePreset(tempDir, 'cheap');
      const manager = createPresetManager(ctx, config);
      const output = createOutput();

      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: '' },
        output,
      );

      const text = getOutputText(output);
      expect(text).toContain('cheap ← stored');
    });

    test('shows no-presets message when none configured', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {};
      const manager = createPresetManager(ctx, config);
      const output = createOutput();

      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: '' },
        output,
      );

      const text = getOutputText(output);
      expect(text).toContain('No presets configured');
    });

    test('saves a preset without changing the current session', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {
        presets: {
          cheap: {
            orchestrator: { model: 'anthropic/claude-3.5-haiku' },
            'code-navigator': { model: 'openai/gpt-5.4-mini' },
          },
        },
      };
      const manager = createPresetManager(ctx, config);
      const output = createOutput();

      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'cheap' },
        output,
      );

      const text = getOutputText(output);
      expect(text).toContain('Saved preset "cheap"');
      expect(text).toContain('next launch only');
      expect(readWorkspacePreset(tempDir)).toBe('cheap');
      expect(getActiveRuntimePreset()).toBeNull();
      expect(ctx.client.config.update).not.toHaveBeenCalled();
      expect(ctx.client.instance.dispose).not.toHaveBeenCalled();
    });

    test('does not update the TUI snapshot after saving a preset', async () => {
      recordTuiAgentModels({
        agentModels: {
          'code-navigator': 'openai/gpt-5.4-mini',
          coder: 'openai/gpt-5.4-mini',
        },
      });

      const ctx = createMockContext();
      const config: PluginConfig = {
        presets: {
          cheap: {
            orchestrator: { model: 'anthropic/claude-3.5-haiku' },
            'code-navigator': { model: 'openai/gpt-5.5' },
          },
        },
      };
      const manager = createPresetManager(ctx, config);
      const output = createOutput();

      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'cheap' },
        output,
      );

      expect(readTuiSnapshot().agentModels).toEqual({
        'code-navigator': 'openai/gpt-5.4-mini',
        coder: 'openai/gpt-5.4-mini',
      });
    });

    test('keeps JSONC config unchanged while persisting the workspace selection', async () => {
      const configDir = path.join(tempDir, 'opencode-config');
      fs.mkdirSync(configDir, { recursive: true });
      process.env.OPENCODE_CONFIG_DIR = configDir;

      const configPath = path.join(configDir, 'oh-my-opencode-slim.jsonc');
      fs.writeFileSync(
        configPath,
        `{
          // User-selected preset should be updated even in JSONC files.
          "preset": "old",
          "agents": {
            "orchestrator": { "model": "old-model" },
          },
        }`,
      );

      const ctx = { ...createMockContext(), directory: tempDir };
      const config: PluginConfig = {
        presets: {
          cheap: {
            orchestrator: { model: 'anthropic/claude-3.5-haiku' },
          },
        },
      };
      const manager = createPresetManager(ctx, config);
      const output = createOutput();

      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'cheap' },
        output,
      );

      expect(fs.readFileSync(configPath, 'utf-8')).toContain('"preset": "old"');
      expect(readWorkspacePreset(tempDir)).toBe('cheap');
      expect(ctx.client.config.update).not.toHaveBeenCalled();
      expect(ctx.client.instance.dispose).not.toHaveBeenCalled();
    });

    test('saves a preset with temperature without runtime config update', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {
        presets: {
          precise: {
            orchestrator: { model: 'openai/o3', temperature: 0.1 },
          },
        },
      };
      const manager = createPresetManager(ctx, config);
      const output = createOutput();

      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'precise' },
        output,
      );

      const text = getOutputText(output);
      expect(text).toContain('next launch only');
      expect(readWorkspacePreset(tempDir)).toBe('precise');
      expect(ctx.client.config.update).not.toHaveBeenCalled();
      expect(ctx.client.instance.dispose).not.toHaveBeenCalled();
    });

    test('saves a preset with a variant without runtime config update', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {
        presets: {
          thinker: {
            architector: {
              model: 'anthropic/claude-sonnet-4-6',
              variant: 'thinking',
            },
          },
        },
      };
      const manager = createPresetManager(ctx, config);
      const output = createOutput();

      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'thinker' },
        output,
      );

      const text = getOutputText(output);
      expect(text).toContain('next launch only');
      expect(readWorkspacePreset(tempDir)).toBe('thinker');
      expect(ctx.client.config.update).not.toHaveBeenCalled();
      expect(ctx.client.instance.dispose).not.toHaveBeenCalled();
    });

    test('shows error for unknown preset name', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {
        presets: {
          cheap: { orchestrator: { model: 'anthropic/claude-3.5-haiku' } },
        },
      };
      const manager = createPresetManager(ctx, config);
      const output = createOutput();

      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'nonexistent' },
        output,
      );

      const text = getOutputText(output);
      expect(text).toContain('not found');
      expect(text).toContain('cheap');
      expect(ctx.client.config.update).not.toHaveBeenCalled();
      expect(ctx.client.instance.dispose).not.toHaveBeenCalled();
    });

    test('shows error when no presets configured but argument given', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {};
      const manager = createPresetManager(ctx, config);
      const output = createOutput();

      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'cheap' },
        output,
      );

      const text = getOutputText(output);
      expect(text).toContain('not found');
      expect(text).toContain('No presets configured');
    });

    test('unknown preset does not change active state or dispose instance', async () => {
      setActiveRuntimePreset('cheap');
      recordTuiAgentModels({
        agentModels: {
          'code-navigator': 'openai/gpt-5.4-mini',
        },
      });

      const ctx = createMockContext();
      const config: PluginConfig = {
        presets: {
          cheap: { orchestrator: { model: 'anthropic/claude-3.5-haiku' } },
        },
      };
      const manager = createPresetManager(ctx, config);
      const output = createOutput();

      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'nonexistent' },
        output,
      );

      const text = getOutputText(output);
      expect(text).toContain('not found');
      expect(getActiveRuntimePreset()).toBe('cheap');
      expect(ctx.client.config.update).not.toHaveBeenCalled();
      expect(ctx.client.instance.dispose).not.toHaveBeenCalled();
    });

    test('shows empty preset message when preset has no valid overrides', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {
        presets: {
          empty: {
            orchestrator: {},
          },
        },
      };
      const manager = createPresetManager(ctx, config);
      const output = createOutput();

      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'empty' },
        output,
      );

      const text = getOutputText(output);
      expect(text).toContain('empty');
      expect(ctx.client.config.update).not.toHaveBeenCalled();
    });

    test('saves a preset with options without runtime config update', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {
        presets: {
          thinker: {
            architector: {
              model: 'anthropic/claude-sonnet-4-6',
              options: {
                thinking: { type: 'enabled', budgetTokens: 10000 },
              },
            },
          },
        },
      };
      const manager = createPresetManager(ctx, config);
      const output = createOutput();

      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'thinker' },
        output,
      );

      const text = getOutputText(output);
      expect(text).toContain('next launch only');
      expect(readWorkspacePreset(tempDir)).toBe('thinker');
      expect(ctx.client.config.update).not.toHaveBeenCalled();
      expect(ctx.client.instance.dispose).not.toHaveBeenCalled();
    });

    test('trims whitespace from preset name argument', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {
        presets: {
          cheap: { orchestrator: { model: 'anthropic/claude-3.5-haiku' } },
        },
      };
      const manager = createPresetManager(ctx, config);
      const output = createOutput();

      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: '  cheap  ' },
        output,
      );

      const text = getOutputText(output);
      expect(text).toContain('Saved preset "cheap"');
      expect(ctx.client.config.update).not.toHaveBeenCalled();
      expect(ctx.client.instance.dispose).not.toHaveBeenCalled();
    });

    test('shows suggestion for multi-word arguments', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {
        presets: {
          cheap: { orchestrator: { model: 'anthropic/claude-3.5-haiku' } },
        },
      };
      const manager = createPresetManager(ctx, config);
      const output = createOutput();

      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'cheap powerful' },
        output,
      );

      const text = getOutputText(output);
      expect(text).toContain('cannot contain spaces');
      expect(text).toContain('/preset cheap');
      expect(ctx.client.config.update).not.toHaveBeenCalled();
    });

    test('catches tab-separated arguments', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {
        presets: {
          cheap: { orchestrator: { model: 'anthropic/claude-3.5-haiku' } },
        },
      };
      const manager = createPresetManager(ctx, config);
      const output = createOutput();

      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'cheap\tpowerful' },
        output,
      );

      const text = getOutputText(output);
      expect(text).toContain('cannot contain spaces');
      expect(ctx.client.config.update).not.toHaveBeenCalled();
    });

    test('saves a mixed preset without changing current-session agents', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {
        presets: {
          mixed: {
            orchestrator: { model: 'anthropic/claude-3.5-haiku' },
            'code-navigator': {},
            architector: { temperature: 0.3 },
          },
        },
      };
      const manager = createPresetManager(ctx, config);
      const output = createOutput();

      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'mixed' },
        output,
      );

      const text = getOutputText(output);
      expect(text).toContain('Saved preset "mixed"');
      expect(text).toContain('next launch only');
      expect(readWorkspacePreset(tempDir)).toBe('mixed');
      expect(ctx.client.config.update).not.toHaveBeenCalled();
      expect(ctx.client.instance.dispose).not.toHaveBeenCalled();
    });

    test('resolves array-form model to first entry', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {
        presets: {
          fallback: {
            orchestrator: {
              model: ['anthropic/claude-3.5-haiku', 'openai/gpt-5.5'],
            },
          },
        },
      };
      const manager = createPresetManager(ctx, config);
      const output = createOutput();

      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'fallback' },
        output,
      );

      const text = getOutputText(output);
      expect(text).toContain('Saved preset "fallback"');
      expect(text).toContain('next launch only');
      expect(readWorkspacePreset(tempDir)).toBe('fallback');
      expect(ctx.client.config.update).not.toHaveBeenCalled();
      expect(ctx.client.instance.dispose).not.toHaveBeenCalled();
    });

    test('resolves array-form model with object entries', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {
        presets: {
          thinker: {
            architector: {
              model: [
                { id: 'anthropic/claude-sonnet-4-6', variant: 'thinking' },
                { id: 'openai/o3' },
              ],
            },
          },
        },
      };
      const manager = createPresetManager(ctx, config);
      const output = createOutput();

      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'thinker' },
        output,
      );

      const text = getOutputText(output);
      expect(text).toContain('Saved preset "thinker"');
      expect(text).toContain('next launch only');
      expect(readWorkspacePreset(tempDir)).toBe('thinker');
      expect(ctx.client.config.update).not.toHaveBeenCalled();
      expect(ctx.client.instance.dispose).not.toHaveBeenCalled();
    });

    test('saves a preset with variant and options', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {
        presets: {
          thinker: {
            architector: {
              model: 'anthropic/claude-sonnet-4-6',
              variant: 'thinking',
              options: { thinking: { type: 'enabled', budgetTokens: 10000 } },
            },
          },
        },
      };
      const manager = createPresetManager(ctx, config);
      const output = createOutput();

      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'thinker' },
        output,
      );

      const text = getOutputText(output);
      expect(text).toContain('next launch only');
      expect(readWorkspacePreset(tempDir)).toBe('thinker');
    });

    test('tracks active preset after switch', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {
        presets: {
          cheap: { orchestrator: { model: 'anthropic/claude-3.5-haiku' } },
          powerful: { orchestrator: { model: 'openai/gpt-5.5' } },
        },
      };
      const manager = createPresetManager(ctx, config);

      // Switch to cheap
      const output1 = createOutput();
      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'cheap' },
        output1,
      );
      expect(getOutputText(output1)).toContain('Saved preset');

      // List presets should now show cheap as active
      const output2 = createOutput();
      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: '' },
        output2,
      );
      expect(getOutputText(output2)).toContain('cheap ← stored');

      // Switch to powerful
      const output3 = createOutput();
      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'powerful' },
        output3,
      );
      expect(getOutputText(output3)).toContain('Saved preset "powerful"');

      // List should now show powerful as active
      const output4 = createOutput();
      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: '' },
        output4,
      );
      expect(getOutputText(output4)).toContain('powerful ← stored');

      // Cleanup module state
      setActiveRuntimePreset(null);
    });
  });

  describe('project-local store', () => {
    test('saves into <projectRoot>/.opencode/state/workspace-preset.json', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {
        presets: {
          cheap: { orchestrator: { model: 'anthropic/claude-3.5-haiku' } },
        },
      };
      const manager = createPresetManager(ctx, config);
      const output = createOutput();

      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'cheap' },
        output,
      );

      expect(getOutputText(output)).toContain('Saved preset "cheap"');
      expect(getWorkspacePresetStorePath(tempDir)).toBe(
        path.join(tempDir, '.opencode', 'state', 'workspace-preset.json'),
      );
      const stored = JSON.parse(
        fs.readFileSync(getWorkspacePresetStorePath(tempDir), 'utf-8'),
      );
      expect(stored).toEqual({ version: 2, preset: 'cheap' });
    });
  });

  describe('registerCommand', () => {
    test('registers preset command when not present', () => {
      const ctx = createMockContext();
      const config: PluginConfig = {};
      const manager = createPresetManager(ctx, config);
      const opencodeConfig: Record<string, unknown> = {};

      manager.registerCommand(opencodeConfig);

      const command = (opencodeConfig.command as Record<string, unknown>)
        .preset as { template: string; description: string };
      expect(command).toBeDefined();
      expect(command.template).toContain('presets');
      expect(command.description).toContain('/preset');
    });

    test('does not overwrite existing preset command', () => {
      const ctx = createMockContext();
      const config: PluginConfig = {};
      const manager = createPresetManager(ctx, config);
      const existing = { template: 'custom', description: 'custom' };
      const opencodeConfig: Record<string, unknown> = {
        command: { preset: existing },
      };

      manager.registerCommand(opencodeConfig);

      expect((opencodeConfig.command as Record<string, unknown>).preset).toBe(
        existing,
      );
    });
  });

  describe('preset switching stale state', () => {
    test('saving successive presets leaves runtime state unchanged', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {
        presets: {
          cheap: {
            architector: { model: 'cheap-model', temperature: 0.3 },
          },
          powerful: {
            orchestrator: { model: 'powerful-model' },
          },
        },
        agents: {
          architector: { model: 'baseline-model' },
        },
      };
      const manager = createPresetManager(ctx, config);
      const output1 = createOutput();

      // Switch to cheap first
      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'cheap' },
        output1,
      );
      expect(getOutputText(output1)).toContain('Saved preset "cheap"');
      expect(ctx.client.config.update).not.toHaveBeenCalled();
      expect(ctx.client.instance.dispose).not.toHaveBeenCalled();

      const output2 = createOutput();
      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'powerful' },
        output2,
      );

      expect(getOutputText(output2)).toContain('Saved preset "powerful"');
      expect(getActiveRuntimePreset()).toBeNull();
      expect(readWorkspacePreset(tempDir)).toBe('powerful');
      expect(ctx.client.config.update).not.toHaveBeenCalled();
      expect(ctx.client.instance.dispose).not.toHaveBeenCalled();
    });

    test('new preset with same agents still avoids runtime config update', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {
        presets: {
          cheap: {
            architector: { model: 'a' },
          },
          cheaper: {
            architector: { model: 'b' },
          },
        },
      };
      const manager = createPresetManager(ctx, config);
      const output1 = createOutput();

      // Switch to cheap first
      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'cheap' },
        output1,
      );
      expect(getOutputText(output1)).toContain('Saved preset "cheap"');
      expect(ctx.client.config.update).not.toHaveBeenCalled();
      expect(ctx.client.instance.dispose).not.toHaveBeenCalled();

      const output2 = createOutput();
      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'cheaper' },
        output2,
      );

      expect(getOutputText(output2)).toContain('Saved preset "cheaper"');
      expect(ctx.client.config.update).not.toHaveBeenCalled();
      expect(ctx.client.instance.dispose).not.toHaveBeenCalled();
    });

    test('preset selection persists across successive saves without runtime update', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {
        presets: {
          cheap: {
            architector: { model: 'a' },
          },
          expensive: {
            architector: { model: 'b' },
          },
        },
      };
      const manager = createPresetManager(ctx, config);

      // Switch to cheap successfully
      const output1 = createOutput();
      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'cheap' },
        output1,
      );
      expect(getActiveRuntimePreset()).toBeNull();
      expect(readWorkspacePreset(tempDir)).toBe('cheap');

      // Try to switch to expensive
      const output2 = createOutput();
      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: 'expensive' },
        output2,
      );

      expect(getActiveRuntimePreset()).toBeNull();
      expect(readWorkspacePreset(tempDir)).toBe('expensive');
      expect(getOutputText(output2)).toContain('Saved preset "expensive"');
      expect(ctx.client.config.update).not.toHaveBeenCalled();
      expect(ctx.client.instance.dispose).not.toHaveBeenCalled();
    });

    test('stored selection is shown when manager is created', async () => {
      const ctx = createMockContext();
      const config: PluginConfig = {
        presets: {
          cheap: {
            architector: { model: 'a' },
          },
          powerful: {
            architector: { model: 'b' },
          },
        },
      };

      saveWorkspacePreset(tempDir, 'cheap');
      const manager = createPresetManager(ctx, config);

      // Listing reads persisted state so a new manager sees the next launch choice.
      const output = createOutput();
      await manager.handleCommandExecuteBefore(
        { command: 'preset', sessionID: 's1', arguments: '' },
        output,
      );

      const text = getOutputText(output);
      expect(text).toContain('cheap ← stored');
      expect(text).toContain('powerful');

      // Cleanup
      setActiveRuntimePreset(null);
    });
  });
});
