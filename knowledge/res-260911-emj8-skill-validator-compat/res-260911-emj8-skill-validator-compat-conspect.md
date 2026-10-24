# Skill Validator Compatibility Design: Form Checks vs Capability Cross-References

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 5
phase-a-failures: 0
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

## Research Question

How should a skill validator be designed so that it checks not only
frontmatter form (field presence, shapes, naming rules) but also capability
compatibility -- that every preset, command, agent permission, and binary a
skill declares actually resolves against the runtime manifest -- with
dangling references failing hard instead of passing silently?

## 1. The Form Layer: What the Agent Skills Spec Gives

The canonical Agent Skills specification defines the SKILL.md form baseline:
a skill is a directory containing at minimum a SKILL.md file, whose YAML
frontmatter carries `name`, `description`, and the optional `license`,
`compatibility`, `metadata`, and `allowed-tools` fields, followed by a
Markdown instruction body ("Agent Skills specification").

The form rules are precise:

- `name` (required): 1-64 characters, lowercase alphanumerics and hyphens
  only, no leading/trailing or consecutive hyphens, and it MUST match the
  parent directory name.
- `description` (required): 1-1024 characters, describing what the skill
  does and when to use it, including trigger keywords.
- `license` (optional): short license name or bundled license file name.
- `compatibility` (optional): 1-500 characters when present, free text for
  environment requirements such as intended product, required system
  packages, or network access needs. Most skills omit it.
- `metadata` (optional): string-to-string map for client properties outside
  the spec.
- `allowed-tools` (optional, experimental): space-separated pre-approved
  tool list with varying agent support ("Agent Skills specification").

