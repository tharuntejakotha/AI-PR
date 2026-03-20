# POC: Git push → PR → Checkmarx-style input → AI → PR comment

## Minimum flow (implemented)

1. Developer pushes and opens/updates a **pull request**.
2. GitHub Actions workflow **`.github/workflows/pr-ai-security-comment.yml`** runs.
3. **Checkmarx payload** is taken from:
   - Repository secret **`CHECKMARX_OUTPUT`** (paste/export from Checkmarx), **or**
   - If unset, **`checkmarx-poc/sample-findings.txt`** (demo only).
4. Script **`scripts/checkmarx_ai_pr_comment.py`** sends that text to **OpenAI** and asks for a PR comment in this shape:
   - 🔴 Issue  
   - ⚠️ Risk  
   - ✅ Fix (with code snippet)  
   - 💡 Recommendation  
5. The workflow posts the result as a **comment on the same PR**.

## GitHub setup

| Secret | Required | Purpose |
|--------|----------|---------|
| `OPENAI_API_KEY` | **Yes** | OpenAI API |
| `CHECKMARX_OUTPUT` | No | Real Checkmarx export text; if missing, sample file is used |

**Repo → Settings → Secrets and variables → Actions → New repository secret**

## Next step (real Checkmarx)

- Trigger Checkmarx on PR (Checkmarx GitHub integration / your existing scan).
- When the scan finishes, either:
  - **CI job** writes findings to a file and sets `CHECKMARX_OUTPUT` from that artifact (e.g. upload then download in a dependent workflow), or  
  - **Webhook** receives Checkmarx results and calls GitHub API / `workflow_dispatch` with payload.

This repo implements the **middle + end** of the chain (payload → AI → PR comment). Wiring Checkmarx’s own trigger/export is product-specific.

## Local test (optional)

```bash
export OPENAI_API_KEY=sk-...
cp checkmarx-poc/sample-findings.txt checkmarx_input.txt
python3 scripts/checkmarx_ai_pr_comment.py
cat comment.md
```
