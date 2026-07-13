"""
query_web.py — Bridge script for the web-search AI skill.

Queries OpenWebUI's web search engine and returns live results from the internet.

Usage:
    python query_web.py "your search query"
    python query_web.py --help

The script authenticates via OPENWEBUI_API_KEY env var.  If the key is unset,
requests will likely fail (no anonymous web search on OpenWebUI).

Configuration environment variables:
    OPENWEBUI_URL          Base URL of OpenWebUI instance (default: http://localhost:8080)
    OPENWEBUI_API_KEY      API key / JWT token
    WEB_SEARCH_TOP_K       Number of results to fetch (default: 5)
    WEB_SEARCH_TIMEOUT     Request timeout in seconds (default: 30)
    LOG_LEVEL              Python logging level: DEBUG, INFO, WARNING, ERROR (default: WARNING)
"""
from __future__ import annotations

import json
import logging
import os
import sys
from pathlib import Path
from typing import Any

import requests  # type: ignore[import-untyped]

# ---------------------------------------------------------------------------
# Configuration — override via environment variables
# ---------------------------------------------------------------------------

OPENWEBUI_URL = os.getenv("OPENWEBUI_URL", "http://localhost:8080").rstrip("/")

API_KEY = os.getenv("OPENWEBUI_API_KEY", "")

TOP_K = int(os.getenv("WEB_SEARCH_TOP_K", "5"))

REQUEST_TIMEOUT = int(os.getenv("WEB_SEARCH_TIMEOUT", "30"))

logging.basicConfig(
    level=getattr(logging, os.getenv("LOG_LEVEL", "WARNING").upper(), logging.WARNING),
    format="%(levelname)s | %(message)s",
)
log = logging.getLogger("query_web")

# ---------------------------------------------------------------------------
# Authentication
# ---------------------------------------------------------------------------

# Reuse query_rag's JWT minting if available; otherwise just use API key.
# We import lazily to keep this script lightweight — no hard dependency on
# PyJWT or the book-rag script's internals.
_jwt_token: str | None = None


def _get_auth_header() -> dict[str, str]:
    """Return Authorization header from API key, or attempt JWT fallback.

    If OPENWEBUI_API_KEY is set, it is used directly as a Bearer token.
    Otherwise we try to import query_rag's JWT keyfile minting.  This keeps
    the web-search script self-contained while still benefiting from local
    dev convenience (auto-minting from the server .key file).
    """
    if API_KEY:
        return {"Authorization": f"Bearer {API_KEY}"}

    global _jwt_token
    if _jwt_token is None:
        # Attempt to steal JWT from the book-rag module (if installed)
        try:
            # Use importlib to avoid hard dependency on query_rag
            from importlib import import_module

            qrag = import_module("query_rag")
            _jwt_token = qrag._get_jwt_from_keyfile()
        except Exception:
            _jwt_token = ""  # Don't retry

    if _jwt_token:
        return {"Authorization": f"Bearer {_jwt_token}"}

    log.warning("No API key set — web search request will likely fail")
    return {}


# ---------------------------------------------------------------------------
# Core search function
# ---------------------------------------------------------------------------

# The expected response envelope from OpenWebUI /api/v1/retrieval/web/search
# {
#   "documents": [
#       {"url": "...", "content": "...", "title": "..."},
#       ...
#   ]
# }
# Older versions may return {"results": [...]} or {"items": [...]}.
# We normalise all three shapes.


