# Secrets Management & Monitoring

Covers the two hardening areas from `kubernetes/SECURITY_HARDENING.md`:
secrets management (encryption, rotation, access control) and monitoring
(audit logging, security monitoring, alerting). The WAF deploy steps are in
`kubernetes/app/README.md`.

---

## Secrets Management

### Encryption at rest ✅
- **Kubernetes Secrets:** the EKS cluster uses envelope encryption with a
  KMS key (`eks.tf` module default; verified live —
  `describe-cluster.encryptionConfig` has a `keyArn` on `secrets`). etcd
  stores the ciphertext, not the plaintext.
- **The Secret values themselves** are random, generated at install with
  `openssl rand -hex 24`, never written to git or a file (D4). The Postgres
  volume holding the data is an encrypted gp3 EBS volume (I8/D7).

### Access control ✅
- Namespaced: `app-db-credentials` lives only in `vulnerable-app`;
  `postgres-credentials` only in `database`. A pod can't read another
  namespace's Secrets.
- The app pod runs with `automountServiceAccountToken: false` and its
  ServiceAccount has **no** RBAC Role, so a compromised app can't call the
  Kubernetes API to list Secrets (K5). Verified: a non-system principal
  reading Secrets triggers the `secret-access` alarm below.
- Only `appuser`'s password is copied to the app namespace; the `postgres`
  superuser password never leaves `database`.

### Rotation
Rotation isn't automatic yet. Two levels:

**Manual (works today):**
1. Change the password in Postgres: `ALTER USER appuser WITH PASSWORD '<new>';`
2. Update both Secrets (`postgres-credentials` in `database`,
   `app-db-credentials` in `vulnerable-app`).
3. `kubectl -n vulnerable-app rollout restart deployment/vulnerable-flask`
   (env vars are read only at container start).

Recreating the Secret alone does **not** rotate the DB password — Postgres
only reads it when initialising an empty volume.

**Automated (recommended next step): External Secrets Operator + AWS Secrets Manager**
- Store the password once in Secrets Manager; enable managed rotation (a
  rotation Lambda updates the secret and the database on a schedule).
- Install External Secrets Operator (ESO) with a Pod Identity role scoped to
  `secretsmanager:GetSecretValue` on that one secret ARN.
- An `ExternalSecret` in each namespace syncs it into a Kubernetes Secret on
  an interval, so rotation propagates without editing manifests.
- Benefits over the copy approach: one source of truth, CloudTrail audit of
  every secret read, scheduled rotation, no drift between namespaces.

This is the `D4` "next step". The IAM pattern mirrors the EBS CSI / ALB
controller roles already in Terraform (Pod Identity, least-privilege policy).

---

## Monitoring & Alerting

### Log collection ✅
| Source | Destination | Where configured |
|---|---|---|
| EKS control plane: `api`, `audit`, `authenticator` | CloudWatch `/aws/eks/eks-interview-lab/cluster` | `eks.tf` (module default) |
| WAF request logs (with `authorization`/`cookie` redacted) | CloudWatch `aws-waf-logs-eks-interview-lab-app` | `waf.tf` |
| ALB access logs (optional) | S3 | Ingress annotation (commented) |

Pod/app logs are on stdout; ship them with Fluent Bit to CloudWatch
(Container Insights) as a follow-up if you need app-level log search.

### Security monitoring & alerting ✅
`monitoring.tf` creates an SNS topic (`…-security-alerts`) and these alarms;
set `alert_email` in `terraform.tfvars` to get notified.

| Alarm | Fires when | Signal |
|---|---|---|
| `waf-blocked-spike` | >50 WAF blocks / 5 min | attack or scan in progress |
| `waf-rate-limited` | any rate-rule block | brute force / DoS on a source IP |
| `pod-exec` | `kubectl exec`/`attach` into any pod | interactive access to a container |
| `secret-access` | >5 Secret `get`/`list` by a non-system user / 5 min | possible credential theft |
| `authz-denied` | >20 forbidden API calls / 5 min | RBAC probing |

Metric filters parse the EKS audit JSON for the pod-exec, secret-access and
authz-denied signals.

### Testing the alerts
```bash
# Subscribe (confirm via the email link) then:
terraform output security_alerts_topic_arn

# pod-exec alarm: exec into a pod, then watch the alarm flip to ALARM
kubectl -n vulnerable-app exec deploy/vulnerable-flask -- true
aws cloudwatch describe-alarms --region us-west-2 \
  --alarm-names eks-interview-lab-pod-exec --query 'MetricAlarms[0].StateValue'

# WAF block: once the ALB is up, a request matching a managed rule or /debug
# increments BlockedRequests; the blocked-spike alarm fires past threshold.
```
Alarms evaluate over 5-minute periods, so allow a few minutes. Audit-log
metric filters depend on the control-plane audit log, which is already on.
