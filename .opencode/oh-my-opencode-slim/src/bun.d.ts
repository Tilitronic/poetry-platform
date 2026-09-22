/**
 * Minimal ambient declaration for the Bun globals used in this codebase.
 *
 * WHY: the upstream `bun-types` package cannot be resolved in this repo
 * snapshot (no package.json / node_modules — both gitignored), which
 * broke editor TypeScript diagnostics. Only the APIs actually referenced
 * in `src/` are declared here; keep in sync if more Bun globals are used.
 */
declare const Bun: {
  file(path: string | URL): {
    json(): Promise<unknown>;
  };
};
