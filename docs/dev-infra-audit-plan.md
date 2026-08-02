# Dev Infrastructure Audit — Global Plan

Audit date: 2026-08-01
Status legend: `[x]` done · `[~]` in progress (own session) · `[ ]` pending

## ✅ What's done well (no action needed)

- **Docker-контейнер OpenCode** (`tools/opencode-docker/`): multi-stage build (3 stages),
  read-only rootfs, `--cap-drop=ALL`, non-root user, SHA256-pinned base image + installer,
  file-based secrets з `ALLOWED_SECRETS` whitelist, instance lock, healthcheck,
  `.dockerignore`, Xvfb + Playwright.
- **Monorepo tooling**: pnpm workspaces, Turborepo pipeline, `pnpm-lock.yaml`.
- **OpenCode config**: DCP config на 22+ моделі, MCP (context7 + gh_grep), команди, memory shelf.

## 🔴 Critical (C)

- [x] **C1 — docker-compose.yml + Dockerfile для сервісів** _(протестовано 2026-08-01)_
      Створено сесією «Комплексний аудит dev інфраструктури»: `docker-compose.yml`,
      `Dockerfile.dev`, `dev-entrypoint.sh`, `Makefile`, `docs/docker-dev.md`, `.env.example`,
      `.dockerignore`, `.devcontainer/`, `secrets/`.
      **Тест:** `up` → обидва healthy; рантайми на місці; postgres доступний; author-studio 200
      на :9000; secrets+Xvfb працюють після фіксу.
      **Виправлено:** додано `ENTRYPOINT ["/usr/local/bin/dev-entrypoint.sh"]` до `Dockerfile.dev`
      (раніше entrypoint ніколи не виконувався — secrets/Xvfb не стартували).
      **Відкрито:** (a) `docker compose exec` не бачить export-и entrypoint — секрети тільки в
      PID1; (b) `pnpm dev` запускає лише author-studio (publishing-platform без `dev`-скрипта,
      api-server — Python, не turbo).
      → закомітити результати.
- [x] **C2 — OMO slim в Docker** — `tools/opencode-docker/config/opencode.json` тепер містить
      envsitter-guard@0.0.4, opencode-telemetry@0.1.19, OMO slim (`file:///workspace/.opencode/oh-my-opencode-slim`)
  - gh_grep MCP. Перевірено у dev-контейнері: opencode 1.18.4, пакети плагінів у кеші,
    boss-агент (OMO slim) активний, telemetry DB пише.
- [x] **C3 — Два конфіги** — `.opencode/opencode.json` (agents, boss, кольори) +
      `.opencode/opencode.jsonc` (permissions, providers, mcp, plugin, commands) з перекриттям
      агентів, непередбачуване злиття. → об'єднані в один файл `opencode.jsonc` (model +
      agent modes/colors перенесені, `opencode.json` видалено). Валідовано у dev-контейнері.
- [x] **C4 — Різні імена агентів** — global OMO: `oracle/fixer/code-reviewer`; project OMO:
      `architector/coder/reviewer`. Плюс AGENTS.md використовує `explorer/oracle/fixer/...`.
      → узгодити неймінг (global vs project vs docs). _(2026-08-01: глобальне перейменування
      зроблено — `oracle→architector`, `fixer→coder`, `code-reviewer→reviewer`,
      `opencode-service→ai-specialist`, `explorer→code-navigator`, `librarian→researcher`,
      старі нативні імена у `disabled_agents`, `.md` промпти перейменовано, AGENTS.md §8
      оновлено. Лишилось проєктне доочищення: дублікат `librarian`+`researcher` у пресетах
      та `@web_scout` у промптах → див. M9)_
