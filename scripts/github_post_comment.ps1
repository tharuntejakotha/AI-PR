param(
    [string]$Owner = 'tharuntejakotha',
    [string]$Repo = 'AI-PR',
    [Parameter(Mandatory = $true)][string]$PrNumber
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if ([string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
    throw 'GITHUB_TOKEN not set in environment.'
}
if ([string]::IsNullOrWhiteSpace($PrNumber)) {
    throw 'PrNumber is empty.'
}

$commentPath = Join-Path (Get-Location) 'ai-pr-comment.md'
if (-not (Test-Path -LiteralPath $commentPath)) {
    throw "Comment file not found: $commentPath"
}
$comment = Get-Content -Raw -LiteralPath $commentPath -Encoding UTF8

$payload = @{
    body = $comment
}

$payloadJson = $payload | ConvertTo-Json -Depth 10

$uri = "https://api.github.com/repos/$Owner/$Repo/issues/$PrNumber/comments"

Invoke-RestMethod -Method Post -Uri $uri `
    -Headers @{
        Authorization = ('token ' + $env:GITHUB_TOKEN)
        Accept = 'application/vnd.github+json'
        'User-Agent' = 'Jenkins-AI-PR-comment'
    } `
    -ContentType 'application/json' `
    -Body $payloadJson | Out-Null

Write-Host "Posted AI comment to GitHub PR #$PrNumber"

