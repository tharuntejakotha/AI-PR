param(
    [string]$Owner = 'tharuntejakotha',
    [string]$Repo = 'AI-PR',
    [Parameter(Mandatory = $true)][string]$PrNumber
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
    throw 'GITHUB_TOKEN not set in environment.'
}
if ([string]::IsNullOrWhiteSpace($PrNumber)) {
    throw 'PrNumber is empty.'
}

$comment = Get-Content -Raw -Path 'ai-pr-comment.md' -Encoding UTF8

$payload = @{
    body = $comment
}

$payloadJson = $payload | ConvertTo-Json -Depth 10

$uri = "https://api.github.com/repos/$Owner/$Repo/issues/$PrNumber/comments"

Invoke-RestMethod -Method Post -Uri $uri `
    -Headers @{
        Authorization = ('token ' + $env:GITHUB_TOKEN)
        Accept = 'application/vnd.github+json'
    } `
    -ContentType 'application/json' `
    -Body $payloadJson | Out-Null

Write-Host "Posted AI comment to GitHub PR #$PrNumber"

