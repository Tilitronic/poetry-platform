# DIA-188 OpenCode Version Pin + OMO 2.2.14 Compatibility Floor - Conspect (res028)

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 8
phase-a-failures: 0
shelf-registration: memory-shelf.yaml (shelf.conspects)
-->

Conspect for DIA-188 (OMO self-sufficiency, OPEN): persist the authoritative ground truth on (1) the newest stable opencode version to pin, (2) how the installer actually works, (3) the OMO Slim 2.2.14 compatibility floor, and (4) the project-internal Dockerfile.dev migration implication. Every external claim is grounded in the 8 locally archived source files under `sources/` (Phase A output, archived 2026-08-15 by @researcher). ALL 8 provisioned sources were archived; there were ZERO Phase A failures and ZERO exclusions (the two npm 404 responses are themselves the archivable facts, not failures). This conspect EXTENDS res019 (OMO 2.2.13 version gate) by pinning the opencode runtime floor for 2.2.14 and the migration path for the project's pinned opencode build.

## 1. Decision context and constraint frame (project-internal, not external-source claims)

- **DIA-188 ticket**: "OMO self-sufficiency" - establish the correct opencode version to pin in the project's dev container and confirm OMO Slim 2.2.14 compatibility against it. The research question: which stable opencode release satisfies both the newest-stable preference AND the OMO plugin/sdk exact-pin floor.
- **Project current state (project-internal ground truth)**: `Dockerfile.dev` line 24 pins `OPENCODE_VERSION=1.18.4`; lines 127-133 install via `curl https://opencode.ai/install` piped through `bash`, verifying a `sha256` of the INSTALL SCRIPT (`fc3c1b2...`), not the downloaded binary. Both the version and the verification strategy are now known to be stale/non-ideal (see section 4).
- **Conspecter lane (project-internal)**: pure-synthesis tier (practice-protected.md section 5/6, DIA-135 D7). Bash FLAT DENY (curl/wget/trafilatura/crwl allow-list removed), webfetch denied, task denied; edit scoped to `knowledge/*` + `.opencode/memory-shelf.yaml`. Model routing deepseek-v4-flash, variant low, temperature 0.1. No network fetch was performed during this synthesis - all claims derive from the archived sources.
- **Relationship to res019**: res019 (OMO 2.2.13 version gate) established the SAME exact-pin mechanism (`@opencode-ai/plugin` + `@opencode-ai/sdk` @ 1.18.13) as the OMO compatibility floor at 2.2.13. This conspect confirms the floor is UNCHANGED at 2.2.14 and adds the runtime-side opencode pin decision + repo relocation + installer-truth findings. The two conspects are complementary, not overlapping.

## 2. Newest stable opencode release and the release cadence (archived evidence)

- **v1.18.18 is the newest stable opencode release**, published 2026-08-13T01:15:04Z (tag `v1.18.18`, target commit `14b37df39168eaf6a6faf862ec4a7bbe9c825bbd`, prerelease false, immutable release) - sources/anomalyco-releases-latest.json (assets `latest-linux.yml`, `latest.json`, `latest.yml`; body: Kimi system prompt selection for Moonshot/Kimi providers + xhigh reasoning effort fix for xAI models).
- **The release page confirms a 1.18.x-only cadence**: the archived releases page lists v1.18.9 through v1.18.18 as consecutive entries (v1.18.18 -> v1.18.17 -> v1.18.16 -> v1.18.15 -> v1.18.14 -> v1.18.13 -> v1.18.12 -> v1.18.11 -> v1.18.10 -> v1.18.9), each with per-release notes - sources/anomalyco-releases-page.md. Releases are tagged by `opencode-agent[bot]`, reinforcing the fully-automated, high-frequency (often multiple per week) patch cadence within the single 1.18.x line.
- **npm is NOT a version source for opencode**: both `https://registry.npmjs.org/@opencode-ai/opencode` and `https://registry.npmjs.org/opencode` return HTTP 404 `{"error":"Not found"}` (archived verbatim in sources/npm-opencode-ai.json and sources/npm-opencode.json). Therefore `dist-tags.latest` is N/A and opencode is NOT distributed via npm; GitHub releases (anomalyco/opencode) are the canonical version source.

