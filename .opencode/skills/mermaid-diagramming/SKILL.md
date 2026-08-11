---
name: mermaid-diagramming
description: 'Best practices for Mermaid.js diagrams — tier-based declaration ordering, subgraph grouping, classDef styling, shape conventions, node limits (7-15), edge labeling, C4 and sequence diagram rules. Invoke when creating or improving architecture, flow, or analysis diagrams.'
compatibility: opencode
metadata:
  audience: developers
  workflow: visualization-and-diagramming
---

# Mermaid Diagramming Best Practices

**When to use Mermaid vs console text diagrams:**
- **Use Mermaid** for diagrams with >7 elements, C4 architecture boundaries, sequence diagrams with alt/par/loop, or when the output will be rendered by VS Code/GitHub/docs site.
- **Use console text** (Rich tree, PHART, hascii, ASCII inline via the `console-charting` skill) for ≤7 elements, quick sketches in chat/terminal, simple hierarchies, or any plain-text context.
- **Rule of thumb:** If it needs subgraphs, boundaries, or branching with >2 paths → Mermaid. If it fits in one terminal screen as a tree or ASCII box → console text.

## Diagram Type Selection

| To show... | Use |
|---|---|
| System architecture, boundaries, tiers | C4 Context / Container |
| Process flow, decisions, branching | `flowchart` |
| Interactions over time between actors/systems | `sequenceDiagram` |
| States and transitions | `stateDiagram-v2` |
| Data model and relationships | `erDiagram` |

## Layout Direction

- **`flowchart TB` (top-down):** hierarchies, decision trees, layered architectures
- **`flowchart LR` (left-right):** pipelines, data flow, sequential processes
- Prefer TB as default — most readers scan top-to-bottom

## Declaration Order (Critical for Readability)

**Declare ALL elements in visual order BEFORE any relationships.** The layout engine positions nodes as it encounters them. Random order = crossing edges.

### C4 Diagrams — Mandatory Order
```
1. Person(...)             — all actors
2. System(...)             — the system being described
3. System_Boundary(...)    — system boundaries containing:
   - Container(...)        — in tier order within boundary
   - ContainerDb(...)      — databases
4. System_Ext(...)         — all external systems
5. Rel(...)                — all relationships LAST
```

### Flowcharts — Order Rules
```
1. Actors / external triggers (topmost/leftmost)
2. Internal systems in flow order (top-to-bottom or left-to-right)
3. Databases, queues, stores (bottommost/rightmost)
4. All edges/relationships LAST
```

## Node Limits

| Complexity | Elements | Target |
|---|---|---|
| Simple | ≤6 | 0 edge crossings |
| Medium | 7-12 | <3 crossings |
| Complex | 13-15 | <5 crossings |

**If >15 elements: split into two diagrams** at a natural boundary (system boundary, trust boundary, domain boundary).

## Shape Conventions

| Shape | Syntax | Meaning |
|---|---|---|
| Stadium | `A([Text])` | Start / End |
| Rectangle | `A[Text]` | Action / Process |
| Diamond | `A{Text}` | Decision / Branch |
| Cylinder | `A[(Text)]` | Database / Store |
| Rounded | `A(Text)` | State / Event |
| Circle | `A((Text))` | Connector |

## Edge Rules

- **Label every edge** — unlabeled arrows are the #1 readability killer
- Solid `-->` for primary flow, dashed `-.->` for secondary/async, thick `==>` for critical path
- Short edge labels: use `|"reason"|` syntax — `A -->|"creates"| B`
- **Labels >20 chars MUST use `\n` for line breaks:** `A -->|"first line\nsecond line"| B` — prevents awkward auto-wrapping that breaks dark mode readability
- In sequence diagrams: `->>+` activates participant, `-->>-` deactivates