- [x] **C5 — Глобальні плагіни не зафіксовані** — у `~/.config/opencode/opencode.jsonc`
      6 з 7 плагінів без версій (`envsitter-guard`, `opencode-subagent-output`,
      `opencode-plugin-openspec`, `opencode-snip`, `opencode-telemetry`, `opencode-token-monitor`,
      `oh-my-opencode-slim`). → зафіксувати версії. _(2026-08-01: всі 7 зафіксовано —
      `@0.0.4/@0.1.4/@1.6.1/@0.1.19/@0.5.0/@2.2.8`, subagent-output → `#a9a163dff`.
      Версії звірені з кешем, JSON валідовано, CHANGELOG оновлено. Потрібен рестарт
      OpenCode для перевірки завантаження плагінів.)_
      _(2026-08-01 верифікація з @ai-specialist: `github:`-спека для subagent-output
      не працювала — репо без package.json, кеш порожній. Виправлено: файл
      `subagent-reporter.ts@a9a163dff` скопійовано у `~/.config/opencode/plugins/`
      (спосіб із README репо), `github:`-рядок прибрано з масиву; DCP
      (`opencode-dynamic-context-pruning`) випав під час C5 — повернуто як
      `@tarquinen/opencode-dcp@3.1.14`, щоб глобальний `dcp.jsonc` не був сиротою.)_
- [x] **C6 — Суперечність прав** — `practice-protected.md` класифікує `@ai_assist_specialist`
      як pure-analyst (read-only), але `opencode.jsonc` дає йому `edit: allow` + `bash curl/wget`.
      → приведено до реальності: `ai-assist-specialist` → `ai-specialist`, `edit: deny`,
      `task: deny`, `mode: subagent`, curl/wget залишено (read-only web research),
      футер-нотка в practice-protected.md.

- [x] **M9 — Проєктне доочищення C4** _(виконано 2026-08-01)_ — у проєктному
      `.opencode/oh-my-opencode-slim.jsonc` дублювалися ключі `librarian` і `researcher`
      у всіх 3 пресетах (форк аліасить `librarian→researcher`), а `orchestratorPrompts`
      посилалися на `@web_scout` (прибраний displayName). → злито в єдиний `researcher`
      (веб-MCP з librarian перенесено в researcher, де було `mcps: []`),
      `agents.librarian.displayName: web_scout` видалено, `@web_scout` → `@researcher`
      у 2 промптах. JSONC валідовано; у кожному пресеті рівно один `researcher`.

## 🟠 Significant (M)

- [ ] **M8 — Розділити спеціаліста на двох агентів** (нов. 2026-08-01)
      `ai-specialist` (раніше `ai-assist-specialist`) має стати двома агентами:
  1. **Менеджер ресурсів / куратор джерел** — шукає релевантні джерела з документаціями,
     кешує їх локально, кладе на власний memory-shelf, і на кожне джерело ставить
     **термін критичного огляду** — щоб періодично перевіряти, чи не з'явилися кращі
     рішення або зміни.
  2. **Спеціаліст** — вирішує всі питання, спираючись на **закешовані документації**;
     якщо потрібного джерела немає — робить запит **менеджеру ресурсів** на пошук нової.
     Коли менеджер ресурсів починає шукати: використовує `@researcher` і **одночасно**
     питає користувача, що той радить.

- [~] **M1 — `.devcontainer/devcontainer.json`** — створено сесією docker-аудиту
  (uses `docker-compose.yml`, service `dev`, extensions, forwardPorts). → закомітити разом з C1.
- [x] **M2 — coder без обмежень** _(виконано 2026-08-01)_ — `coder` в `opencode.jsonc` має
      `mode: subagent` без `permission` (на відміну від architector/analyzer/reviewer з усім
      `deny`). → рішення: **задокументувати намір, обмеження НЕ додавати** — coder є
      реалізатором, йому потрібні edit/bash (dev build, lint, tests) та task для підлеглих
      агентів; будь-який deny ламає його основну функцію. Намір задокументовано коментарем
      над блоком `coder` у `.opencode/opencode.jsonc`.
