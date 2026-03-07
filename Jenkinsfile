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
}
stage('AI Review') {
    steps {
        powershell '''
        $url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$env:GEMINI_API_KEY"

        $issues = Get-Content sonar_issues.json | ConvertFrom-Json

        $summary = ""

        foreach ($issue in $issues.issues) {
            $summary += "Rule: " + $issue.rule + "`n"
            $summary += "Severity: " + $issue.severity + "`n"
            $summary += "Message: " + $issue.message + "`n"
            $summary += "File: " + $issue.component + "`n`n"
        }

        $body = @{
            contents = @(
                @{
                    parts = @(
                        @{
                            text = "Analyze these SonarQube issues from a Java Spring Boot project and suggest fixes:`n`n$summary"
                        }
                    )
                }
            )
        }

        $jsonBody = $body | ConvertTo-Json -Depth 6

        Invoke-RestMethod `
            -Uri $url `
            -Method Post `
            -ContentType "application/json" `
            -Body $jsonBody
        '''
    }
}

    }
}
