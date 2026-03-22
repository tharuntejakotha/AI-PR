param(
    [string]$PromptFile = 'ai-pr-prompt.txt',
    [string]$OutputFile = 'ai-pr-comment.md',
    [string]$Model = 'gpt-4.1-mini',
    [int]$TimeoutSec = 120
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Windows PowerShell 5.1: ConvertTo-Json can hang on prompts that contain emoji/Unicode (e.g. from Checkmarx templates).
# Build JSON with explicit escaping instead.
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

# Older Windows agents: ensure TLS 1.2 for outbound HTTPS.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$apiKey = $env:OPENAI_API_KEY
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw 'OPENAI_API_KEY not set in environment.'
}

Write-Host "openai_call.ps1: loading prompt from $PromptFile ..."
$prompt = Get-Content -Raw -Path $PromptFile -Encoding UTF8
Write-Host "openai_call.ps1: prompt length $($prompt.Length) characters; building JSON (no ConvertTo-Json) ..."
try { [Console]::Out.Flush() } catch { }

$systemContent = 'You are a security review assistant. Return ONLY markdown using the required sections: Issue, Risk, Fix (with code snippet), Recommendation.'
$bodyJson = "{""model"":$(Format-JsonString $Model),""messages"":[{""role"":""system"",""content"":$(Format-JsonString $systemContent)},{""role"":""user"",""content"":$(Format-JsonString $prompt)}],""temperature"":0.2}"
Write-Host "openai_call.ps1: JSON length $($bodyJson.Length) chars"
try { [Console]::Out.Flush() } catch { }

$uri = 'https://api.openai.com/v1/chat/completions'
Write-Host "Calling OpenAI (timeout=${TimeoutSec}s); waiting on api.openai.com (this often takes 15-120s) ..."
try { [Console]::Out.Flush() } catch { }

# Windows PowerShell 5.1: HttpClient is in System.Net.Http, not loaded by default. PS 7+ usually has it already.
if (-not ('System.Net.Http.HttpClient' -as [type])) {
    Add-Type -AssemblyName System.Net.Http
}

# Use HttpClient + CancellationTokenSource for a reliable timeout.
$client = [System.Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)
$cts = [System.Threading.CancellationTokenSource]::new()
$cts.CancelAfter([TimeSpan]::FromSeconds($TimeoutSec))

try {
    Write-Host "Preparing request..."
    $request = [System.Net.Http.HttpRequestMessage]::new(
        [System.Net.Http.HttpMethod]::Post,
        $uri
    )
    $request.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $apiKey)
    $request.Content = [System.Net.Http.StringContent]::new(
        $bodyJson,
        [System.Text.Encoding]::UTF8,
        'application/json'
    )

    Write-Host "Sending request to OpenAI..."
    try { [Console]::Out.Flush() } catch { }
    # Avoid deadlock: PowerShell can capture a sync context; never block the pipeline thread
    # waiting on continuations that try to post back to it.
    $sendTask = $client.SendAsync($request, $cts.Token)
    $resp = $sendTask.ConfigureAwait($false).GetAwaiter().GetResult()

    Write-Host "Response received (HTTP $($resp.StatusCode))..."
    $readTask = $resp.Content.ReadAsStringAsync()
    $respText = $readTask.ConfigureAwait($false).GetAwaiter().GetResult()
    if (-not $resp.IsSuccessStatusCode) {
        throw ("OpenAI HTTP failure: {0} {1}" -f $resp.StatusCode, $respText)
    }

    $payload = $respText | ConvertFrom-Json
} catch {
    $ex = $_.Exception
    while ($ex -is [System.AggregateException] -and $ex.InnerException) {
        $ex = $ex.InnerException
    }
    $msg = $ex.Message
    if ($ex -is [System.Threading.Tasks.TaskCanceledException] -or $ex -is [System.OperationCanceledException]) {
        $msg = "Timeout reached (${TimeoutSec}s) while calling OpenAI."
    }
    Write-Host "OpenAI request failed. $msg"
    throw
} finally {
    $client.Dispose()
}

if (-not $payload.choices -or $payload.choices.Count -lt 1 -or -not $payload.choices[0].message.content) {
    throw 'OpenAI response missing choices[0].message.content.'
}
$content = $payload.choices[0].message.content
Set-Content -Path $OutputFile -Value $content -Encoding UTF8
Write-Host $content

