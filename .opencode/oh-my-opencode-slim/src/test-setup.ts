// Bun test preload (see bunfig.toml [test] preload). The dev shell exports
// OPENCODE_WORKSPACE_PRESET for the host launcher bridge, but fixture
// workspaces in loader/tui tests define no presets, so a leaked value makes
// resolveWorkspacePreset() throw. Delete it once per test process so fixtures
// run hermetic; suites that need the bridge set it explicitly per test.
delete process.env.OPENCODE_WORKSPACE_PRESET;
