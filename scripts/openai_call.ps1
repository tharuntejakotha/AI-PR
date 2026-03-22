param(
    [string]$PromptFile = 'ai-pr-prompt.txt',
    [string]$OutputFile = 'ai-pr-comment.md',
    [string]$Model = 'gpt-4.1-mini',
    [int]$TimeoutSec = 120
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Older Windows agents: ensure TLS 1.2 for outbound HTTPS.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$apiKey = $env:OPENAI_API_KEY
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw 'OPENAI_API_KEY not set in environment.'
}

Write-Host "openai_call.ps1: loading prompt from $PromptFile ..."
$prompt = Get-Content -Raw -Path $PromptFile -Encoding UTF8
Write-Host "openai_call.ps1: prompt length $($prompt.Length) characters; building JSON request ..."

$body = @{
    model = $Model
    messages = @(
        @{
            role = 'system'
            # Avoid embedding emoji characters directly in the PS source file
            # (PowerShell parsing can fail if the file encoding isn't UTF-8 in Jenkins).
            content = 'You are a security review assistant. Return ONLY markdown using the required sections: Issue, Risk, Fix (with code snippet), Recommendation.'
        },
        @{
            role = 'user'
            content = $prompt
        }
    )
    temperature = 0.2
}

$bodyJson = $body | ConvertTo-Json -Depth 10

$uri = 'https://api.openai.com/v1/chat/completions'
Write-Host "Calling OpenAI (timeout=${TimeoutSec}s); waiting on api.openai.com (this often takes 15-120s) ..."
try { [Console]::Out.Flush() } catch { }

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

