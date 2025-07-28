# Create IAM Instance Profile
resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "jenkins-ec2-instance-profile"
  role = aws_iam_role.jenkins_role.name
}

# IAM Role for Jenkins EC2 Instance to Access EKS and Other AWS Services
resource "aws_iam_role" "jenkins_role" {
  name = "jenkins-eks-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach VPC access policy
resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
}


# Create custom S3 Bucket access for Jenkins instance
resource "aws_iam_policy" "s3_access" {
  name = "jenkins-s3-access"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      Resource = [
        "${aws_s3_bucket.ci_config_bucket.arn}/*"
      ]
    }]
  })
}

# Attach custom S3 bucket access to Jenkins IAM Role
resource "aws_iam_role_policy_attachment" "jenkins_s3_access_attach" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}