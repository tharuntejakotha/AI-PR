pipeline {
    agent any

    environment {
        GEMINI_API_KEY = "AIzaSyBsFzhZVYGrpR6T8IeEyK_n672S7B216Sg"
        SONAR_URL = "http://localhost:9000"
        SONAR_PROJECT = "bug-demo"
    }

    stages {

        stage('Build') {
            steps {
                bat 'mvnw.cmd clean install'
            }
        }

        stage('Sonar Scan') {
            steps {
                bat 'mvnw.cmd sonar:sonar'
            }
        }

        stage('Fetch Sonar Issues') {
            steps {
                bat '''
                curl "%SONAR_URL%/api/issues/search?componentKeys=%SONAR_PROJECT%" > sonar_issues.json
                '''
            }
        }

        stage('AI Review') {
            steps {
                bat '''
                curl -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=%GEMINI_API_KEY%" ^
                -H "Content-Type: application/json" ^
                -d "{\\"contents\\":[{\\"parts\\":[{\\"text\\":\\"Analyze these SonarQube issues and suggest fixes\\"}]}]}"
                '''
            }
        }

    }
}
