#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# DIA-260829-kxqu regression guard: plugin must be Bun-parseable.
# Node masks the bug (experimental-strip-types accepts the file), so we assert under Bun.
# Uses dynamic import (the same path OpenCode's Wy loader uses) and checks the
# Wy-style condition: every export must be function or object-with-server, and default is function.
if command -v bun >/dev/null 2>&1; then
  BUN_BIN="$(command -v bun)"
elif [ -x "$HOME/.bun/bin/bun" ]; then
  BUN_BIN="$HOME/.bun/bin/bun"
elif [ -x "/tmp/bun-1.3.14" ]; then
  BUN_BIN="/tmp/bun-1.3.14"
else
  echo "bun not found; running node fallback check"
  node --experimental-strip-types -e "import('/home/qualt/Projects/poetry-platform/.opencode/plugins/delegation-observer.ts').then(m=>{if(typeof m.default!=='function'){console.error('FAIL');process.exit(1)};console.log('OK (node)')})"
  exit 0
fi
"$BUN_BIN" -e "
import('/home/qualt/Projects/poetry-platform/.opencode/plugins/delegation-observer.ts').then(m=>{
  if(typeof m.default!=='function'){console.error('FAIL: default not a function under Bun');process.exit(1)}
  // Wy check: every export must be function or {server:function}
  function isFn(v){return typeof v==='function'}
  function gy(v){if(isFn(v))return v;if(!v||typeof v!=='object'||!('server' in v))return;if(!isFn(v.server))return;return v.server}
  for(const [k,v] of Object.entries(m)){
    if(!gy(v)){console.error('FAIL: export '+k+' would make Wy throw (not function nor server)');process.exit(1)}
  }
  console.log('OK: delegation-observer loads under Bun (default function, all exports Wy-compatible)')
}).catch(e=>{console.error('FAIL: import error', e.message);process.exit(1)})
"
