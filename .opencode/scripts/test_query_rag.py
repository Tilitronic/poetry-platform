"""
Tests for query_rag.py — the bridge script for the book-rag AI skill.

Covers:
  - Dynamic knowledge base discovery (API + SQLite fallback)
  - #tag parsing and UUID resolution
  - Request building (endpoint, payload, auth)
  - Response parsing and formatting
  - Error handling (network failures, API errors, malformed responses)
  - CLI entry point
"""
from __future__ import annotations

import json
import os
import sys
import subprocess
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

SCRIPT_DIR = Path(__file__).parent.resolve()
sys.path.insert(0, str(SCRIPT_DIR))

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

AUTH_HEADER = {"Authorization": "Bearer test-key-12345", "Content-Type": "application/json"}

TEST_KBS = {
    "core_cs":   "79e8da72-4555-4b8e-8ee5-a045f64ebc81",
    "js":        "704eb50c-3913-4b51-82e9-117e58c69573",
    "ml":        "0e85dc4d-99d2-481e-8d1e-d3569595549c",
    "python":    "df18f6fe-f738-4f21-8e0a-c1a156607ec5",
    "rust":      "a4a36f73-f47b-4164-a854-c492e2706ce7",
    "biopython": "7e48bc87-5748-4adb-b75c-e5ec023b0430",
}


@pytest.fixture(autouse=True)
def _patch_env_and_kb_cache(monkeypatch):
    """Isolate tests from real config and reset KB cache."""
    monkeypatch.setenv("OPENWEBUI_URL", "http://localhost:9999")
    monkeypatch.setenv("OPENWEBUI_API_KEY", "test-key-12345")
    monkeypatch.setenv("OPENWEBUI_DATA_DIR", "C:\\nonexistent\\data")
    monkeypatch.setenv("RAG_HYBRID", "true")
    monkeypatch.setenv("RAG_TOP_K", "3")
    monkeypatch.setenv("RAG_TIMEOUT", "10")
    monkeypatch.setenv("LOG_LEVEL", "CRITICAL")

    # Force fresh import
    for mod in list(sys.modules.keys()):
        if "query_rag" in mod:
            del sys.modules[mod]

    # Reset the cache in the freshly-imported module
    import query_rag as qr_mod
    qr_mod._KB_CACHE = None


@pytest.fixture
def qr():
    """Convenience: freshly-imported query_rag module with mocked KB discovery."""
    import query_rag as m
    with patch.object(m, "_discover_knowledge_bases", return_value=dict(TEST_KBS)):
        # Also reset the cache marker so our mock is used
        m._KB_CACHE = TEST_KBS
        yield m


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def make_response(status_code=200, json_data=None, text=""):
    """Build a minimal requests-like response object."""
    class _FakeResponse:
        def __init__(self, sc, jd, txt):
            self.status_code = sc
            self._jd = jd
            self._txt = txt
        def json(self):
            return self._jd
        @property
        def text(self):
            return self._txt
    return _FakeResponse(status_code, json_data or {}, text)


# ---------------------------------------------------------------------------
# Dynamic KB discovery
# ---------------------------------------------------------------------------

