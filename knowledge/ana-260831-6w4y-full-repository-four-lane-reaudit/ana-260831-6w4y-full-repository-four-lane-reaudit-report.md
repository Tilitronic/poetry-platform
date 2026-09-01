# Повторний повний аудит Poetry Platform / OpenCode setup

**Дата:** 2026-08-31  
**Fixed point:** `ddcb2a2be920` (`omo-slim-changes`)  
**Кампанія:** DIA-260827-wfcx «full repository four-lane audit tests agents code skills plugins»  
**Формат:** чотири незалежні read-only аудити на GPT-5.6 Sol High з фінальною ручною перезвіркою Critical/High знахідок.

## Висновок

Setup має сильну основу: 585 shell-тестів, 1367 OMO-тестів, 157 plugin-тестів, атомарні handoff-записи, deny-first правила для частини ролей, валідний config gate, робочі MCP і вже виконаний cleanup частини scaffold-коду. Але зараз його не можна вважати надійно ізольованим і повністю перевіреним.

Головні блокери:

1. У merged runtime зберігається plaintext Context7 credential у глобальному користувацькому config. Його потрібно відкликати та перевипустити.
2. `delegation-observer` використовує process-global `parentSessionId` для terminal handoff slot: паралельна orchestrator-сесія може записати prognosis у slot іншої сесії.
3. Реальний runtime відрізняється від project config: глобальні DCP, snip, локальний Ponytail, agent/model overrides і доступні `build`/`plan` змінюють перевірений preset та permission surface.
4. Ticket/permission boundaries обходяться: неіснуючий або CLOSED ticket дозволяється, natural-language meta-task substring дає bypass, а shell/interpreter дозволи обходять path-scoped edit rules.
5. Зелені root-гейти створюють хибне відчуття повноти: OMO і plugin suites поза `pnpm test`, обидві зараз червоні; CI відсутній, а pre-push fail-open при вимкненому контейнері.

Рекомендований порядок: спочатку credential + handoff identity, потім закрити authorization/runtime-config boundary, після цього зробити один чесний aggregate CI gate, і лише тоді братися за application-level correctness та cleanup.

## Межі аудиту та методика

Аудит розділено на чотири незалежні лейни:

1. Якість, дієвість і повнота тестів та test gates.
2. Agent configuration, TypeScript plugins, workflow, permissions та session lifecycle.
3. Зайвий код, code smell, overengineering, spaghetti і поглиблення модулів.
4. Skills, MCP, plugins, commands, модифікації та їх фактична runtime-дієвість.

Оцінювалися три різні шари, які не можна змішувати:

- **Committed project state:** файли репозиторію на `ddcb2a2be920`.
- **Global user state:** `/home/mimic/.config/opencode/*`, який не комітиться в репозиторій, але реально merge-иться OpenCode.
- **Effective runtime:** результат `opencode debug agent`, `opencode agent list`, MCP/CLI probes і запущений `poetry-dev`.

Відсутність внутрішнього consumer не вважалася автоматичною підставою видалити architecture-declared public seam. Такі випадки позначено як design-gated, а не як безпечний cleanup.

## Стан перевірок

| Перевірка | Результат | Що насправді доводить |
|---|---:|---|
| `make test-config` | exit 0 | Static JSONC, agent-name, skill-frontmatter, handoff/changelog/EBDV та частина config invariants зелені. |
| `make test-shell` | exit 0, 585/585 | Shell поведінка добре покрита, але runner попереджає про Bats 1.11.0 проти pin 1.14.0. |
| `pnpm test` | exit 0 | Лише 4 Turbo tasks і 124 product TS tests; visualizers, OMO, plugins, Python та shell сюди не входять. |
| Embedded OMO `bun test` | exit 1, 1366 pass / 1 fail | Лишається regression у видимості orchestrator display alias. |
| Plugin suite `bun test` | exit 1, 150 pass / 6 fail / 1 skip | Шість Linux/PowerShell notification tests падають; cleanup test skipped. |
| Query pytest | exit 1 | На host немає `pytest`; 71 query test не мають робочого gate. |
| Python Atlas import | exit 1 | Committed Python adapter не знаходить generated bindings. |
| `scripts/validate-plugin-loads.sh` | exit 1 | Validator hardcode-ить checkout `/home/qualt/Projects/...`. |
| Cold `make test-harness` probe | exit 2 | Harness потребує вже запущений `dev`, хоча `test-infra` ставить його перед smoke bring-up. |
| `make test-runtime-config` | exit 2 | Target, описаний у OpenSpec, досі відсутній. |
| `poetry-dev` health | `Up`, але `unhealthy` | `opencode --version` працює; healthcheck ламається на повторному `gosu dev` під `Config.User=1000:1000`. |

Повний `make test-infra` навмисно не запускався: він перебудовує/зупиняє shared stack. Cold-start defect був підтверджений без деструктивної зміни середовища.

---

## 1. Тести: якість, дієвість та ефективність

### High

#### T-H1. Немає CI, а pre-push дозволяє push без перевірок

- **Доказ:** `.github/workflows/` відсутній; `scripts/verify-pre-push.sh:79-81` повертає success, якщо dev container не запущений.
- **Наслідок:** достатньо зупинити Docker/Podman, щоб push пройшов без workspace, OMO, plugin і Python gates; remote replacement відсутній.
- **Що зробити:** додати required CI з workspace TS, OMO, plugins, shell/config і Python; local fail-open можна лишити лише як UX-компроміс.
- **Статус:** still open. Пов’язано з DIA-260827-gt8l «no enforced CI and pre-push gate fails open».

