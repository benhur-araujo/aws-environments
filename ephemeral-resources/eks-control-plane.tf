########### IAM ROLES RELATED TO EKS - CONTROL PLANE #############

# Policy to Allow EKS Service assume IAM Roles (any role). EKS will be granted a temp token, a token with the permissions to assume IAM Roles:
data "aws_iam_policy_document" "eks-assume-role" {
  statement {
    effect = "Allow" # Allow the service to assume the Role

    principals { # Identifying the service that can assume the Role
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"] # Here is the allowed Action
  }
}

# The Policy Document above will be attached to the Role, so the EKS service will be able to assume THIS role
resource "aws_iam_role" "master-eks-role" {
  name               = "master-eks-role-${terraform.workspace}"
  assume_role_policy = data.aws_iam_policy_document.eks-assume-role.json
}

# Built-in IAM Policy that allows the EKS to call other AWS Services
# https://docs.aws.amazon.com/eks/latest/userguide/security-iam-awsmanpol.html#security-iam-awsmanpol-AmazonEKSClusterPolicy
resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.master-eks-role.name
}

################################ EOF ###################################

# Create EKS Cluster
resource "aws_eks_cluster" "eks-cluster" {
  name = "${var.project}-eks-${terraform.workspace}"
  # EKS will use this role when interacting with other AWS Services
  role_arn = aws_iam_role.master-eks-role.arn
  version  = "1.27"

  kubernetes_network_config {
    # CIDR block to assign to Kubernetes pod and service IP address
    # Recommendation is to do not overlap any other resources in other network that is peered with the cluster VPC
    # Can't overlap with any CIDR block assigned to the cluster VPC
    # Need to be between /24 and /12
    service_ipv4_cidr = "172.30.0.0/16"
    ip_family         = "ipv4"
  }

  vpc_config {
    subnet_ids              = data.aws_subnets.master-subnets.ids # You can't change which subnets you want to use after cluster creation.
    endpoint_public_access  = true
    endpoint_private_access = true          # Enable EKS public API server endpoint https://docs.aws.amazon.com/eks/latest/userguide/cluster-endpoint.html
    public_access_cidrs     = ["0.0.0.0/0"] # EKS API server endpoint source IP, could be used to allow only VPN
    # security_group_ids = [] TODO: make the cluster private
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    #aws_iam_role_policy_attachment.example-AmazonEKSVPCResourceController
  ]
}