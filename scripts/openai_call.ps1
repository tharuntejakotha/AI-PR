param(
    [string]$PromptFile = 'ai-pr-prompt.txt',
    [string]$OutputFile = 'ai-pr-comment.md',
    [string]$Model = 'gpt-4.1-mini',
    [int]$TimeoutSec = 20
)

$ErrorActionPreference = 'Stop'

$apiKey = $env:OPENAI_API_KEY
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw 'OPENAI_API_KEY not set in environment.'
}

$prompt = Get-Content -Raw -Path $PromptFile -Encoding UTF8

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
Write-Host "Calling OpenAI (timeout=${TimeoutSec}s)..."

# Use HttpClient + CancellationTokenSource for a reliable timeout.
$client = [System.Net.Http.HttpClient]::new()
$cts = [System.Threading.CancellationTokenSource]::new()
$cts.CancelAfter([TimeSpan]::FromSeconds($TimeoutSec))

try {
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

    $task = $client.SendAsync($request, $cts.Token)
    $resp = $task.GetAwaiter().GetResult()

    $respText = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    if (-not $resp.IsSuccessStatusCode) {
        throw ("OpenAI HTTP failure: {0} {1}" -f $resp.StatusCode, $respText)
    }

    $payload = $respText | ConvertFrom-Json
} catch {
    Write-Host "OpenAI request failed (timeout=${TimeoutSec}s). Error: $($_.Exception.Message)"
    throw
} finally {
    $client.Dispose()
}

$content = $payload.choices[0].message.content
Set-Content -Path $OutputFile -Value $content -Encoding UTF8
Write-Host $content

