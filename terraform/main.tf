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
    "set -e",
    "sudo apt-get update -y",
    "sudo apt-get install -y openjdk-17-jdk wget unzip",
    "wget -q https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.6.0.92116.zip -O /tmp/sonarqube.zip",
    "sudo unzip /tmp/sonarqube.zip -d /opt/",
    "sudo mv /opt/sonarqube-* /opt/sonarqube",
    "sudo useradd -m sonar || true",
    "sudo chown -R sonar:sonar /opt/sonarqube",
    "sudo bash -c 'cat > /etc/systemd/system/sonarqube.service <<EOF\n[Unit]\nDescription=SonarQube service\nAfter=network.target\n\n[Service]\nType=forking\nExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start\nExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop\nUser=sonar\nGroup=sonar\nRestart=always\nLimitNOFILE=65536\n\n[Install]\nWantedBy=multi-user.target\nEOF'",
    "sudo systemctl daemon-reload",
    "sudo systemctl enable sonarqube",
    "sudo systemctl start sonarqube"
  ]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.jenkins_key.private_key_pem
    host        = self.public_ip
    timeout     = "5m"
  }
}

}