class TestKnowledgeBaseDiscovery:
    """Verify that KBs are discovered from API and SQLite fallback.
    These tests import the module FRESH (no qr fixture that mocks discovery)."""

    def _fresh_query_rag(self):
        """Force a re-import of query_rag for discovery tests."""
        for mod in list(sys.modules.keys()):
            if "query_rag" in mod:
                del sys.modules[mod]
        # Re-apply env
        import query_rag as m
        m._KB_CACHE = None
        return m

    def test_discovery_from_api(self, monkeypatch):
        """API returns KB list → discovery populates cache."""
        monkeypatch.setenv("OPENWEBUI_URL", "http://localhost:9999")
        monkeypatch.setenv("OPENWEBUI_API_KEY", "test-key")
        monkeypatch.setenv("OPENWEBUI_DATA_DIR", "C:\\nonexistent")
        m = self._fresh_query_rag()
        api_response = {
            "items": [
                {"id": "abc-123", "name": "my_kb", "description": "test KB"},
            ]
        }
        with patch.object(m.requests, "get") as mock_get:
            mock_get.return_value = make_response(200, api_response)
            kbs = m._discover_knowledge_bases()
        assert kbs["my_kb"] == "abc-123"
        assert len(kbs) == 1

    def test_discovery_uses_data_field(self, monkeypatch):
        """API returns {data: [...]} → still parsed correctly."""
        monkeypatch.setenv("OPENWEBUI_URL", "http://localhost:9999")
        monkeypatch.setenv("OPENWEBUI_API_KEY", "test-key")
        m = self._fresh_query_rag()
        with patch.object(m.requests, "get") as mock_get:
            mock_get.return_value = make_response(200, {"data": [{"id": "xyz-789", "name": "data_kb"}]})
            kbs = m._discover_knowledge_bases()
        assert kbs["data_kb"] == "xyz-789"

    def test_discovery_api_flat_list(self, monkeypatch):
        """API returns a bare list → handled."""
        monkeypatch.setenv("OPENWEBUI_URL", "http://localhost:9999")
        monkeypatch.setenv("OPENWEBUI_API_KEY", "test-key")
        m = self._fresh_query_rag()
        with patch.object(m.requests, "get") as mock_get:
            mock_get.return_value = make_response(200, [{"id": "list-1", "name": "list_kb"}])
            kbs = m._discover_knowledge_bases()
        assert kbs["list_kb"] == "list-1"

    def test_discovery_empty_api_then_sqlite(self, monkeypatch, tmp_path):
        """API returns empty → falls back to SQLite."""
        db_dir = tmp_path / "data"
        db_dir.mkdir()
        db_path = db_dir / "webui.db"
        conn = __import__("sqlite3").connect(str(db_path))
        conn.execute("CREATE TABLE knowledge (id TEXT, name TEXT)")
        conn.execute("INSERT INTO knowledge VALUES ('sql-uuid', 'sql_kb')")
        conn.commit()
        conn.close()

        monkeypatch.setenv("OPENWEBUI_URL", "http://localhost:9999")
        monkeypatch.setenv("OPENWEBUI_API_KEY", "test-key")
        monkeypatch.setenv("OPENWEBUI_DATA_DIR", str(db_dir))
        m = self._fresh_query_rag()

        with patch.object(m.requests, "get") as mock_get:
            mock_get.return_value = make_response(200, {"items": []})
            kbs = m._discover_knowledge_bases()
        assert kbs["sql_kb"] == "sql-uuid"

    def test_discovery_returns_cached(self, monkeypatch):
        """Second call returns cached result without hitting API."""
        monkeypatch.setenv("OPENWEBUI_URL", "http://localhost:9999")
        monkeypatch.setenv("OPENWEBUI_API_KEY", "test-key")
        m = self._fresh_query_rag()
        m._KB_CACHE = {"cached": "cached-uuid"}
        with patch.object(m.requests, "get") as mock_get:
            kbs = m._discover_knowledge_bases()
            mock_get.assert_not_called()
        assert kbs["cached"] == "cached-uuid"

    def test_discovery_list(self, monkeypatch):
        """_list_knowledge_bases returns formatted entries."""
        monkeypatch.setenv("OPENWEBUI_URL", "http://localhost:9999")
        monkeypatch.setenv("OPENWEBUI_API_KEY", "test-key")
        m = self._fresh_query_rag()
        with patch.object(m.requests, "get") as mock_get:
            mock_get.return_value = make_response(200, {
                "items": [
                    {"id": "abc", "name": "test_kb", "description": "some desc"},
                ]
            })
            lst = m._list_knowledge_bases()
        assert lst[0]["tag"] == "test_kb"
        assert lst[0]["description"] == "some desc"


# ---------------------------------------------------------------------------
# Hashtag parsing
# ---------------------------------------------------------------------------

class TestHashtagParsing:
    def test_no_hashtag(self, qr):
        """No #tag → global search with all KB UUIDs, query unchanged."""
        import query_rag as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, {"documents": [], "metadatas": []})
            m.query_hybrid_rag("what is a decorator")
            call_kwargs = mock_req.post.call_args.kwargs
            all_uuids = list(TEST_KBS.values())
            assert call_kwargs["json"]["collection_names"] == all_uuids
            assert call_kwargs["json"]["query"] == "what is a decorator"

    def test_simple_hashtag(self, qr):
        """#js → collection_names = [js UUID], hashtag stripped."""
        import query_rag as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, {"documents": [], "metadatas": []})
            m.query_hybrid_rag("#js closures explained")
            call_kwargs = mock_req.post.call_args.kwargs
            assert call_kwargs["json"]["collection_names"] == [TEST_KBS["js"]]
            assert call_kwargs["json"]["query"] == "closures explained"

    def test_hashtag_only_no_query(self, qr):
        """Only #tag → error message, not sent to API."""
        import query_rag as m
        with patch.object(m, "requests") as mock_req:
            result = m.query_hybrid_rag("#python")
            assert mock_req.post.call_count == 0
            assert "Error" in result

    def test_csharp_not_parsed(self, qr):
        """'C#' should NOT be treated as a hashtag (no \\w after #)."""
        import query_rag as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, {"documents": [], "metadatas": []})
            m.query_hybrid_rag("How does C# handle async?")
            call_kwargs = mock_req.post.call_args.kwargs
            all_uuids = list(TEST_KBS.values())
            assert call_kwargs["json"]["collection_names"] == all_uuids
            assert "C#" in call_kwargs["json"]["query"]

    def test_multiple_hashtags(self, qr):
        """Multiple #tags → first one wins, all stripped."""
        import query_rag as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, {"documents": [], "metadatas": []})
            m.query_hybrid_rag("#python #javascript generators")
            call_kwargs = mock_req.post.call_args.kwargs
            assert call_kwargs["json"]["collection_names"] == [TEST_KBS["python"]]
            assert "#python" not in call_kwargs["json"]["query"]

    def test_unknown_hashtag(self, qr):
        """Unknown #tag → no fuzzy match → falls back to global search."""
        import query_rag as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, {"documents": [], "metadatas": []})
            m.query_hybrid_rag("#unknowncollection some query")
            call_kwargs = mock_req.post.call_args.kwargs
            # Falls back to all KB UUIDs
            all_uuids = list(TEST_KBS.values())
            assert call_kwargs["json"]["collection_names"] == all_uuids


