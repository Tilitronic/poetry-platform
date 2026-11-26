Res009 — snip jq filter truncation (conspect)
Date: 2026-08-10
Related ticket: DIA-075 (investigation); tracking ticket: DIA-076

Executive summary
snip (edouard-claude/snip) is a CLI output-filter proxy that reduces LLM token consumption by filtering command output before it reaches downstream consumers (for example, an LLM). The snip configuration (TOML at ~/.config/snip/config.toml) exposes per-filter enable/disable controls and global safety caps (max_output_bytes, max_lines, max_line_length). The opencode-snip plugin integrates snip into OpenCode via the tool.execute.before hook and (as of PR #14) uses snip check / snip run subcommands to decide at runtime whether to wrap a particular subcommand. A documented bug (issue #8) showed that naive pipe-splitting prefixed snip to every pipeline segment, breaking jq expressions; PR #14 introduced quote-aware splitting, snip check-based wrapping, and other guards. Practically, the observed corruption of JSON outputs used for downstream sha256 checks was caused by a jq filter/truncation stage in snip; disabling the jq filter (e.g. by setting [filters.enable] jq = false in the user's config) or using a passthrough pattern preserves canonical output for checksum workflows.

Sections
- What is snip (purpose & high-level behaviour)
- Filters & configuration (enable/disable, override, safety caps, tee)
- jq filter behaviour and truncation limits (max_output_bytes / truncate marker)
- opencode-snip integration (how commands are wrapped; tool.execute.before hook)
- Pipe-bug context (issue #8): why naive prefixing breaks jq pipelines
- PR #14 changes: snip check/run subcommands, quote-aware pipe handling, tests
- Practical guidance for checksum/integrity workflows (disable jq filter, use tee, canonical passthrough)
- Works cited (MLA)

1. What is snip
snip is a CLI proxy designed to filter and shorten terminal command output to reduce LLM input tokens. It ships as a user tool (brew/go install) and can be invoked directly or used as a wrapper by tools that prefix commands with snip (opencode-snip). The opencode-snip plugin documents typical savings (examples: go test reduced from 689 tokens to 16 tokens) and registers itself with OpenCode using the tool.execute.before hook so commands are automatically wrapped by snip when appropriate (VincentHardouin, opencode-snip).

2. Filters & configuration
snip reads optional TOML config at ~/.config/snip/config.toml. Key controls: [filters.dir] for user filter directories (user filters override built-ins), [filters.enable] booleans to enable/disable individual built-in filters, and [filters.override.<name>] to adjust a single filter without replacing its file. Global safety caps can be set per pipeline: max_lines, max_line_length, max_output_bytes; a documented example sets filters.global.max_output_bytes = 65536. The tee system saves raw command output for post-mortem debugging; tee defaults to enabled and writes files under ~/.local/share/snip/tee/ (configurable). (edouard-claude, "Configuration").

3. jq filter behaviour and truncation limits
snip implements a staged pipeline where filters may apply truncation actions such as truncate_bytes (max_output_bytes), truncate_lines, or head/tail. The configuration documents default/global caps and a per-filter safety cap that is applied on top of the matched filter's own behaviour. When max_output_bytes or similar truncation is non-zero, the filtered output may be shortened and include a truncation marker; this deterministically changes the byte length of piped output. For workflows that compute a checksum on piped output (e.g., sha256sum on stdout), this truncation is sufficient to change the computed digest. The configuration documentation also describes a summary line mode and the tee system that can save raw output for debugging (edouard-claude, "Configuration").

4. opencode-snip integration
The opencode-snip plugin prefixes shell commands with snip so the LLM sees reduced output. Earlier versions used a static WRAPPED_COMMANDS or an operator regex to decide wrapping; PR #14 reworked this to call snip check at runtime and to use snip run -- for wrapping. The plugin implements a quote-aware pipe-splitting strategy and invokes a shouldWrap/hasSnipSubcommands helper: it calls `snip check -- <words>` to determine whether a particular segment has a configured filter and then prefixes that segment with `snip run --` on success. The plugin uses the tool.execute.before hook to rewrite output.args.command. The README and PR commentary show careful attention to quoting, avoiding {raw: ...} when passing words to the snip check subcommand, and treating non-zero exit codes correctly so the presence of the subcommand is detected without misinterpreting 'no filter' (VincentHardouin, opencode-snip; PR #14).

5. Pipe-bug context (issue #8)
Issue #8 documents a practical failure mode: an operator-regex that split on all | characters caused snip to be prefixed to every pipeline segment, including segments inside jq expressions. Example: a command like

    cat file.json | jq '.content[0].text | fromjson | .results[].content | "\(.title) - \(.id)"'

was transformed into prefixed parts such as `snip ... | snip jq '... | snip fromjson | ...'`, which breaks jq's syntax and execution (jq syntax error). The issue recommends only prefixing the first command in a pipeline or otherwise ensuring downstream segments receive stdin from the prior snip output without their own snip prefix. This bug explains why automated agents repeatedly failed when attempting to run jq pipelines (infinite retries and token waste) until the pipe-handling logic was improved (issue #8).

6. PR #14: fixes and behaviour changes
Pull request #14 replaced static UNPROXYABLE_COMMANDS with runtime snip check calls, added quote-aware full-pipeline splitting, and changed wrapping to `snip run -- <cmd>` rather than bare `snip <cmd>`. It added tests for pipe expressions, 2>&1 redirections, and quoting, removed an extra docs file and improved error handling (nothrow/quiet patterns when probing `snip check`). The PR notes subtle failure modes (hasSnipSubcommands must use .nothrow() so exit code 1 means "subcommand exists but no filter" rather than missing-subcommand). PR #14 also added a snip-prefix guard to avoid double-wrapping segments already containing `snip run --` and fixed multi-word argument handling for snip check.

7. Practical guidance for checksum and integrity workflows
- If a pipeline must preserve exact stdout bytes for downstream checksum computation, avoid filters that can truncate or otherwise change output bytes. Two practical options:
  - Disable the jq/output-size filter in your user config for the filter named `jq` (or any relevant filter) by setting in ~/.config/snip/config.toml:

    [filters.enable]
    jq = false

    This disables the built-in jq filter and lets the pipeline run unmodified through to the consumer. (edouard-claude, "Configuration").

  - Use the tee system to capture raw output for verification: enable tee (or set SNIP_TEE_DIR) so the unfiltered original output is saved under ~/.local/share/snip/tee/, then compute checksums on the tee file rather than filtered stdout. Note tee max_file_size and max_files settings in config.

- For one-off runs or when integrating into scripts, run the canonical passthrough via snip run -- to avoid double-wrapping and to let snip's runtime check determine wrapping only for the intended segment. Example safe wrapper (preserves jq behaviour while letting snip wrap only when appropriate):

    snip run -- cat file.json | jq '.' > output.json

  or, when needing an exact checksum of filtered stdout, compute the checksum on the tee file produced by snip's tee system rather than on stdout.

8. Limitations and excluded claims
All claims in this conspect are grounded in the locally archived sources captured in knowledge/res009-snip-jq-filter-truncation/sources/. No external source was excluded.

Works cited (MLA)
edouard-claude. "Configuration." snip Wiki, GitHub, https://github.com/edouard-claude/snip/wiki/Configuration. Accessed 10 Aug. 2026.
VincentHardouin. opencode-snip. GitHub repository, https://github.com/VincentHardouin/opencode-snip. Accessed 10 Aug. 2026.
VincentHardouin. "Issue #8: pipe-bug / OPERATOR_RE splits jq pipes." GitHub Issues, https://github.com/VincentHardouin/opencode-snip/issues/8. Accessed 10 Aug. 2026.
VincentHardouin. "fix: use snip check/run subcommands, fix pipe handling... (#14)." Pull request discussion, https://github.com/VincentHardouin/opencode-snip/pull/14. Accessed 10 Aug. 2026.

Files archived in this conspect
- knowledge/res009-snip-jq-filter-truncation/sources/configuration.md (archived from https://github.com/edouard-claude/snip/wiki/Configuration)
- knowledge/res009-snip-jq-filter-truncation/sources/opencode-snip.md (archived from https://github.com/VincentHardouin/opencode-snip)
- knowledge/res009-snip-jq-filter-truncation/sources/issues-8.md (archived from https://github.com/VincentHardouin/opencode-snip/issues/8)
- knowledge/res009-snip-jq-filter-truncation/sources/pull-14.md (archived from https://github.com/VincentHardouin/opencode-snip/pull/14)