## 3. REPO RELOCATION (critical): sst/opencode -> anomalyco/opencode

- **All authoritative release artifacts now live under `anomalyco/opencode`**, not `sst/opencode`:
  - The GitHub releases/latest API is `https://api.github.com/repos/anomalyco/opencode/releases/latest` (sources/anomalyco-releases-latest.json) and returns release `369579453` for tag `v1.18.18`.
  - Every release asset `browser_download_url` is under `https://github.com/anomalyco/opencode/releases/download/...` (sources/anomalyco-releases-latest.json).
  - The releases page is `https://github.com/anomalyco/opencode/releases` (sources/anomalyco-releases-page.md).
  - The install script resolves the default URL as `https://github.com/anomalyco/opencode/releases/latest/download/$filename` and the release-version via `https://api.github.com/repos/anomalyco/opencode/releases/latest` (sources/opencode-install-script.sh).
- The project's Dockerfile.dev install block and any `sst/opencode` references must be updated to the `anomalyco/opencode` location. (The specific 198k-star figure is researcher-supplied context, not present in the archived JSON; it is not cited as an archived claim.)

## 4. INSTALLER TRUTH (critical): the opencode.ai/install script does NOT verify the binary

- **`https://opencode.ai/install` resolves to a MUTABLE dev-branch artifact**: the script is served from `raw.githubusercontent.com/anomalyco/opencode/refs/heads/dev/install` (per the Phase A manifest note following the 307 redirect) - sources/opencode-install-script.sh.
- **The script performs NO sha256 verification of the downloaded binary.** It builds a `filename` (`opencode-$os-$arch.tar.gz` on Linux, `.zip` elsewhere) and downloads it with `curl -s -L -o "$tmp_dir/$filename" "$url"` (via `download_with_progress`), then extracts with `tar -xzf` and `mv`s `opencode` into `~/.opencode/bin`. There is NO `sha256sum -c`, no checksum file, and no digest comparison anywhere in the 460-line script. Integrity relies solely on the TLS transport to GitHub.
- **The script lives on a mutable dev branch**: the default (no-version) path resolves `latest` dynamically via the GitHub API each run, so the exact bytes served can change between runs. A pinned `--version` only fixes the release tag; the SCRIPT ITSELF (its logic and any embedded URLs) remains the mutable `dev` branch artifact.
- **Project implication (project-internal)**: the Dockerfile.dev pinned hash `fc3c1b2...` verifies the INSTALL SCRIPT, not the binary - and because the script is a mutable dev-branch artifact, that script-hash is not version-stable across builds. The recommended hardening is a DIRECT binary download from the immutable GitHub release asset + `sha256sum -c` on the release-asset digest, matching the existing `node`/`snip`/`uv`/`mise` pattern already used in the same Dockerfile.
- **The release-asset digest for the opencode binary (linux-x64)**: `opencode-linux-x64.tar.gz` @ v1.18.18 has `digest: sha256:0cddc222418b8553669905a8980c0cda7088f00da24d83d6ac76b01c9fdb2aaf` (size 60,386,126, download_count 75,565) - sources/anomalyco-releases-latest.json. This is the value to pin in a `sha256sum -c` block.

## 5. OMO 2.2.14 compatibility floor

