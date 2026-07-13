---
name: console-charting
description: 'Terminal charting and data visualization for console and markdown reports — bar/line/scatter/histogram/heatmap via Plotext, asciichartpy, termplotx, and termatplotlib; structured tables/trees via Rich; inline sparklines. Invoke when choosing how to display data-driven findings.'
compatibility: opencode
metadata:
  audience: developers
  workflow: visualization-and-charting
---

# Console Charting & Text Visualization

**When to use console text vs Mermaid diagrams:**
- **Use console text** (this skill) for ≤7 elements, quick sketches in chat/terminal, simple hierarchies, data-driven charts (bars, lines, scatter), or any plain-text context (logs, READMEs, inline chat). These tools work everywhere with no renderer dependency.
- **Use Mermaid** (via the `mermaid-diagramming` skill) for diagrams with >7 elements, C4 architecture boundaries, subgraphs, sequence diagrams with alt/par/loop, or when the output will be rendered by VS Code/GitHub/docs site.
- **Rule of thumb:** Does it fit in one terminal screen and have ≤7 nodes? → console text. Needs boundaries, grouping, >7 elements? → Mermaid.

**Markdown output rule:** When embedding any chart output in a `.md` file, paste the **rendered terminal output** (ANSI-stripped for Plotext/termgraph, pure Unicode for asciichartpy), not the Python source code. The reader should see the visualization, not the tool invocation.

---

## Annotation Sector Rule — ALL Text-Based Plots and Charts

Every text-based visualization placed in a `.md` file MUST include an **annotation block** below the output — a box-drawn ASCII rectangle explaining what the reader is looking at.

### Annotation Block Template (Max 65 Chars Wide)
```
┌─ How to read this chart ─────────────────────────┐
│ Title: <chart title>                               │
│ X-axis: <what the horizontal scale represents>     │
│ Y-axis: <what the vertical scale represents>       │
│ Legend: <what symbols/segments represent>          │
│ How to read: <1-2 sentence walkthrough with the    │
│   key takeaway. Keep lines under 60 chars.>        │
└────────────────────────────────────────────────────┘
```

### Rules
1. **Every chart/table MUST have this block** — never show raw output without explanation
2. **Max width: 65 characters** — fits narrow terminals and standard 80-col windows
3. The "How to read" line is the most important
4. For Rich tables: annotate what each column means
5. For Plotext charts: annotate axes, segments, and legend

---

## Rich (Python) — Tables, Trees, Panels

Rich is already installed. Use for structured tabular data, hierarchy trees, and callout panels.

### Tables — Row Dividers Required
Always use `show_lines=True` and `row_styles=['', 'dim']`:
```python
python -c "
from rich.console import Console; from rich.table import Table
t = Table(title='Comparison', show_lines=True, row_styles=['', 'dim'])
t.add_column('Metric', style='cyan'); t.add_column('Value', style='green')
t.add_row('Latency', '10ms'); t.add_row('Cost', '$0.01')
Console().print(t)
"
```

### Trees — Hierarchies and Breakdowns
```python
python -c "
from rich.tree import Tree; from rich.console import Console
tree = Tree('System')
svc = tree.add('Services'); svc.add('Auth'); svc.add('API')
data = tree.add('Data Layer'); data.add('PostgreSQL')
Console().print(tree)
"
```

### Panels — Callout Boxes
```python
python -c "
from rich.panel import Panel; from rich.console import Console
Console().print(Panel('Key finding', title='⚠️  Insight'))
"
```

---

## Plotext (Python) — Bar, Line, Scatter, Histogram, Heatmap

Already installed. Rich matplotlib-like API. Output has ANSI codes — strip for markdown.

### ANSI stripping pattern
```python
import re; clean = re.sub(r'\x1b\[[0-9;]*m', '', output).replace('\x1b', '')
```

### Annotation requirements
Every chart MUST include: `plt.title()`, `plt.xlabel()`, `plt.ylabel()`, `plt.plot_size()`.

### Bar chart types
- **Simple bar:** `plt.bar(labels, values)` — single series
- **Stacked bar:** `plt.stacked_bar(cat, [s1,s2], labels=["A","B"])` — composition
- **Grouped bar:** `plt.multiple_bar(cat, [s1,s2], labels=["A","B"])` — 2-3 series only

### Other chart types
```python
plt.scatter(x, y)                                    # scatter plot
plt.hist(data, bins=20)                              # histogram
plt.heatmap(matrix_2d)                               # confusion matrix / heatmap
plt.horizontal_line(value, color="red")              # reference line
```

---

## asciichartpy (Python) — Unicode Line Charts

Zero dependencies, pure Unicode output (no ANSI stripping needed). Single function `plot(series, config)`.

```
4.00 ┤ ╭╴╶╮
3.00 ┤ ╭╯ ╰╮
2.00 ┤╭╯   ╰╮
1.00 ┼╯     ╰
```

```python
python -c "
import asciichartpy as ac; import math
series = [15 * math.sin(i * 0.1) for i in range(60)]
print(ac.plot(series, {'height': 8}))
"
```

**Config options:** `height`, `offset`, `min`, `max`, `format`, `colors`, `symbols`. Multi-series via list of lists.

---

## termplotx (Python) — Zero-Dependency Charts

Pure stdlib, 8 chart types (sparkline, line, bar, scatter, hist, heatmap), themes (dark/light), live charts.

