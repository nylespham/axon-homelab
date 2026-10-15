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

variable "api_allowed_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the public EKS API endpoint, e.g. [\"203.0.113.10/32\"]. Set in terraform.tfvars"

  validation {
    condition     = !contains(var.api_allowed_cidrs, "0.0.0.0/0")
    error_message = "Don't open the EKS API to the whole internet; use your own IP /32."
  }
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

variable "app_repository_name" {
  type        = string
  default     = "vulnerable-flask"
  description = "Name of the private ECR repository for the app image"
}

variable "eks_addon_registry_account" {
  type        = string
  default     = "602401143452"
  description = "AWS account hosting the EKS add-on images for this region (602401143452 for us-west-2 and most commercial regions; see the EKS docs 'Amazon container image registries')"
}

variable "waf_rate_limit" {
  type        = number
  default     = 2000
  description = "Max requests per 5-minute window per source IP before WAF blocks (AWS minimum is 100; 2000 is a sane floor)"
}

variable "log_retention_days" {
  type        = number
  default     = 30
  description = "CloudWatch log retention for WAF and app logs"
}

variable "alert_email" {
  type        = string
  default     = ""
  description = "Email to subscribe to the security-alerts SNS topic. Empty = create the topic but no subscription (add one later)."
}
