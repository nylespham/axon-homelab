# Security Configuration Examples
# These are examples for candidates to reference during the interview
# Copy and customize these configurations as needed

# Security Group for EKS Cluster
resource "aws_security_group" "eks_cluster_sg" {
  name_prefix = "eks-cluster-"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-cluster-security-group"
  }
}

# Security Group for EKS Nodes
resource "aws_security_group" "eks_nodes_sg" {
  name_prefix = "eks-nodes-"
  vpc_id     = module.vpc.vpc_id

  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-nodes-security-group"
  }
}

# KMS Key for EKS Cluster Encryption
resource "aws_kms_key" "eks_cluster_encryption" {
  description             = "EKS Cluster Encryption Key"
  deletion_window_in_days = 7

  tags = {
    Name = "eks-cluster-encryption-key"
  }
}

# KMS Key Alias
resource "aws_kms_alias" "eks_cluster_encryption" {
  name          = "alias/eks-cluster-encryption"
  target_key_id = aws_kms_key.eks_cluster_encryption.key_id
}

# Output security group IDs for reference
output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = aws_security_group.eks_cluster_sg.id
}

output "eks_nodes_security_group_id" {
  description = "EKS nodes security group ID"
  value       = aws_security_group.eks_nodes_sg.id
}

output "kms_key_id" {
  description = "KMS key ID for cluster encryption"
  value       = aws_kms_key.eks_cluster_encryption.key_id
}
