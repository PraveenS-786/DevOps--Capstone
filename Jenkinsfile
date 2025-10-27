pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID     = credentials('aws-access-key')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-key')
        TF_VAR_region         = 'ap-south-1'
    }

    stages {
        stage('Checkout Terraform Code') {
            steps {
                git branch: 'main', url: 'https://github.com/your-repo/terraform-sonarqube.git'
            }
        }

        stage('Terraform Init & Apply') {
            steps {
                sh '''
                cd terraform
                terraform init
                terraform apply -auto-approve
                '''
            }
        }

        stage('Save Terraform Private Key') {
            steps {
                sh '''
                cd terraform
                terraform output -raw private_key_pem > ec2_key.pem
                chmod 400 ec2_key.pem
                '''
            }
        }

        stage('Show SonarQube URL') {
            steps {
                sh '''
                EC2_IP=$(terraform -chdir=terraform output -raw ec2_public_ip)
                echo "✅ SonarQube is available at: http://$EC2_IP:9000"
                '''
            }
        }

        stage('Destroy Infrastructure') {
            when {
                expression { return params.DESTROY_INSTANCE == true }
            }
            steps {
                sh '''
                cd terraform
                terraform destroy -auto-approve
                '''
            }
        }
    }
}