- **OMO Slim v2.2.14 exact-pins `@opencode-ai/plugin` and `@opencode-ai/sdk` both @ 1.18.13** (no caret, exact pin) in `dependencies` - sources/omo-v2214-package-json.json (package.json v2.2.14, raw.githubusercontent.com/alvinunreal/oh-my-opencode-slim/v2.2.14/package.json). The exact-pin mechanism matches what res019 documented for 2.2.13, so the OMO floor is **opencode >= 1.18.13**.
- **1.18.18 satisfies the floor with headroom**: the newest stable opencode 1.18.18 is >= the exact-pinned 1.18.13 floor, so pinning the newest stable opencode satisfies the OMO 2.2.14 dependency contract.
- **Cross-reference res019**: res019 established the identical floor (1.18.13) at OMO 2.2.13 via the same exact-pin; 2.2.14 keeps it unchanged. This conspect EXTENDS res019 (2.2.14 floor + opencode pin migration + repo relocation), it does not duplicate it.

## 6. Breaking changes 1.18.4 -> 1.18.18 (archived release-note evidence)

Scanned the archived per-release notes for the 1.18.4 -> 1.18.18 window (sources/anomalyco-releases-page.md covers 1.18.9-1.18.18; sources/anomalyco-releases-latest.json covers 1.18.18 body):

- **NONE of the changes break plugins, TUI-host, or config-schema for the project's usage.** The release notes are dominated by provider/model bugfixes, desktop-app localization/RTL work, and web UI fixes.
- **Notable 1.18.16 config change is MORE LENIENT, not breaking**: v1.18.16 "Ignore unknown top-level config fields instead of failing config parsing" (sources/anomalyco-releases-page.md) - i.e., unknown top-level config fields no longer fail startup. This is a relaxation, safe for the project.
- Other 1.18.x highlights (all non-breaking for the project): 1.18.17 session-compaction/retry fixes, MERGE Gateway reasoning variants, DeepSeek V4 Flash sampling defaults, Muse family system-prompt routing; 1.18.15 message-chronology fixes; 1.18.14 provider retry + ACP usage fixes; 1.18.13 TUI/desktop RTL + PR-number-in-context; 1.18.12 Azure GPT-5.5+ reasoning fix; 1.18.11 MCP SSE reconnect-loop + interleaved reasoning-field fix; 1.18.9 legacy MCP SDK client compatibility (sources/anomalyco-releases-page.md, sources/anomalyco-releases-latest.json).
- The only version in the scanned window explicitly referencing TUI is 1.18.13 ("GitHub pull request reviews now include the pull request number and URL in context") - additive, non-breaking.
- **Net assessment**: upgrading the project pin from 1.18.4 to 1.18.18 is safe for the plugin/TUI-host/config-schema surface that OMO 2.2.14 and the project rely on.

## 7. Project implication: Dockerfile.dev migration (project-internal ground truth)

Grounded in the project-internal excerpt (sources/dockerfile-dev.md) plus the external archives, the recommended migration for `Dockerfile.dev`:

1. **Pin `OPENCODE_VERSION=1.18.18`** (line 24 ARG) - the newest stable, satisfying the OMO 2.2.14 floor.
2. **Replace the install-script block** (lines 127-133) with a direct binary download + sha256 verification:
   - Download `https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-x64.tar.gz`
   - Verify with `sha256sum -c` against `0cddc222418b8553669905a8980c0cda7088f00da24d83d6ac76b01c9fdb2aaf`
   - Extract and install `opencode` to `/usr/local/bin/opencode`.
   - This removes the mutable-script dependency and the stale `fc3c1b2...` script-hash, matching the node/snip/uv/mise pattern already in the same file.
3. **Update any `sst/opencode` references** to `anomalyco/opencode` (repo relocation, section 3).

## 8. Unarchived / excluded sources

- **NONE.** All 8 provisioned sources were archived with zero failures and zero exclusions. The two npm 404 responses (`@opencode-ai/opencode` and `opencode`) are themselves archived facts (they prove opencode is not on npm) and are cited as such - they are NOT treated as failures. res019-conspect and Dockerfile.dev are project-internal references (not fetched), cited in place per the manifest.

## 9. Works cited (MLA)