#### T-H2. `test-infra` не здатний стартувати з холодного стану

- **Доказ:** `Makefile:141-144,303-305` запускає container-dependent `test-harness` до `scripts/test-docker-smoke.sh`; `scripts/__tests__/harness-scenario-replay.bats:30-37` викликає `docker compose exec`; cold probe завершився exit 2, 3/3 scenarios failed: `service "dev" is not running`.
- **Наслідок:** задокументований full infra gate не bootstrap-ить власні prerequisites.
- **Що зробити:** піднімати stack до harness або виконувати harness після єдиного smoke bring-up; teardown захистити `EXIT` trap.
- **Статус:** new regression.

#### T-H3. Root tests не запускають OMO, а його suite червона

- **Доказ:** `pnpm-workspace.yaml:1-3` не включає embedded OMO; прямий `bun test` дав 1366 pass / 1 fail. Regression знаходиться в `.opencode/oh-my-opencode-slim/src/agents/display-name.test.ts:190-192` та cloning logic `src/agents/index.ts:670-678`.
- **Наслідок:** `pnpm test` і pre-push можуть бути зеленими, поки user-visible orchestrator alias зникає.
- **Що зробити:** виправити visible alias cloning; додати OMO tests і typecheck до aggregate gate/CI.
- **Статус:** still open; DIA-260827-6wvm «embedded OMO suite excluded from root tests hides orchestrator alias regression».

#### T-H4. Plugin behavioral suite червона і не є push-gate

- **Доказ:** прямий run: 150 pass / 6 fail / 1 skip; failures у `.opencode/plugins/__tests__/needs-input-observer.dia189.test.mjs:422-505`; `scripts/verify-pre-push.sh:97-103` не виконує повний fast plugin suite.
- **Наслідок:** lifecycle, notification та state-machine regressions не блокують push, а `test-infra` прогнозовано червоний на Linux.
- **Що зробити:** в тестах ін’єктувати Windows/WSL availability замість припущення про `powershell.exe`; прибрати skip; додати fast plugin target до pre-push/CI.
- **Статус:** still open; DIA-260827-36ht «plugin behavioral gate is red and missing from pre-push».

#### T-H5. Python Atlas adapter поза lint/test gates

- **Доказ:** `packages/phonetics-core/src/atlas/load_atlas.py:43-316` — 316 рядків runtime-коду; `scripts/verify-python.sh:37-38` його не перевіряє; Python test target відсутній.
- **Наслідок:** mmap lifetime, corruption handling, Unicode normalization та TS/Python parity можуть ламатися непомітно.
- **Що зробити:** оформити Python adapter як installable artifact, додати import/load/corruption fixtures та cross-language parity test до Python/CI gate.
- **Статус:** still open; DIA-260827-48iw «Python phonetics-core atlas loader has no test or lint gate».

### Medium

#### T-M1. Routing-order tests копіюють production logic і не підключені до gate

- **Доказ:** `.opencode/scripts/__tests__/routing-order-gate.test.mjs:23-90,374-455` містить копію regex/decision logic; production `.opencode/plugins/delegation-observer.ts:3267-3346` уже має `dcp.jsonc`, а копія ні; `Makefile:194-215` suite не запускає.
- **Наслідок:** тест може лишатися зеленим після divergence з production.
- **Що зробити:** винести pure helpers або тестувати реальний hook; wire у `make test-config`.
- **Статус:** still open; DIA-260827-uv «routing-order regression suite copies logic and is orphaned».

#### T-M2. Query tests не мають середовища й містять слабкі assertions

- **Доказ:** `.opencode/scripts/test_query_web.py:464-465,495-524`; CLI tests приймають `0` або `1` і взаємно різні payload encodings; direct pytest падає через відсутній module.
- **Наслідок:** exit-code, escaping та request regressions можуть пройти непомітно.
- **Що зробити:** окремий pytest environment, mocked HTTP/subprocess seam, точні exits і payloads, підключення до CI.

#### T-M3. Product coverage концентрується на formatting і scaffold imports

- **Доказ:** `apps/author-studio/src/stores/example-store.test.ts:1-3`, `apps/api-server/tests/test_auth.py:4-24`, `packages/analytics-pipeline/tests/test_smoke.py:4-27`; visualizer packages не мають test scripts.
- **Наслідок:** scheduling/error recovery, Unicode tokenizer behavior, editor lifecycle, mounted UI та visualizer teardown не мають сигналу.
- **Що зробити:** додавати behavior tests на реальних seams, а не загальну line-coverage ціль.

#### T-M4. Bats runner не відтворюваний

- **Доказ:** `scripts/__tests__/bats-wrapper.sh:81-90,138-153`; vendor — 1.11.0, pin — 1.14.0; mismatch лише warning; довільний system `bats` має пріоритет без version check.
- **Наслідок:** 585 зелених тестів можуть мати різну семантику на двох машинах.
- **Що зробити:** enforce exact version або завжди використовувати immutable vendored/container runner.

#### T-M5. `test-infra` не гарантує teardown після Python failure

- **Доказ:** `Makefile:141-144` — послідовний recipe без enclosing trap; smoke може залишити stack up.
- **Наслідок:** failure змінює стан наступних тестів.
- **Що зробити:** one-shell recipe з `EXIT` trap і збереженням початкового exit code.