## Styling with classDef

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'darkMode': true, 'background': '#1e1e2e', 'primaryColor': '#2d3a5c', 'primaryTextColor': '#e0e0e0'}}}%%
```
Apply classDef consistently — do not inline style individual nodes:

### Theme-Safe Colors (Required)
Every `classDef` MUST include BOTH `fill` AND `color` (text color). Without explicit `color`, text inherits the theme default — in dark themes, light text on light fills becomes invisible.

Use this dark-neutral palette with `color:#e0e0e0` (light text — readable on every dark fill):

```
classDef process fill:#1e3a5f,stroke:#5b8def,color:#e0e0e0,stroke-width:2px
classDef decision fill:#3d2e00,stroke:#eab308,color:#e0e0e0,stroke-width:2px
classDef store fill:#2d1b4e,stroke:#a855f7,color:#e0e0e0,stroke-width:2px
classDef boundary fill:#1e1e2e,stroke:#64748b,color:#94a3b8,stroke-width:1px,stroke-dasharray:5 5
classDef success fill:#0f2d1a,stroke:#22c55e,color:#e0e0e0,stroke-width:2px
classDef danger fill:#2d0f0f,stroke:#ef4444,color:#e0e0e0,stroke-width:2px
```

**Design rationale:**
- Dark fills (`#1e3a5f`, `#3d2e00`, etc.) work as distinct background cards in both dark and light themes
- Light text (`#e0e0e0`) maintains ~10:1 contrast ratio against all recommended fills
- Stroke colors are bright (`#5b8def`, `#eab308`, etc.) to outline shapes against any background
- In light themes, the dark fills appear as colored cards with vivid borders — still readable with light text

## Subgraph Rules

- Use `subgraph` for **real** logical boundaries (service, tier, security zone)
- Keep nesting ≤2 levels deep — deeper nesting doubles height and slows rendering
- Every subgraph needs a descriptive title — `subgraph svc[API Service Layer]`
- Do NOT subgraph everything — too many subgraphs creates noise

## Sequence Diagram Rules

```
sequenceDiagram
    actor User
    participant A as "Service A"
    participant B as "Service B"

    User->>+A: Request
    A->>+B: Forward
    B-->>-A: Response
    alt Success
        A-->>-User: OK
    else Error
        A-->>User: Error
    end
```

- Use `alt`/`else` for conditional branches, `par`/`and` for parallel, `loop` for repeats
- Activate/deactivate (`+`/`-`) to show service active periods
- Notes: `Note over A,B: explanation` for cross-participant context

## Cross-Theme Colors (Required for All Mermaid Diagrams)

Mermaid diagrams must render readably in BOTH light and dark VS Code themes. Every Mermaid block MUST start with a `%%{init}` directive that sets explicit, non-theme-dependent colors:

```
%%{init: {'theme': 'base', 'themeVariables': {
  'darkMode': true, 'background': '#1e1e2e',
  'primaryColor': '#2d3a5c', 'primaryTextColor': '#e0e0e0',
  'primaryBorderColor': '#5b8def', 'lineColor': '#5b8def',
  'secondaryColor': '#3d3520', 'tertiaryColor': '#2a2a36',
  'signalColor': '#5b8def', 'signalTextColor': '#e0e0e0',
  'labelTextColor': '#e0e0e0', 'noteTextColor': '#e0e0e0',
  'noteBkgColor': '#3d3520', 'actorLineColor': '#5b8def',
  'actorBorderColor': '#5b8def', 'actorBkg': '#2d3a5c',
  'actorTextColor': '#e0e0e0', 'sequenceNumberColor': '#e0e0e0',
  'activationBorderColor': '#5b8def', 'activationBkgColor': '#2d3a5c'
}}}
%%```

**Why this works:** `theme: 'base'` with `darkMode: true` and explicit `themeVariables` overrides ALL color defaults. The diagram uses a dark-neutral background (`#1e1e2e`) with light text (`#e0e0e0`) and vivid accent strokes (`#5b8def`). This palette renders readably in both light and dark theme contexts — in dark mode it blends naturally, in light mode it reads as distinct dark cards with ~10:1 contrast ratio.

**Mandatory for:** flowcharts, sequence diagrams, graphs. Not applicable to C4 (C4 has its own styling mechanism — see C4 section below).

