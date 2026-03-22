# Jenkins helper: run checkmarx_ai_pr_comment.py with output aligned to github_post_comment.ps1 (ai-pr-comment.md).
param(
    [string]$InputFile = 'checkmarx_input.txt'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if (-not (Test-Path -LiteralPath $InputFile)) {
    throw "Checkmarx input not found: $InputFile"
}

$env:COMMENT_OUTPUT_FILE = 'ai-pr-comment.md'

$python = $null
foreach ($name in @('python', 'py')) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) {
        $python = $cmd.Source
        break
    }
}
if (-not $python) {
    throw 'Python not found on PATH. Install Python 3 or add python/py for the Jenkins agent.'
}

Write-Host "Using Python: $python"
& $python (Join-Path $PSScriptRoot 'checkmarx_ai_pr_comment.py') $InputFile