#### T-M6. Turbo test cache не інвалідовується при зміні test config

- **Доказ:** `turbo.json:21-27` inputs не включають `vitest.config.ts` і `tsconfig*.json`; весь root run був replayed from cache.
- **Наслідок:** зміна test environment може повторно використати stale green result.
- **Що зробити:** `$TURBO_DEFAULT$` або явні config inputs; альтернативно вимкнути caching для test.

#### T-M7. Один cleanup test навмисно skipped

- **Доказ:** `.opencode/plugins/__tests__/empty-result-detection.test.mjs:538-555`; plugin run — 1 skip.
- **Наслідок:** process-lifetime Set cleanup може регресувати без сигналу.
- **Що зробити:** narrow test seam або behavioral reuse-session test.

### Low

#### T-L1. Документація називає `pnpm test` «all tests»

- **Доказ:** `docs/onboarding.md:43-50,290-299`.
- **Наслідок:** developer бачить exit 0, хоча OMO/plugins червоні й Python не запускається.
- **Що зробити:** назвати команду «workspace JS tests» і документувати один canonical aggregate gate.

### Сильні сторони тестів

- Shell suite має широкий negative-path coverage і зараз 585/585.
- OMO suite велика та поведінкова: 1367 тестів, лише одна чітка regression.
- Plugin tests працюють на реальних hook surfaces: circuit breaking, apoptosis, handoffs, reload dedupe, ticket gates.
- Editor formatting має 91 test case; TS Atlas loader — 24 focused cases.
- `make test-config` справді покриває багато structural invariants і зараз зелений.
- Попередній stuck-failed apoptosis regression тепер має реальний hook-level test; targeted history 16/16.

---

## 2. Agents, TypeScript plugins, workflow та permissions

### Critical

#### W-C1. Parallel orchestrator sessions можуть пошкодити handoff slots

- **Доказ:** `.opencode/plugins/delegation-observer.ts:1131,3591-3593,4475-4476` зберігає першу task-caller session у process-global `parentSessionId`, а terminal handoff вибирає її перед `context.sessionID`. `.opencode/plugins/__tests__/parallel-handoff.test.mjs:596-625` фактично закріплює unsafe precedence.
- **Сценарій:** session A першою викликає `task`; session B пізніше пише terminal handoff; B архівує/перезаписує slot A та pointer отримує неправильну identity.
- **Що зробити:** slot identity завжди брати з trusted `context.sessionID`; root-session state тримати per-session, не process-global.
- **Статус:** still open; DIA-260827-y9n9 «critical cross-session handoff corruption via process-global parentsessionid».

### High

#### W-H1. Universal ticket gate дозволяє неіснуючі й CLOSED tickets

- **Доказ:** `.opencode/plugins/delegation-observer.ts:3074-3109` перевіряє лише filename existence; not found генерує warning і продовжує; status не читається.
- **Наслідок:** fabricated DIA ID або CLOSED ticket стає формальною «авторизацією» engineering work.
- **Що зробити:** exact lookup через єдиний ticket scanner, вимагати OPEN status, fail closed на scan failure/not found.
- **Статус:** still open; DIA-260827-mgfv «high universal ticket gate allows nonexistent and closed tickets».

#### W-H2. Shell та interpreters обходять path-scoped permissions

- **Доказ:** researcher/resource-manager можуть `curl -o`, `wget -O` і redirection (`.opencode/opencode.jsonc:493-500,595-601`); coder має `node *`, `bun *`, `python3 *` (`:337-342`); section-2.5 edit gate явно не перехоплює bash (`delegation-observer.ts:3114-3124`).
- **Наслідок:** lane із `edit: knowledge/*` може записати будь-де; coder може змінити `.opencode/` в обхід AI-specialist gate.
- **Що зробити:** path-validating fetch/write adapters; protected-path shell gate; прибрати broad interpreters там, де вони не потрібні.
- **Статус:** still open; DIA-260827-ft3z «high shell permissions bypass write scopes via curl wget redirection».

#### W-H3. Natural-language meta-task bypass надто широкий

- **Доказ:** `.opencode/plugins/delegation-observer.ts:2974-2995` шукає substring `create ticket`, `procedural authorization`, `meta-task` тощо.
- **Наслідок:** звичайний prompt на кшталт `do not create ticket` або injected text пропускає DIA-217 resolution.
- **Що зробити:** лишити exact `[META-TASK]` marker, перевіряти target lane й дозволену operation; natural-language substrings прибрати.
- **Статус:** new.

#### W-H4. Reviewer не може отримати diff, який зобов’язаний рев’ювати

- **Доказ:** `.opencode/opencode.jsonc:292-298` забороняє reviewer bash; prompt в `.opencode/oh-my-opencode-slim.jsonc:1634-1635` вимагає `git diff`, `git log` та ref resolution.
- **Наслідок:** reviewer може дивитися current files замість fixed-point delta й пропустити regression.
- **Що зробити:** narrow read-only git-diff/log tool або обов’язковий immutable diff artifact у dispatch.
- **Статус:** still open; DIA-260827-4q3h «high reviewer cannot acquire its required diff bash denied».

### Medium

#### W-M1. Model routing має кілька суперечливих джерел

