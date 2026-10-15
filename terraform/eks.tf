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

  # Module v21 never bootstraps the default addons, so without these nodes
  # stay NotReady ("cni plugin not initialized") and DNS doesn't work.
  # Versions are pinned: unpinned, the module resolves the newest build on
  # every plan, so addons drift and show "(known after apply)". Bump on purpose:
  #   aws eks describe-addon-versions --kubernetes-version <ver> --addon-name <name>
  addons = {
    # Managed VPC CNI with network policy enforcement. Without
    # enableNetworkPolicy, EKS silently ignores every NetworkPolicy.
    vpc-cni = {
      addon_version               = "v1.23.2-eksbuild.3"
      before_compute              = true
      resolve_conflicts_on_create = "OVERWRITE"
      configuration_values        = jsonencode({ enableNetworkPolicy = "true" })
    }
    kube-proxy = {
      addon_version  = "v1.32.13-eksbuild.52"
      before_compute = true
    }
    coredns = {
      addon_version = "v1.11.4-eksbuild.80"
    }
    eks-pod-identity-agent = {
      addon_version  = "v1.4.0-eksbuild.4"
      before_compute = true
    }
    # EBS CSI driver: EKS has no working volume provisioner without it, so the
    # Postgres PVC would stay Pending
    aws-ebs-csi-driver = {
      addon_version = "v1.67.0-eksbuild.1"
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
      ami_type = "AL2023_x86_64_STANDARD"

      # Root volume. disk_size is ignored with the module's custom launch
      # template (the default), so the disk is set here, encrypted with the
      # AWS-managed aws/ebs key.
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 20
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      # Caps the module's AmazonEC2ContainerRegistryReadOnly to pulls from the
      # app repo and the EKS add-on registry (terraform/ecr.tf)
      iam_role_permissions_boundary = aws_iam_policy.node_boundary.arn

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
