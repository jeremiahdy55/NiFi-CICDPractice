resource "aws_eks_cluster" "eks_cluster" {
  name     = "my-eks-cluster" # used in {aws kubectl update-kubeconfig ...} command after {terraform apply}
  role_arn = aws_iam_role.eks_cluster_role.arn
  version = "1.29"

  vpc_config {
    subnet_ids = [aws_subnet.public.id, aws_subnet.public_b.id]
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids = [aws_security_group.eks_cluster_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSVPCResourceController
  ]
}

# IAM Role for EKS cluster control plane
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster_role.name
}

data "aws_eks_cluster" "cluster" {
  name = aws_eks_cluster.eks_cluster.name
}

# data "aws_eks_cluster_auth" "cluster" {
#   name = aws_eks_cluster.eks_cluster.name
# }