- **Доказ:** active preset `promo` (`.opencode/oh-my-opencode-slim.jsonc:3`) маршрутизує analyzer-escalated на DeepSeek (`:1306-1314`), AGENTS.md і `knowledge/model-registry.yaml:167-171` називають GPT-5.6 Luna; reviewer preset і registry теж розходяться.
- **Наслідок:** quota/cost/capability policy не відповідає runtime.
- **Що зробити:** один generated routing source + effective-runtime validation.
- **Статус:** still open; DIA-260827-8la4 «medium model routing sources disagree registry vs prompt vs runtime».

#### W-M2. Narrow roles мають зайві повноваження

- **Доказ:** resource-manager має unrestricted `task: allow` (`.opencode/opencode.jsonc:586-602`); designer не має permission block (`:503-506`); memory-manager обмежує лише edit (`:518-528`) і успадковує глобальні можливості.
- **Наслідок:** вузька роль може делегувати arbitrary writer або писати поза ownership через shell.
- **Що зробити:** explicit deny-first blocks; resource-manager task map лише researcher/conspecter.
- **Статус:** DIA-260827-ic3r та DIA-260827-ld2l лишаються open.

#### W-M3. Паралельні permission asks гублять visibility

- **Доказ:** waiting entry keyed by session (`needs-input-observer.ts:282`); будь-яка одна reply викликає `clear(sessionID)` (`:1307-1321`); renderer не показує persisted `permissions` (`scripts/ticker-render.sh:41-49`).
- **Наслідок:** друга незакрита permission зникає з ticker/compaction view.
- **Що зробити:** key by request ID або clear session лише коли pending set порожній; render pending permissions.
- **Статус:** still open; DIA-260827-gnsv «medium concurrent permission asks lose ticker visibility».

#### W-M4. `lane_id` може вийти за handoff directory

- **Доказ:** raw identity входить у `join()` на `delegation-observer.ts:1709,1729-1731,1765`; caller-provided `lane_id` стоїть перед trusted context на `:4475-4476`.
- **Наслідок:** `../` може перезаписати session state поза `handoffs/`.
- **Що зробити:** тільки runtime session ID; anchored safe-ID grammar; resolved-path containment.
- **Статус:** still open; DIA-260827-5blh «medium handoff identity permits path traversal».

#### W-M5. Routine idle telemetry маскується під semantic handoff

- **Доказ:** `delegation-observer.ts:4012-4030` пише `event_type: handoff` без prognosis/slot; `scripts/session-log:67-79` показує його як handoff.
- **Наслідок:** recovery consumer не відрізняє batch completion від terminal prognosis.
- **Що зробити:** окремий `delegation_batch_complete`; `handoff` резервувати для slot-producing terminal event.
- **Статус:** still open; DIA-260827-ce63 «medium mechanical idle rows masquerade as handoffs».

#### W-M6. Plugin-load validator прив’язаний до checkout колеги

- **Доказ:** `scripts/validate-plugin-loads.sh:16,20` hardcode-ить `/home/qualt/Projects/poetry-platform`; локальний run exit 1.
- **Наслідок:** Bun-loader regression guard не працює ні тут, ні в `/workspace`.
- **Що зробити:** repo root із location script, canonical file URL, test fixture для двох checkout paths.
- **Статус:** new.

#### W-M7. Effective runtime config gate досі не реалізований

- **Доказ:** `openspec/changes/runtime-config-test/tasks.md:81-95` описує target; `Makefile:194-220` його не має; `make test-runtime-config` exit 2.
- **Наслідок:** static tests не бачать global merge, plugin duplication, model shadowing і built-in agents.
- **Що зробити:** завершити T1/T2 slices з clean-home і real-home fixtures та запускати у container CI.
- **Статус:** still open; DIA-260821-n8sq «add runtime config test make test-runtime-config in clean home».

#### W-M8. Dev healthcheck дає хибний `unhealthy`

- **Доказ:** `Dockerfile.dev:349-350` запускає `gosu dev opencode --version`; running container має `Config.User=1000:1000`, тож `gosu` падає `operation not permitted`; прямий `opencode --version` повертає 1.18.18.
- **Наслідок:** automation і developer сприймають здоровий OpenCode як broken stack.
- **Що зробити:** healthcheck запускати прямо як configured user; після rebuild перевірити Fedora Podman і WSL Docker.
- **Статус:** still open; DIA-260827-wvev «dev container healthcheck unhealthy: gosu not in dev PATH, use opencode --version directly». Фактична причина ширша за назву ticket: повторний privilege drop, а не лише PATH.

### Сильні сторони workflow

- Orchestrator dispatch має named allow-list і `*: deny`.
- AI-auditor має повний explicit read-only block.
- Capability token використовує випадковий HMAC secret, expiry і timing-safe verification.
- Handoff write path використовує temp/fsync/rename, archive-on-overwrite і terminal-status filtering.
- Observer reload dedupe та permission watchdog мають суттєве behavioral coverage.
- `make test-config` перевіряє agent-name lockstep, EBDV, JSONC і багато project policy invariants.

---

## 3. Зайвий код, smells, overengineering і correctness

### High

#### C-H1. Formatting filter руйнує CodeMirror transaction semantics

- **Доказ:** `packages/editor-engine/src/view/opusFormattingFilter.ts:282-295` замінює transaction на `{changes, selection}` з одним cursor.
- **Відтворення:** modified transaction втратив effects, `scrollIntoView` і `userEvent`; mixed two-cursor edit скоротив ranges з 2 до 1.
- **Наслідок:** extensions втрачають StateEffects/annotations, explicit scroll зникає, multi-cursor editing мовчки ламається.
- **Що зробити:** map усі selection ranges через final `ChangeSet`; зберегти effects, annotations, user event і scroll; додати interface regression tests.
- **Статус:** prior finding still open.

