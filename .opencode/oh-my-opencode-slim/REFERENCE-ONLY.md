# REFERENCE-ONLY — not the running plugin

The fork SOURCE (src/) is NOT loaded at runtime — no package.json/dist, do not build or edit it as the live plugin. The RUNNING plugin is the npm-installed `oh-my-opencode-slim@2.2.13` (project + global `opencode.jsonc` plugin arrays). However, this directory IS the live OMO prompt-override dir: the npm plugin sets `PROMPTS_DIR_NAME="oh-my-opencode-slim"` and reads `<agent>.md` / `<agent>_append.md` files and `knowledge/` from here at runtime. Keep this checkout for diff/reference only.
