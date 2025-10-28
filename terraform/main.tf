##########################################
# PROVIDER CONFIGURATION
##########################################
provider "aws" {
  region = var.region
}

##########################################
# SSH KEY GENERATION
##########################################
# Generate private key locally (kept in Jenkins)
resource "tls_private_key" "jenkins_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS key pair using the generated public key
resource "aws_key_pair" "jenkins_generated" {
  key_name   = "jenkins-sonarqube-key"
  public_key = tls_private_key.jenkins_key.public_key_openssh
}

##########################################
# SECURITY GROUP
##########################################
resource "aws_security_group" "sonarqube_sg" {
  name        = "sonarqube_sg"
  description = "Allow SSH and SonarQube access"

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SonarQube Web UI"
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

##########################################
# EC2 INSTANCE
##########################################
resource "aws_instance" "sonarqube_ec2" {
  ami                    = "ami-0f5ee92e2d63afc18" # Ubuntu 22.04 (ap-south-1)
  instance_type          = "m7i-flex.large"
  key_name               = aws_key_pair.jenkins_generated.key_name
  vpc_security_group_ids = [aws_security_group.sonarqube_sg.id]

  tags = {
    Name = "SonarQube-Server"
  }

  ##########################################
  # SSH CONNECTION FOR REMOTE EXEC
  ##########################################
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.jenkins_key.private_key_pem
    host        = self.public_ip
  }

  ##########################################
  # REMOTE EXEC PROVISIONER
  ##########################################
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get clean",
      "sudo apt-get update -y",
      "sudo apt-get install -y software-properties-common wget unzip curl",
      "sudo add-apt-repository universe -y",
      "sudo apt-get update -y",
      "sudo apt-get install -y openjdk-17-jdk",
      "wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.6.0.92116.zip",
      "unzip sonarqube-*.zip",
      "sudo mv sonarqube-* /opt/sonarqube",
      "sudo useradd -r -s /bin/false sonar || true",
      "sudo chown -R sonar:sonar /opt/sonarqube",
      <<-EOF
        sudo bash -c 'cat <<SERVICE > /etc/systemd/system/sonarqube.service
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
SERVICE'
      EOF
    ,
      "sudo systemctl daemon-reload",
      "sudo systemctl enable sonarqube",
      "sudo systemctl start sonarqube"
    ]
  }

  ##########################################
  # OPTIONAL: Print IP After Creation
  ##########################################
  provisioner "local-exec" {
    command = "echo EC2 Public IP: ${self.public_ip}"
  }
}

##########################################
# OUTPUTS
##########################################
output "ec2_public_ip" {
  value = aws_instance.sonarqube_ec2.public_ip
}