#### C-H2. Equal-revision worker overwrite порушує user priority

- **Доказ:** `packages/editor-engine/src/orchestrator/Orchestrator.ts:24-33` відкидає лише нижчу revision і не зберігає provenance/priority; test `Orchestrator.test.ts:46-59` закріплює equal overwrite.
- **Наслідок:** user або MarkPoetry write на revision N може бути перезаписаний worker result тієї ж revision.
- **Що зробити:** поглибити Orchestrator Module: Interface приймає revision + source/priority і порівнює `(revision, priority)`; додати equal-revision user-vs-worker test.
- **Статус:** prior finding still open.

#### C-H3. `PoetryDataContract` типізує schema document, не payload instance

- **Доказ:** `packages/data-contracts/src/index.ts:9-13` робить `typeof contract`; отриманий type має `$schema`, `properties`, `required`, а не instance fields. Tests `src/index.test.ts:8-59` перевіряють лише schema object.
- **Наслідок:** центральний cross-app Seam не дає compile-time type для реальних poems; consumers підуть у `any` або дублювання.
- **Що зробити:** окремо export schema document і generated/inferred instance type + validator/serializer. Це design-gated: `architecture.md:736-808` описує Protobuf/Canonical JSON target, а реалізація — Draft-07 JSON Schema.
- **Статус:** prior finding still open.

#### C-H4. Duplicate line IDs псують Map/order invariant

- **Доказ:** `packages/editor-engine/src/state/PoetryState.ts:16-25` перезаписує Map entry, але додає той самий ID в `order`; `removeLine()` на `:29-31` видаляє всі дублікати.
- **Наслідок:** display order містить кілька однакових ID, що посилаються на один atom; попередній atom стає orphaned для state.
- **Що зробити:** explicit uniqueness invariant: reject duplicate або upsert без повторного append; додати duplicate/removal tests.
- **Статус:** prior finding still open.

### Medium

#### C-M1. Python Atlas adapter не імпортується зі fresh checkout

- **Доказ:** `load_atlas.py:50-76` шукає `dist/python`; committed bindings лежать у `scripts/generated/python`; `analytics-pipeline/pyproject.toml:5-9` не оголошує `flatbuffers`, `numpy`, `panphon` чи adapter dependency. Direct import дав `ImportError`.
- **Наслідок:** architecture-declared Python Adapter не працює; це не safe deletion, бо cross-language seam є цільовим.
- **Що зробити:** один canonical generated path, installable Python package, declared deps та clean-checkout import/load test.

#### C-M2. `.sha256` sidecar не містить SHA-256 binary

- **Доказ:** generator пише semantic content hash (`generate_phonetic_atlas.py:110-135,442-445`); test `load-atlas.test.ts:266-282` порівнює sidecar лише з metadata всередині binary. Actual binary SHA починається `7e59bf37`, sidecar — `e8e96f21`.
- **Наслідок:** tampering довільних feature bytes може не змінити ні metadata, ні sidecar comparison; назва та коментарі обіцяють гарантію, якої немає.
- **Що зробити:** sidecar = digest raw bytes; semantic provenance hash лишити окремим чітко названим полем.

#### C-M3. Atlas codegen fail-open і розсіює generated artifacts

- **Доказ:** `packages/phonetics-core/scripts/codegen.js:69-87` ловить кожну language failure і все одно завершується success; TS генерується в `dist/ts`, runtime імпортує `src/atlas/generated`; Python має ще третю копію в `scripts/generated/python`; build не залежить від codegen (`turbo.json:12-19`).
- **Наслідок:** stale/часткові adapters кешуються як успішна генерація; schema, code і binary не мають Locality.
- **Що зробити:** один fail-closed generation Module з atomic canonical outputs і verification. C++ target видаляти лише після design disposition.

#### C-M4. Visualizer modules shallow і не володіють lifecycle повністю

- **Доказ:** 2D приймає unused `any` Orchestrator і має empty `update()` (`visualizer-2d/src/interactive/index.ts:8,47-54`); `VisualizerContainer.vue:31-50` не викликає `destroy`; 3D приймає unused `any`, а unmount dispose-ить renderer, але не geometry/material (`visualizer-3d/src/index.ts:7,32-40,56-59`).
- **Наслідок:** Interface витікає whole Orchestrator без Leverage; remount може залишати GPU resources; SSR/interactive малюють placeholder, не contract data.
- **Що зробити:** зберегти visualizer Seam, але поглибити його навколо typed contract snapshot + scene model + complete lifecycle ownership.

#### C-M5. Author Studio змішує target UI з unreachable Quasar demo scaffold

- **Доказ:** `routes.ts:3-8` оголошує `IndexPage`, але `MainLayout.vue:1-27` не має `router-view`; `IndexPage.vue`/`ExampleComponent.vue` містять demo/todo; i18n встановлено без `$t()` usage.
- **Наслідок:** суперечлива app structure, зайві dependencies/assets, хибна entry surface.
- **Що зробити:** безпечно видалити unreachable demo page/component/assets та unused i18n wiring. Empty workers/API/analytics target seams — design-gated, не automatic deletion.
- **Статус:** publishing-platform і throwing stress-lang-core scaffolds уже правильно видалені; Author Studio residue лишився.

