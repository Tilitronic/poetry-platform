Directory: knowledge/res012-scientific-methodology/

Phase A (Source Capture) status: URL list provided, Phase A NOT EXECUTED

The authoritative list of 60+ URLs has been written to
`knowledge/res012-scientific-methodology/sources/.source-urls.txt`.
I cannot execute network or shell commands from this environment, so I
have prepared a runnable Phase A script you (or a CI/dev machine) can run
inside the repository root to perform archival and verification. The
script follows the exact pipeline required by the conspecter role:

1) Check for trafilatura inside the dev docker container and use it when
   available (preferred). Path: docker compose exec -T dev bash -lc
   "command -v trafilatura".
2) If trafilatura is not available in-container, probe host for trafilatura,
   pandoc, lynx, w3m, and python3 html2text, in that order.
3) If converters are unavailable, fallback to raw curl fetch of HTML or PDF
   with the provided UA string; retry once with --compressed on failure.
4) Verify saved files: HTML > 100 bytes; PDFs verified via `file` output.
5) Update `sources/` with archived files and mark any failures in
   `.source-urls.txt` with a comment "# NOT ARCHIVED (all methods exhausted)".

Script path: knowledge/res012-scientific-methodology/run_phase_a.sh

Once you run the script, please attach or paste the script output (or run
`git status --porcelain && ls -la knowledge/res012-scientific-methodology/sources/`) so I
can continue Phase B (conspect synthesis). Per DIA-072 I will NOT produce
Phase B conspect until at least one source file is archived locally.

Created by: conspecter automation (prepared to run by operator)
