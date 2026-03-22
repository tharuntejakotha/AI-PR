# Resolves GitHub PR number for Jenkins post-build commenting.
# Prefers CHANGE_ID / ghprbPullId; otherwise looks up open PR by head ref (owner:branch).
# Prints only the PR number to stdout (for returnStdout). Logs go to Write-Host.

param(
    [string]$Owner = 'tharuntejakotha',
    [string]$Repo = 'AI-PR'
)

$ErrorActionPreference = 'Stop'

if (-not [string]::IsNullOrWhiteSpace($env:CHANGE_ID)) {
    Write-Output $env:CHANGE_ID.Trim()
    exit 0
}
if (-not [string]::IsNullOrWhiteSpace($env:ghprbPullId)) {
    Write-Output $env:ghprbPullId.Trim()
    exit 0
}

$token = $env:GITHUB_TOKEN
if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host 'resolve_pr_number: GITHUB_TOKEN not set; cannot look up PR by branch.'
    exit 0
}

$branch = $env:BRANCH_FOR_PR_RESOLVE
if ([string]::IsNullOrWhiteSpace($branch)) { $branch = $env:BRANCH_NAME }
if ([string]::IsNullOrWhiteSpace($branch)) { $branch = $env:GIT_BRANCH }
if ($branch -and $branch.StartsWith('origin/')) {
    $branch = $branch.Substring('origin/'.Length)
}

if ([string]::IsNullOrWhiteSpace($branch)) {
    Write-Host 'resolve_pr_number: no branch in BRANCH_FOR_PR_RESOLVE / BRANCH_NAME / GIT_BRANCH.'
    exit 0
}

$head = "${Owner}:${branch}"
$enc = [uri]::EscapeDataString($head)
$uri = "https://api.github.com/repos/$Owner/$Repo/pulls?state=open&head=$enc"

Write-Host "resolve_pr_number: querying GitHub for head=$head"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$res = Invoke-RestMethod -Method Get -Uri $uri -Headers @{
    Authorization  = "token $token"
    Accept         = 'application/vnd.github+json'
    'User-Agent'   = 'Jenkins-AI-PR-resolve'
}

$list = @($res)
if ($list.Count -gt 0) {
    Write-Output ([string]$list[0].number)
    exit 0
}

Write-Host "resolve_pr_number: no open PR for head $head"
exit 0
