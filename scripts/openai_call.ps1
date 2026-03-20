param(
    [string]$PromptFile = 'ai-pr-prompt.txt',
    [string]$OutputFile = 'ai-pr-comment.md',
    [string]$Model = 'gpt-4.1-mini'
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

$res = Invoke-RestMethod `
    -Method Post `
    -Uri 'https://api.openai.com/v1/chat/completions' `
    -Headers @{ Authorization = ('Bearer ' + $apiKey) } `
    -ContentType 'application/json' `
    -Body $bodyJson

$content = $res.choices[0].message.content
Set-Content -Path $OutputFile -Value $content -Encoding UTF8
Write-Host $content

