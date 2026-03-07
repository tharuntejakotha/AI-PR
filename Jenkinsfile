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

        $issues = Get-Content "sonar_issues.json" -Raw

        $bodyObject = @{
            contents = @(
                @{
                    parts = @(
                        @{
                            text = "Analyze these SonarQube issues and suggest code fixes for a Java Spring Boot project: $issues"
                        }
                    )
                }
            )
        }

        $jsonBody = $bodyObject | ConvertTo-Json -Depth 10

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
