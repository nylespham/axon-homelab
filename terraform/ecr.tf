# Private ECR repository for the Flask app image.
# Build and push with the Makefile at the repo root (make push).

resource "aws_ecr_repository" "app" {
  name = var.app_repository_name

  # A tag always means the same image: a push can't silently replace what's
  # running, and the deployed tag (git SHA) maps to exactly one build
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  # Lab only: lets terraform destroy remove the repo even with images in it
  force_delete = true
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images (failed or superseded pushes) after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep the 20 most recent images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = { type = "expire" }
      },
    ]
  })
}

# Least-privilege image pulls for the nodes.
#
# The EKS module always attaches AmazonEC2ContainerRegistryReadOnly to the
# node role (no toggle), which allows pulling from every repository in the
# account and listing/describing them. A permissions boundary caps that
# without replacing the module's role: effective permissions are the
# intersection of the role's policies and this boundary.
# - Everything except ECR passes through unchanged (EKS worker, CNI, etc.)
# - ECR is limited to pulls from this repository and from AWS's EKS add-on
#   registry (vpc-cni, kube-proxy, coredns, EBS CSI, Pod Identity images)
data "aws_iam_policy_document" "node_boundary" {
  statement {
    sid         = "AllowAllExceptEcr"
    effect      = "Allow"
    not_actions = ["ecr:*"]
    resources   = ["*"]
  }

  statement {
    sid       = "EcrAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # account-level action, no resource scoping
  }

  statement {
    sid    = "EcrPullAppAndEksAddons"
    effect = "Allow"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
    ]
    resources = [
      aws_ecr_repository.app.arn,
      "arn:aws:ecr:${var.aws_region}:${var.eks_addon_registry_account}:repository/*",
    ]
  }
}

resource "aws_iam_policy" "node_boundary" {
  name_prefix = "${var.cluster_name}-node-boundary-"
  description = "Permissions boundary for EKS nodes: ECR pulls only from the app repo and the EKS add-on registry"
  policy      = data.aws_iam_policy_document.node_boundary.json
}
