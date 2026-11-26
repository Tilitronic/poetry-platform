"""Shared JSONC comment/trailing-comma stripper (single owner: preset lane).

Owner: DIA-260918-vsq8 (scripts/presets.py is the only importer). POINTER:
scripts/check-orchestrator-prompt-drift.sh keeps its own FROZEN inline copy
for its behavioral gate - do NOT unify them; this copy tracks only
double-quote as a string delimiter (fix 6) while the drift copy still tracks
both quote kinds. Any change here must keep the apostrophe and URL tests in
scripts/__tests__/workspace-preset-selection.bats green.

Stdlib only, no imports.
"""


def strip_jsonc(src):
    """Char-level stripper: // and /* */ comments dropped only outside
    double-quoted strings; trailing commas before } or ] dropped. URLs
    (https://...) survive because '/' inside a string never enters
    comment-scanning. Single quotes are ordinary characters (JSON has no
    single-quoted strings), so apostrophes in text never open a string.
    """
    out = []
    i = 0
    n = len(src)
    in_string = False
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if in_string:
            out.append(c)
            if c == "\\":
                i += 1
                if i < n:
                    out.append(src[i])
            elif c == '"':
                in_string = False
            i += 1
            continue
        if c == '"':
            in_string = True
            out.append(c)
            i += 1
            continue
        if c == "/" and nxt == "/":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if c == "/" and nxt == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                i += 1
            i += 2
            continue
        if c == ",":
            j = i + 1
            while j < n and src[j].isspace():
                j += 1
            if j < n and src[j] in "}]":
                i += 1
                continue
        out.append(c)
        i += 1
    return "".join(out)
