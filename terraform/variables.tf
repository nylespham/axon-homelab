variable "aws_region" {
  type        = string
  default     = "us-west-2"
  description = "AWS region for resources"
}

variable "cluster_name" {
  type        = string
  default     = "eks-interview-lab"
  description = "EKS cluster name"
}

variable "cluster_version" {
  type        = string
  default     = "1.32"
  description = "Kubernetes version for EKS cluster"
}

variable "node_instance_type" {
  type        = string
  default     = "t3.small"
  description = "EC2 instance type for EKS nodes"
}

variable "node_desired_capacity" {
  type        = number
  default     = 1
  description = "Desired number of nodes in the node group"
}

variable "node_max_capacity" {
  type        = number
  default     = 3
  description = "Maximum number of nodes in the node group"
}

variable "use_spot_instances" {
  type        = bool
  default     = false
  description = "Use Spot instances (can be interrupted)"
}