#### C-M6. `delegation-observer` — надто широкий Module

- **Доказ:** `.opencode/plugins/delegation-observer.ts` має 4985 рядків і в одному closure поєднує ticket authorization, lifecycle/apoptosis, handoff persistence, routing policy, formatting, telemetry, context budgeting та tools.
- **Наслідок:** control-flow взаємодії важко локально довести; попередні bugs уже виникали саме між gates і lifecycle paths.
- **Що зробити:** не дробити заради розміру. Виділити глибокі pure Modules на реальних seams: ticket authorization, handoff identity/store, lifecycle state machine, routing policy; plugin лишити Adapter-ом до OpenCode hooks.

### Low

#### C-L1. CommandBus обслуговує лише no-op producer

- **Доказ:** `opusDecorator.ts:33-40` — єдиний production producer, `execute: () => {}`; `command-bus.ts:16-40` усе одно сортує queue і запускає flush.
- **Наслідок:** document/viewport updates роблять зайву роботу та маскують реальне formatting flow.
- **Що зробити:** safe deletion — no-op enqueue. Сам public CommandBus Seam видаляти лише після design decision.

#### C-L2. Editor містить очевидні redundant paths/debug machinery

- **Доказ:** `tokenizer.ts:24-100` експортує punctuation catalog, який `tokenize()` не читає; `TokenType.typographical` не emit-иться; `opusFormattingFilter.ts:205-224` дублює cursor loop; `:235-286` має непідтверджену allocation micro-optimization; `OpusEditorView.ts:85-103` log-ить кожен update і публікує misspelled `window.__edotorView`.
- **Наслідок:** додаткові branches та undocumented global без Leverage.
- **Що зробити:** після semantic regression tests видалити unused table/type member, debug global/logging і спростити micro-optimization.

### Сильні сторони application code

- Editor 96/96, data-contracts 2/2 і TS Atlas 24/24 focused tests зелені.
- TS Atlas Adapter перевіряє `PHAT`, нормалізує IPA до NFC і відрізняє corruption від miss.
- Дві committed Atlas binaries зараз byte-identical; проблема саме в integrity contract, не copy drift.
- Orchestrator коректно відкидає strictly older revisions і unknown IDs.
- MainLayout створює Orchestrator у composition root.
- 3D view dynamically imported, animation frame cancel-иться, renderer частково dispose-иться.
- Recent cleanup коректно прибрав empty publishing platform та throwing stress-lang package, залишивши їх як documented future seams.

---

## 4. Skills, MCP, plugins, commands і фактичне використання

### Critical

#### S-C1. Plaintext Context7 credential у merged global config

- **Доказ:** `/home/mimic/.config/opencode/opencode.jsonc:10` містить непорожнє literal credential, не `{env:...}`. Значення у звіті навмисно не відтворюється. Project config уже використовує безпечну env-підстановку на `.opencode/opencode.jsonc:739-744`.
- **Наслідок:** config dump, backup, support log або read access може ексфільтрувати ключ.
- **Що зробити негайно:** revoke/rotate; замінити literal на `{env:CONTEXT7_API_KEY}`; перевірити історію логів/backups.
- **Статус:** prior finding still open; це global user-state incident, не committed project secret.

### High

#### S-H1. Global DCP/snip/Ponytail забруднюють project runtime

- **Доказ:** `/home/mimic/.config/opencode/opencode.jsonc:4` вмикає `opencode-snip@latest`, `@tarquinen/opencode-dcp@latest` і local Ponytail; project окремо вмикає Ponytail на `.opencode/opencode.jsonc:713-718`; `opencode debug` показує `snip binary not found`; stale DCP config лишився в `~/.config/opencode/dcp.jsonc`.
- **Наслідок:** DCP, який вважався видаленим, активний; Ponytail hooks/skills дублюються; `latest` створює supply-chain drift.
- **Що зробити:** прибрати global snip/DCP/local Ponytail і stale DCP config; лишити один project-pinned Ponytail.
- **Статус:** project-level removal працює, але effective merge still broken.

#### S-H2. `/tdd-cycle` порушує RED/GREEN instance separation

- **Доказ:** `.opencode/opencode.jsonc:760-764` напряму запускає одного `coder`, template виконує RED і GREEN; AGENTS.md та promo prompt вимагають різні coder instances.
- **Наслідок:** test author реалізує під власні тести й обходить DIA-175 independence gate.
- **Що зробити:** command owner = orchestrator; окремі RED і GREEN dispatches з campaign ticket.

#### S-H3. Global model/agent blocks shadow active `promo` preset

- **Доказ:** global config задає root model і overlapping agents; runtime resolve-ить orchestrator/reviewer на global DeepSeek V4 Pro замість promo Hy3/Muse (`.opencode/oh-my-opencode-slim.jsonc:1154-1160,1230-1235`). Legacy architect/tester/writer також доступні.
- **Наслідок:** перевірені cost/quota/model-diversity та role contracts не є фактичними.
- **Що зробити:** винести global profiles із project runtime або прибрати overlapping agent/model blocks; обов’язковий resolved-config test.

#### S-H4. Built-in `build` і `plan` залишаються write-capable обходом

- **Доказ:** `.opencode/opencode.jsonc:127-133` disable-ить лише `explore`/`general`; `opencode agent list` показує `build (primary)` і `plan (primary)`; effective build успадковує broad edit/bash.
- **Наслідок:** user/command може перейти в lane поза orchestrator ticket/delegation rules.
- **Що зробити:** disable або жорстко restrict; validate resolved agent inventory.

