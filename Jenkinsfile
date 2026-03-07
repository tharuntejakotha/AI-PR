pipeline {
    agent any

    environment {
        GEMINI_API_KEY = "AIzaSyBsFzhZVYGrpR6T8IeEyK_n672S7B216Sg"
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
                curl "%SONAR_URL%/api/issues/search?componentKeys=%SONAR_PROJECT%" -o sonar_issues.json
                '''
            }
        }
       stage('AI Review') {
            steps {

                bat '''
                curl -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=%GEMINI_API_KEY%" ^
                -H "Content-Type: application/json" ^
                -d "{\\"contents\\":[{\\"parts\\":[{\\"text\\":\\"Analyze the SonarQube issues in this project and suggest fixes for SQL injection, runtime errors and security vulnerabilities.\\"}]}]}"
                '''
            }
        }

    }
}
