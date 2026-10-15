# Security Configuration Examples
#
# The provided file created two security groups and a KMS key that nothing
# used:
# - "eks_cluster_sg" / "eks_nodes_sg" weren't attached to the cluster or the
#   node group. The EKS module already creates and attaches its own cluster
#   and node security groups. The unused node SG also allowed all TCP from
#   itself and 1025-65535 from the cluster SG, broader than the module's rules.
# - "eks_cluster_encryption" KMS key wasn't wired to the cluster. The EKS
#   module already creates a KMS key and encrypts Kubernetes Secrets with it
#   (create_kms_key / encryption_config defaults), so it was a second, unused
#   key costing $1/month.
#
# Unused security resources give false assurance in a review, so they were
# removed. The real controls live in eks.tf:
# - Secrets encryption: module-managed KMS key (module default)
# - Control-plane audit logs: enabled_log_types (module default:
#   audit, api, authenticator)
# - API endpoint restricted to var.api_allowed_cidrs, private endpoint on
# - VPC CNI network policy enforcement, EBS CSI driver via Pod Identity