# ---------------------------------------------------------------------------
# Authentication
# ---------------------------------------------------------------------------

class TestAuthentication:
    def test_api_key_from_env(self, qr):
        """OPENWEBUI_API_KEY env var → used as Bearer token."""
        import query_rag as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, {"documents": [], "metadatas": []})
            m.query_hybrid_rag("test")
            auth = mock_req.post.call_args.kwargs["headers"].get("Authorization", "")
            assert auth == "Bearer test-key-12345"

    def test_no_api_key_no_keyfile(self, qr):
        """No API key and no .key file → no Authorization header sent."""
        import query_rag as m
        with patch.object(m, "API_KEY", ""):
            with patch.object(m, "_get_jwt_from_keyfile", return_value=None):
                with patch.object(m, "requests") as mock_req:
                    mock_req.post.return_value = make_response(200, {"documents": [], "metadatas": []})
                    m.query_hybrid_rag("test")
                    headers = mock_req.post.call_args.kwargs["headers"]
                    assert "Authorization" not in headers or not headers["Authorization"]


# ---------------------------------------------------------------------------
# Request building
# ---------------------------------------------------------------------------

class TestRequestBuilding:
    def test_correct_endpoint(self, qr):
        """Should POST to /api/v1/retrieval/query/collection."""
        import query_rag as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, {"documents": [], "metadatas": []})
            m.query_hybrid_rag("test")
            url = mock_req.post.call_args.args[0]
            assert "retrieval/query/collection" in url

    def test_hybrid_flag(self, qr):
        """RAG_HYBRID=true → payload includes hybrid: True."""
        import query_rag as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, {"documents": [], "metadatas": []})
            m.query_hybrid_rag("test")
            assert mock_req.post.call_args.kwargs["json"]["hybrid"] is True

    def test_top_k_default(self, qr):
        """RAG_TOP_K=3 → k=3."""
        import query_rag as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, {"documents": [], "metadatas": []})
            m.query_hybrid_rag("test")
            assert mock_req.post.call_args.kwargs["json"]["k"] == 3

    def test_custom_top_k(self, qr):
        """Pass k parameter overrides default."""
        import query_rag as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, {"documents": [], "metadatas": []})
            m.query_hybrid_rag("test", k=10)
            assert mock_req.post.call_args.kwargs["json"]["k"] == 10

    def test_no_kbs_discovered(self, qr):
        """No KBs discovered and no tag → error."""
        import query_rag as m
        with patch.object(m, "_discover_knowledge_bases", return_value={}):
            result = m.query_hybrid_rag("test")
            assert "No knowledge bases discovered" in result


# ---------------------------------------------------------------------------
# Response parsing
# ---------------------------------------------------------------------------

