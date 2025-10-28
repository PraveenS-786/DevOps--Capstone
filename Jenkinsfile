pipeline {
    agent any

    environment {
        AWS_REGION     = 'ap-south-1'
        SONARQUBE_ENV  = 'MySonarQube'
        PROJECT_KEY    = 'devops-capstone'
        SONAR_USER     = 'admin'
        SONAR_PASS     = 'admin'
    }

    parameters {
        booleanParam(name: 'DESTROY_INSTANCE', defaultValue: false, description: 'Destroy EC2 after analysis')
    }

    stages {

        stage('Checkout Code') {
            steps {
                echo "📦 Checking out repository..."
                git branch: 'main', url: 'https://github.com/PraveenS-786/DevOps--Capstone.git'
            }
        }

        stage('Provision SonarQube EC2 (Terraform)') {
            steps {
                echo "🚀 Running Terraform to create EC2..."
                withCredentials([[ 
                    $class: 'AmazonWebServicesCredentialsBinding', 
                    credentialsId: 'praveen-iam' 
                ]]) {
                    bat '''
                    cd terraform
                    terraform init -input=false
                    terraform apply -auto-approve -input=false
                    '''
                }
            }
        }

        stage('Wait for SonarQube Startup') {
            steps {
                script {
                    def ec2_ip = bat(script: 'cd terraform && terraform output -raw ec2_public_ip', returnStdout: true).trim()
                    echo "🌐 SonarQube server starting at: http://${ec2_ip}:9000"
                    echo "⌛ Waiting 2 minutes for SonarQube to start..."
                    sleep(time: 120, unit: 'SECONDS')
                }
            }
        }

       stage('Generate SonarQube Token') {
    steps {
        script {
            // ✅ Capture EC2 IP safely
            def ec2_ip = bat(script: 'cd terraform && terraform output -raw ec2_public_ip', returnStdout: true).trim()
            echo "SonarQube server IP: ${ec2_ip}"

            // ✅ Use variable in a clean one-line command
            bat """
            curl -u ${SONAR_USER}:${SONAR_PASS} ^
                 -X POST "http://${ec2_ip}:9000/api/user_tokens/generate?name=jenkins-token-${BUILD_ID}" ^
                 -o token.json
            """

            // ✅ Parse JSON token
            def tokenJson = readJSON file: 'token.json'
            env.SONAR_TOKEN = tokenJson.token
            echo "🔑 Temporary SonarQube token created successfully."
        }
    }
}


        stage('Build & Analyze Code') {
            steps {
                script {
                    def ec2_ip = bat(script: 'cd terraform && terraform output -raw ec2_public_ip', returnStdout: true).trim()
                    bat """
                    mvn clean verify sonar:sonar ^
                      -Dsonar.projectKey=${PROJECT_KEY} ^
                      -Dsonar.host.url=http://${ec2_ip}:9000 ^
                      -Dsonar.login=${SONAR_TOKEN}
                    """
                }
            }
        }

        stage('Check Quality Gate Result') {
            steps {
                script {
                    def ec2_ip = bat(script: 'cd terraform && terraform output -raw ec2_public_ip', returnStdout: true).trim()
                    echo "📊 Fetching Quality Gate result..."
                    bat """
                    curl -s -u ${SONAR_TOKEN}: "http://${ec2_ip}:9000/api/qualitygates/project_status?projectKey=${PROJECT_KEY}" > sonar_result.json
                    """
                    def sonarResult = readJSON file: 'sonar_result.json'
                    def status = sonarResult.projectStatus.status
                    echo "🎯 SonarQube Quality Gate Status: ${status}"
                    if (status != "OK") {
                        error("❌ Quality Gate failed! Check SonarQube dashboard for details.")
                    } else {
                        echo "✅ Code passed the SonarQube Quality Gate!"
                    }
                }
            }
        }

        stage('Revoke Token & Show Dashboard') {
            steps {
                script {
                    def ec2_ip = bat(script: 'cd terraform && terraform output -raw ec2_public_ip', returnStdout: true).trim()
                    bat """
                    curl -u ${SONAR_USER}:${SONAR_PASS} -X POST "http://${ec2_ip}:9000/api/user_tokens/revoke?name=jenkins-token-${BUILD_ID}"
                    """
                    echo """
                    =====================================================
                    ✅ SonarQube Dashboard: http://${ec2_ip}:9000/projects
                    =====================================================
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
                    bat '''
                    cd terraform
                    terraform destroy -auto-approve
                    '''
                }
            }
        }
    }

    post {
        always {
            echo '🏁 Pipeline finished.'
        }
        success {
            echo '🎉 Code analysis completed successfully.'
        }
        failure {
            echo '❌ Pipeline failed. Check Jenkins logs and SonarQube dashboard.'
        }
    }
}

