pipeline {
    agent any

    environment {
        AWS_REGION     = 'ap-south-1'
        SONARQUBE_ENV  = 'MySonarQube'   // Jenkins SonarQube server config name
        PROJECT_KEY    = 'devops-capstone'
        SONAR_USER     = 'admin'         // SonarQube admin user
        SONAR_PASS     = 'admin'         // default admin password (change after first login)
    }

    stages {
        stage('Checkout Terraform Code') {
            steps {
                git branch: 'main', url: 'https://github.com/PraveenS-786/DevOps--Capstone.git'
            }
        }

        stage('Terraform Init & Apply') {
            steps {
                withCredentials([[ 
                    $class: 'AmazonWebServicesCredentialsBinding', 
                    credentialsId: 'praveen-iam' 
                ]]) {
                    bat '''
                    cd terraform
                    terraform init
                    terraform apply -auto-approve
                    '''
                }
            }
        }

        stage('Build & Test Code') {
            steps {
                bat '''
                echo Running code build and tests...
                mvn clean verify
                '''
            }
        }

        stage('SonarQube Analysis (on EC2)') {
            steps {
                script {
                    // Get EC2 public IP from Terraform output
                    def ec2_ip = bat(
                        script: 'cd terraform && terraform output -raw ec2_public_ip',
                        returnStdout: true
                    ).trim()

                    echo "SonarQube Server running at: http://${ec2_ip}:9000"

                    // ✅ Generate temporary token for Jenkins via SonarQube API
                    def tokenResponse = bat(
                        script: """
                        curl -u ${SONAR_USER}:${SONAR_PASS} -X POST "http://${ec2_ip}:9000/api/user_tokens/generate?name=jenkins-token-%BUILD_ID%" > token.json
                        """,
                        returnStdout: true
                    )

                    def tokenJson = readJSON file: 'token.json'
                    def SONAR_TOKEN = tokenJson.token
                    echo "✅ Generated temporary SonarQube token."

                    // Run SonarQube scan with the dynamic token
                    bat """
                    mvn sonar:sonar ^
                      -Dsonar.projectKey=${PROJECT_KEY} ^
                      -Dsonar.host.url=http://${ec2_ip}:9000 ^
                      -Dsonar.login=${SONAR_TOKEN}
                    """

                    // Wait for analysis result to be processed
                    echo "⌛ Waiting for SonarQube analysis report..."
                    sleep(time: 10, unit: 'SECONDS')

                    // ✅ Fetch analysis Quality Gate result
                    bat """
                    curl -s -u ${SONAR_TOKEN}: "http://${ec2_ip}:9000/api/qualitygates/project_status?projectKey=${PROJECT_KEY}" > sonar_result.json
                    """

                    def sonarResult = readJSON file: 'sonar_result.json'
                    def status = sonarResult.projectStatus.status
                    echo "🎯 SonarQube Quality Gate Status: ${status}"

                    if (status != "OK") {
                        error "❌ SonarQube Quality Gate failed. Please check the dashboard."
                    }

                    // ✅ Revoke the temporary token
                    bat """
                    curl -u ${SONAR_USER}:${SONAR_PASS} -X POST "http://${ec2_ip}:9000/api/user_tokens/revoke?name=jenkins-token-%BUILD_ID%"
                    """
                    echo "🧹 Temporary token revoked successfully."
                }
            }
        }

        stage('Show SonarQube Dashboard URL') {
            steps {
                bat '''
                cd terraform
                for /f "usebackq delims=" %%i in (`terraform output -raw ec2_public_ip`) do set EC2_IP=%%i
                echo =============================================
                echo ✅ SonarQube Dashboard: http://%EC2_IP%:9000
                echo =============================================
                '''
            }
        }

        stage('Destroy Infrastructure') {
            when {
                expression { return params.DESTROY_INSTANCE == true }
            }
            steps {
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
            echo '✅ Pipeline completed successfully.'
        }
    }
}
