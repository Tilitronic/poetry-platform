import { deepMerge, findPluginConfigPaths, loadConfigFromPath } from './loader';
import type { Preset } from './schema';
import {
  readWorkspacePreset,
  resolveWorkspacePreset,
  saveWorkspacePreset,
} from './workspace-preset';

function configuredPresets(directory: string): Record<string, Preset> {
  const { userConfigPath, projectConfigPath } =
    findPluginConfigPaths(directory);
  const loadRegistry = (configPath: string | null) => {
    if (!configPath) return null;
    const warnings: string[] = [];
    const config = loadConfigFromPath(configPath, {
      silent: true,
      onWarning: (warning) => warnings.push(warning.message),
    });
    if (warnings.length > 0) {
      throw new Error(
        `invalid preset configuration ${configPath}: ${warnings[0]}`,
      );
    }
    return config;
  };
  const user = loadRegistry(userConfigPath);
  const project = loadRegistry(projectConfigPath);
  return deepMerge(user?.presets, project?.presets) ?? {};
}

function formatError(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function main(): number {
  const [command, directory, argument = ''] = process.argv.slice(2);
  if (!command || !directory) {
    console.error(
      'usage: workspace-preset-cli.ts save|resolve WORKSPACE [NAME]',
    );
    return 2;
  }

  try {
    const presets = configuredPresets(directory);
    if (command === 'save') {
      if (!argument) {
        console.log(
          `Stored selection: ${readWorkspacePreset(directory) ?? 'none'}`,
        );
        console.log('Usage: make preset NAME=NAME');
        return 0;
      }
      if (!Object.hasOwn(presets, argument)) {
        throw new Error(
          `Preset "${argument}" not found. Available presets: ${Object.keys(presets).join(', ') || 'none'}`,
        );
      }
      const workspace = saveWorkspacePreset(directory, argument);
      console.log(
        `Saved preset "${argument}" for workspace ${workspace}. It applies on the next launch only.`,
      );
      return 0;
    }

    if (command === 'resolve') {
      const resolution = resolveWorkspacePreset(directory, presets, argument);
      console.log(`${resolution.name ?? '-'} ${resolution.source}`);
      return 0;
    }

    throw new Error(`unknown command: ${command}`);
  } catch (error) {
    console.error(`workspace preset selection failed: ${formatError(error)}`);
    return 1;
  }
}

if (import.meta.main) {
  process.exitCode = main();
}