#### S-H5. OMO version/source drift не закритий

- **Доказ:** project runtime 2.2.17 (`.opencode/opencode.jsonc:709-718`), Docker 2.2.14 (`tools/opencode-docker/config/opencode.json:24-27`), embedded metadata 2.2.11 (`.opencode/oh-my-opencode-slim/package.json:2-5`), `REFERENCE-ONLY.md:1-3` стверджує 2.2.13.
- **Наслідок:** host, container і audited vendored code можуть поводитися по-різному; документація вводить в оману.
- **Що зробити:** одна source-of-truth policy, sync pins/docs, effective version assertion у runtime gate.

#### S-H6. OpenSpec commands написані під інший tool/runtime contract

- **Доказ:** `opsx-apply.md:18` використовує `AskUserQuestion`, `opsx-continue.md:32` — `TodoWrite`, `opsx-archive.md:62` — Claude-style `Task ... general-purpose`; commands не мають agent binding, а default orchestrator не має потрібних bash/edit rights. Host не має `openspec`, container має 1.7.0.
- **Наслідок:** commands зависають, hallucinate tools або тиснуть на orchestrator обійти policy.
- **Що зробити:** native OpenCode tool names/schema, project agent names, explicit owning agent; host/container functional smoke.

#### S-H7. Reviewer `book-rag` contract неможливо виконати

- **Доказ:** promo дає reviewer `book-rag` (`oh-my-opencode-slim.jsonc:1237-1241`), reviewer bash deny (`opencode.jsonc:292-297`), skill вимагає script/command execution (`book-rag/SKILL.md:38-43,172-174`).
- **Наслідок:** reviewer не може виконати mandatory grounding і може вигадувати його результат.
- **Що зробити:** прибрати mandatory RAG або дати dedicated read-only retrieval tool.

#### S-H8. `teaching` призначений ролям без потрібних capability

- **Доказ:** skill вимагає Python RAG (`teaching/SKILL.md:38-47`) та описує writes (`:123-134`); promo призначає його architector, openspec-plan, ai-specialist, ai-auditor, які deny-ять bash/edit або дозволяють лише `openspec *`.
- **Наслідок:** mandatory Step 0 неможливий; persistence суперечить lane ownership.
- **Що зробити:** розділити read-only pedagogy і persistence або надати вузький RAG tool лише відповідним ролям.

### Medium

#### S-M1. Playwright skill починається з неіснуючого executable

- **Доказ:** `playwright-browser/SKILL.md:34-36,58-72` рекомендує `playwright-cli`; у container його немає; `npx --no-install @playwright/cli` падає. Fallback `playwright cli` / `npx playwright cli` на `:394-403` працює.
- **Наслідок:** primary recipes падають на першій команді.
- **Що зробити:** стандартизувати всі examples на реально provisioned CLI або встановити/pin exact executable.
- **Статус:** partially improved: fallback уже робочий.

#### S-M2. Skill validator перевіряє форму, але не capability compatibility

- **Доказ:** `.opencode/scripts/validate-skills.sh:11-22` перевіряє frontmatter/name/description/activation/license; current run — 26 pass, 40 warnings. Усі 20 explicit refs зараз існують, але dangling preset ref або impossible bash requirement не hard-fail-ить.
- **Наслідок:** green config не гарантує виконуваність skill.
- **Що зробити:** cross-reference preset arrays, command names, agent permissions та required binaries у clean runtime fixtures.

#### S-M3. Orchestrator отримує wildcard усіх skills

- **Доказ:** `.opencode/oh-my-opencode-slim.jsonc:1162-1168`; effective runtime бачить project, global і два Ponytail roots.
- **Наслідок:** delegation-only role отримує browser/RAG/implementation prompts, trigger collisions і зайвий context surface.
- **Що зробити:** explicit minimal orchestration allow-list; implementation skills deny.

### Low

#### S-L1. `book-rag` посилається на `@rag` замість `/rag`

- **Доказ:** `.opencode/skills/book-rag/SKILL.md:41`; реальна command surface — `.opencode/commands/rag.md`.
- **Наслідок:** agent може не знайти command і перейти до забороненого bash fallback.
- **Що зробити:** виправити spelling і додати command-reference validator.

### Фактична usage matrix

| Surface | Project intent | Effective runtime | Оцінка |
|---|---|---|---|
| OMO | `promo`, project 2.2.17 | Host 2.2.17, але global models shadow roles; Docker 2.2.14 | Partial |
| Plugins | OMO, project Ponytail, envsitter, local observers | Додатково global local Ponytail, snip, DCP | Broken merge |
| Skills | 20 explicit refs + orchestrator wildcard | Усі refs resolve; duplicate Ponytail roots visible | Partial |
| TDD | `tdd-craftsman`, independent RED/GREEN | `/tdd-cycle` використовує одного coder | Broken |
| RAG | reviewer book-rag; teaching на кількох lanes | Частина lanes не може запустити mandatory bash | Broken |
| Playwright | coder/escalated/designer | Working fallback, wrong primary command | Partial |
| MCP | Context7, gh_grep, websearch | Live probes healthy | Working |
| OpenSpec | opsx suite + openspec-plan | Container CLI працює; command contracts/routing ні | Partial |
| Built-ins | orchestrator-only workflow | `build`/`plan` reachable | Unsafe |

### Сильні сторони skills/plugins

