module "eks" {
  source             = "terraform-aws-modules/eks/aws"
  version            = "~> 21.0"
  name               = var.cluster_name
  kubernetes_version = var.cluster_version
  subnet_ids         = module.vpc.private_subnets
  vpc_id             = module.vpc.vpc_id

  # Public API endpoint restricted to known CIDRs (set yours in
  # terraform.tfvars); nodes use the private endpoint
  endpoint_public_access                   = true
  endpoint_public_access_cidrs             = var.api_allowed_cidrs
  endpoint_private_access                  = true
  enable_cluster_creator_admin_permissions = true

  addons = {
    # Managed VPC CNI with network policy enforcement. Without
    # enableNetworkPolicy, EKS silently ignores every NetworkPolicy.
    vpc-cni = {
      before_compute              = true
      resolve_conflicts_on_create = "OVERWRITE"
      configuration_values        = jsonencode({ enableNetworkPolicy = "true" })
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
    # EBS CSI driver: EKS has no working volume provisioner without it, so the
    # Postgres PVC would stay Pending
    aws-ebs-csi-driver = {
      pod_identity_association = [{
        role_arn        = aws_iam_role.ebs_csi.arn
        service_account = "ebs-csi-controller-sa"
      }]
    }
  }

  # Node group configuration
  eks_managed_node_groups = {
    default = {
      desired_size   = var.node_desired_capacity
      min_size       = 1
      max_size       = var.node_max_capacity
      instance_types = [var.node_instance_type]

      # Instance type configuration
      capacity_type = var.use_spot_instances ? "SPOT" : "ON_DEMAND"

      # Security improvements
      ami_type = "AL2_x86_64"

      # Node group configuration
      disk_size = 20

      # Labels
      labels = {
        Environment = "interview"
        Purpose     = "devsecops-lab"
      }
    }
  }

  tags = {
    Environment = "eks-interview-lab"
    Terraform   = "true"
    Purpose     = "devsecops-interview"
  }
}

# IAM role for the EBS CSI controller, assumed through EKS Pod Identity
resource "aws_iam_role" "ebs_csi" {
  name_prefix = "${var.cluster_name}-ebs-csi-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
