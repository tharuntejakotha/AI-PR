# Fetches unresolved SonarQube issues for a project via Web API and writes checkmarx_input.txt
# for the existing AI PR comment flow (same filename as Checkmarx POC).
param(
    [string]$SonarHost = $env:SONAR_HOST_URL,
    [string]$ProjectKey = $env:SONAR_PROJECT_KEY,
    [string]$Branch = $env:SONAR_BRANCH,
    [string]$SourceRoot = 'src/main/java',
    [string]$OutFile = 'checkmarx_input.txt',
    [int]$PageSize = 100,
    [int]$MaxIssues = 500
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$token = if ($env:SONAR_TOKEN) { $env:SONAR_TOKEN.Trim() } else { '' }
if ([string]::IsNullOrWhiteSpace($token)) {
    throw 'SONAR_TOKEN is not set.'
}

if ([string]::IsNullOrWhiteSpace($SonarHost)) {
    $SonarHost = 'http://localhost:9000'
}
$SonarHost = $SonarHost.TrimEnd('/')

if ([string]::IsNullOrWhiteSpace($ProjectKey)) {
    $ProjectKey = 'BugDemo'
}

Write-Host "fetch_sonar_issues: SonarHost=$SonarHost ProjectKey=$ProjectKey"

Add-Type -AssemblyName System.Web

function Invoke-SonarIssuesPage {
    param([int]$Page)
    $q = [System.Web.HttpUtility]::UrlEncode($ProjectKey)
    $uri = "$SonarHost/api/issues/search?componentKeys=$q&resolved=false&ps=$PageSize&p=$Page"
    if (-not [string]::IsNullOrWhiteSpace($Branch)) {
        $b = [System.Web.HttpUtility]::UrlEncode($Branch)
        $uri += "&branch=$b"
    }

    $headers = @{ Authorization = 'Bearer ' + $token }
    try {
        return Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    } catch {
        $pair = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($token + ':'))
        $basic = @{ Authorization = 'Basic ' + $pair }
        return Invoke-RestMethod -Uri $uri -Headers $basic -Method Get
    }
}

$all = New-Object System.Collections.Generic.List[object]
$page = 1
do {
    Write-Host "fetch_sonar_issues: requesting page $page ..."
    $resp = Invoke-SonarIssuesPage -Page $page
    $issuesThisPage = @($resp.issues)
    foreach ($i in $issuesThisPage) {
        [void]$all.Add($i)
        if ($all.Count -ge $MaxIssues) { break }
    }
    $page++
    $more = ($issuesThisPage.Count -eq $PageSize) -and ($all.Count -lt $MaxIssues)
} while ($more)

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('[Dynamic findings for AI PR comment]')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('Source: SonarQube + local code pattern scan')
[void]$sb.AppendLine("Project: $ProjectKey")
if (-not [string]::IsNullOrWhiteSpace($Branch)) {
    [void]$sb.AppendLine("Branch: $Branch")
}
[void]$sb.AppendLine('')

if ($all.Count -eq 0) {
    [void]$sb.AppendLine('No unresolved issues were returned for this project (clean per current SonarQube state, or analysis still processing).')
} else {
    [void]$sb.AppendLine("Total unresolved issues (capped at $MaxIssues): $($all.Count)")
    [void]$sb.AppendLine('')
    $prefix = "$ProjectKey`:"
    foreach ($i in $all) {
        $path = $i.component
        if ($path -and $path.StartsWith($prefix)) {
            $path = $path.Substring($prefix.Length)
        }
        [void]$sb.AppendLine('Query: ' + $(if ($i.rule) { $i.rule } else { 'unknown' }))
        [void]$sb.AppendLine('Severity: ' + $(if ($i.severity) { $i.severity } else { '' }))
        [void]$sb.AppendLine('Type: ' + $(if ($i.type) { $i.type } else { '' }))
        [void]$sb.AppendLine("File: $path")
        [void]$sb.AppendLine('Line: ' + $(if ($i.line) { $i.line } else { '' }))
        [void]$sb.AppendLine('Description: ' + $(if ($i.message) { $i.message } else { '' }))
        [void]$sb.AppendLine('')
    }
}

[void]$sb.AppendLine('-----')
[void]$sb.AppendLine('Local code findings (dynamic pattern scan)')
[void]$sb.AppendLine('')

$localCount = 0
$rules = @(
    @{
        Pattern = '\/\s*0\b'
        Query = 'Divide_By_Zero_Pattern'
        Severity = 'HIGH'
        Type = 'BUG'
        Description = 'Division by literal zero pattern found in source code.'
    },
    @{
        Pattern = 'throw\s+new\s+SQLException\s*\('
        Query = 'SQLException_Thrown'
        Severity = 'MEDIUM'
        Type = 'CODE_SMELL'
        Description = 'Code throws SQLException directly; review whether this path reflects a real SQL error flow.'
    },
    @{
        Pattern = 'execute(Query|Update)\s*\(\s*".*"\s*\+\s*'
        Query = 'Potential_SQL_String_Concatenation'
        Severity = 'HIGH'
        Type = 'SECURITY_HOTSPOT'
        Description = 'Potential SQL query string concatenation detected; validate with prepared statements and input sanitization.'
    }
)

if (Test-Path -LiteralPath $SourceRoot) {
    foreach ($rule in $rules) {
        $matches = Select-String -Path (Join-Path $SourceRoot '*.java') -Pattern $rule.Pattern -AllMatches -CaseSensitive:$false -Recurse
        foreach ($m in $matches) {
            $localCount++
            $relative = $m.Path.Replace((Get-Location).Path + '\', '')
            [void]$sb.AppendLine("Query: $($rule.Query)")
            [void]$sb.AppendLine("Severity: $($rule.Severity)")
            [void]$sb.AppendLine("Type: $($rule.Type)")
            [void]$sb.AppendLine("File: $relative")
            [void]$sb.AppendLine("Line: $($m.LineNumber)")
            [void]$sb.AppendLine("Description: $($rule.Description)")
            [void]$sb.AppendLine('')
        }
    }
} else {
    [void]$sb.AppendLine("Source root not found: $SourceRoot")
    [void]$sb.AppendLine('')
}

if ($localCount -eq 0) {
    [void]$sb.AppendLine('No local pattern matches found in current source scan.')
    [void]$sb.AppendLine('')
}

Set-Content -LiteralPath $OutFile -Value $sb.ToString() -Encoding UTF8
Write-Host "fetch_sonar_issues: wrote Sonar issues ($($all.Count)) + local code findings ($localCount) to $OutFile"
