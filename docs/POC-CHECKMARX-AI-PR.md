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

## Jenkins (same POC flow)

Pipeline **`jenkinsfile`** follows the same minimum path on the agent:

1. **Checkout** (`checkout scm` — use a **Multibranch Pipeline** or job where the SCM ref is the PR so `CHANGE_ID` / branch resolution works).
2. **Build** (Maven).
3. **Prepare Checkmarx findings** → `checkmarx_input.txt` from optional Jenkins secret text credential **`checkmarx-output`**, or from **`checkmarx-poc/sample-findings.txt`** if that credential is missing.
4. **Checkmarx scan** — placeholder step; replace with your Checkmarx plugin/CLI and have it **write/update `checkmarx_input.txt`** with the error/export text.
5. **AI PR comment from Checkmarx** — `scripts/run_checkmarx_ai_jenkins.ps1` runs **`scripts/checkmarx_ai_pr_comment.py`**, then **`scripts/github_post_comment.ps1`** posts **`ai-pr-comment.md`** on the PR.

Jenkins credentials (IDs must match):

| Credential ID | Type | Required |
|---------------|------|----------|
| `openai-api-key` | Secret text | Yes |
| `github-token` | Secret text (PAT, `repo` + PR comment) | Yes |
| `checkmarx-output` | Secret text (Checkmarx export) | No (sample used if absent) |
| `sonar-token` | Secret text | Yes for Sonar stage |

**Agent:** **Python 3** on `PATH` (`python` or `py`) is optional. If Python is missing, Jenkins uses **`checkmarx_to_openai_prompt.ps1`** + **`openai_call.ps1`** (same prompt shape as the Python script). Sonar runs **after** the Checkmarx/AI path so a down Sonar server does not block the security-comment POC.

## Local test (optional)

```bash
export OPENAI_API_KEY=sk-...
cp checkmarx-poc/sample-findings.txt checkmarx_input.txt
python3 scripts/checkmarx_ai_pr_comment.py
cat comment.md
```
