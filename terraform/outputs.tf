output "jenkins_public_ip" {
  value = aws_instance.jenkins.public_ip
}

output "nifi_public_ip" {
  value = aws_instance.nifi.public_ip
}

output "nifi_private_ip" {
  value = aws_instance.nifi.private_ip
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_id" {
  value = aws_subnet.public.id
}

output "S3_bucket_name" {
  value = aws_s3_bucket.ci_config_bucket.bucket
}

output "eks_cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "eks_cluster_ca_certificate" {
  value = aws_eks_cluster.eks_cluster.certificate_authority[0].data
}
