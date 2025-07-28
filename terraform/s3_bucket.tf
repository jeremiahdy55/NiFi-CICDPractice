# --- Create S3 Bucket ---
resource "aws_s3_bucket" "ci_config_bucket" {
  bucket = "cicd-config-bucket-${random_id.suffix.hex}"
  force_destroy = true

  tags = {
    Name = "cicd-config-bucket"
    Environment = "CI"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_policy" "ci_config_bucket_policy" {
  bucket = aws_s3_bucket.ci_config_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
        {
        Sid = "AllowJenkinsInstanceProfileAccess",
        Effect = "Allow",
        Principal = {
            AWS = [aws_iam_role.jenkins_role.arn]
        },
        Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject"
        ],
        Resource = "${aws_s3_bucket.ci_config_bucket.arn}/*"
        }
    ]
  })

}

# Write NiFi IP address to S3 Bucket
resource "null_resource" "upload_nifi_ip" {
  depends_on = [aws_instance.nifi]

  provisioner "local-exec" {
    environment = {
      AWS_REGION = "us-west-2"
    }
    command = <<EOT
        echo "${aws_instance.nifi.public_ip}" > /tmp/nifi_ip.txt
        aws s3 cp /tmp/nifi_ip.txt s3://${aws_s3_bucket.ci_config_bucket.bucket}/nifi_ip.txt
    EOT
  }
}