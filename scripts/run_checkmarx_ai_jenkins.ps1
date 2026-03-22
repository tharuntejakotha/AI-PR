# Jenkins helper: Checkmarx text -> OpenAI -> ai-pr-comment.md (same end state as GitHub Actions).
# Prefers Python (parity with checkmarx_ai_pr_comment.py); falls back to PowerShell if python/py is missing.
param(
    [string]$InputFile = 'checkmarx_input.txt'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if (-not (Test-Path -LiteralPath $InputFile)) {
    throw "Checkmarx input not found: $InputFile"
}

$python = $null
foreach ($name in @('python', 'py')) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) {
        $python = $cmd.Source
        break
    }
}

if ($python) {
    $env:COMMENT_OUTPUT_FILE = 'ai-pr-comment.md'
    Write-Host "Using Python: $python"
    & $python (Join-Path $PSScriptRoot 'checkmarx_ai_pr_comment.py') $InputFile
    return
}

Write-Host 'Python not on PATH; using PowerShell path (checkmarx_to_openai_prompt.ps1 + openai_call.ps1).'
& (Join-Path $PSScriptRoot 'checkmarx_to_openai_prompt.ps1') -InputFile $InputFile
Write-Host 'Starting openai_call.ps1 (network call to OpenAI; console may pause up to the configured timeout).'
try { [Console]::Out.Flush() } catch { }
& (Join-Path $PSScriptRoot 'openai_call.ps1')
