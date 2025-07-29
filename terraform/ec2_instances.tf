## Define the ec2 instances to be provisioned by terraform: Jenkins instance, Kafka instance
resource "aws_instance" "jenkins" {
  ami                         = var.ami_id
  instance_type               = var.instance_type_medium
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.default.id]
#   key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.jenkins_profile.name

  # Run these commands on creation
user_data = <<-EOF
#!/bin/bash

sleep 30
exec > /var/log/jenkins-setup.log 2>&1

# System update
sudo apt-get update -y
sudo apt-get upgrade -y

# Install zip and unzip
sudo apt-get install -y zip unzip

# Install Java (required to run Jenkins)
sudo apt-get install -y openjdk-17-jdk curl gnupg software-properties-common

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
sudo rm -rf awscliv2.zip aws/

# Add Jenkins repository and import GPG key
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
/usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
/etc/apt/sources.list.d/jenkins.list > /dev/null

# Install Jenkins
sudo apt-get update -y
sudo apt-get install -y jenkins

# Add S3_bucket file name as environment variable
echo "S3_BUCKET=${aws_s3_bucket.ci_config_bucket.bucket}" >> /etc/environment

# Enable and start Jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins
EOF

  tags = {
    Name = "Jenkins-Server-fromTF"
    Role = "jenkins"
  }

  root_block_device {
    volume_size = 24   # 24 GB Storage
    volume_type = "gp3"
  }

  depends_on = [
    aws_internet_gateway.igw,
    aws_route_table_association.public_assoc,
    aws_s3_bucket.ci_config_bucket
  ]
}

resource "aws_instance" "nifi" {
  ami                         = var.ami_id
  instance_type               = var.instance_type_medium
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.default.id]
  associate_public_ip_address = true

  # provide SSH key to access instance directly
  key_name = var.key_name

  tags = {
    Name = "NiFi-Server"
    Role = "nifi"
  }

  root_block_device {
    volume_size = 12
    volume_type = "gp3"
  }

  depends_on = [
    aws_internet_gateway.igw,
    aws_route_table_association.public_assoc,
  ]
}