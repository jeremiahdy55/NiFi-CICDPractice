output "jenkins_public_ip" {
  value = aws_instance.jenkins.public_ip
}

output "jenkins_public_ip" {
  value = aws_instance.nifi.public_ip
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_id" {
  value = aws_subnet.public.id
}

output "ci_config_bucket_name" {
  value = aws_s3_bucket.ci_config_bucket.bucket
}