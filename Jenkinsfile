pipeline {
    agent any

       environment {
        AWS_REGION     = 'ap-south-1'
        SONARQUBE_ENV  = 'MySonarQube'
        PROJECT_KEY    = 'devops-capstone'
        SONAR_USER     = 'admin'
        SONAR_PASS     = 'admin'
        DOCKERHUB_USERNAME = 'praveen197'   
        APP_NAME       = 'devops-capstone-app'
    }


    parameters {
        booleanParam(name: 'DESTROY_INSTANCE', defaultValue: false, description: 'Destroy EC2 after analysis')
    }

    stages {

        stage('Checkout Code') {
            steps {
                echo " Checking out repository..."
                git branch: 'main', url: 'https://github.com/PraveenS-786/DevOps--Capstone.git'
            }
        }

        stage('Provision SonarQube EC2 (Terraform)') {
            steps {
                echo " Running Terraform to create EC2..."
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
                    echo " SonarQube server starting at: http://${ec2_ip}:9000"
                    echo " Waiting 2 minutes for SonarQube to start..."
                    sleep(time: 120, unit: 'SECONDS')
                }
            }
        }

     stage('Generate SonarQube Token') {
    steps {
        script {
            //  Capture EC2 IP correctly
            bat '''
            cd terraform
            terraform output -raw ec2_public_ip > ec2_ip.txt
            '''
            def ec2_ip = readFile('terraform/ec2_ip.txt').trim()
            echo " SonarQube server IP: ${ec2_ip}"

            //  Generate token safely using captured IP
            bat """
            curl -u ${SONAR_USER}:${SONAR_PASS} ^
                 -X POST "http://${ec2_ip}:9000/api/user_tokens/generate?name=jenkins-token-${BUILD_ID}" ^
                 -o token.json
            """

            //  Parse JSON and export token
            def tokenJson = readJSON file: 'token.json'
            env.SONAR_TOKEN = tokenJson.token
            echo " Temporary SonarQube token created successfully."
        }
    }
}



      stage('Build & Analyze Code') {
    steps {
        script {
            //   saved IP file instead of calling terraform inline
            def ec2_ip = readFile('terraform/ec2_ip.txt').trim()
            echo "Running SonarQube analysis against ${ec2_ip}:9000"

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
            def ec2_ip = readFile('terraform/ec2_ip.txt').trim()
            def status = "NONE"
            def attempts = 0

            echo "📊 Waiting for SonarQube to process the analysis report..."

            //  Poll SonarQube every 10s until we get OK or ERROR (max 2 min)
            while (status == "NONE" && attempts < 12) {
                bat """
                curl -s -u ${SONAR_TOKEN}: ^
                     "http://${ec2_ip}:9000/api/qualitygates/project_status?projectKey=${PROJECT_KEY}" ^
                     -o sonar_result.json
                """
                def sonarResult = readJSON file: 'sonar_result.json'
                status = sonarResult.projectStatus.status
                echo "Attempt ${attempts + 1}: Quality Gate status = ${status}"
                if (status == "NONE") {
                    sleep(time: 10, unit: 'SECONDS')
                }
                attempts++
            }

            echo "🎯 Final SonarQube Quality Gate Status: ${status}"

            if (status != "OK") {
                error(" Quality Gate failed! Check SonarQube dashboard for details.")
            } else {
                echo "Code passed the SonarQube Quality Gate!"
            }
        }
    }
}
      stage('Build WAR File') {
    steps {
        bat """
        mvn clean package -DskipTests
        """
    }
}

stage('Build Docker Image') {
    steps {
        script {
            echo "🐳 Building Docker image..."
            bat """
            docker build -t ${DOCKERHUB_USERNAME}/${APP_NAME}:${BUILD_NUMBER} .
            """
        }
    }
}




stage('Deploy App on EC2') {
    steps {
        script {
            def ec2_ip = readFile('terraform/ec2_ip.txt').trim()
            echo "🚀 Deploying container on EC2 (${ec2_ip})..."

            bat """
            pscp -i terraform/jenkins-sonarqube-key.pem terraform/jenkins-sonarqube-key.pem ubuntu@${ec2_ip}:/home/ubuntu/
            """

            bat """
            plink -i terraform/jenkins-sonarqube-key.pem ubuntu@${ec2_ip} ^
              "sudo apt-get update -y && sudo apt-get install -y docker.io && \
               sudo systemctl start docker && sudo systemctl enable docker && \
               sudo docker stop devops-capstone-app || true && sudo docker rm devops-capstone-app || true && \
               sudo docker pull praveen197/devops-capstone-app:51 && \
               sudo docker run -d -p 8080:8080 --name devops-capstone-app praveen197/devops-capstone-app:51"
            """
        }
    }
}




        stage('Revoke Token & Show Dashboard') {
    steps {
        script {
            // ✅ Read the EC2 IP from the saved file instead of calling terraform inline
            def ec2_ip = readFile('terraform/ec2_ip.txt').trim()

            // ✅ Revoke the token safely
            bat """
            curl -u ${SONAR_USER}:${SONAR_PASS} ^
                 -X POST "http://${ec2_ip}:9000/api/user_tokens/revoke?name=jenkins-token-${BUILD_ID}"
            """

            // ✅ Print the dashboard URL
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













