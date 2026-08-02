# Secrets for the dev container

Place one secret per file. Filenames must match the whitelist in
`dev-entrypoint.sh`. The entrypoint loads them into env vars at container start.

Example:

```bash
echo "sk-ant-..." > secrets/anthropic_api_key
echo "sk-..."      > secrets/openai_api_key
echo "c7-..."      > secrets/context7_api_key
echo "ghp_..."     > secrets/github_token
echo "sk-..."      > secrets/exa_api_key
```

These files are mounted read-only into the container at `/run/secrets` and are
excluded from git via `.gitignore`. Never commit real secrets.

## File permissions

Secret files should be `0600` (owner read/write only) to prevent other users on
the host from reading them:

```bash
chmod 600 secrets/anthropic_api_key
```

Secret files must be non-empty. Empty files result in empty env vars (the
entrypoint loads the file content verbatim).

## Allowed filenames (from dev-entrypoint.sh)

| File | Env var injected |
|------|------------------|
| `anthropic_api_key` | `ANTHROPIC_API_KEY` |
| `openai_api_key` | `OPENAI_API_KEY` |
| `context7_api_key` | `CONTEXT7_API_KEY` |
| `github_token` | `GITHUB_TOKEN` |
| `exa_api_key` | `EXA_API_KEY` |

Any other file placed here is ignored — the entrypoint and profile script load
only the five whitelisted names above. (The AWS/GCP names were removed in M2 —
no service mounts or uses them; re-add to the whitelist and
`docker-compose.yml` in the same change if a future service needs them.)
