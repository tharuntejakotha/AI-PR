pipeline {
    agent any

    environment {
        GEMINI_API_KEY = credentials('gemini-api-key')
        SONAR_URL = "http://localhost:9000"
        SONAR_PROJECT = "bug-demo"
        SONAR_TOKEN = "squ_1362a50ae39789eadef40c96341bbca26fb68957"
    }

    stages {

        stage('Build') {
            steps {
                bat 'mvnw.cmd clean install'
            }
        }

       stage('Sonar Scan') {
            steps {

                bat '''
                mvnw.cmd clean verify sonar:sonar ^
                -Dsonar.projectKey=%SONAR_PROJECT% ^
                -Dsonar.host.url=%SONAR_URL% ^
                -Dsonar.login=%SONAR_TOKEN%
                '''
            }
        }

         stage('Fetch Sonar Issues') {
    steps {
        bat '''
        curl -u %SONAR_TOKEN%: "http://localhost:9000/api/issues/search?componentKeys=bug-demo" -o sonar_issues.json
        '''
    }
}stage('AI Review') {
    steps {
        withCredentials([string(credentialsId: 'gemini-api-key', variable: 'GEMINI_API_KEY')]) {
            powershell '''
                $apiKey = $env:GEMINI_API_KEY.Trim()
                if ([string]::IsNullOrWhiteSpace($apiKey)) {
                    Write-Error "GEMINI_API_KEY is empty or not set"; exit 1
                }
                $url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey"

                if (-not (Test-Path sonar_issues.json)) {
                    Write-Error "sonar_issues.json not found"; exit 1
                }

                $issuesJson = Get-Content sonar_issues.json -Raw | ConvertFrom-Json
                $issueList = $issuesJson.issues | Select-Object -First 15

                $summary = "Analyze these SonarQube issues for a Java Spring Boot project and suggest fixes:`n`n"
                foreach ($issue in $issueList) {
                    $summary += "Rule: $($issue.rule)`nSeverity: $($issue.severity)`nMessage: $($issue.message)`nFile: $($issue.component)`n---`n"
                }

                $body = @{
                    contents = @(
                        @{
                            parts = @(
                                @{ text = $summary }
                            )
                        }
                    )
                }
                $jsonBody = $body | ConvertTo-Json -Depth 10 -Compress

                try {
                    $response = Invoke-RestMethod -Uri $url -Method Post -ContentType "application/json" -Body $jsonBody
                    Write-Output "AI Analysis Result:"
                    Write-Output ($response.candidates[0].content.parts[0].text)
                } catch {
                    Write-Error "API Request failed: $_"
                    if ($_.Exception.Response) {
                        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                        $errorDetails = $reader.ReadToEnd()
                        Write-Output "Error Details: $errorDetails"
                    }
                    exit 1
                }
            '''
        }
    }
}

    }
}