The spec adds progressive disclosure (metadata at startup, full body on
activation, scripts and references loaded only as needed) and points to the
skills-ref reference library for frontmatter validation ("Agent Skills
specification").

The critical finding, stated in the archived source itself, is what the
spec does NOT do: it never cross-references `compatibility` text against
real system packages, never resolves `allowed-tools` against an agent's
actual tool list, and never checks `scripts/` executability or
referenced-file existence ("Agent Skills specification"). A compatibility
validator therefore starts where the spec stops: parse declared
capabilities and resolve each against the runtime manifest (presets,
commands, agents and permissions, binaries, files), hard-failing anything
unresolvable. The free-text `compatibility` field is flagged as the classic
trap -- form-valid always, capability-meaningful only if the validator
parses and resolves its claims ("Agent Skills specification").

## 2. The Failure Mode That Motivates the Compat Layer

A community bug report against an opencode fork (v1.17.0) documents exactly
the failure mode compatibility validators exist to prevent: form-only checks
that pass, or silently ignore, fields whose meaning is never enforced
downstream ("Skills: Inconsistent Documentation").

The priority-ordered issue list includes: a root-level SKILL.md file
recognized as a valid skill when it should not be; `license`,
`compatibility`, and `metadata` never stored, persisted, or forwarded to
the model; name and description lengths unvalidated; the name regex
unvalidated; and the name-must-match-directory rule unenforced ("Skills:
Inconsistent Documentation").

The thread draws the exact line this research question asks about:
frontmatter FORM (name regex and length, description length, directory-name
match) versus CAPABILITY wiring (metadata actually reaching the model,
skills actually registered as commands and autocomplete suggestions). It
also records the hard-fail precedent that justifies hard-failing dangling
references: the maintainer-leaning position that failing as hard as
possible is preferred, citing the established pattern of throwing when
configuration resolves to something invalid, with the open question framed
as whether invalid skills are skipped with a warning or fail loading
("Skills: Inconsistent Documentation").

Design consequence: the compat layer should treat a dangling preset,
unknown command, unknown agent or permission, missing required binary, or
impossible requirement as the analog of invalid configuration -- a
hard failure, not a warning -- consistent with the recorded precedent.

## 3. The Ajv Keyword Mechanism: Form Check and Compat Check in One Pass

The official Ajv documentation describes four user-defined keyword types,
each with a distinct cost and power profile ("User defined keywords"):

1. `code` (code generation function, recommended since v7): generates
   validation code with access to parent data and path; safe against code
   injection, best performance, precise control.
2. `validate` (function): runs directly against the data value; suitable
   for prototyping before conversion to compiled keywords, for keywords
   independent of the schema value (with `schema: false`), and for keywords
   supporting `$data` references.
3. `compile` (function): factory called once at schema compilation that
   returns a validation closure; costs one extra function call per
   validation versus codegen, but can pre-build expensive state.
4. `macro` (function): runs at compile time and returns another schema
   applied alongside the original; zero runtime cost and portable because
   the expansion is standard JSON Schema ("User defined keywords").

Two supporting mechanisms complete the picture. First, `metaSchema`
validates the keyword's own schema value, catching authoring mistakes
early -- directly applicable to capability keywords, for example by
constraining a `requires_binaries` array or an `agents` enum ("User
defined keywords"). Second, structured error reporting: keywords define
error messages via `error: { message, params }`, or `validate`/`compile`
keywords assign `.errors` on the validation function, with async keywords
rejecting with a validation error; every error needs at least `keyword`,
`message`, and `params` ("User defined keywords").

The archived takeaway, and the core of the two-layer design: custom
keywords plus `metaSchema` plus structured errors deliver the form check
(`metaSchema` constraining the keyword value) AND the compatibility check
(a `validate`/`compile` closure cross-referencing the runtime manifest --
preset arrays, command names, agent permissions, binary existence) in a
single pass, with hard-fail errors naming the dangling reference ("User
defined keywords").

The Jsonic vendor guide (2026-05-19) confirms the same implementation menu
with worked TypeScript examples: `validate` for simple membership checks
such as a command name in a registry; `compile` for manifest-capturing
closures such as a preset-array snapshot or an agent permission map;
`macro` where the capability rule rewrites to built-in vocabulary; and
`async` keywords where the check needs I/O such as a binary-on-PATH probe
or a preset resolvability lookup ("JSON Schema Custom Keywords").

The guide also stresses registration order (`ajv.addKeyword()` must run
BEFORE `ajv.compile()`, since later registrations never reach
already-compiled validators) and the `ajv-keywords` plugin's 15-plus
pre-built extras as prior art ("JSON Schema Custom Keywords").

## 4. Cross-Reference Patterns: From Sibling Fields to Manifest Closures

Standard JSON Schema validates each field in isolation; it has no built-in
"endDate after startDate" rule. Two supported patterns fill the gap
("JSON Schema Custom Keywords"):

- `$data` references (with `new Ajv({ $data: true })`): a keyword such as
  `minimum` reads a sibling value at validation time (for example
  `{ "minimum": { "$data": "1/minPrice" } }`). Declarative, works with any
  supported keyword, resolves safely (undefined passes except for `const`;
  wrong type fails).
- Custom keyword with `schema: false` receiving the parent object and
  checking its fields together; more flexible for multi-field rules
  ("JSON Schema Custom Keywords").

The capability-validator mapping, stated explicitly in the archived guide:
a skill's `agents`, `commands`, or `presets` fields are cross-document
references, not sibling fields, so the equivalent of `$data` is a
compile-time closure over the runtime manifest -- the preset list, the
command registry, the agent permission map, a PATH scan. The keyword
receives the declared value and checks membership or existence against the
captured manifest ("JSON Schema Custom Keywords").

For existence checks requiring I/O, `async: true` keywords return
`Promise<boolean>` with the root schema declaring `$async: true`. The
guide's worked example is an email-uniqueness database lookup; the direct
analog is a required-binary check or a registry lookup for preset
existence. The guidance is to keep async keywords focused (one check each)
and batch related I/O inside the keyword ("JSON Schema Custom Keywords").

The portability warning matters for shared contracts: `validate` and
`compile` keywords are Ajv-specific and fail or are silently ignored
elsewhere, while `macro` expansions are spec-compliant and portable. For
public contracts the recommendation is to prefer standard vocabulary or
macro keywords, document Ajv-specific keywords, and provide fallback logic
(such as a standalone fixture test) for non-Ajv consumers ("JSON Schema
Custom Keywords").

## 5. Fixture Taxonomy: Pinning Each Dangling-Reference Failure

A pre-implementation crate spec for a skills-validator test suite provides
the fixture-taxonomy pattern to copy: fixtures organized by category under
`tests/fixtures/skills/`, with `valid/` (minimal, complete, multi-file),
`invalid/` (missing-frontmatter, malformed-toml, missing-name,
invalid-name, unknown-fields), `edge-cases/` (unicode-content, large-file,
empty-optional-fields, circular-references), and `multi-location/`
(same-named skills in different locations testing duplicate-warning logic),
each with per-fixture acceptance criteria ("Test Fixtures").

The user stories pin the contract: valid fixtures must always pass,
invalid fixtures must fail with known error patterns, edge cases must
cover parsing boundaries, and multi-location fixtures must exercise
duplicate handling ("Test Fixtures").

For capability compatibility the archived source prescribes extending the
`invalid/` tree with one fixture per dangling-reference failure mode:
dangling preset reference, unknown command name, unknown agent or
permission, missing required binary, and impossible requirement (for
example mutually exclusive constraints). Each fixture pins the expected
error so that negative tests assert the exact failure, not merely that
validation failed ("Test Fixtures").

## 6. Local Inventory: Current Validator State (Repo-Local, Not Cited)

The following describes the repository's existing validator as observed in
`scripts/__tests__/validate-skills.bats` (532 lines). It is local
inventory, not an archived research source, and carries no MLA citation.

Current hard checks (exit 1): YAML parse errors, truncated frontmatter,
missing frontmatter, missing or empty `name`, missing or empty
`description`, name/directory mismatch, non-mapping YAML root, missing
SKILL.md, byte-exact cross-location duplicates, and missing required
Socratic-interview skill files. Current soft checks (exit 0 with stderr
warnings): missing activation phrase, missing license, near-duplicate
skills differing from the global copy, and a missing global skills tree
(skips the duplicate-detection tier). Exit-code contract: 0 when all hard
checks pass, 1 when any hard check fails (collect-all semantics, never
fail-fast), 2 for infrastructure failure (python3 unavailable or skills
root missing).

Gap relative to this conspect: no check resolves `compatibility`,
`allowed-tools`, presets, commands, agents/permissions, or binaries
against any runtime manifest. The natural extension point is a compat tier
modeled on the duplicate-detection tier: manifest snapshot at startup,
one hard failure per dangling reference, collect-all reporting, and one
fixture per failure mode per the taxonomy in section 5.

## 7. Recommended Two-Layer Design

1. Layer 1 -- form (keep, extend to spec): name regex and length,
   description length, directory-name match, frontmatter presence and
   mapping shape. These are pure-schema checks; `metaSchema` on any new
   keyword constrains the keyword's own value shape.
2. Layer 2 -- compat (new): one custom keyword per reference class
   (preset, command, agent/permission, binary, file). Simple membership
   checks use `validate`; manifest-snapshot checks use `compile` closures;
   I/O-backed existence checks use `async` keywords with `$async: true`;
   anything expressible in builtins uses `macro` for portability.
3. Failure policy: every dangling reference is a hard failure naming the
   exact unresolved claim, following the recorded hard-fail precedent;
   collection is collect-all (every dangling ref reported in one run),
   never fail-fast.
4. Fixtures: extend the `invalid/` tree with one pinned fixture per compat
   failure mode (dangling preset, unknown command, unknown
   agent/permission, missing binary, impossible requirement) plus
   multi-location conflict fixtures; negative tests assert exact error
   text.
5. Portability: document Ajv-specific keywords and keep a standalone
   fixture test as the non-Ajv fallback so the schema is not the only
   artifact that understands the contract.

## Works Cited

"Agent Skills specification." AgentSkills.io, agentskills.io/specification.
Archived 2026-09-11.

"JSON Schema Custom Keywords: Extending Ajv and Validators." Jsonic,
jsonic.io/guides/json-schema-extensions, 19 May 2026. Archived 2026-09-11.

"Skills: Inconsistent Documentation and Behaviour." anomalyco/opencode,
issue 31616, github.com/anomalyco/opencode/issues/31616. Archived
2026-09-11.

"Test Fixtures (skills-validator crate spec 00010)." docs.rs,
docs.rs/crate/skills-validator/latest/source/specs/
spec-00010-test-fixtures.md. Archived 2026-09-11.

"User defined keywords." Ajv, ajv.js.org/keywords.html. Archived
2026-09-11.

## Unarchived/Excluded

Per the researcher's `.source-urls.txt` evaluation, the following
candidates were excluded and are NOT cited in the body:

- python-jsonschema referencing documentation: reference-resolution
  mechanics, not capability cross-checks.
- vscode-json-languageservice `$dynamicRef` PR: reference-resolution
  mechanics, not capability cross-checks.
- oh-my-openagent async-loader tests: frontmatter loading only, no compat
  enforcement.

Also present in `sources/` but not a source: `placeholder.txt`
(single-word placeholder, no research content).
