################## IAM ROLE FOR EKS WORKER NODES ###################

# IAM Role with attached policy allowing EC2 instances assume this role. EC2 will be granted a temp token, a token with the permissions to assume this Role
# Check eks-control-plane.tf file, I used a different approach there that do the same
resource "aws_iam_role" "master-eks-workers-role" {
  name = "master-eks-workers-role-${terraform.workspace}"

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

### Built-in IAM Policies that allows the EC2 to call other AWS Services ###

# This policy allows Amazon EKS worker nodes to connect to Amazon EKS Clusters
# https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEKSWorkerNodePolicy.html
resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy-attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.master-eks-workers-role.name
}

# This policy provides the Amazon VPC CNI Plugin (amazon-vpc-cni-k8s) the permissions it requires to modify the IP address configuration on your EKS worker nodes.
# https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEKS_CNI_Policy.html
resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy-attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.master-eks-workers-role.name
}

# Provides read-only access to Amazon EC2 Container Registry repositories
# https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEC2ContainerRegistryReadOnly.html
resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly-attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.master-eks-workers-role.name
}

### EOF ###

#################################### EOF ##########################################

# Create two EKS Node Groups
resource "aws_eks_node_group" "master-eks-workers" {
  count           = 2
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = "${var.project}-eks-node-group-${count.index}-${terraform.workspace}"
  node_role_arn   = aws_iam_role.master-eks-workers-role.arn
  subnet_ids      = [data.aws_subnets.master-subnets.ids["${count.index}"]]
  capacity_type   = "ON_DEMAND"
  instance_types  = ["t3.micro"]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }
  update_config {
    max_unavailable = 1
  }

  # Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy-attachment,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy-attachment,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly-attachment,
  ]
}