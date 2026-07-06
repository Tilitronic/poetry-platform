# $30 Preset

This preset is for people who want a strong setup built around **Codex Plus ($20/month)** and **GitHub Copilot Pro ($10/month)**.

It uses Codex Plus for the OpenAI models and GitHub Copilot for the premium design models, giving you a mixed-provider setup for about **$30/month total**.

---

## The Config

```jsonc
{
    "preset": "thirtydollars",
    "presets": {
      "thirtydollars": { "orchestrator": { "model": "openai/gpt-5.5", "variant": "medium", "skills": [ "*" ], "mcps": [ "*", "websearch"] },
        "oracle": { "model": "openai/gpt-5.5", "variant": "high", "skills": [], "mcps": [] },
        "librarian": { "model": "openai/gpt-5.4-mini", "variant": "low", "skills": [], "mcps": [ "websearch", "context7", "gh_grep" ] },
        "explorer": { "model": "openai/gpt-5.4-mini", "variant": "low", "skills": [], "mcps": [] },
        "designer": { "model": "github-copilot/gemini-3.5-flash", "skills": [], "mcps": [] },
        "fixer": { "model": "openai/gpt-5.5", "variant": "low", "skills": [], "mcps": [] }
      }
    }
  }
```
