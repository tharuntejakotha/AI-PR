pipeline {
    agent any

    environment {
        
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
}
stage('AI Review') {
    steps {
        withCredentials([string(credentialsId: 'grok-api-key', variable: 'GROK_API_KEY')]) {
            powershell '''
            $apiKey = $env:GROK_API_KEY.Trim()

            if ([string]::IsNullOrWhiteSpace($apiKey)) {
                Write-Error "GROK_API_KEY missing"
                exit 1
            }

            Write-Output "Grok key detected"
            Write-Output "Key length: $($apiKey.Length)"

            if (-not (Test-Path sonar_issues.json)) {
                Write-Error "sonar_issues.json not found"
                exit 1
            }

            $issuesJson = Get-Content sonar_issues.json -Raw | ConvertFrom-Json
            $issueList = $issuesJson.issues | Select-Object -First 10

            $summary = "Analyze these SonarQube issues from a Java Spring Boot project and suggest fixes:`n`n"

            foreach ($issue in $issueList) {
                $summary += "Rule: $($issue.rule)`n"
                $summary += "Severity: $($issue.severity)`n"
                $summary += "Message: $($issue.message)`n"
                $summary += "File: $($issue.component)`n---`n"
            }

            $body = @{
                model = "grok-2-latest"
                messages = @(
                    @{
                        role = "user"
                        content = $summary
                    }
                )
            }

            $jsonBody = $body | ConvertTo-Json -Depth 10

            try {
                $response = Invoke-RestMethod `
                    -Uri "https://api.x.ai/v1/chat/completions" `
                    -Method Post `
                    -Headers @{
                        "Authorization" = "Bearer $apiKey"
                    } `
                    -ContentType "application/json" `
                    -Body $jsonBody

                Write-Output "AI Review Result:"
                Write-Output $response.choices[0].message.content

            } catch {
                Write-Error "Grok API Request failed: $_"
                exit 1
            }
            '''
        }
    }
}
    }
}