def search_web(
    query: str,
    k: int | None = None,
) -> str:
    """Run a live web search through OpenWebUI and return formatted results.

    Parameters
    ----------
    query : str
        The search query string.
    k : int, optional
        Number of top results to request (defaults to *TOP_K*).

    Returns
    -------
    str
        Formatted result string with sources, or an error message.
    """
    if not query or not query.strip():
        return "Error: Empty search query."

    num_results = k or TOP_K

    # -- Build payload ----------------------------------------------------------
    # OpenWebUI web search accepts a simple query + k payload.  Some versions
    # also support a `type` field ("web", "news", "scholar") — we default to
    # "web" which is the standard web search.
    payload: dict[str, Any] = {
        "query": query.strip(),
        "k": num_results,
    }

    auth_headers = _get_auth_header()
    headers = {"Content-Type": "application/json", **auth_headers}

    log.debug("POST %s/api/v1/retrieval/web/search  payload=%s",
              OPENWEBUI_URL, json.dumps(payload, default=str))

    # -- Execute ----------------------------------------------------------------
    try:
        response = requests.post(
            f"{OPENWEBUI_URL}/api/v1/retrieval/web/search",
            json=payload,
            headers=headers,
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
                "Check server load or increase WEB_SEARCH_TIMEOUT."
            )
        return f"Network error querying OpenWebUI: {exc_name}: {exc}"

    # -- Parse response ---------------------------------------------------------
    if response.status_code != 200:
        try:
            detail = response.json().get("detail", response.text)
        except Exception:
            detail = response.text[:500]
        return f"OpenWebUI API Error ({response.status_code}): {detail}"

    try:
        data = response.json()
    except (json.JSONDecodeError, ValueError):
        return "OpenWebUI returned malformed JSON response."

    # Normalise different response shapes
    documents: list[dict[str, Any]] = []
    if "documents" in data and isinstance(data["documents"], list):
        # Shape 1: {"documents": [{"url": ..., "content": ..., ...}, ...]}
        documents = data["documents"]
    elif "results" in data and isinstance(data["results"], list):
        # Shape 2: {"results": [{"url": ..., "content": ..., ...}, ...]}
        documents = data["results"]
    elif "items" in data and isinstance(data["items"], list):
        # Shape 3: {"items": [{"link": ..., "snippet": ..., ...}, ...]}
        documents = data["items"]

    if not documents:
        return (
            "Web search completed, but no results were returned. "
            "Try a different query or check OpenWebUI web search configuration."
        )

    # -- Format output ----------------------------------------------------------
    lines = [
        "=== LIVE WEB SEARCH RESULTS ===",
        f"Source: OpenWebUI web search ({OPENWEBUI_URL})",
        f"Query: {query.strip()}",
        "",  # blank line separator
    ]

    for idx, doc in enumerate(documents, 1):
        # Normalise field names: OpenWebUI may use 'url' or 'link' for the URL,
        # and 'content', 'snippet', or 'text' for the body.
        title = doc.get("title") or ""
        url = doc.get("url") or doc.get("link") or ""
        content = (
            doc.get("content")
            or doc.get("snippet")
            or doc.get("text")
            or ""
        )

        lines.append(f"[{idx}] {title}" if title else f"[{idx}]")
        if url:
            lines.append(f"     URL: {url}")
        if content:
            # Strip excessive whitespace and truncate to keep output clean
            cleaned = " ".join(content.split())
            if len(cleaned) > 600:
                cleaned = cleaned[:600] + "…"
            lines.append(f"     {cleaned}")
        lines.append("─" * 60)

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------


def main() -> None:
    """CLI entry point."""
    # Unicode support for Windows terminal
    _reconfigure = getattr(sys.stdout, "reconfigure", None)
    if callable(_reconfigure):
        try:
            _reconfigure(encoding="utf-8")
        except Exception:
            pass

    if len(sys.argv) < 2 or sys.argv[1] in ("--help", "-h"):
        script_name = Path(sys.argv[0]).name
        print(f"Usage: python {script_name} [--top-k N] <search query>")
        print(f"       python {script_name} --help")
        print("")
        print("Environment variables:")
        print("  OPENWEBUI_URL         OpenWebUI base URL (default: http://localhost:8080)")
        print("  OPENWEBUI_API_KEY     API key / Bearer token")
        print("  WEB_SEARCH_TOP_K      Results count (default: 5)")
        print("  WEB_SEARCH_TIMEOUT    Request timeout in seconds (default: 30)")
        print("  LOG_LEVEL             Logging level: DEBUG|INFO|WARNING|ERROR (default: WARNING)")
        print("")
        print("Examples:")
        print(f'  python {script_name} "latest Python 3.13 features"')
        print(f'  python {script_name} --top-k 10 "TypeScript 5.8 release notes"')
        sys.exit(0 if sys.argv[1:] else 1)

    # Parse optional --top-k flag
    query_parts: list[str] = []
    top_k_override: int | None = None
    i = 1
    while i < len(sys.argv):
        if sys.argv[i] == "--top-k" and i + 1 < len(sys.argv):
            try:
                top_k_override = int(sys.argv[i + 1])
                i += 2
                continue
            except ValueError:
                pass  # treat as part of query
        query_parts.append(sys.argv[i])
        i += 1

    if not query_parts:
        print("Error: Missing search query string.", file=sys.stderr)
        sys.exit(1)

    query_string = " ".join(query_parts)
    result = search_web(query_string, k=top_k_override)
    print(result)

    # Exit with non-zero if result is an error message
    if result.startswith("Error:") or result.startswith("Failed") or result.startswith("OpenWebUI"):
        sys.exit(1)


if __name__ == "__main__":
    main()