- [x] **M3 — gh_grep MCP в Docker config** — додано до `tools/opencode-docker/config/opencode.json`
      (https://mcp.grep.app).
- [ ] **M4 — «Привиди»** — `code-navigator` та `researcher` визначені в `opencode.json`
      (рядки 40-47), але ніколи не диспатчаться. → прибрати або задокументувати.
- [ ] **M5 — `ai-assist-sources.yaml`** — згадується у workflow, файл тепер знайдено:
      `.opencode/oh-my-opencode-slim/knowledge/ai-assist-sources.yaml`. → перевірити, що шлях
      у workflow збігається.
- [ ] **M6 — api-server не готовий до контейнеризації** — `apps/api-server/pyproject.toml`
      існує (FastAPI/asyncpg/SQLAlchemy), але окремого Dockerfile немає. Покривається `Dockerfile.dev`
      сесії docker-аудиту. → після C1 оцінити, чи потрібен окремий production Dockerfile.
- [~] **M7 — PostgreSQL ніде не визначений** — тепер визначений у `docker-compose.yml`
  (postgres:16-alpine, named volume `pgdata`). → закомітити разом з C1.

## 🟡 Minor (9)

- [ ] **m1 — `shamefully-hoist=true`** у `.npmrc` — антипатерн. Оцінити необхідність /
      задокументувати причину.
- [ ] **m2 — Порти не задокументовані** — тепер задокументовані у `docs/docker-dev.md`
      (9000/8000/3000). → перевірити, що `.env.example` і compose збігаються.
- [ ] **m3 — `references.shelf.path` вказує на директорію** — `.opencode/opencode.jsonc:149-152`
      вказує `.opencode` замість файлу. → поправити на `memory-shelf.yaml`.
- [ ] **m4 — Глобальний DCP порожній** — `~/.config/opencode/dcp.jsonc` має лише
      `maxContextLimit: "50%"`; project `.opencode/dcp.jsonc` має modelMaxLimits на 22+ моделі.
      → перенести/уніфікувати.
- [ ] **m5 — skills lock тільки на cli-review** — `.opencode/oh-my-opencode-slim/skills-lock.json`
      містить лише cli-review. → зафіксувати всі skills.
- [x] **m6 — `ai-assist-specialist` має `mode: primary` замість `subagent`**
      (`opencode.jsonc:58`) — суперечить ролі research-агента. → виправлено в C6:
      перейменовано в `ai-specialist`, `mode: subagent`.
- [x] **m7 — `opencode.jsonc` — синтаксис/відступи** — блок `ai-assist-specialist` має зламані
      відступи (рядки 56-70), `council` теж. → блок `ai-specialist` переформатовано в C6;
      `council` відступи — на черзі.
- [x] **m8 — AGENTS.md неймінг vs фактичні агенти** — таблиця в AGENTS.md
      (`explorer/librarian/oracle/...`) розходиться з реальними іменами. → синхронізовано
      в C4 (глобальний §8 + проєктний AGENTS.md без старих імен).
- [ ] **m9 — дублювання агентів у системному промпті** — `explorer` vs `code_explorer`,
      `oracle` vs `code_architect` тощо. → уніфікувати.

## 🎯 Порядок роботи

Робота ведеться сесія за сесією, викреслюючи пункти по черзі. C1/M1/M7 вже обробляє окрема
сесія docker-аудиту — після її завершення закомітити результати і звірити їх з цим планом.

1. C1 (окрема сесія) → закомітити результати
2. C2 — OMO slim + envsitter + telemetry в Docker config (1 год)
3. C3 — об'єднати `opencode.json` + `opencode.jsonc` (1 год)
4. C4 — узгодити імена агентів (global vs project) — **виконано 2026-08-01**
5. C6 — узгодити practice-protected.md з реальними правами — **виконано 2026-08-01**
6. C5 — зафіксувати версії глобальних плагінів — **виконано 2026-08-01**
7. M2, M4–M7, M8, m1–m9 — по одному в нових сесіях
