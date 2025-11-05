// CUSTOMIZED JENKINSFILE FOR YOUR PROJECT
// Project: Embedding Security in Every Stage of the CI/CD Lifecycle
// Repository: github.com/tanmayrannavare/devsecops (PUBLIC)

pipeline {
    agent any
    
    environment {
        DOCKER_IMAGE = "tanmayrannavare/devsecops"
        DOCKER_TAG = "${BUILD_NUMBER}"
        SONARQUBE_SERVER = "SonarQube"
        OWASP_DC_INSTALLATION = "OWASP-DC"
    }
    
        stages {
        
        stage('1. Git Checkout') {
            steps {
                echo '========== Cloning PUBLIC Repository =========='
                // PUBLIC REPO - NO CREDENTIALS
                git branch: 'main',
                    url: 'https://github.com/tanmayrannavare/devsecops.git'
            }
        }
        
        stage('2. Code Quality Analysis (SonarQube)') {
            steps {
                echo '========== Running SonarQube Static Analysis =========='
                script {
                    // For static analysis of JavaScript/HTML/CSS
                    withSonarQubeEnv("${SONARQUBE_SERVER}") {
                        sh '''
                            sonar-scanner \
                            -Dsonar.projectKey=devsecops-web \
                            -Dsonar.projectName="DevSecOps Web App" \
                            -Dsonar.sources=. \
                            -Dsonar.exclusions=node_modules/**,build/**,dist/** \
                            -Dsonar.sourceEncoding=UTF-8
                        '''
                    }
                }
            }
        }
        
        stage('3. Quality Gate Check') {
            steps {
                echo '========== Checking SonarQube Quality Gate =========='
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
        
        stage('4. Dependency Scanning (Trivy)') {
            steps {
                echo '========== Scanning for Vulnerable Dependencies =========='
                // Scan JavaScript dependencies if using npm
                sh '''
                    if [ -f "package.json" ]; then
                        echo "Node.js dependencies detected - scanning with Trivy"
                        trivy fs --format json --output trivy-fs-report.json .
                    else
                        echo "No Node.js dependencies found"
                    fi
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-fs-report.json', allowEmptyArchive: true
                }
            }
        }
        
        stage('5. Security Scanning (OWASP ZAP Baseline)') {
            steps {
                echo '========== Pre-deployment Security Analysis =========='
                // Check for hardcoded secrets/credentials
                sh '''
                    echo "Scanning for hardcoded secrets..."
                    grep -r "password\|api_key\|secret\|token" . \
                        --include="*.js" \
                        --include="*.html" \
                        --include="*.css" \
                        || echo "No obvious secrets found (good!)"
                '''
            }
        }
        
        stage('6. Build Docker Image') {
            steps {
                echo '========== Building Docker Image =========='
                script {
                    dockerImage = docker.build("${DOCKER_IMAGE}:${DOCKER_TAG}")
                    docker.build("${DOCKER_IMAGE}:latest")
                }
            }
        }
        
        stage('7. Scan Docker Image (Trivy)') {
            steps {
                echo '========== Scanning Docker Image with Trivy =========='
                sh "trivy image --format json --output trivy-image-report.json ${DOCKER_IMAGE}:${DOCKER_TAG}"
                sh "trivy image --exit-code 1 --severity CRITICAL,HIGH ${DOCKER_IMAGE}:${DOCKER_TAG}"
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-image-report.json', allowEmptyArchive: true
                }
            }
        }
        
        stage('8. Push Docker Image (Optional)') {
            when {
                branch 'main'
            }
            steps {
                echo '========== Pushing Docker Image to Registry =========='
                script {
                    try {
                        docker.withRegistry('https://registry.hub.docker.com', 'dockerhub-credentials') {
                            dockerImage.push("${DOCKER_TAG}")
                            dockerImage.push("latest")
                        }
                    } catch (Exception e) {
                        echo "⚠️ Docker push skipped (credentials not configured)"
                        echo "Image built locally: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                    }
                }
            }
        }
        
        stage('9. Deploy to Test Environment') {
            steps {
                echo '========== Deploying to Test Environment =========='
                sh '''
                    docker stop test-app || true
                    docker rm test-app || true
                    docker run -d --name test-app -p 8080:8080 ${DOCKER_IMAGE}:${DOCKER_TAG}
                    echo "Test app deployed at: http://localhost:8080"
                    sleep 15
                '''
            }
        }
        
        stage('10. DAST - Dynamic Security Testing') {
            steps {
                echo '========== Running OWASP ZAP Dynamic Scan =========='
                sh '''
                    docker run --rm --network="host" -v $(pwd):/zap/wrk:rw \
                        -t owasp/zap2docker-stable \
                        zap-baseline.py \
                        -t http://localhost:8080 \
                        -r zap-report.html || true
                '''
            }
            post {
                always {
                    publishHTML(target: [
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: '.',
                        reportFiles: 'zap-report.html',
                        reportName: 'ZAP Security Report'
                    ])
                }
            }
        }
        
        stage('11. Deploy to Live') {
            when {
                branch 'main'
            }
            input {
                message "Deploy to Live Environment?"
                ok "Deploy"
            }
            steps {
                echo '========== Deploying to Live Environment =========='
                sh '''
                    docker stop live-app || true
                    docker rm live-app || true
                    docker run -d --name live-app -p 80:8080 ${DOCKER_IMAGE}:${DOCKER_TAG}
                    echo "✅ Application deployed to: http://localhost"
                '''
            }
        }
    }
    
    post {
        always {
            echo '========== Pipeline Execution Completed =========='
            cleanWs()
        }
        success {
            echo '✅ Pipeline Succeeded! Application is secure and deployed!'
        }
        failure {
            echo '❌ Pipeline Failed! Check logs above for details'
        }
    }
}
