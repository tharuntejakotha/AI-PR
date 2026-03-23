#!/usr/bin/env python3
"""
Minimum POC: read Checkmarx-style text, call OpenAI, write GitHub PR comment body (markdown).
"""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request


def read_input(path: str) -> str:
    with open(path, encoding="utf-8") as f:
        return f.read().strip()


def call_openai(api_key: str, checkmarx_output: str) -> str:
    system = (
        "You write concise GitHub pull request comments for security findings. "
        "Use exactly the user's required section headers and emoji. "
        "Output valid markdown only, no code fences around the whole comment."
    )
    user = f"""Generate a GitHub PR comment for the following security issue.

Include:
🔴 Issue
⚠️ Risk
✅ Fix (with code snippet)
💡 Recommendation

Keep formatting clean using markdown.

Input:
{checkmarx_output}
"""
    body = {
        "model": os.environ.get("OPENAI_MODEL", "gpt-4.1-mini"),
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "temperature": 0.2,
    }
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        "https://api.openai.com/v1/chat/completions",
        data=data,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        payload = json.load(resp)
    choices = payload.get("choices") or []
    if not choices:
        raise RuntimeError(f"Unexpected OpenAI response: {payload}")
    content = choices[0].get("message", {}).get("content") or ""
    return content.strip()


def main() -> int:
    api_key = os.environ.get("OPENAI_API_KEY", "").strip()
    if not api_key:
        print("OPENAI_API_KEY is not set", file=sys.stderr)
        return 1

    in_path = os.environ.get("CHECKMARX_INPUT_FILE", "checkmarx_input.txt")
    if len(sys.argv) > 1:
        in_path = sys.argv[1]
    if not os.path.isfile(in_path):
        print(f"Input file not found: {in_path}", file=sys.stderr)
        return 1

    out_path = os.environ.get("COMMENT_OUTPUT_FILE", "comment.md")
    checkmarx_output = read_input(in_path)
    if not checkmarx_output:
        print("Checkmarx input is empty", file=sys.stderr)
        return 1

    comment = call_openai(api_key, checkmarx_output)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(comment)
        f.write("\n")

    print(f"Wrote PR comment body to {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
