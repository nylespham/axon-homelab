# Security monitoring and alerting.
#
# Signals already in place elsewhere:
# - EKS control-plane audit/api/authenticator logs -> CloudWatch (eks.tf)
# - WAF request logs -> CloudWatch (waf.tf)
# This file turns those into alerts: an SNS topic, CloudWatch alarms on WAF
# blocks, and metric filters over the audit log for high-risk API calls.

resource "aws_sns_topic" "security_alerts" {
  name = "${var.cluster_name}-security-alerts"

  tags = {
    Environment = "eks-interview-lab"
    Terraform   = "true"
  }
}

resource "aws_sns_topic_subscription" "security_alerts_email" {
  count     = var.alert_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# --- WAF: alarm when blocks spike (attack in progress) ---
resource "aws_cloudwatch_metric_alarm" "waf_blocked_spike" {
  alarm_name          = "${var.cluster_name}-waf-blocked-spike"
  alarm_description   = "WAF blocked > 50 requests in 5 min: possible attack or scan"
  namespace           = "AWS/WAFV2"
  metric_name         = "BlockedRequests"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 50
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = aws_wafv2_web_acl.app.name
    Region = var.aws_region
    Rule   = "ALL"
  }

  alarm_actions = [aws_sns_topic.security_alerts.arn]
  ok_actions    = [aws_sns_topic.security_alerts.arn]

  tags = {
    Environment = "eks-interview-lab"
    Terraform   = "true"
  }
}

# --- WAF: alarm specifically on rate-limit blocks (brute force / DoS) ---
resource "aws_cloudwatch_metric_alarm" "waf_rate_limited" {
  alarm_name          = "${var.cluster_name}-waf-rate-limited"
  alarm_description   = "WAF rate-based rule is blocking a source IP"
  namespace           = "AWS/WAFV2"
  metric_name         = "BlockedRequests"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = aws_wafv2_web_acl.app.name
    Region = var.aws_region
    Rule   = "RateLimit"
  }

  alarm_actions = [aws_sns_topic.security_alerts.arn]

  tags = {
    Environment = "eks-interview-lab"
    Terraform   = "true"
  }
}

# --- Audit log metric filters: high-risk Kubernetes API calls ---
# The EKS audit log group is created by the module as /aws/eks/<cluster>/cluster.
locals {
  eks_audit_log_group = "/aws/eks/${var.cluster_name}/cluster"
}

# pods/exec and pods/attach = someone getting a shell in a pod
resource "aws_cloudwatch_log_metric_filter" "pod_exec" {
  name           = "${var.cluster_name}-pod-exec"
  log_group_name = local.eks_audit_log_group

  # Match the pods/exec|attach subresource regardless of verb: websocket-based
  # exec (newer kubectl) logs verb "get", older exec logs "create", so keying
  # on verb misses half of them.
  pattern = "{ ($.objectRef.resource = \"pods\") && ($.objectRef.subresource = \"exec\" || $.objectRef.subresource = \"attach\") }"

  metric_transformation {
    name          = "PodExecCount"
    namespace     = "EksSecurity/${var.cluster_name}"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "pod_exec" {
  alarm_name          = "${var.cluster_name}-pod-exec"
  alarm_description   = "kubectl exec/attach into a pod (interactive access)"
  namespace           = "EksSecurity/${var.cluster_name}"
  metric_name         = "PodExecCount"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}

# Reads of Secrets (get/list) outside the system components
resource "aws_cloudwatch_log_metric_filter" "secret_access" {
  name           = "${var.cluster_name}-secret-access"
  log_group_name = local.eks_audit_log_group

  pattern = "{ ($.objectRef.resource = \"secrets\") && ($.verb = \"get\" || $.verb = \"list\") && ($.user.username != \"system:*\") }"

  metric_transformation {
    name          = "SecretAccessCount"
    namespace     = "EksSecurity/${var.cluster_name}"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "secret_access" {
  alarm_name          = "${var.cluster_name}-secret-access"
  alarm_description   = "A non-system principal read Secrets via the API"
  namespace           = "EksSecurity/${var.cluster_name}"
  metric_name         = "SecretAccessCount"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}

# 403s from the API server (failed authz: probing or a misconfigured client).
# Match on responseStatus.code, not the annotations["authorization.k8s.io/
# decision"] key: CloudWatch JSON filter selectors read dots as nested
# fields, so a key that literally contains dots can't be referenced.
resource "aws_cloudwatch_log_metric_filter" "authz_denied" {
  name           = "${var.cluster_name}-authz-denied"
  log_group_name = local.eks_audit_log_group

  pattern = "{ ($.responseStatus.code = 403) }"

  metric_transformation {
    name          = "AuthzDeniedCount"
    namespace     = "EksSecurity/${var.cluster_name}"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "authz_denied" {
  alarm_name          = "${var.cluster_name}-authz-denied"
  alarm_description   = "Spike in forbidden API requests (authz probing)"
  namespace           = "EksSecurity/${var.cluster_name}"
  metric_name         = "AuthzDeniedCount"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 20
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}

output "security_alerts_topic_arn" {
  description = "SNS topic for security alerts (subscribe more endpoints as needed)"
  value       = aws_sns_topic.security_alerts.arn
}
