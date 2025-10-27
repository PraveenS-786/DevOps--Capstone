pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-south-1'
        SONARQUBE_ENV = 'MySonarQube'   // The name of your SonarQube server configured in Jenkins
        PROJECT_KEY = 'devops-capstone' // Unique project name for SonarQube
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
                echo Running code build and unit tests...
                cd app
                mvn clean verify
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                script {
                    bat '''
                    cd app
                    echo Starting SonarQube analysis...
                    '''
                    withSonarQubeEnv("${SONARQUBE_ENV}") {
                        bat '''
                        cd app
                        mvn sonar:sonar ^
                          -Dsonar.projectKey=%PROJECT_KEY% ^
                          -Dsonar.host.url=http://localhost:9000 ^
                          -Dsonar.login=admin ^
                          -Dsonar.password=admin
                        '''
                    }
                }
            }
        }

        stage('Wait for SonarQube Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: false
                }
            }
        }

        stage('Save Terraform Private Key') {
            steps {
                bat '''
                cd terraform
                terraform output -raw private_key_pem > ec2_key.pem
                echo "Skipping chmod (not needed on Windows)"
                '''
            }
        }

        stage('Show SonarQube URL') {
            steps {
                bat '''
                cd terraform
                for /f "usebackq delims=" %%i in (`terraform output -raw ec2_public_ip`) do set EC2_IP=%%i
                echo =============================================
                echo ✅ SonarQube is available at: http://%EC2_IP%:9000
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
            echo '✅ Pipeline completed.'
        }
    }
}
