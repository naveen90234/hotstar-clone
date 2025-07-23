# EKS Cluster and Node Group Provisioning using Terraform
# This script provisions an EKS cluster and a node group in AWS using Terraform.
data "aws_iam_policy_document" "assume_role" { # This document defines the trust relationship for the EKS cluster IAM role with AWS EKS service
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "example" { # This IAM role is for the EKS cluster
  name               = "eks-cluster-cloud"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSClusterPolicy" { # This attaches the AmazonEKSClusterPolicy to the EKS cluster IAM role
  # This policy allows the EKS cluster to manage AWS resources
  # such as EC2 instances, security groups, etc.
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.example.name
}

#get vpc data
data "aws_vpc" "default" { # This retrieves the default VPC in the region
  default = true
}
#get public subnets for cluster
data "aws_subnets" "public" { # This retrieves the public subnets in the default VPC
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
#cluster provision
resource "aws_eks_cluster" "example" { # This resource creates the EKS cluster
  name     = "EKS_CLOUD"
  role_arn = aws_iam_role.example.arn

  vpc_config {
    subnet_ids = data.aws_subnets.public.ids
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSClusterPolicy,
  ]
}

resource "aws_iam_role" "example1" { # This IAM role is for the EKS node group
  # This role allows the EKS node group to interact with AWS services
  # such as EC2, ECR, and the EKS control plane.
  name = "eks-node-group-cloud"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSWorkerNodePolicy" { # This attaches the AmazonEKSWorkerNodePolicy to the EKS node group IAM role
  # This policy allows the EKS node group to manage worker nodes in the cluster.
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.example1.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKS_CNI_Policy" { # This attaches the AmazonEKS_CNI_Policy to the EKS node group IAM role
  # This policy allows the EKS node group to manage the Amazon VPC CNI plugin
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.example1.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEC2ContainerRegistryReadOnly" { # This attaches the AmazonEC2ContainerRegistryReadOnly policy to the EKS node group IAM role
  # This policy allows the EKS node group to pull container images from Amazon ECR.
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.example1.name
}

#create node group
resource "aws_eks_node_group" "example" { # This resource creates the EKS node group
  # The node group is a set of EC2 instances that run the Kubernetes worker nodes.
  cluster_name    = aws_eks_cluster.example.name
  node_group_name = "Node-cloud"
  node_role_arn   = aws_iam_role.example1.arn
  subnet_ids      = data.aws_subnets.public.ids

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }
  instance_types = ["t2.medium"]

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.example-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.example-AmazonEC2ContainerRegistryReadOnly,
  ]
}
