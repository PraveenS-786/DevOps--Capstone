pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-south-1'
        SONARQUBE_ENV = 'MySonarQube'
        PROJECT_KEY = 'devops-capstone'
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
                mvn clean verify
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                script {
                    withSonarQubeEnv("${SONARQUBE_ENV}") {
                        bat '''
                        echo Starting SonarQube analysis...
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
