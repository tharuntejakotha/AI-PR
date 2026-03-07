pipeline {
    agent any

    stages {

       

        stage('Build') {
            steps {
                script {
                    try {
                        sh 'mvn clean install'
                    } catch (Exception e) {
                        env.BUILD_FAILED = "true"
                        echo "Build failed"
                    }
                }
            }
        }

        stage('Sonar Scan') {
            steps {
                script {
                    try {
                        sh 'mvn sonar:sonar'
                    } catch (Exception e) {
                        env.SONAR_FAILED = "true"
                        echo "Sonar check failed"
                    }
                }
            }
        }

        stage('AI Review') {
            when {
                expression {
                    return env.BUILD_FAILED == "true" || env.SONAR_FAILED == "true"
                }
            }
            steps {
                sh 'curl http://localhost:8080/ai/review'
            }
        }

    }
}
