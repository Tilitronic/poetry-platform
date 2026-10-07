"""
query_rag.py — Bridge script for the opencode book-rag skill.

Queries local OpenWebUI's RAG pipeline (hybrid BM25+vector search +
BGE-reranker-v2-m3 cross-encoder) with optional #collection filtering.

Usage:
    python query_rag.py "[#tag] <query>"       # Query RAG (tagged or global)
    python query_rag.py --list [--refresh]     # List KB tags (cached)
    python query_rag.py --route "<topic>"      # Auto-select best KB(s)
    python query_rag.py --refresh              # Force KB cache refresh
    python query_rag.py --books #<tag>         # List books in a KB
    python query_rag.py --books-all            # List books in all KBs
    python query_rag.py --stats                # KB statistics summary

Environment variables:
    OPENWEBUI_API_KEY     API key for OpenWebUI (default: auto-mint JWT)
    OPENWEBUI_URL         OpenWebUI server URL (default: http://localhost:8080)
    OPENWEBUI_DATA_DIR    OpenWebUI data directory (default: %APPDATA%/open-webui/data)
    RAG_CACHE_DIR         KB cache directory (default: ~/.config/opencode/skills/book-rag)
    RAG_CACHE_TTL         KB cache TTL in seconds (default: 3600; 0=disabled)
    RAG_TOP_K             Chunks to retrieve (default: 6)
    RAG_HYBRID            Enable hybrid BM25+vector search (default: true)
    RAG_TIMEOUT           Request timeout (default: 20s)
    RAG_ROUTE_THRESHOLD   Minimum score for --route results (default: 0.15)
    RAG_ROUTE_MAX_RESULTS Max KBs returned by --route (default: 3)
    LOG_LEVEL             Log level: DEBUG, INFO, WARNING (default: INFO)

Knowledge bases are discovered dynamically at runtime from OpenWebUI's own
API (GET /api/v1/knowledge/) with a SQLite fallback, then cached to a
YAML file with a configurable TTL — no hardcoded UUIDs or names needed.

Design notes:
  - A #tag is recognized anywhere in the query (re.search, not re.match)
    so "dna #bio_python" still filters correctly; only the tag token is
    stripped from the search text. "C#" is never treated as a tag — a #
    must be followed by a word character.
  - If a #tag is provided but doesn't resolve (exact or fuzzy), the query
    falls back to a global search across all KBs instead of failing, so
    typos and unknown tags still return results.
  - Relevance scores are included per-chunk.  A WARNING line is emitted
    when the top score is below 0.3 (weak semantic match).
  - First-run auto-setup will generate an API key if none is configured.
"""
from __future__ import annotations

import difflib
import hashlib
import json
import logging
import os
import re
import secrets
import sqlite3
import subprocess
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests  # type: ignore[import-untyped]


def _mask_key(key: str) -> str:
    """Mask an API key for safe display in logs and error messages."""
    if not key or len(key) < 8:
        return "****"
    return f"{key[:4]}****{key[-4:]}"


class _SecretFilter(logging.Filter):
    """Redact API keys and JWT tokens from log records."""
    def filter(self, record: logging.LogRecord) -> bool:
        if API_KEY and isinstance(record.msg, str):
            record.msg = record.msg.replace(API_KEY, _mask_key(API_KEY))
        if API_KEY and isinstance(record.args, tuple):
            record.args = tuple(
                str(a).replace(API_KEY, _mask_key(API_KEY))
                if isinstance(a, str) else a
                for a in record.args
            )
        return True


# PyJWT is optional — used only for local JWT minting from the .key file.
# If unavailable, the script falls back to OPENWEBUI_API_KEY env var.
pyjwt: Any | None = None
try:
    import jwt as _jwt
    pyjwt = _jwt
except ImportError:
    pass

# PyYAML is optional — used for human-readable KB cache files.
# Falls back to JSON (stdlib) when unavailable.
_yaml: Any | None = None
try:
    import yaml as _yaml_import
    _yaml = _yaml_import
except ImportError:
    pass

# ---------------------------------------------------------------------------
# KB cache configuration
# ---------------------------------------------------------------------------

_CACHE_DIR = Path(
    os.getenv(
        "RAG_CACHE_DIR",
        os.path.join(os.environ.get("USERPROFILE", ""), ".config",
                      "opencode", "skills", "book-rag"),
    )
)
_CACHE_FILENAME = "knowledge-bases.yaml" if _yaml else "knowledge-bases.json"
_CACHE_PATH = _CACHE_DIR / _CACHE_FILENAME
CACHE_TTL = int(os.getenv("RAG_CACHE_TTL", "3600"))  # seconds; 0 = disabled

# Module-level cache state (set by get_kb_list, read by _list_kb_tags)
_cache_was_hit: bool = False
_cache_age_seconds: float = 0.0

# ---------------------------------------------------------------------------
# Configuration — override via environment variables
# ---------------------------------------------------------------------------

OPENWEBUI_URL = os.getenv("OPENWEBUI_URL", "http://localhost:8080").rstrip("/")

# API key or JWT token.  If empty we attempt to mint a JWT from the server's
# .key file (local dev only).  Set OPENWEBUI_API_KEY in production.
API_KEY = os.getenv("OPENWEBUI_API_KEY", "")

# Path to OpenWebUI's data directory (for .key file and knowledge DB fallback)
OPENWEBUI_DATA_DIR = os.getenv(
    "OPENWEBUI_DATA_DIR",
    os.path.join(os.environ.get("APPDATA", ""), "open-webui", "data"),
)

# Number of chunks to retrieve (OpenWebUI may return fewer if thresholded)
TOP_K = int(os.getenv("RAG_TOP_K", "6"))

# Enable hybrid BM25 + vector search (uses OpenWebUI's config)
HYBRID = os.getenv("RAG_HYBRID", "true").lower() in ("1", "true", "yes")

