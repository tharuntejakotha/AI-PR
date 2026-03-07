pipeline {
    agent any

    stages {

        stage('Build') {
            steps {
                script {
                    try {
                        bat 'mvn clean install'
                    } catch (Exception e) {
                        echo "Build failed"
                    }
                }
            }
        }

        stage('Sonar Scan') {
            steps {
                script {
                    try {
                        bat 'mvn sonar:sonar'
                    } catch (Exception e) {
                        echo "Sonar check failed"
                    }
                }
            }
        }

        stage('AI Review') {
            steps {
                bat 'curl http://localhost:8080/ai/review'
            }
        }

    }
}