## Anti-Patterns

- ❌ Random node declaration order (causes crossing edges)
- ❌ No labels on edges (arrows without meaning)
- ❌ More than 15 elements in one diagram
- ❌ Inline styles on every node (use classDef)
- ❌ Deeply nested subgraphs (>2 levels)
- ❌ Relying on color alone — always pair with shape or label
- ❌ Mixing C4 levels in one diagram (context + container together)
- ❌ Mermaid diagram without `%%{init}` directive — text and lines are invisible in some themes
- ❌ Sequence diagram without `actorLineColor` and `signalColor` in themeVariables — connector lines become invisible grey

## C4-Specific Rules

⚠️ **C4 diagrams in Mermaid are experimental.** `UpdateElementStyle` and `UpdateRelStyle` may not work in all renderers (VS Code, GitHub, etc.). For reliable cross-theme rendering, **prefer an equivalent `flowchart` graph** instead of `C4Context` — it supports `classDef`, `%%{init}`, and all theme variables.

If you must use `C4Context`:
- `C4Context`: one level per diagram — never mix context and container
- `C4Container`: show high-level tech building blocks only
- Node IDs in PascalCase: `Person(user, "Developer")`
- Relationship labels always included: `Rel(user, sys, "Uses")`
- C4 has fixed styling — CSS themes and `classDef` do NOT affect C4 diagrams
- Add `UpdateElementStyle` for each element (blue fill + dark text for main systems, amber for externals)
- Add `UpdateRelStyle` for each relationship (blue lines + dark text)
- **Test in target renderer** — if styling doesn't render, convert to `flowchart` graph instead

### C4 Theme-Safe Colors (Required)

C4 ignores `classDef` and theme variables. To make C4 diagrams readable in both light and dark themes, use `UpdateElementStyle` and `UpdateRelStyle` at the end of every C4 diagram.

**Person and System (dark blue fill, light text):**
```
UpdateElementStyle(user, $fontColor="#e0e0e0", $bgColor="#1e3a5f", $borderColor="#5b8def")
UpdateElementStyle(opencode, $fontColor="#e0e0e0", $bgColor="#1e3a5f", $borderColor="#5b8def")
```

**External systems (dark amber fill, light text):**
```
UpdateElementStyle(ext_sys, $fontColor="#e0e0e0", $bgColor="#3d2e00", $borderColor="#eab308")
```

**Relationships (blue lines, light text):**
```
UpdateRelStyle(from, to, $lineColor="#5b8def", $textColor="#e0e0e0")
```

**Complete pattern — always add at end of C4 diagram:**
```
    %% ── Theme-safe styling (dark mode) ──
    UpdateElementStyle(user, $fontColor="#e0e0e0", $bgColor="#1e3a5f", $borderColor="#5b8def")
    UpdateElementStyle(sys, $fontColor="#e0e0e0", $bgColor="#1e3a5f", $borderColor="#5b8def")
    UpdateElementStyle(ext, $fontColor="#e0e0e0", $bgColor="#3d2e00", $borderColor="#eab308")

    UpdateRelStyle(user, sys, $lineColor="#5b8def", $textColor="#e0e0e0")
    UpdateRelStyle(sys, ext, $lineColor="#5b8def", $textColor="#e0e0e0")
```

**Why this palette works in both themes:**
- `#1e3a5f` (dark blue) / `#3d2e00` (dark amber) — dark fills that appear as distinct background cards in both light and dark themes
- `#e0e0e0` (light text) — readable at ~10:1 contrast against dark fills in any theme
- `#5b8def` (bright blue) / `#eab308` (bright amber) — vivid strokes visible against any background
- The dark fill + light text combo works naturally: dark mode blends in, light mode reads as colored cards

## Validation Checklist

After writing any diagram, verify:
1. **0 crossings** for simple, <3 for medium, <5 for complex
2. **Visual hierarchy** — the main system is the most prominent element
3. **All edges labeled** — no naked arrows
4. **Single concept** — one diagram = one idea
5. **Fits node limit** — ≤15 elements; split if larger

