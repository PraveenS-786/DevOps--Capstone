pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-south-1'
        SONARQUBE_ENV = 'MySonarQube'   // Name of your SonarQube server config in Jenkins
        PROJECT_KEY = 'devops-capstone' // Unique Sonar project key
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
                    // Fetch EC2 public IP from Terraform output
                    def ec2_ip = bat(
                        script: 'cd terraform && terraform output -raw ec2_public_ip',
                        returnStdout: true
                    ).trim()

                    echo "SonarQube Server: http://${ec2_ip}:9000"

                    // Run SonarQube analysis against EC2 SonarQube server
                    withSonarQubeEnv("${SONARQUBE_ENV}") {
                        bat """
                        echo Running SonarQube analysis on http://${ec2_ip}:9000 ...
                        mvn sonar:sonar ^
                          -Dsonar.projectKey=%PROJECT_KEY% ^
                          -Dsonar.host.url=http://${ec2_ip}:9000 ^
                          -Dsonar.login=admin ^
                          -Dsonar.password=admin
                        """
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
