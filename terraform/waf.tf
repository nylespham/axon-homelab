# AWS WAFv2 web ACL for the app's public ALB (Ingress in kubernetes/app).
#
# NOTE (homelab): this is the Task-2 "WAF configuration" deliverable. The web
# ACL and its rules are defined (and can be applied) for reference, but in
# this lab there is no public ALB to attach it to (the Ingress/ALB controller
# are left undeployed), so it inspects no live traffic here. In a real
# environment the Ingress annotation alb.ingress.kubernetes.io/wafv2-acl-arn
# attaches it. The rule design and rationale are what's being demonstrated.
#
# A WAF is a compensating control, not a fix for the app's intentional vulns
# (docs/FINDINGS.md A3): it blocks known attack patterns and rate-abuse, but
# IDOR and broken auth still need code. Scope REGIONAL = for an ALB (CLOUDFRONT
# would be for a CloudFront distribution). The ACL is attached to the ALB by
# the Ingress annotation alb.ingress.kubernetes.io/wafv2-acl-arn = this ARN.

resource "aws_wafv2_web_acl" "app" {
  name        = "${var.cluster_name}-app"
  description = "Protects the vulnerable Flask app ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # 1. AWS managed Common Rule Set (OWASP-style: broad XSS, LFI, bad patterns).
  #    Start in Count if you see false positives, then remove override_action.
  rule {
    name     = "CommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # 2. AWS managed SQLi rule set (the app's /search is injectable)
  rule {
    name     = "SQLiRuleSet"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # 3. AWS managed Known Bad Inputs (exploit payloads, path traversal)
  rule {
    name     = "KnownBadInputs"
    priority = 3
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputs"
      sampled_requests_enabled   = true
    }
  }

  # 4. Block the /debug endpoint outright (leaks env vars and DB config).
  #    The real fix is removing the route; this stops external reads now.
  rule {
    name     = "BlockDebug"
    priority = 4
    action {
      block {}
    }
    statement {
      byte_match_statement {
        search_string         = "/debug"
        positional_constraint = "STARTS_WITH"
        field_to_match {
          uri_path {}
        }
        text_transformation {
          priority = 0
          type     = "LOWERCASE"
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockDebug"
      sampled_requests_enabled   = true
    }
  }

  # 5. Block client-supplied X-Forwarded-For (the /admin check trusts it).
  #    The ALB appends the real client IP; a request that already carries the
  #    header is trying to spoof it, so drop it. Real fix is auth in code.
  rule {
    name     = "BlockXffSpoof"
    priority = 5
    action {
      block {}
    }
    statement {
      size_constraint_statement {
        comparison_operator = "GE"
        size                = 1
        field_to_match {
          single_header {
            name = "x-forwarded-for"
          }
        }
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockXffSpoof"
      sampled_requests_enabled   = true
    }
  }

  # 6. Rate limit per source IP (brute force on /login, scraping, DoS).
  #    5-minute sliding window; 2000 reqs is AWS's floor.
  rule {
    name     = "RateLimit"
    priority = 6
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.cluster_name}-app"
    sampled_requests_enabled   = true
  }

  tags = {
    Environment = "eks-interview-lab"
    Terraform   = "true"
    Purpose     = "devsecops-interview"
  }
}

# WAF logs -> CloudWatch. The log group name MUST start with aws-waf-logs-.
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.cluster_name}-app"
  retention_in_days = var.log_retention_days

  tags = {
    Environment = "eks-interview-lab"
    Terraform   = "true"
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "app" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.app.arn

  # Don't write cookie/authorization values into the logs
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }
  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
}

output "waf_web_acl_arn" {
  description = "ARN of the app WAF web ACL (set on the Ingress wafv2-acl-arn annotation)"
  value       = aws_wafv2_web_acl.app.arn
}