class TestResponseParsing:
    def test_success_with_results(self, qr):
        """200 with documents → formatted context string."""
        import query_rag as m
        fake_data = {
            "documents": [["Python supports decorators.", "@decorator syntax is sugar."]],
            "metadatas": [[{"name": "python_book.txt", "score": 0.95},
                          {"name": "python_book.txt", "score": 0.88}]],
        }
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, fake_data)
            result = m.query_hybrid_rag("decorators")
        assert "RETRIEVED KNOWLEDGE" in result
        assert "python_book.txt" in result
        assert "Python supports decorators." in result

    def test_success_no_results(self, qr):
        """200 with empty results → no-results message."""
        import query_rag as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, {"documents": [], "metadatas": []})
            result = m.query_hybrid_rag("obscure")
        assert "no relevant results" in result.lower()

    def test_api_error_401(self, qr):
        """401 → error message with status code and detail."""
        import query_rag as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(401, {"detail": "Not authenticated"})
            result = m.query_hybrid_rag("test")
        assert "API Error (401)" in result
        assert "Not authenticated" in result

    def test_api_error_plain_text(self, qr):
        """Non-JSON error body → plain text is included."""
        import query_rag as m
        resp = MagicMock()
        resp.status_code = 502
        resp.text = "<html>Bad Gateway</html>"
        resp.json.side_effect = ValueError("not json")
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = resp
            result = m.query_hybrid_rag("test")
        assert "API Error (502)" in result

    def test_connection_error(self, qr):
        """Connection refused → friendly message."""
        import query_rag as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.side_effect = ConnectionRefusedError("Connection refused")
            result = m.query_hybrid_rag("test")
        assert "Failed to connect" in result

    def test_timeout(self, qr):
        """Timeout → specific message."""
        import query_rag as m
        import requests as real_requests
        with patch.object(m, "requests") as mock_req:
            mock_req.post.side_effect = real_requests.exceptions.Timeout("timed out")
            result = m.query_hybrid_rag("test")
        assert "did not respond within" in result

    def test_missing_documents_key(self, qr):
        """Response missing 'documents' key → handled gracefully."""
        import query_rag as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, {"metadatas": []})
            result = m.query_hybrid_rag("test")
        assert "no relevant results" in result.lower()

    def test_empty_document_list(self, qr):
        """Empty document list → handled gracefully."""
        import query_rag as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, {"documents": [[]], "metadatas": [[]]})
            result = m.query_hybrid_rag("test")
        assert "no relevant results" in result.lower()

    def test_source_fallback(self, qr):
        """Metadata without 'name' → fallback to 'source'."""
        import query_rag as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, {
                "documents": [["content"]],
                "metadatas": [[{"source": "fallback_doc.txt"}]]
            })
            result = m.query_hybrid_rag("test")
        assert "fallback_doc.txt" in result

    def test_no_metadata_at_all(self, qr):
        """No metadata per chunk → Unknown Source."""
        import query_rag as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, {
                "documents": [["content"]],
                "metadatas": [[{}]]
            })
            result = m.query_hybrid_rag("test")
        assert "Unknown Source" in result


# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

class TestEdgeCases:
    def test_empty_string(self, qr):
        """Empty string → immediate error."""
        import query_rag as m
        with patch.object(m, "requests") as mock_req:
            result = m.query_hybrid_rag("")
        assert mock_req.post.call_count == 0
        assert "Error" in result

    def test_whitespace_only(self, qr):
        """Whitespace only → immediate error."""
        import query_rag as m
        with patch.object(m, "requests") as mock_req:
            result = m.query_hybrid_rag("   ")
        assert mock_req.post.call_count == 0
        assert "Error" in result

    def test_very_long_query(self, qr):
        """Long query → still sent successfully."""
        import query_rag as m
        long_q = "what " * 500 + "#docs"
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, {"documents": [], "metadatas": []})
            m.query_hybrid_rag(long_q)
            assert len(mock_req.post.call_args.kwargs["json"]["query"]) > 0

    def test_hashtag_with_digits(self, qr):
        """#py3 → no fuzzy match (not 50% similar to any KB) → global fallback."""
        import query_rag as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, {"documents": [], "metadatas": []})
            m.query_hybrid_rag("#py3 async")
            all_uuids = list(TEST_KBS.values())
            assert mock_req.post.call_args.kwargs["json"]["collection_names"] == all_uuids

    def test_hashtag_with_underscore(self, qr):
        """#bio_python → fuzzy matched to biopython (they share 10/11 chars)."""
        import query_rag as m
        with patch.object(m, "requests") as mock_req:
            mock_req.post.return_value = make_response(200, {"documents": [], "metadatas": []})
            m.query_hybrid_rag("dna #bio_python")
            # Fuzzy matcher corrects bio_python → biopython → biopython UUID
            assert mock_req.post.call_args.kwargs["json"]["collection_names"] == [TEST_KBS["biopython"]]


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

class TestCliEntryPoint:
    def test_cli_missing_args(self):
        """No arguments → exit code 1 + error message."""
        result = subprocess.run(
            [sys.executable, str(SCRIPT_DIR / "query_rag.py")],
            capture_output=True, text=True, timeout=30,
        )
        assert result.returncode == 1
        assert "Error: Missing search query string." in result.stdout + result.stderr

    def test_cli_with_query(self):
        """With a query → runs without crashing."""
        result = subprocess.run(
            [sys.executable, str(SCRIPT_DIR / "query_rag.py"), "test query"],
            capture_output=True, text=True, timeout=30,
        )
        assert result.returncode == 0


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