# Request timeout in seconds (20s default for local RAG; increase via env var for slow servers)
REQUEST_TIMEOUT = int(os.getenv("RAG_TIMEOUT", "20"))

# Logging — INFO by default; set LOG_LEVEL=DEBUG for troubleshooting
logging.basicConfig(
    level=getattr(logging, os.getenv("LOG_LEVEL", "INFO").upper(), logging.INFO),
    format="%(levelname)s | %(message)s",
)
log = logging.getLogger("query_rag")
log.addFilter(_SecretFilter())

# Route configuration
ROUTE_THRESHOLD = float(os.getenv("RAG_ROUTE_THRESHOLD", "0.15"))
ROUTE_MAX_RESULTS = int(os.getenv("RAG_ROUTE_MAX_RESULTS", "3"))
# Higher threshold for auto-routing (no explicit #tag) — 0.3 ensures
# we only auto-select a KB when confidence is decent, falling back to
# global search otherwise.
AUTO_ROUTE_THRESHOLD = float(os.getenv("AUTO_ROUTE_THRESHOLD", "0.30"))

# ---------------------------------------------------------------------------
# KB cache I/O
# ---------------------------------------------------------------------------

def _serialize_cache(data: dict) -> str:
    """Serialize cache data to YAML or JSON string."""
    if _yaml:
        return _yaml.dump(data, default_flow_style=False, sort_keys=False,
                          allow_unicode=True)
    return json.dumps(data, indent=2, ensure_ascii=False)


def _deserialize_cache(text: str) -> dict | None:
    """Deserialize YAML or JSON cache string. Returns None on parse error."""
    try:
        if _yaml:
            result = _yaml.safe_load(text)
        else:
            result = json.loads(text)
        return result if isinstance(result, dict) else None
    except Exception:
        log.debug("Cache deserialization failed — treating as cache miss")
        return None


def _load_kb_cache(*, ignore_ttl: bool = False) -> dict | None:
    """
    Load KB cache from disk. Returns None if no cache, expired, or corrupt.

    When ignore_ttl=True, returns stale cache regardless of age (used for
    degraded mode when OpenWebUI is unreachable).

    Returns dict with keys: kbs, cached_at, age_seconds
    """
    if not _CACHE_PATH.is_file():
        return None

    if CACHE_TTL <= 0 and not ignore_ttl:
        return None  # Cache disabled by user

    try:
        text = _CACHE_PATH.read_text(encoding="utf-8")
    except Exception:
        log.debug("Could not read cache file")
        return None

    data = _deserialize_cache(text)
    if data is None:
        return None

    cached_at_str = data.get("cached_at", "")
    kbs = data.get("kbs", [])
    if not kbs or not cached_at_str:
        return None

    # Compute age
    try:
        cached_at = datetime.fromisoformat(cached_at_str)
        age = (datetime.now(timezone.utc) - cached_at).total_seconds()
    except (ValueError, TypeError):
        log.debug("Cache timestamp invalid — treating as miss")
        return None

    if not ignore_ttl and age > CACHE_TTL:
        log.info("KB cache expired (age: %s, TTL: %ds)",
                 _format_age(age), CACHE_TTL)
        return None

    return {"kbs": kbs, "cached_at": cached_at_str, "age_seconds": age}


def _save_kb_cache(kbs: list[dict[str, str]]) -> None:
    """
    Write KB cache atomically: write to same-directory .tmp file, then
    os.replace() (atomic overwrite, no unlink/rename race window).
    Prevents corruption from crashes mid-write.
    """
    _CACHE_DIR.mkdir(parents=True, exist_ok=True)

    data = {
        "cached_at": datetime.now(timezone.utc).isoformat(),
        "ttl_seconds": CACHE_TTL,
        "kbs": kbs,
    }

    tmp_path = _CACHE_PATH.with_suffix(_CACHE_PATH.suffix + ".tmp")
    try:
        content = _serialize_cache(data)
        tmp_path.write_text(content, encoding="utf-8")
        os.replace(tmp_path, _CACHE_PATH)
        log.info("KB cache updated — %d KBs cached to %s",
                 len(kbs), _CACHE_PATH.name)
    except Exception:
        log.warning("Failed to write KB cache — continuing with in-memory data")
        if tmp_path.exists():
            try:
                tmp_path.unlink()
            except Exception:
                pass


