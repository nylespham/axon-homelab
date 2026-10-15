# NOTE (homelab): this provisions the IAM role + Pod Identity for the AWS
# Load Balancer Controller, but the controller itself (a Helm chart) and the
# Ingress (kubernetes/app/ingress.yaml) are NOT installed in this lab — we
# don't expose the app on a public ALB. These resources are kept as a
# reference for how the WAF would be wired to a real ALB. Safe to remove if
# you'd rather not create the unused IAM role.
#
# IAM for the AWS Load Balancer Controller, which turns the app's Ingress
# into an ALB and attaches the WAF web ACL (terraform/waf.tf).
#
# Assumed through EKS Pod Identity (same pattern as the EBS CSI driver in
# eks.tf) by the controller's service account in kube-system.
#
# The controller's required IAM policy is large and versioned by the project,
# so it's kept in alb-controller-iam-policy.json instead of inline. Refresh it
# with (pin the controller version you install):
#   curl -o terraform/alb-controller-iam-policy.json \
#     https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.13.0/docs/install/iam_policy.json

resource "aws_iam_role" "alb_controller" {
  name_prefix = "${var.cluster_name}-albc-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = {
    Environment = "eks-interview-lab"
    Terraform   = "true"
  }
}

resource "aws_iam_policy" "alb_controller" {
  name_prefix = "${var.cluster_name}-albc-"
  description = "AWS Load Balancer Controller permissions"
  policy      = file("${path.module}/alb-controller-iam-policy.json")
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

# Bind the role to the controller's service account via Pod Identity. The
# Helm install must use this exact SA name (serviceAccount.name) and not
# create its own IAM annotation.
resource "aws_eks_pod_identity_association" "alb_controller" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.alb_controller.arn
}

output "alb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller service account"
  value       = aws_iam_role.alb_controller.arn
}
