module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = ">= 4.0"

  name = "eks-interview-lab-vpc"
  cidr = "10.20.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.20.1.0/24", "10.20.2.0/24"]
  public_subnets  = ["10.20.101.0/24", "10.20.102.0/24"]

  # Network configuration
  enable_nat_gateway = true
  single_nat_gateway = true
  enable_vpn_gateway = false

  # Security improvements
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags
  tags = {
    Environment = "eks-interview-lab"
    Purpose     = "devsecops-interview"
  }

  # Subnet tags for EKS
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

data "aws_availability_zones" "available" {}
