pipeline {
    agent any

    environment {
        AWS_REGION    = 'ap-south-1'
        SONARQUBE_ENV = 'MySonarQube'
        PROJECT_KEY   = 'devops-capstone'
        SONAR_USER    = 'admin'
        SONAR_PASS    = 'admin'
    }

    parameters {
        booleanParam(
            name: 'DESTROY_INSTANCE',
            defaultValue: false,
            description: 'Destroy EC2 after analysis (optional)'
        )
    }

    stages {
        stage('Checkout Code') {
            steps {
                echo "📦 Checking out repository..."
                git branch: 'main', url: 'https://github.com/PraveenS-786/DevOps--Capstone.git'
            }
        }

        stage('Terraform Init & Apply') {
            steps {
                echo "🚀 Initializing Terraform..."
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'praveen-iam'
                ]]) {
                    sh '''
                    cd terraform
                    terraform init -input=false
                    terraform apply -auto-approve -input=false
                    '''
                }
            }
        }

        stage('Build & Test Code') {
            steps {
                echo "🧱 Building and testing project..."
                sh '''
                mvn clean verify -DskipTests=false
                '''
            }
        }

        stage('SonarQube Code Analysis (on EC2)') {
            steps {
                script {
                    echo "🔍 Fetching EC2 public IP..."
                    def ec2_ip = sh(
                        script: 'cd terraform && terraform output -raw ec2_public_ip',
                        returnStdout: true
                    ).trim()

                    echo "🌐 SonarQube Server running at: http://${ec2_ip}:9000"

                    echo "🔑 Generating temporary SonarQube token..."
                    sh """
                    curl -u ${SONAR_USER}:${SONAR_PASS} -X POST "http://${ec2_ip}:9000/api/user_tokens/generate?name=jenkins-token-${BUILD_ID}" > token.json
                    """

                    def tokenJson = readJSON file: 'token.json'
                    def SONAR_TOKEN = tokenJson.token
                    echo "✅ Token generated successfully."

                    echo "🚀 Running SonarQube analysis..."
                    sh """
                    mvn sonar:sonar \
                      -Dsonar.projectKey=${PROJECT_KEY} \
                      -Dsonar.host.url=http://${ec2_ip}:9000 \
                      -Dsonar.login=${SONAR_TOKEN}
                    """

                    echo "⌛ Waiting for SonarQube Quality Gate result..."
                    sleep(time: 15, unit: 'SECONDS')

                    echo "📊 Fetching quality gate status..."
                    sh """
                    curl -s -u ${SONAR_TOKEN}: "http://${ec2_ip}:9000/api/qualitygates/project_status?projectKey=${PROJECT_KEY}" > sonar_result.json
                    """

                    def sonarResult = readJSON file: 'sonar_result.json'
                    def status = sonarResult.projectStatus.status
                    echo "🎯 SonarQube Quality Gate Status: ${status}"

                    if (status != "OK") {
                        error "❌ Quality Gate failed. Check SonarQube dashboard for issues."
                    }

                    echo "🧹 Revoking temporary token..."
                    sh """
                    curl -u ${SONAR_USER}:${SONAR_PASS} -X POST "http://${ec2_ip}:9000/api/user_tokens/revoke?name=jenkins-token-${BUILD_ID}"
                    """
                    echo "✅ Temporary token revoked successfully."
                }
            }
        }

        stage('Show SonarQube Dashboard URL') {
            steps {
                script {
                    def ec2_ip = sh(
                        script: 'cd terraform && terraform output -raw ec2_public_ip',
                        returnStdout: true
                    ).trim()
                    echo """
                    ===========================================
                    ✅ SonarQube Dashboard: http://${ec2_ip}:9000
                    ===========================================
                    """
                }
            }
        }

        stage('Destroy Infrastructure') {
            when {
                expression { return params.DESTROY_INSTANCE == true }
            }
            steps {
                echo "💣 Destroying Terraform infrastructure..."
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'praveen-iam'
                ]]) {
                    sh '''
                    cd terraform
                    terraform destroy -auto-approve
                    '''
                }
            }
        }
    }

    post {
        always {
            echo '✅ Pipeline execution finished.'
        }
        failure {
            echo '❌ Pipeline failed. Check logs for details.'
        }
        success {
            echo '🎉 Pipeline completed successfully!'
        }
    }
}