- Project Context7 config і Docker secrets використовують env/file substitution, не plaintext.
- Context7, gh_grep і researcher websearch на цьому fixed point були healthy; попередній MCP circuit finding resolved.
- Усі 20 explicit role skill references зараз resolve-яться.
- Promo routing явно задає models/skills/MCP per role.
- Local skill validator має корисні hard checks для frontmatter/name і duplicate trees.
- OpenSpec 1.7.0 та browser backends реально присутні в dev container.

---

## Що змінилося від попереднього аудиту

### Підтверджено виправленим або покращеним

- Observer registration dedupe реалізовано; `scripts/validate-observer-dedupe.sh` проходить.
- Stuck-failed apoptosis regression має реальний hook-level test.
- Project-level DCP/snip removal лишається правильним; проблема тепер локалізована у global user config.
- Усі 20 explicit skill references існують; dangling `simplify` references прибрані.
- MCP endpoints на цьому запуску healthy; попередні circuit-open incidents не відтворилися.
- Playwright fallback `playwright cli` працює.
- Empty publishing-platform і throwing stress-lang-core scaffolds видалені без стирання architecture-declared future seams.
- Project OMO bump до 2.2.17 застосовано, хоча cross-environment drift ще не закритий.

### Лишається відкритим

- Cross-session handoff identity corruption.
- Ticket existence/status authorization gap.
- Shell/path permission bypasses.
- Reviewer diff acquisition contradiction.
- Global config/plugin/model contamination.
- Embedded OMO та plugin suites поза root gate і червоні.
- Python Atlas adapter/gates, content integrity і codegen locality.
- CodeMirror transaction corruption, equal-revision priority і duplicate line IDs.
- Visualizer lifecycle/data seam та Author Studio demo residue.

### Нові або уточнені знахідки

- Cold-start ordering ламає `test-infra` до bring-up.
- Natural-language meta-task bypass надто широкий.
- `validate-plugin-loads.sh` hardcode-ить чужий absolute path.
- Turbo test cache inputs не включають test configs.
- Dev healthcheck падає через повторний `gosu` під already-unprivileged user.
- Global credential incident підтверджено без розкриття secret value.

## Архітектурні можливості поглиблення

1. **Handoff Store Module.** Один Interface: trusted session identity, slot containment, atomic write/archive/pointer. OpenCode hook — тонкий Adapter. Це дає максимальні Leverage і Locality для parallel-session correctness.
2. **Ticket Authorization Module.** Один parser/scanner/status policy для dispatch, config gate і bypass audit. Зараз authorization розмазаний по control flow і має суперечливі fail-open paths.
3. **Effective Runtime Config Module/Gate.** Clean-home + real-home resolution, plugin inventory, agent inventory, model/preset resolution, version pins. Це закриває найбільший розрив між reviewed file і фактичним runtime.
4. **Editor Orchestrator Module.** Revision + provenance + priority як одна state transition policy; caller не повинен вручну відтворювати precedence.
5. **Phonetic Atlas Artifact Module.** Schema → fail-closed generation → TS/Python adapters → raw-byte integrity → parity tests через один Interface.
6. **Visualization Scene Module.** Pure scene із `PoetryDataContract`; D3 interactive, SSR і Three.js стають окремими Adapters із повним lifecycle ownership.

## Пріоритетний remediation plan

### P0 — негайно

1. Rotate plaintext Context7 credential; прибрати його з global config/backups.
2. Виправити handoff identity: `context.sessionID` first/only, safe ID + containment, parallel-session regression.

### P1 — наступний security/reliability batch

3. Universal ticket gate: existing OPEN ticket або hard block; strict `[META-TASK]` capability; no natural-language bypass.
4. Закрити shell/interpreter path bypasses і permission over-grants.
5. Очистити global OpenCode profile: DCP, snip, duplicate Ponytail, overlapping models/agents; disable/restrict build/plan.
6. Дати reviewer безпечний immutable diff seam.

### P2 — чесні gates

7. Реалізувати `make test-runtime-config` для clean-home і merged runtime.
8. Додати required CI; включити OMO, plugins, shell/config і Python.
9. Полагодити cold-start `test-infra`, teardown trap, Linux plugin fixtures та OMO alias regression.
10. Виправити healthcheck і Bats/Turbo reproducibility.

### P3 — correctness та Module depth

11. CodeMirror transaction semantics, revision/priority і duplicate line invariant.
12. Payload type/validator для PoetryDataContract.
13. Consolidated fail-closed Atlas generation, Python packaging та actual byte integrity.
14. Typed visualization scene/lifecycle і safe deletion Quasar/editor residue.

## Фінальна оцінка

Це не «поганий setup»: у ньому вже більше governance і behavioral testing, ніж у типовому OpenCode repository. Проблема в тому, що policy surface виріс швидше, ніж єдині глибокі Modules та effective-runtime verification. Найбільший виграш дасть не додавання нових guards, skills або plugins, а скорочення кількості джерел правди й поглиблення чотирьох seams: handoff identity, ticket authorization, runtime config resolution та aggregate verification.

До виправлення P0/P1 не варто додавати Headroom, нові context plugins або ще один orchestration layer: merged runtime уже містить зайві DCP/snip/Ponytail hooks, а новий шар збільшить невизначеність. Спочатку зробіть runtime детермінованим і gates чесними; після цього compression plugin можна оцінювати на вимірюваних session-analytics/eval сценаріях.
