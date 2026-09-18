import type { PluginInput } from '@opencode-ai/plugin';
import type { ModelEntry, PluginConfig, Preset } from '../config';
import {
  clearWorkspacePreset,
  getWorkspacePresetStorePath,
  readWorkspacePreset,
  saveWorkspacePreset,
} from '../config/workspace-preset';
import { createInternalAgentTextPart } from '../utils';

const COMMAND_NAME = 'preset';

/**
 * Creates a preset manager for the /preset slash command.
 *
 * Stores the requested preset in the project-local store
 * (<projectRoot>/.opencode/state/workspace-preset.json) for the next
 * launch. It deliberately does not mutate runtime or TUI state because the
 * current process already loaded its agent configuration.
 */
export function createPresetManager(ctx: PluginInput, config: PluginConfig) {
  let activePreset: string | null = null;

  /**
   * Handle the /preset command from command.execute.before hook.
   *
   * - No arguments: list available presets
   * - With argument: switch to the named preset
   */
  async function handleCommandExecuteBefore(
    input: {
      command: string;
      sessionID: string;
      arguments: string;
    },
    output: { parts: Array<{ type: string; text?: string }> },
  ): Promise<void> {
    if (input.command !== COMMAND_NAME) {
      return;
    }

    // Clear the template so OpenCode doesn't send it to the LLM
    output.parts.length = 0;

    const arg = input.arguments.trim();
    const presets = config.presets ?? {};

    if (!arg) {
      try {
        activePreset = readWorkspacePreset(ctx.directory);
        output.parts.push(
          createInternalAgentTextPart(
            `Stored selection: ${activePreset ?? 'none'}\n${formatPresetList(presets)}`,
          ),
        );
      } catch (error) {
        output.parts.push(
          createInternalAgentTextPart(
            `Failed to read stored preset for ${ctx.directory}: ${formatError(error)}`,
          ),
        );
      }
      return;
    }

    // Clear path mirrors `make preset NAME=none`: drops the stored
    // selection so launches fall back to the declared default or no preset.
    // Runtime state is untouched; only the list highlight resets.
    if (arg === 'none') {
      try {
        const workspace = clearWorkspacePreset(ctx.directory);
        activePreset = null;
        output.parts.push(
          createInternalAgentTextPart(
            `Cleared preset for workspace ${workspace} (store: ${getWorkspacePresetStorePath(ctx.directory)}). Launches fall back to the declared default or no preset.`,
          ),
        );
      } catch (error) {
        output.parts.push(
          createInternalAgentTextPart(
            `Clear failed for workspace ${ctx.directory}: ${formatError(error)}`,
          ),
        );
      }
      return;
    }

    // Guard against multi-word arguments
    if (/\s/.test(arg)) {
      const suggestion = arg.split(/\s+/)[0];
      output.parts.push(
        createInternalAgentTextPart(
          `Preset names cannot contain spaces. Did you mean: /preset ${suggestion}?`,
        ),
      );
      return;
    }

    // Switch to named preset
    await switchPreset(arg, presets, output);
  }

  /**
   * Register the /preset command in the OpenCode config.
   */
  function registerCommand(opencodeConfig: Record<string, unknown>): void {
    const configCommand = opencodeConfig.command as
      | Record<string, unknown>
      | undefined;
    if (!configCommand?.[COMMAND_NAME]) {
      if (!opencodeConfig.command) {
        opencodeConfig.command = {};
      }
      (opencodeConfig.command as Record<string, unknown>)[COMMAND_NAME] = {
        template: 'List available presets and save one for the next launch',
        description: 'Save a preset for the next launch (e.g., /preset cheap)',
      };
    }
  }

  /** Save a validated preset for this workspace's next launch. */
  async function switchPreset(
    presetName: string,
    presets: Record<string, Preset>,
    output: { parts: Array<{ type: string; text?: string }> },
  ): Promise<void> {
    if (!Object.hasOwn(presets, presetName)) {
      const available = Object.keys(presets);
      const hint =
        available.length > 0
          ? `Available presets: ${available.join(', ')}`
          : 'No presets configured. Define presets in oh-my-opencode-slim.jsonc.';
      output.parts.push(
        createInternalAgentTextPart(
          `Preset "${presetName}" not found. ${hint}`,
        ),
      );
      return;
    }

    try {
      const workspace = saveWorkspacePreset(ctx.directory, presetName);
      activePreset = presetName;
      output.parts.push(
        createInternalAgentTextPart(
          `Saved preset "${presetName}" for workspace ${workspace} (store: ${getWorkspacePresetStorePath(ctx.directory)}). It applies on the next launch only, on every launch path (make opencode, shell+opencode, direct, subdir).`,
        ),
      );
    } catch (error) {
      output.parts.push(
        createInternalAgentTextPart(
          `Save failed for preset "${presetName}": ${formatError(error)}`,
        ),
      );
    }
  }

  /**
   * Format the list of available presets with the stored one highlighted.
   */
  function formatPresetList(presets: Record<string, Preset>): string {
    const names = Object.keys(presets);
    if (names.length === 0) {
      return 'No presets configured. Define presets in oh-my-opencode-slim.jsonc under the "presets" field.';
    }

    const lines = ['Available presets:'];
    for (const name of names) {
      const marker = name === activePreset ? ' <- stored' : '';
      const preset = presets[name];
      const agentNames = Object.keys(preset);
      const models = agentNames
        .map((a) => {
          const cfg = preset[a];
          const modelStr =
            typeof cfg.model === 'string'
              ? cfg.model
              : Array.isArray(cfg.model) && cfg.model.length > 0
                ? resolveFirstModel(cfg.model)
                : undefined;
          return modelStr ? `    ${a} -> ${modelStr}` : `    ${a}`;
        })
        .join('\n');
      lines.push(`  ${name}${marker}`);
      lines.push(models);
    }
    lines.push('\nUsage: /preset <name> to save for the next launch.');

    return lines.join('\n');
  }

  /**
   * Resolve the first model from an array-form model entry.
   */
  function resolveFirstModel(
    models: Array<string | ModelEntry>,
  ): string | undefined {
    if (models.length === 0) return undefined;
    const first = models[0];
    return typeof first === 'string' ? first : first.id;
  }

  return {
    handleCommandExecuteBefore,
    registerCommand,
  };
}

export type PresetManager = ReturnType<typeof createPresetManager>;

function formatError(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