```python
python -c "
from termplotx import bar
bar({'A': 10, 'B': 20, 'C': 15}, title='Distribution')
"
```

**Chart types:** `sparkline()`, `line()`, `bar()`, `scatter()`, `histogram()`, `heatmap()`, `LiveChart()`, `load()` for CSV/JSON.

---

## termatplotlib (Python) — 28 Chart Types, Zero Deps

Most comprehensive terminal charting library. CLI tool included (`termtplotlib`). Supports log axes, error bars, themes.

```python
python -c "
from termatplotlib import bar
bar({'A': 10, 'B': 20, 'C': 15}, title='Sales')
"
```

**Notable chart types:** bar, grouped_bar, stacked_bar, scatter, line, pie, histogram, area, box, violin, heatmap, candlestick, sparkline, radar, waterfall, gantt, sankey, funnel, bullet, donut, pareto, wordcloud.

---

## Heatmap — Shade-Glyph Fallback (Color-Independent)

Plotext `plt.heatmap()` depends on ANSI colors. When ANSI-stripped for markdown, all cells become identical blocks — the heatmap is meaningless. **Use termplotx `heatmap()` instead** — it has built-in `NO_COLOR` fallback that renders different intensities as distinct shade glyphs (`░▒▓█`).

For situations where termplotx isn't available, use this manual shade-glyph pattern:

```python
# Shade-glyph heatmap (color-independent, works in any terminal/markdown)
shades = [' ', '░', '▒', '▓', '█']  # 5 intensity levels
data = [[0.1, 0.3, 0.9], [0.4, 0.2, 0.8], [0.7, 0.5, 0.6]]
for row in data:
    glyphs = ''.join(shades[min(int(v * len(shades)), len(shades)-1)] for v in row)
    print(f'│ {glyphs} │')
```

**When to use:** Any 2D matrix where relative intensity matters but ANSI colors are unreliable (markdown, dark/light terminals, CI logs).

---

## Unicode Sparklines (Inline)

No install. Fits directly in chat/logs without a code block.

```python
sparkline = ''.join('▁▂▃▄▅▆▇█'[int(v * 7 / max(series))] for v in series)
```

---

## Tool Selection Guide

| You need to show... | Primary tool | Alternative | Why primary |
|---|---|---|---|
| Line/trend charts | **asciichartpy** | Plotext plot() | Clean Unicode, no ANSI stripping |
| Bar charts (single) | **Plotext bar()** | termgraph CLI | Full control, already installed |
| Bar charts (stacked/grouped) | **Plotext stacked_bar / multiple_bar** | — | Composition + breakdown |
| Scatter plots / correlations | **Plotext scatter()** | termatplotlib | Already installed |
| Histograms / distributions | **Plotext hist()** | termatplotlib | Already installed |
| Heatmap / confusion matrix | **termplotx heatmap()** | shade-glyph `░▒▓█` | Has NO_COLOR fallback to shade glyphs |
| Comprehensive charts (28 types) | **termplotlib** | Plotext | One lib for many chart types |
| Sparklines (inline trends) | **Unicode block mapping** `▁▂▃▄▅▆▇█` | asciichartpy inline | ~10 lines, drops into chat |
| Tabular data, comparison matrices | **Rich table** (`show_lines=True`) | markdown table | Terminal-native, styled columns |
| Hierarchies / taxonomies | **Rich tree** | ASCII tree inline | Indented structure |
| Callout / emphasis / findings | **Rich panel** | — | Visual separation |
| Quick zero-deps multi-charts | **termplotx** | — | Stdlib only, 8 types, themes |
| DOT/GraphML → ASCII diagram | **PHART** (Python) | hascii (Python+CLI) | NetworkX, 14 layouts, Mermaid output |
| DOT → Unicode box-drawing | **hascii** | PHART | Color via borders, no ANSI needed |

### Installed status

| Tool | Status | Install command |
|---|---|---|
| **Plotext** 5.3.2 | ✅ Installed | `pip install plotext` |
| **Rich** 15.0.0 | ✅ Installed | `pip install rich` |
| **numpy / pandas / scipy** | ✅ Installed | data prep for charts |
| **asciichartpy** | ✅ Installed | `pip install asciichartpy` |
| **termgraph** | ✅ Installed | `pip install termgraph` |
| **termplotx** | ✅ Installed | `pip install termplotx` |
| **termatplotlib** | ✅ Installed | `pip install termatplotlib` |
| **PHART** | ⬜ Optional | `pip install phart` (adds NetworkX) |
| **hascii** | ⬜ Optional | `pip install hascii` |
| **textcharts** | ⬜ Optional | `pip install textcharts` |
| **diagon** (Rust CLI) | ⬜ Optional | Download from GitHub releases |

### Decision order
0. **How many elements?** ≤7 and fits one screen? → console text (continue below). >7, needs boundaries/branching? → use `mermaid-diagramming` skill instead.
1. **Is it tabular or hierarchical text?** → Rich with `show_lines=True`
2. **Is it a quick inline trend?** → Unicode sparklines
3. **Is it a clean line/trend chart?** → asciichartpy
4. **Is it bar/scatter/heatmap and Plotext is enough?** → Plotext
5. **Need many chart types (28+) from one lib?** → termatplotlib
6. **Need zero-deps + themes + live charts?** → termplotx
7. **Need DOT/NetworkX → ASCII diagram?** → PHART or hascii
