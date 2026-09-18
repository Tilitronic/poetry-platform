import { deepMerge, findPluginConfigPaths, loadConfigFromPath } from './loader';
import type { Preset } from './schema';
import {
  clearWorkspacePreset,
  getWorkspacePresetStorePath,
  readWorkspacePreset,
  resolveWorkspacePreset,
  saveWorkspacePreset,
} from './workspace-preset';

function configuredRegistry(directory: string): {
  presets: Record<string, Preset>;
  declaredDefault: string | undefined;
} {
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
  const presets = deepMerge(user?.presets, project?.presets) ?? {};
  // Project wins for the declared default, mirroring mergePluginConfigs.
  const declaredDefault =
    (project?.preset?.trim() ? project.preset : undefined) ??
    (user?.preset?.trim() ? user.preset : undefined);
  return { presets, declaredDefault };
}

function formatError(error: unknown): string {
  if (error instanceof Error) {
    const cause =
      error.cause instanceof Error ? `: ${error.cause.message}` : '';
    return `${error.message}${cause}`;
  }
  return String(error);
}

export function runCli(args: string[]): number {
  const [command, directory, argument = ''] = args;
  if (!command || !directory) {
    console.error(
      'usage: workspace-preset-cli.ts save|resolve WORKSPACE [NAME]',
    );
    return 2;
  }

  try {
    const { presets, declaredDefault } = configuredRegistry(directory);
    if (command === 'save') {
      if (!argument) {
        console.log(
          `Stored selection: ${readWorkspacePreset(directory) ?? 'none'}`,
        );
        console.log('Usage: make preset NAME=NAME (NAME=none clears)');
        return 0;
      }
      if (argument === 'none') {
        const workspace = clearWorkspacePreset(directory);
        console.log(
          `Cleared preset for workspace ${workspace} (store: ${getWorkspacePresetStorePath(directory)}). Launches fall back to the declared default or no preset.`,
        );
        return 0;
      }
      if (!Object.hasOwn(presets, argument)) {
        throw new Error(
          `Preset "${argument}" not found. Available presets: ${Object.keys(presets).join(', ') || 'none'}`,
        );
      }
      const workspace = saveWorkspacePreset(directory, argument);
      console.log(
        `Saved preset "${argument}" for workspace ${workspace} (store: ${getWorkspacePresetStorePath(directory)}). It applies on the next launch only, on every launch path (make opencode, shell+opencode, direct, subdir).`,
      );
      return 0;
    }

    if (command === 'resolve') {
      const resolution = resolveWorkspacePreset(
        directory,
        presets,
        argument,
        declaredDefault,
      );
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
  process.exitCode = runCli(process.argv.slice(2));
}
