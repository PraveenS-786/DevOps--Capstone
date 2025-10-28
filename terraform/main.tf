provider "aws" {
  region = var.region
}

# Generate SSH key pair locally (private key will stay in Jenkins workspace)
resource "tls_private_key" "jenkins_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS key pair from the generated public key
resource "aws_key_pair" "jenkins_generated" {
  key_name   = "jenkins-sonarqube-key"
  public_key = tls_private_key.jenkins_key.public_key_openssh
}

# Create Security Group for EC2
resource "aws_security_group" "sonarqube_sg" {
  name        = "sonarqube_sg"
  description = "Allow SSH and SonarQube access"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create EC2 Instance
resource "aws_instance" "sonarqube_ec2" {
  ami           = "ami-0f5ee92e2d63afc18"  # Ubuntu 22.04 (change per region)
  instance_type = "m7i-flex.large"
  key_name      = aws_key_pair.jenkins_generated.key_name
  vpc_security_group_ids = [aws_security_group.sonarqube_sg.id]

  tags = {
    Name = "SonarQube-Server"
  }

provisioner "remote-exec" {
  inline = [
    "sudo apt-get clean",
    "sudo apt-get update -y",
    "sudo apt-get install -y software-properties-common",
    "sudo add-apt-repository universe -y",
    "sudo apt-get update -y",
    "sudo apt-get install -y openjdk-17-jdk wget unzip curl",
    "wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.6.0.92116.zip",
    "unzip sonarqube-*.zip",
    "sudo mv sonarqube-* /opt/sonarqube",
    "sudo useradd -r -s /bin/false sonar || true",
    "sudo chown -R sonar:sonar /opt/sonarqube",
    "sudo bash -c 'cat <<EOF > /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonar
Group=sonar
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF'",
    "sudo systemctl daemon-reload",
    "sudo systemctl enable sonarqube",
    "sudo systemctl start sonarqube"
  ]
}


}


