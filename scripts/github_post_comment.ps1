param(
    [string]$Owner = 'tharuntejakotha',
    [string]$Repo = 'AI-PR',
    [Parameter(Mandatory = $true)][string]$PrNumber,
    [int]$TimeoutSec = 90
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Same as openai_call.ps1: PS 5.1 ConvertTo-Json can hang on Unicode/emoji in PR bodies.
function Format-JsonString([string]$Value) {
    if ($null -eq $Value) { return '""' }
    $sb = New-Object System.Text.StringBuilder ([Math]::Max(32, $Value.Length * 2 + 2))
    [void]$sb.Append('"')
    for ($i = 0; $i -lt $Value.Length; $i++) {
        $ch = $Value[$i]
        if ($ch -eq [char]'"') {
            [void]$sb.Append('\')
            [void]$sb.Append('"')
        } elseif ($ch -eq [char]'\') {
            [void]$sb.Append('\\')
        } elseif ($ch -eq "`n") {
            [void]$sb.Append('\n')
        } elseif ($ch -eq "`r") {
            [void]$sb.Append('\r')
        } elseif ($ch -eq "`t") {
            [void]$sb.Append('\t')
        } else {
            $code = [int][char]$ch
            if ($code -lt 32) {
                [void]$sb.AppendFormat('\u{0:x4}', $code)
            } else {
                [void]$sb.Append($ch)
            }
        }
    }
    [void]$sb.Append('"')
    return $sb.ToString()
}

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

Write-Host "github_post_comment.ps1: loading $commentPath ..."
$comment = Get-Content -Raw -LiteralPath $commentPath -Encoding UTF8
Write-Host "github_post_comment.ps1: comment length $($comment.Length) chars; building JSON ..."

$bodyJson = '{"body":' + (Format-JsonString $comment) + '}'

$uri = "https://api.github.com/repos/$Owner/$Repo/issues/$PrNumber/comments"
Write-Host "github_post_comment.ps1: POST $uri (timeout=${TimeoutSec}s) ..."
try { [Console]::Out.Flush() } catch { }

if (-not ('System.Net.Http.HttpClient' -as [type])) {
    Add-Type -AssemblyName System.Net.Http
}

$client = [System.Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)
$cts = [System.Threading.CancellationTokenSource]::new()
$cts.CancelAfter([TimeSpan]::FromSeconds($TimeoutSec))

try {
    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Post, $uri)
    $request.Headers.UserAgent.ParseAdd('Jenkins-AI-PR-comment')
    $request.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('token', $env:GITHUB_TOKEN)
    $request.Headers.TryAddWithoutValidation('Accept', 'application/vnd.github+json') | Out-Null
    $request.Content = [System.Net.Http.StringContent]::new(
        $bodyJson,
        [System.Text.Encoding]::UTF8,
        'application/json'
    )

    $sendTask = $client.SendAsync($request, $cts.Token)
    $resp = $sendTask.ConfigureAwait($false).GetAwaiter().GetResult()

    $readTask = $resp.Content.ReadAsStringAsync()
    $respText = $readTask.ConfigureAwait($false).GetAwaiter().GetResult()

    if (-not $resp.IsSuccessStatusCode) {
        throw ("GitHub HTTP {0}: {1}" -f $resp.StatusCode, $respText)
    }
} catch {
    $ex = $_.Exception
    while ($ex -is [System.AggregateException] -and $ex.InnerException) {
        $ex = $ex.InnerException
    }
    $msg = $ex.Message
    if ($ex -is [System.Threading.Tasks.TaskCanceledException] -or $ex -is [System.OperationCanceledException]) {
        $msg = "Timeout (${TimeoutSec}s) posting to GitHub."
    }
    Write-Host "GitHub request failed. $msg"
    throw
} finally {
    $cts.Dispose()
    $client.Dispose()
}

Write-Host "Posted AI comment to GitHub PR #$PrNumber"
