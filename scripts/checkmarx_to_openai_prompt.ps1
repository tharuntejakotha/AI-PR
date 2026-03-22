# Builds ai-pr-prompt.txt from Checkmarx-style text (same intent as checkmarx_ai_pr_comment.py user message).
param(
    [string]$InputFile = 'checkmarx_input.txt',
    [string]$OutPrompt = 'ai-pr-prompt.txt'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $InputFile)) {
    throw "Checkmarx input not found: $InputFile"
}

$checkmarxOutput = (Get-Content -Raw -LiteralPath $InputFile -Encoding UTF8).Trim()
if ([string]::IsNullOrWhiteSpace($checkmarxOutput)) {
    throw 'Checkmarx input is empty.'
}

# Match scripts/checkmarx_ai_pr_comment.py user prompt (emoji written at runtime, UTF-8 file).
$user = @"
Generate a GitHub PR comment for the following security issue.

Include:
🔴 Issue
⚠️ Risk
✅ Fix (with code snippet)
💡 Recommendation

Keep formatting clean using markdown.

Input:
$checkmarxOutput
"@

Set-Content -LiteralPath $OutPrompt -Value $user -Encoding UTF8
Write-Host "Wrote OpenAI user prompt to $OutPrompt"