def _format_age(seconds: float) -> str:
    """Format a duration in seconds as a human-readable string."""
    if seconds < 60:
        return f"{int(seconds)}s"
    minutes = int(seconds // 60)
    if minutes < 60:
        return f"{minutes}m"
    hours = minutes // 60
    remaining_minutes = minutes % 60
    return f"{hours}h {remaining_minutes}m"

# ---------------------------------------------------------------------------
# Dynamic knowledge base discovery
# ---------------------------------------------------------------------------
# OpenWebUI does NOT expose a public read-only endpoint for KB listing.
# We use a two-tier discovery:
#   1. Call GET /api/v1/knowledge/ (requires auth — works on remote installs)
#   2. Fallback: read webui.db SQLite directly (local install only)
#
# We cache the result in _KB_CACHE so UUIDs are fetched at most once per run.

_KB_CACHE: dict[str, str] | None = None
"""Cache: lower-cased KB name → ChromaDB collection UUID."""


def get_kb_list(*, force_refresh: bool = False) -> list[dict[str, str]]:
    """
    Return the KB list with descriptions, using persistent cache when possible.

    Single entry point for KB metadata used by --list, --route, and error
    handlers. Checks YAML/JSON cache first; fetches from API only when cache
    is stale or missing.

    Parameters
    ----------
    force_refresh : bool
        When True, bypass cache and fetch from API (used by --refresh).

    Returns
    -------
    list[dict[str, str]]
        List of {tag, name, description, id} dicts.
    """
    global _cache_was_hit, _cache_age_seconds

    # -- Check persistent cache -----------------------------------------------
    if not force_refresh:
        cached = _load_kb_cache()
        if cached is not None:
            _cache_was_hit = True
            _cache_age_seconds = cached["age_seconds"]
            log.info("KB cache hit (age: %s) — using cached data",
                     _format_age(cached["age_seconds"]))
            return cached["kbs"]

    # -- Cache miss or forced — fetch from API --------------------------------
    _cache_was_hit = False
    kbs = _fetch_kb_list_from_api()

    if kbs:
        _save_kb_cache(kbs)
        return kbs

    # -- Degraded mode: API failed, try stale cache ---------------------------
    stale = _load_kb_cache(ignore_ttl=True)
    if stale:
        _cache_was_hit = True
        _cache_age_seconds = stale["age_seconds"]
        log.warning(
            "Using stale KB cache (age: %s) — OpenWebUI is unreachable",
            _format_age(stale["age_seconds"]),
        )
        return stale["kbs"]

    return []


def _fetch_kb_list_from_api() -> list[dict[str, str]]:
    """
    Fetch KB list with descriptions from OpenWebUI API, with SQLite fallback.
    Returns empty list on failure.
    """
    # Ensure _discover_knowledge_bases has populated the UUID cache
    kbs = _discover_knowledge_bases()
    if not kbs:
        return []

    result: list[dict[str, str]] = []
    auth_headers = _get_auth_header()

    # Try API for enriched data (with descriptions)
    try:
        resp = requests.get(
            f"{OPENWEBUI_URL}/api/v1/knowledge/",
            headers={"Content-Type": "application/json", **auth_headers},
            timeout=REQUEST_TIMEOUT,
        )
        if resp.status_code == 200:
            data = resp.json()
            items = data if isinstance(data, list) else (
                data.get("data") or data.get("items") or []
            )
            for kb in items:
                name = kb.get("name", "")
                if name.lower() in kbs:
                    result.append({
                        "tag": name.lower(),
                        "name": name,
                        "description": kb.get("description", "") or "",
                        "id": kb.get("id", ""),
                    })
            if result:
                return result
    except Exception:
        log.debug("API fetch for KB list failed", exc_info=True)

    # Fallback: names from UUID cache (no descriptions)
    for tag, uid in sorted(kbs.items()):
        result.append({"tag": tag, "name": tag, "description": "", "id": uid})
    return result


def _score_topic(topic: str, kb: dict[str, str]) -> float:
    """
    Score how well a topic matches a KB using weighted keyword overlap.

    Weights are tuned for ~12 KBs with distinct descriptions. Returns [0.0, 1.0].
    """
    topic_lower = topic.lower()
    topic_words = set(re.findall(r'\w+', topic_lower))
    tag = kb["tag"].lower()
    name_words = set(re.findall(r'\w+', kb["name"].lower()))
    desc_words = set(re.findall(r'\w+', kb["description"].lower()))

    stopwords = {"the", "a", "an", "is", "of", "and", "in", "to", "for",
                 "with", "on", "at", "by", "as", "or", "it", "be", "this",
                 "that", "your", "my", "we", "you"}
    topic_words -= stopwords
    name_words -= stopwords
    desc_words -= stopwords

    score = 0.0

    # Tag match — strongest signal
    if tag in topic_lower:
        score += 0.35
    else:
        tag_parts = set(tag.replace("_", " ").replace("-", " ").split())
        if tag_parts & topic_words:
            score += 0.15

    # Name word overlap
    name_matches = topic_words & name_words
    score += min(0.25, len(name_matches) * 0.12)

    # Description word overlap (weighted higher for descriptive queries)
    desc_matches = topic_words & desc_words
    score += min(0.40, len(desc_matches) * 0.15)

    # Bigram overlap (catches multi-word phrases like "machine learning")
    topic_list = sorted(topic_words)
    desc_list = sorted(desc_words)
    topic_bigrams = set(zip(topic_list, topic_list[1:]))
    desc_bigrams = set(zip(desc_list, desc_list[1:]))
    bigram_matches = topic_bigrams & desc_bigrams
    score += min(0.30, len(bigram_matches) * 0.08)

    return min(1.0, round(score, 3))


def _route_topic(topic: str) -> str:
    """
    Find the best-matching KB(s) for a given topic string.

    Returns formatted output with ranked matches or a "no match" message.
    """
    kbs = get_kb_list()
    if not kbs:
        return "Error: No knowledge bases available for routing."

    scored = []
    for kb in kbs:
        s = _score_topic(topic, kb)
        if s >= ROUTE_THRESHOLD:
            scored.append((s, kb))

    scored.sort(key=lambda x: x[0], reverse=True)
    top = scored[:ROUTE_MAX_RESULTS]

    lines = [f'Routing: "{topic}"']
    lines.append("─" * 55)

    if not top:
        lines.append("No matching knowledge base found.")
        lines.append("Consider: web search, or global query (no #tag).")
    else:
        for score, kb in top:
            tag = kb["tag"]
            desc = kb["description"] or kb["name"]
            lines.append(f"#{tag} (score: {score:.2f}) — {desc}")

    return "\n".join(lines)


def _auto_route_best(topic: str) -> dict | None:
    """
    Auto-route a topic to the best KB when no explicit #tag was given.

    Returns the KB dict (with an extra `_score` key) if the top match
    exceeds AUTO_ROUTE_THRESHOLD, or None to fall back to global search.
    """
    kbs = get_kb_list()
    if not kbs:
        return None

    best_score = 0.0
    best_kb = None
    for kb in kbs:
        s = _score_topic(topic, kb)
        if s > best_score:
            best_score = s
            best_kb = kb

    if best_kb and best_score >= AUTO_ROUTE_THRESHOLD:
        best_kb["_score"] = best_score
        return best_kb

    return None


def _discover_knowledge_bases() -> dict[str, str]:
    """
    Return {lower_tag: uuid} for every knowledge base discoverable via
    OpenWebUI API or local SQLite.  Result is cached after first call.
    """
    global _KB_CACHE
    if _KB_CACHE is not None:
        return _KB_CACHE

    _KB_CACHE = {}  # prevent re-entry on error

    # -- Tier 1: API query ------------------------------------------------
    auth_headers = _get_auth_header()
    try:
        resp = requests.get(
            f"{OPENWEBUI_URL}/api/v1/knowledge/",
            headers={"Content-Type": "application/json", **auth_headers},
            timeout=REQUEST_TIMEOUT,
        )
        if resp.status_code == 200:
            data = resp.json()
            items = data if isinstance(data, list) else data.get("data") or data.get("items") or []
            for kb in items:
                name = kb.get("name", "")
                uid = kb.get("id", "")
                if name and uid:
                    _KB_CACHE[name.lower()] = uid
            if _KB_CACHE:
                log.info("Discovered %d KBs via API", len(_KB_CACHE))
                return _KB_CACHE
            log.debug("API returned empty KB list — falling back to SQLite")
        else:
            log.debug("API returned %s — falling back to SQLite", resp.status_code)
    except Exception:
        log.debug("API query failed — falling back to SQLite", exc_info=True)

    # -- Tier 2: local SQLite fallback ------------------------------------
    db_path = Path(OPENWEBUI_DATA_DIR) / "webui.db"
    if db_path.is_file():
        try:
            conn = sqlite3.connect(str(db_path))
            cur = conn.cursor()
            cur.execute("SELECT id, name FROM knowledge")
            for uid, name in cur.fetchall():
                if name and uid:
                    _KB_CACHE[name.lower()] = uid
            conn.close()
            if _KB_CACHE:
                log.info("Discovered %d KBs via SQLite", len(_KB_CACHE))
        except Exception:
            log.debug("SQLite fallback failed", exc_info=True)

    if not _KB_CACHE:
        log.warning("No knowledge bases discovered — script will not work without KBs")
    return _KB_CACHE


def _resolve_knowledge_base_smart(tag: str) -> tuple[str | None, str | None]:
    """
    Resolve a #tag to a ChromaDB collection UUID with typo correction.

    Uses a three-tier approach:
      1. Exact match (case-insensitive) — instant hit.
      2. Fuzzy match via difflib (cutoff=0.5) — auto-corrects common typos.
      3. No match — returns (None, None), triggering global fallback.

    Returns
    -------
    tuple[str | None, str | None]
        (collection_uuid, actual_tag_name) — both None when no KB matches.
    """
    kbs = _discover_knowledge_bases()
    key = tag.lower()

    # Tier 1: exact match
    uid = kbs.get(key)
    if uid:
        return uid, key

    # Tier 2: fuzzy match — find the closest known KB name
    possible = difflib.get_close_matches(key, list(kbs.keys()), n=1, cutoff=0.5)
    if possible:
        corrected = possible[0]
        log.warning(
            "Typo detected in #%s — auto-corrected to nearest match: #%s",
            tag, corrected,
        )
        return kbs[corrected], corrected

    # Tier 3: nothing found
    return None, None


def _list_knowledge_bases() -> list[dict[str, str]]:
    """Return KB list with descriptions. Uses cache layer."""
    return get_kb_list()


_SETUP_ATTEMPTED = False


def _print_manual_setup_instructions() -> None:
    """Print manual setup instructions when auto-setup cannot proceed."""
    print(
        "\nCould not auto-configure API access.\n"
        "Manual setup steps:\n"
        "  1. Open OpenWebUI in your browser\n"
        "  2. Go to Settings \u2192 Admin Panel \u2192 API Keys\n"
        "  3. Enable API key authentication\n"
        "  4. Generate a new API key\n"
        "  5. Set it as an environment variable:\n"
        "     $env:OPENWEBUI_API_KEY = 'sk-your-key-here'\n"
        "     [Environment]::SetEnvironmentVariable(\n"
        "       'OPENWEBUI_API_KEY', 'sk-your-key-here', 'User')\n"
        "  6. Re-run your query\n",
        file=sys.stderr,
    )


def _maybe_auto_setup() -> str | None:
    """
    Attempt first-run auto-setup when no auth is available.

    Tries to:
      1. Verify OpenWebUI is running
      2. Connect to webui.db
      3. Enable API keys in config
      4. Generate an API key
      5. Set the key as a user-level environment variable

    Returns the generated API key on success, None on failure.
    Runs at most once per process lifetime.
    """
    global _SETUP_ATTEMPTED, API_KEY
    if _SETUP_ATTEMPTED:
        return None
    _SETUP_ATTEMPTED = True

    if API_KEY or _get_jwt_from_keyfile():
        return None  # Auth already available

    print("=" * 55, file=sys.stderr)
    print("First-run setup: no API key found.", file=sys.stderr)
    print("=" * 55, file=sys.stderr)

    # Step 1: Check OpenWebUI is running
    try:
        resp = requests.get(OPENWEBUI_URL, timeout=3)
        log.info("OpenWebUI is running at %s", OPENWEBUI_URL)
    except Exception:
        print(
            f"\nOpenWebUI is not running at {OPENWEBUI_URL}.\n"
            "Start it and re-run this script.\n",
            file=sys.stderr,
        )
        return None

    # Step 2: Connect to webui.db
    db_path = Path(OPENWEBUI_DATA_DIR) / "webui.db"
    if not db_path.is_file():
        _print_manual_setup_instructions()
        return None

    try:
        conn = sqlite3.connect(str(db_path))
        cur = conn.cursor()
    except Exception:
        log.debug("Could not connect to webui.db", exc_info=True)
        _print_manual_setup_instructions()
        return None

    # Step 3: Enable API keys if not already enabled
    try:
        cur.execute("SELECT value FROM config WHERE key = ?", ("auth.enable_api_keys",))
        row = cur.fetchone()
        if row and str(row[0]).lower() not in ("true", "1"):
            cur.execute("UPDATE config SET value = ? WHERE key = ?",
                        ("true", "auth.enable_api_keys"))
            conn.commit()
            log.info("Enabled API keys in OpenWebUI config")
    except Exception:
        log.debug("Could not check/update config table", exc_info=True)

    # Step 4: Find admin user
    user_id: str | None = None
    try:
        cur.execute('SELECT id FROM "user" WHERE role = ? LIMIT 1', ("admin",))
        row = cur.fetchone()
        if row:
            user_id = str(row[0])
    except Exception:
        log.debug("Could not find admin user", exc_info=True)

    if not user_id:
        print("\nNo admin user found in webui.db.\n", file=sys.stderr)
        _print_manual_setup_instructions()
        conn.close()
        return None

    # Step 5: Generate API key (match OpenWebUI's format: SHA-256 hash)
    raw_key = f"sk-{secrets.token_urlsafe(32)}"
    key_hash = hashlib.sha256(raw_key.encode()).hexdigest()
    key_id = str(uuid.uuid4())

    try:
        now = int(time.time())
        cur.execute(
            "INSERT INTO api_key (id, user_id, key, data, expires_at, "
            "last_used_at, created_at, updated_at) "
            "VALUES (?, ?, ?, ?, 0, NULL, ?, ?)",
            (key_id, user_id, raw_key,
             json.dumps({"name": "opencode-rag (auto-generated)"}),
             now, now),
        )
        conn.commit()
        log.info("API key generated and stored in webui.db")
    except Exception:
        log.debug("Could not insert API key into webui.db", exc_info=True)
        print("\nCould not write to webui.db api_key table.\n", file=sys.stderr)
        _print_manual_setup_instructions()
        conn.close()
        return None

    conn.close()

    # Step 6: Set environment variable
    env_set_ok = False
    try:
        result = subprocess.run(
            ["powershell", "-NoProfile", "-Command",
             "[Environment]::SetEnvironmentVariable("
             "'OPENWEBUI_API_KEY', '{0}', 'User')".format(raw_key)],
            capture_output=True, text=True, timeout=10,
        )
        env_set_ok = result.returncode == 0
        if not env_set_ok:
            log.debug("PowerShell env var stderr: %s", result.stderr)
    except Exception:
        log.debug("PowerShell env var set failed", exc_info=True)

    # Step 7: Print results
    print(file=sys.stderr)
    print(f"API key generated: {raw_key}", file=sys.stderr)
    print(file=sys.stderr)

    if env_set_ok:
        print(
            "The key has been saved as a user-level environment variable.\n"
            "It will be available in new terminal sessions.\n"
            "For this session, also run:\n"
            f"  $env:OPENWEBUI_API_KEY = '{raw_key}'\n",
            file=sys.stderr,
        )
    else:
        print(
            "Could not set environment variable automatically.\n"
            "Run these commands in PowerShell:\n"
            f"  $env:OPENWEBUI_API_KEY = '{raw_key}'\n"
            f"  [Environment]::SetEnvironmentVariable("
            f"'OPENWEBUI_API_KEY', '{raw_key}', 'User')\n",
            file=sys.stderr,
        )

    print("Re-run your query to use the RAG pipeline.", file=sys.stderr)
    print("=" * 55, file=sys.stderr)

    # Set in-memory for current process
    API_KEY = raw_key
    return raw_key


# ---------------------------------------------------------------------------
# Authentication
# ---------------------------------------------------------------------------

def _get_jwt_from_keyfile() -> str | None:
    """
    On a local development machine, OpenWebUI stores its JWT signing secret
    in data/.key.  We forge a short-lived admin token from it.

    This is a convenience for local-only use.  Production deployments should
    set OPENWEBUI_API_KEY instead.  Never run this on a multi-user or
    internet-exposed instance — forging JWTs from the .key file effectively
    grants full admin access within the 1-hour token window.
    """
    key_path = Path(OPENWEBUI_DATA_DIR) / ".key"
    if not key_path.is_file():
        log.debug("No .key file found at %s", key_path)
        return None

    if pyjwt is None:
        log.warning("PyJWT not installed — cannot mint token from .key file")
        return None

    secret = key_path.read_text(encoding="utf-8").strip()
    if not secret:
        return None

    # Find the admin user ID from the webui.db
    user_id: str | None = None
    db_path = Path(OPENWEBUI_DATA_DIR) / "webui.db"
    if db_path.is_file():
        try:
            conn = sqlite3.connect(str(db_path))
            cur = conn.cursor()
            cur.execute("SELECT id FROM \"user\" WHERE role = 'admin' LIMIT 1")
            row = cur.fetchone()
            if row:
                user_id = str(row[0])
            conn.close()
        except Exception:
            log.debug("Could not query webui.db for admin user", exc_info=True)

    if not user_id:
        log.warning("No admin user found in webui.db — cannot mint JWT")
        return None

    now = int(time.time())
    payload: dict[str, Any] = {
        "id": user_id,
        "email": "",
        "role": "admin",
        "exp": now + 3600,    # 1 hour validity
        "iat": now,
    }
    try:
        return str(pyjwt.encode(payload, secret, algorithm="HS256"))
    except Exception:
        log.exception("Failed to encode JWT")
        return None


def _get_auth_header() -> dict[str, Any]:
    """Return the Authorization header, trying API key then JWT fallback."""
    if API_KEY:
        log.debug("Using API key: %s", _mask_key(API_KEY))
        return {"Authorization": f"Bearer {API_KEY}"}

    token = _get_jwt_from_keyfile()
    if token:
        log.debug("Using JWT from .key file")
        return {"Authorization": f"Bearer {token}"}

    # No auth — attempt first-run setup
    _maybe_auto_setup()
    if API_KEY:
        log.debug("Using API key from auto-setup: %s", _mask_key(API_KEY))
        return {"Authorization": f"Bearer {API_KEY}"}

    log.warning("No authentication available — request will likely fail")
    return {}


# ---------------------------------------------------------------------------
# Core query function
# ---------------------------------------------------------------------------

def query_hybrid_rag(raw_prompt: str, k: int | None = None) -> str:
    """
    Query OpenWebUI's RAG pipeline with optional #collection filtering.

    Parameters
    ----------
    raw_prompt : str
        The full query string, optionally containing a #tag.
        Example: "#js closures explained" or "what is a monad"
    k : int, optional
        Number of results to request (defaults to TOP_K).

    Returns
    -------
    str
        Formatted context string with source annotations, or an error message.
    """
    if not raw_prompt or not raw_prompt.strip():
        return "Error: Empty query string."

    num_results = k or TOP_K

    # -- Parse optional #tag anywhere in the query ---------------------------
    # re.search (not re.match): a #tag is recognized even mid-sentence
    # ("dna #bio_python"), per the edge-case tests. "C#" stays safe — a #
    # must be followed by a word character to count as a tag.
    hashtag_match = re.search(r"#(\w+)", raw_prompt)
    collection_uuid: str | None = None
    collection_tag: str = ""
    actual_resolved_tag: str | None = ""
    used_fuzzy_correction: bool = False
    clean_query: str = raw_prompt.strip()

    if hashtag_match:
        collection_tag = hashtag_match.group(1)
        # Smart resolver: exact match → fuzzy match → explicit error (no auto-global)
        collection_uuid, actual_resolved_tag = _resolve_knowledge_base_smart(collection_tag)
        if collection_uuid and actual_resolved_tag and actual_resolved_tag != collection_tag.lower():
            used_fuzzy_correction = True
        # Remove ONLY the matched tag token so it doesn't pollute embeddings;
        # the rest of the query stays intact even when the tag is mid-sentence.
        clean_query = (
            raw_prompt[:hashtag_match.start()] + raw_prompt[hashtag_match.end():]
        ).strip()

    if not clean_query:
        return "Error: Query is empty after removing #tag. Provide actual search terms."

    # -- Determine collection strategy --------------------------------------
    # Triage: exact tag → fuzzy-corrected tag → agent-directed global (no silent fallback)
    auth_headers = _get_auth_header()

    if collection_uuid:
        collection_names = [collection_uuid]
        action = "fuzzy-corrected" if used_fuzzy_correction else "tagged"
        log.info("%s search in collection #%s", action.title(), actual_resolved_tag or collection_tag)
    elif not hashtag_match:
        # No #tag given → try auto-routing to best KB first
        routed_kb = _auto_route_best(clean_query)
        if routed_kb:
            collection_names = [routed_kb["id"]]
            collection_tag = routed_kb["tag"]  # used in output label
            log.info('Auto-routed "%s" → #%s (score: %.2f)',
                     clean_query[:60], collection_tag, routed_kb["_score"])
        else:
            # Auto-route didn't find a confident match → global search
            kbs = _discover_knowledge_bases()
            collection_names = list(kbs.values())
            if not collection_names:
                return "Error: No knowledge bases discovered. Check OpenWebUI connection."
            log.info("Auto-route: no confident match — global search across %d KBs",
                     len(collection_names))
    else:
        # Tag was given but didn't resolve (exact or fuzzy) → global fallback.
        # Unknown/typo'd tags return results instead of hard-failing; the
        # response label below still marks the query as a global search.
        kbs = _discover_knowledge_bases()
        collection_names = list(kbs.values())
        if not collection_names:
            return "Error: No knowledge bases discovered. Check OpenWebUI connection."
        log.warning("Unknown #%s — falling back to global search across %d KBs",
                    collection_tag, len(collection_names))

    payload: dict[str, Any] = {
        "query": clean_query,
        "collection_names": collection_names,
        "k": num_results,
        "hybrid": HYBRID,
    }

    log.debug("POST %s/retrieval/query/collection  payload=%s",
              OPENWEBUI_URL, json.dumps(payload, default=str))

    # -- Execute ------------------------------------------------------------
    try:
        response = requests.post(
            f"{OPENWEBUI_URL}/api/v1/retrieval/query/collection",
            json=payload,
            headers={"Content-Type": "application/json", **auth_headers},
            timeout=REQUEST_TIMEOUT,
        )
    except Exception as exc:
        exc_name = type(exc).__name__
        if "Connection" in exc_name or "connection" in str(exc).lower():
            return (
                f"Failed to connect to OpenWebUI at {OPENWEBUI_URL}. "
                "Ensure the server is running."
            )
        if "Timeout" in exc_name or "timed out" in str(exc).lower():
            return (
                f"OpenWebUI did not respond within {REQUEST_TIMEOUT}s. "
                "Check server load or increase RAG_TIMEOUT."
            )
        return f"Network error querying OpenWebUI: {exc_name}: {exc}"

    # -- Parse response -----------------------------------------------------
    if response.status_code != 200:
        try:
            detail = response.json().get("detail", response.text)
        except Exception:
            detail = response.text[:500]
        return f"OpenWebUI API Error ({response.status_code}): {detail}"

    try:
        data = response.json()
    except json.JSONDecodeError:
        return "OpenWebUI returned malformed JSON response."

    documents: list[list[str]] = data.get("documents", [])
    metadatas: list[list[dict[str, Any]]] = data.get("metadatas", [])

    # The API returns one inner list per queried collection.
    chunks = documents[0] if documents else []
    metas = metadatas[0] if metadatas else []

    if not chunks:
        return (
            "RAG search completed, but no relevant results met the "
            "relevance threshold. Try broadening your query."
        )

    # -- Compute max relevance score for quality signal ----------------------
    scores = [meta.get("score") for meta in metas if meta.get("score") is not None]
    max_score = max(scores) if scores else 0.0

    # -- Format output ------------------------------------------------------
    resolved_label = actual_resolved_tag or collection_tag or ""
    if used_fuzzy_correction:
        label = f"Auto-corrected #{collection_tag} → #{resolved_label}"
    elif hashtag_match and collection_uuid:
        label = f"#{resolved_label}"
    elif not hashtag_match and collection_tag:
        # Auto-routed — no #tag was given but we selected a KB
        label = f"Auto-routed → #{collection_tag}"
    else:
        label = "Global (all KBs)"
    lines = [f"=== RETRIEVED KNOWLEDGE ({label}) ==="]
    lines.append(f"Source: OpenWebUI RAG (hybrid={HYBRID})")
    if max_score < 0.3:
        # Low relevance signal: warn the agent so it doesn't treat weak results as facts
        lines.append(
            f"[WARNING] Top relevance score is {max_score:.3f} (below 0.3). "
            "These results may be weakly related to your query. "
            "Verify before using as ground truth."
        )
    lines.append("")

    for idx, (chunk, meta) in enumerate(zip(chunks, metas, strict=False)):
        source = (
            meta.get("name")
            or meta.get("source")
            or "Unknown Source"
        )
        score = meta.get("score", None)
        score_str = f" [score={score:.4f}]" if score is not None else ""
        lines.append(f"[{idx + 1}] From: {source}{score_str}")
        lines.append(chunk.strip())
        lines.append("-" * 55)

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def _list_books(tag: str) -> str:
    """
    List all files/books in a specific knowledge base.

    Uses GET /api/v1/knowledge/{uuid}/files (OpenWebUI >= 0.3).
    Falls back to SQLite (webui.db) when the API endpoint is unavailable
    or returns an error — this endpoint is non-standard and may not exist
    in all OpenWebUI versions.
    """
    uuid, _ = _resolve_knowledge_base_smart(tag)
    if not uuid:
        return f"Error: Unknown knowledge base tag '#{tag}'."

    # -- Tier 1: API call (best-effort, may 404 on some versions) ------------
    auth_headers = _get_auth_header()
    items: list[dict[str, Any]] = []
    api_succeeded = False
    try:
        resp = requests.get(
            f"{OPENWEBUI_URL}/api/v1/knowledge/{uuid}/files",
            headers={"Content-Type": "application/json", **auth_headers},
            timeout=REQUEST_TIMEOUT,
        )
        if resp.status_code == 200:
            data = resp.json()
            items = data if isinstance(data, list) else data.get("items") or data.get("data") or []
            api_succeeded = True
    except Exception:
        log.debug("API /knowledge/{uuid}/files failed — trying SQLite fallback", exc_info=True)

    # -- Tier 2: SQLite fallback (local installs only) ------------------------
    if not api_succeeded:
        db_path = Path(OPENWEBUI_DATA_DIR) / "webui.db"
        if db_path.is_file():
            try:
                conn = sqlite3.connect(str(db_path))
                cur = conn.cursor()
                # OpenWebUI stores file metadata in a 'file' table, linked to
                # knowledge via knowledge_id. Schema varies by version.
                cur.execute(
                    "SELECT f.filename, f.data FROM file f "
                    "JOIN knowledge k ON k.id = f.knowledge_id WHERE k.id = ?",
                    (uuid,),
                )
                for filename, data_json in cur.fetchall():
                    data_obj: dict[str, Any] = {}
                    try:
                        data_obj = json.loads(data_json) if isinstance(data_json, str) else {}
                    except (json.JSONDecodeError, TypeError):
                        pass
                    items.append({
                        "filename": filename,
                        "data": data_obj if isinstance(data_obj, dict) else {},
                    })
                conn.close()
                if items:
                    log.info("Listed %d books via SQLite fallback for #%s", len(items), tag)
            except Exception:
                log.debug("SQLite fallback for --books failed", exc_info=True)

    if not items:
        return f"No files found in knowledge base '#{tag}'."

    tag_label = f"#{tag}"
    lines = [f"=== BOOKS IN {tag_label} ==="]
    lines.append(f"Total: {len(items)} items")
    lines.append("")

    # Deduplicate by filename (OpenWebUI sometimes has duplicate entries)
    seen: set[str] = set()
    unique_items = []
    for item in items:
        fn = item.get("filename", "")
        if fn and fn not in seen:
            seen.add(fn)
            unique_items.append(item)

    for idx, item in enumerate(unique_items, 1):
        filename = item.get("filename", "Unknown")
        status = item.get("data", {}).get("status", "unknown")
        content_preview = item.get("data", {}).get("content", "")

        status_icon = "✓" if status == "completed" else ("✗" if status == "failed" else "?")
        lines.append(f"[{idx}] {status_icon} {filename}")

        # Extract brief description from content if available
        if content_preview:
            desc = content_preview.strip().split("\n")[0][:120]
            if desc:
                lines.append(f"      {desc}")
        lines.append("")

    return "\n".join(lines)


def _list_books_all() -> str:
    """
    List books across ALL discovered knowledge bases in a single output.
    Calls _list_books internally for each KB and concatenates results.
    """
    kbs = _discover_knowledge_bases()
    if not kbs:
        return "Error: No knowledge bases discovered."

    sections: list[str] = []
    for tag in sorted(kbs.keys()):
        result = _list_books(tag)
        sections.append(result)
    return "\n".join(sections)


def _stats() -> str:
    """
    Return a compact statistics summary of all knowledge bases.
    """
    kbs = _discover_knowledge_bases()
    if not kbs:
        return "Error: No knowledge bases discovered."

    lines = ["=== KNOWLEDGE BASE STATISTICS ==="]
    lines.append("")
    total_files = 0
    for tag in sorted(kbs.keys()):
        uuid = kbs[tag]
        file_count = 0
        # Try API first, then SQLite
        auth_headers = _get_auth_header()
        try:
            resp = requests.get(
                f"{OPENWEBUI_URL}/api/v1/knowledge/{uuid}/files",
                headers={"Content-Type": "application/json", **auth_headers},
                timeout=REQUEST_TIMEOUT,
            )
            if resp.status_code == 200:
                data = resp.json()
                items = data if isinstance(data, list) else data.get("items") or data.get("data") or []
                file_count = len(set(it.get("filename", "") for it in items if it.get("filename")))
        except Exception:
            pass

        if file_count == 0:
            # SQLite fallback count
            db_path = Path(OPENWEBUI_DATA_DIR) / "webui.db"
            if db_path.is_file():
                try:
                    conn = sqlite3.connect(str(db_path))
                    cur = conn.cursor()
                    cur.execute(
                        "SELECT COUNT(*) FROM file f JOIN knowledge k ON k.id = f.knowledge_id WHERE k.id = ?",
                        (uuid,),
                    )
                    row = cur.fetchone()
                    if row:
                        file_count = int(row[0])
                    conn.close()
                except Exception:
                    pass

        total_files += file_count
        lines.append(f"  #{tag}: {file_count} files")

    lines.append("")
    lines.append(f"Total: {len(kbs)} KBs, {total_files} files")
    return "\n".join(lines)


def main() -> None:
    """CLI entry point."""
    # Ensure stdout can handle Unicode (e.g. math symbols like −) on Windows.
    # reconfigure() is available on standard Python TextIOWrapper but not on
    # all stream types; mypy may flag it as unknown so we use hasattr + try.
    _reconfigure = getattr(sys.stdout, "reconfigure", None)
    if callable(_reconfigure):
        try:
            _reconfigure(encoding="utf-8")
        except Exception:
            pass

    # Parse --refresh as a modifier flag (can appear anywhere in args)
    force_refresh = "--refresh" in sys.argv
    args = [a for a in sys.argv[1:] if a != "--refresh"]

    if not args and not force_refresh:
        print("Error: Missing search query string.", file=sys.stderr)
        print(f"Usage: python {Path(sys.argv[0]).name} \"[#tag] <query>\"", file=sys.stderr)
        print(f"       python {Path(sys.argv[0]).name} --list [--refresh]", file=sys.stderr)
        print(f"       python {Path(sys.argv[0]).name} --route \"<topic>\" [--refresh]", file=sys.stderr)
        print(f"       python {Path(sys.argv[0]).name} --refresh", file=sys.stderr)
        print(f"       python {Path(sys.argv[0]).name} --books #<tag>", file=sys.stderr)
        print(f"       python {Path(sys.argv[0]).name} --books-all", file=sys.stderr)
        print(f"       python {Path(sys.argv[0]).name} --stats", file=sys.stderr)
        print("", file=sys.stderr)
        print("Available #tags:", file=sys.stderr)
        for kb in _list_knowledge_bases():
            tag = kb["tag"]
            desc = kb["description"]
            line = f"  #{tag}"
            if desc:
                line += f"  — {desc}"
            print(line, file=sys.stderr)
        sys.exit(1)

    if force_refresh and not args:
        # --refresh alone: just refresh and confirm
        kbs = get_kb_list(force_refresh=True)
        if kbs:
            print(f"KB cache refreshed — {len(kbs)} KBs cached.")
        else:
            print("Error: Could not refresh KB cache. Check OpenWebUI connection.",
                  file=sys.stderr)
            sys.exit(1)
        return

    if args[0] == "--list":
        if force_refresh:
            get_kb_list(force_refresh=True)
        _list_kb_tags()
        return

    if args[0] == "--route":
        if len(args) < 2:
            print("Error: --route requires a topic string.", file=sys.stderr)
            print(f'Example: python {Path(sys.argv[0]).name} --route "closures and scope"',
                  file=sys.stderr)
            sys.exit(1)
        topic = " ".join(args[1:])
        if force_refresh:
            get_kb_list(force_refresh=True)
        print(_route_topic(topic))
        return

    if args[0] == "--stats":
        print(_stats())
        return

    if args[0] == "--books":
        if len(args) < 2:
            print("Error: --books requires a #tag argument.", file=sys.stderr)
            print("Example: python {} --books #csc".format(Path(sys.argv[0]).name), file=sys.stderr)
            sys.exit(1)
        tag = args[1].lstrip("#")
        print(_list_books(tag))
        return

    if args[0] == "--books-all":
        print(_list_books_all())
        return

    query_string = args[0]
    result = query_hybrid_rag(query_string)
    print(result)


def _list_kb_tags() -> None:
    """Print available KB tags with descriptions and dynamic example queries."""
    kbs = _list_knowledge_bases()
    if not kbs:
        print("No knowledge bases discovered. Check OpenWebUI connection.")
        return

    # Source indicator
    if _cache_was_hit:
        source = f"(cached, age: {_format_age(_cache_age_seconds)})"
    else:
        source = "(fresh)"

    print(f"Available knowledge base tags: {source}")
    print()
    for kb in kbs:
        tag = kb["tag"]
        desc = kb["description"]
        line = f"  #{tag}"
        if desc:
            line += f"  — {desc}"
        print(line)
    print()

    # Dynamic examples — use actual available tags (up to 5)
    script_name = Path(sys.argv[0]).name
    print("Query examples:")
    for kb in kbs[:5]:
        tag = kb["tag"]
        print(f'  python {script_name} "#{tag} <your query>"')
    print(f'  python {script_name} "global search (no tag)"')
    print(f'  python {script_name} --route "<topic>"')


if __name__ == "__main__":
    main()