1. anomalyco/opencode. "Releases - Latest: v1.18.18." GitHub API, 2026, api.github.com/repos/anomalyco/opencode/releases/latest. Accessed 15 Aug. 2026. [archived: sources/anomalyco-releases-latest.json]
2. anomalyco/opencode. "Releases." GitHub, 2026, github.com/anomalyco/opencode/releases. Accessed 15 Aug. 2026. [archived: sources/anomalyco-releases-page.md]
3. anomalyco/opencode. "OpenCode Installer (install.sh)." opencode.ai/install, 2026, opencode.ai/install. Accessed 15 Aug. 2026. [archived: sources/opencode-install-script.sh]
4. npm registry. "@opencode-ai/opencode - registry metadata." registry.npmjs.org, 2026, registry.npmjs.org/@opencode-ai/opencode. Accessed 15 Aug. 2026. [archived: sources/npm-opencode-ai.json; 404 documented]
5. npm registry. "opencode - registry metadata." registry.npmjs.org, 2026, registry.npmjs.org/opencode. Accessed 15 Aug. 2026. [archived: sources/npm-opencode.json; 404 documented]
6. alvinunreal. "oh-my-opencode-slim package.json (v2.2.14)." GitHub raw, 2026, raw.githubusercontent.com/alvinunreal/oh-my-opencode-slim/v2.2.14/package.json. Accessed 15 Aug. 2026. [archived: sources/omo-v2214-package-json.json]
7. poetry-platform. "Dockerfile.dev - OPENCODE_VERSION pin + OpenCode install block (excerpt)." Project-internal, 2026, Dockerfile.dev. Accessed 15 Aug. 2026. [archived: sources/dockerfile-dev.md]
8. conspecter lane. "OMO Slim 2.2.13 Version-Gate Research (res019)." Project-internal knowledge, 2026, knowledge/res019-omo-slim-version-gate/res019-omo-slim-version-gate-conspect.md. Accessed 15 Aug. 2026. [referenced in place, not copied]

## 10. Claim-to-source mapping (key claims)

- "v1.18.18 is the newest stable opencode release, published 2026-08-13T01:15:04Z" -> sources/anomalyco-releases-latest.json
- "1.18.x-only cadence; per-release notes 1.18.9-1.18.18; tagged by opencode-agent[bot]" -> sources/anomalyco-releases-page.md, sources/anomalyco-releases-latest.json
- "opencode is NOT on npm (404 for both @opencode-ai/opencode and opencode)" -> sources/npm-opencode-ai.json, sources/npm-opencode.json
- "All release artifacts live under anomalyco/opencode (not sst/opencode); install script resolves latest from anomalyco/opencode" -> sources/anomalyco-releases-latest.json, sources/anomalyco-releases-page.md, sources/opencode-install-script.sh
- "install script performs NO sha256 verification of the downloaded binary; served from mutable dev branch" -> sources/opencode-install-script.sh
- "opencode-linux-x64.tar.gz v1.18.18 sha256 = 0cddc222418b8553669905a8980c0cda7088f00da24d83d6ac76b01c9fdb2aaf" -> sources/anomalyco-releases-latest.json
- "OMO 2.2.14 exact-pins @opencode-ai/plugin + @opencode-ai/sdk @ 1.18.13 (floor unchanged from 2.2.13); 1.18.18 satisfies with headroom" -> sources/omo-v2214-package-json.json, res019 (cross-ref)
- "No breaking changes 1.18.4 -> 1.18.18 for plugins/TUI-host/config-schema; 1.18.16 config parser MORE lenient (ignores unknown top-level fields)" -> sources/anomalyco-releases-page.md, sources/anomalyco-releases-latest.json
- "Dockerfile.dev currently pins OPENCODE_VERSION=1.18.4; pinned hash fc3c1b2... verifies the install SCRIPT, not the binary (stale/unstable)" -> sources/dockerfile-dev.md (project-internal) + sources/opencode-install-script.sh
