# Findings: Provided Configuration Review

A review of the lab's provided files before deploying them. Many are broken,
outdated or insecure in ways that don't show an error — they "work" but
silently do nothing. Each finding gives **impact → fix → verified**.

**27 findings:** 26 resolved (✅), 1 kept by design (🎯 A3 — the app's
deliberate vulns). Legend: ✅ fixed · 🎯 intentional.

**Jump to:** [Database](#database) · [Infrastructure](#infrastructure-terraform) ·
[Kubernetes](#kubernetes) · [Application](#application) · [Repository](#repository) ·
[Live verification](#live-verification-2026-10-16) · [Remaining risks](#remaining-risks)

## Summary

| # | Area | Finding | Status |
|---|------|---------|--------|
| D1 | Database | `init-db.sql` is MySQL syntax; on PostgreSQL it creates nothing but reports success | ✅ |
| D2 | Database | Hard-coded IDs point posts and comments at the wrong rows | ✅ |
| D3 | Database | App DB user has full privileges (`GRANT ALL`) | ✅ |
| D4 | Database | Plain-text passwords in `postgres-values.yaml` | ✅ |
| D5 | Database | Several Helm values use keys the chart doesn't have; silently ignored | ✅ |
| D6 | Database | Docs state wrong data counts and import as superuser without error stop | ✅ |
| D7 | Database | Deployed release ignored the fixed values: plain-text passwords, unencrypted gp2 volume, wrong namespace | ✅ |
| I1 | Infra | No EBS CSI driver: the Postgres PVC can never bind | ✅ (code) |
| I2 | Infra | NetworkPolicies not enforced: VPC CNI policy enforcement is off | ✅ (code) |
| I3 | Infra | Public EKS API endpoint open to `0.0.0.0/0` | ✅ (code) |
| I4 | Infra | `security-examples.tf` creates SGs and a KMS key that nothing uses | ✅ (code) |
| I5 | Infra | `backend.example.tf` is loaded as live config (it ends in `.tf`) | ✅ |
| I6 | Infra | EKS module v21 renamed outputs and node group keys | ✅ |
| I7 | Infra | Amazon Linux 2 node AMI (end of life) | ✅ |
| I8 | Infra | `disk_size` is ignored; node root volume not explicitly encrypted | ✅ (code) |
| I9 | Infra | WAF example is bypassable and can't be deployed as written | ✅ (code) |
| M1 | Infra | No security monitoring/alerting on the audit and WAF logs | ✅ (code) |
| K1 | Kubernetes | `PodSecurityPolicy` example: removed in Kubernetes 1.25 | ✅ |
| K2 | Kubernetes | NetworkPolicies select a `name` label Kubernetes never sets | ✅ |
| K3 | Kubernetes | Policies block DNS; app egress open to the internet on 80/443 | ✅ |
| K4 | Kubernetes | App ingress allowed from a `waf` namespace; ALB traffic doesn't come from pods | ✅ |
| K5 | Kubernetes | RBAC grants the app `get secrets` it never needs | ✅ |
| K6 | Kubernetes | PDB `minAvailable: 1` with one replica blocks every node drain | ✅ |
| A1 | App | Dockerfile health check uses `curl`, which isn't in the image | ✅ |
| A2 | App | Home page never shows comments; flash messages never render | ✅ |
| A3 | App | SQLi, XSS, IDOR, header-based admin, `/debug`, hard-coded secrets | 🎯 |
| G1 | Repo | LocalStack license secret and CA key committed to a public repo | ✅ |

---

## Database

### D1. `init-db.sql` is MySQL, not PostgreSQL ✅
**Impact:** The app and Helm chart are PostgreSQL. Running the script on
Postgres fails on every statement (`AUTO_INCREMENT`, `USE`, `DELIMITER`,
`'user'@'%'`, ...), creates no tables, yet still prints
`Database initialization completed successfully!` because `psql` continues
after errors by default. Every app page then fails.
**Fix:** Rewrote in PostgreSQL (`SERIAL`, `REFERENCES`, a SQL function
instead of the MySQL procedure). Added `\set ON_ERROR_STOP on` and wrapped it
in one transaction, so it's all-or-nothing and a failure is loud.
**Verified:** Postgres 17: 9 users, 14 posts, 22 comments. A re-run (or a
missing role) aborts with an error and no success message.

### D2. Hard-coded IDs break the data ✅
**Impact:** Even on MySQL, three posts used `author_id` 6–8 assuming they were
john/jane/bob (actually 5–7; user 8 didn't exist yet). The insert failed on
the foreign key, its comments failed too, and the shifted IDs attached the
load-test comments to "Internal Document" and other sensitive posts.
**Fix:** Inserts look up authors by username and posts by title, so they
can't drift from the generated keys.

### D3. App DB user has full privileges ✅
**Impact:** `GRANT ALL` to `appuser@'%'`. Combined with the app's SQL
injection, an attacker could drop tables or set `is_admin = TRUE`.
**Fix:** Tables owned by `postgres`; `appuser` gets only `SELECT` on the four
tables and `INSERT` on `comments` — everything the app does, nothing more.

**Live gap found 2026-10-16, now fixed:** the Bitnami chart makes `appuser`
the owner of the `public` schema, and an owner keeps `CREATE` regardless of
grants — so `appuser` could still create objects, and also had `CREATEDB`.
Hardened in `init-db.sql` and on the running DB: `ALTER SCHEMA public OWNER
TO postgres`, `REVOKE CREATE ON SCHEMA public FROM appuser`, `ALTER ROLE
appuser NOCREATEDB`.

**Verified** (read-only queries, no payloads sent): `CREATE` on public → `f`,
`CREATEDB` → `f`, schema owner → `postgres`. Injection can still *read* (the
lab target) but can't create, escalate, or destroy.

### D4. Plain-text passwords in Helm values ✅
**Impact:** `postgresPassword: "postgres"` and `password: "apppass"`
committed to git; the superuser password is trivially guessable.
**Fix:** `auth.existingSecret: postgres-credentials`, generated at install
with `openssl rand -hex 24` — nothing secret in git. Exact create commands
are in [`database/README.md`](../database/README.md); rotation and access
control in [`SECRETS_AND_MONITORING.md`](SECRETS_AND_MONITORING.md).
**Verified:** `helm template` shows both passwords mounted from the Secret,
no chart-generated Secret.
**Next step:** sync from AWS Secrets Manager (External Secrets Operator) for
automated rotation and audit.

### D5. Helm values silently ignored ✅
**Impact:** Checked against chart 18.12.x: `primary.securityContext`,
top-level `networkPolicy` and top-level `service` aren't chart keys, so the
"hardening" in the file did nothing. `storageClass: gp2` has no working
provisioner on a new EKS cluster (see I1).
**Fix:** Real keys: `primary.podSecurityContext` /
`containerSecurityContext` (non-root, read-only root FS, drop ALL, seccomp
`RuntimeDefault`), `primary.networkPolicy` (only the app's pods on 5432, no
external egress), the `ebs-gp3-encrypted` class, and
`automountServiceAccountToken: false`.
**Verified:** `helm template` output contains each setting.

### D6. Docs ✅
`database/README.md` and `docs/TEST_DATA.md` claimed 10 users and 20+
comments, and imported as superuser with no error stop. Updated to the real
counts and a fail-fast import.

### D7. Deployed release didn't use the fixed values ✅
**Impact:** The `postgres` release in the cluster (chart 18.12.4, installed
2026-10-15) was installed in `default` with the original values, not
`database/postgres-values.yaml`, so D4, D5 and I1 are fixed in code only:
- Plain-text `password: apppass` / `postgresPassword: postgres` in the
  release values (readable with `helm get values`)
- Volume on `gp2`, unencrypted: `vol-0f823be4e3ecf2512` reports
  `Encrypted: False`, and EBS encryption by default is off in us-west-2.
  The `ebs-gp3-encrypted` StorageClass was never applied.
- Wrong namespace: the app expects `postgres-postgresql.database` and the
  NetworkPolicies are written for `database`
- The StatefulSet is gone (only the PVC and Services remain), so no
  database is running

**Fix:** EBS encryption can't be turned on for an existing volume, so the
release and its PVC are replaced (test data only, reloaded from
`init-db.sql`):
```bash
helm -n default uninstall postgres
kubectl -n default delete pvc data-postgres-postgresql-0
kubectl apply -f kubernetes/storageclass.yaml
# Secrets: see D4
helm install postgres oci://registry-1.docker.io/bitnamicharts/postgresql \
  --version 18.12.4 -n database -f database/postgres-values.yaml
```
**Verify:** `kubectl -n database get pvc` shows `ebs-gp3-encrypted`, the
volume reports `Encrypted: True`, and `helm -n database get values postgres`
contains no passwords.

## Infrastructure (Terraform)

### I1. No EBS CSI driver ✅ (code; applied with the next `terraform apply`)
**Impact:** EKS no longer ships a working in-tree EBS provisioner. Without
the `aws-ebs-csi-driver` add-on, the Postgres PVC stays `Pending` forever.
**Fix:** Add-on installed through EKS Pod Identity (no node-wide IAM
permissions), with an IAM role limited to `AmazonEBSCSIDriverPolicy`. Added
`kubernetes/storageclass.yaml`: gp3, `encrypted: "true"`,
`WaitForFirstConsumer`.

### I2. NetworkPolicies not enforced ✅ (code)
**Impact:** The VPC CNI ignores NetworkPolicy objects unless
`enableNetworkPolicy` is on. Every policy in the examples would apply
without error and block nothing: false assurance.
**Fix:** Managed `vpc-cni` add-on with
`configuration_values = { enableNetworkPolicy = "true" }`.
**Test after apply:** a pod in another namespace must fail to reach
`postgres-postgresql.database:5432`.

### I3. EKS API open to the internet ✅ (code)
**Impact:** `endpoint_public_access = true` with the module default
`0.0.0.0/0`: the control plane is reachable from anywhere (auth still
required, but it's unnecessary exposure).
**Fix:** `endpoint_public_access_cidrs = var.api_allowed_cidrs` (your IP
/32), private endpoint on for nodes. A validation rule rejects `0.0.0.0/0`.
`terraform.tfvars` is gitignored so your IP stays out of the public repo.

### I4. Unused security resources ✅ (code)
**Impact:** Two security groups and a KMS key were created but attached to
nothing. They look like controls in a review but protect nothing; the KMS
key costs $1/month.
**Fix:** Removed. The real controls are module features: KMS encryption of
Kubernetes Secrets and control-plane audit logs (`audit`, `api`,
`authenticator`) are on by default in EKS module v21.

### I5. `backend.example.tf` loaded as live config ✅
Terraform loads every `*.tf` file, so the "example" was an active S3 backend
pointing at a bucket owned by another AWS account. It's now fully commented
out. The real backend (`backend.tf`) uses a versioned, encrypted bucket with
public access blocked and S3-native locking (`use_lockfile`).

### I6. EKS module v21 API changes ✅
`~> 21.0` installs a version where `node_groups` became
`eks_managed_node_groups` (attribute `node_group_arn`), `cluster_id` is only
set on Outposts (so the output was blank), and `desired_capacity` was
silently ignored (now `desired_size`).

### I7. Amazon Linux 2 node AMI ✅
`ami_type = "AL2_x86_64"`: AL2 is end of life, and EKS publishes no AL2
images for Kubernetes 1.33+. Now `AL2023_x86_64_STANDARD` (changing the
AMI replaces the node group).

### I8. Node disk settings ignored ✅ (code; applied with the next `terraform apply`)
The module uses a custom launch template by default, so `disk_size = 20` is
ignored and the root volume isn't explicitly encrypted (EBS encryption by
default is off in the account). **Fix:** `block_device_mappings` on
`/dev/xvda`: 20 GiB gp3, `encrypted = true` with the AWS-managed `aws/ebs`
key. Applying it rolls the nodes, since a volume can't be encrypted in place.

### I9. WAF ✅ (code)
**Was wrong with the example:** custom rules were exact-string matches
(`' OR '1'='1`, `<script>`), defeated by any change in spacing, case or
encoding; and the `aws_lb` block had no listeners/targets and referenced
undefined variables, so it couldn't deploy.
**Built (`terraform/waf.tf`, `alb-controller.tf`, `kubernetes/app/ingress.yaml`):**
- WAFv2 REGIONAL web ACL on the app's ALB with AWS **managed** rule groups
  (Common, SQLi, KnownBadInputs) instead of brittle string matches, plus a
  rate-based rule (`var.waf_rate_limit`, default 2000/5min/IP).
- Two app-specific blocks as compensating controls: `/debug` (leaks env/DB
  config) and any client-supplied `X-Forwarded-For` (the `/admin` check
  trusts it).
- The ALB is created by the AWS Load Balancer Controller from an Ingress;
  the web ACL is attached via `alb.ingress.kubernetes.io/wafv2-acl-arn`.
  Controller IAM is a least-privilege Pod Identity role (official policy,
  pinned, scanned: only acm/ec2/elb/wafv2/shield + service-linked-role).
- WAF logs → CloudWatch (`authorization`/`cookie` redacted).
**Homelab note:** the WAF config is applied as the Task-2 deliverable but is not attached to a live ALB (the Ingress + ALB controller are left undeployed to avoid exposing the vulnerable app publicly). It demonstrates the rule design; it inspects no traffic in this lab.
**Caveat:** a WAF is a compensating control. It cuts exploitability of
pattern-based attacks but can't fix IDOR or broken auth — those need code
(A3). Tighten by running managed groups in Count first, then Block.

### M1. Monitoring & alerting ✅ (code)
**Gap:** audit/api logs were enabled (module default) but nothing acted on
them — no alerts.
**Built (`terraform/monitoring.tf`):** SNS topic (`…-security-alerts`,
optional email via `var.alert_email`) with CloudWatch alarms: WAF block
spikes, WAF rate-limit blocks, `kubectl exec`/`attach` into pods, non-system
Secret reads, and forbidden-API spikes. The last three are log metric
filters over the EKS audit log. See `docs/SECRETS_AND_MONITORING.md`.

## Kubernetes

In `kubernetes/kubernetes-security-examples.yaml`. All verified with
`kubeconform -strict` against Kubernetes 1.32 (12/12 valid) and
`trivy config` (no HIGH/CRITICAL findings).

- **K1 ✅** `PodSecurityPolicy` (`policy/v1beta1`) was removed in 1.25 and
  fails to apply. Replaced by Pod Security Admission `restricted` labels on
  the `vulnerable-app` and `database` namespaces.
- **K2 ✅** Policies selected namespaces by `name: ...`, a label Kubernetes
  never sets, so they matched nothing. Now `kubernetes.io/metadata.name`. The
  DB policy's `app: postgres` selector didn't match the Bitnami labels either;
  Postgres ingress is now handled by the chart's own policy (D5).
- **K3 ✅** The default-deny and DB policies blocked DNS. The app policy
  allowed egress to 80/443 anywhere, an exfiltration path for a
  known-vulnerable app. Now: default deny, DNS to kube-dns only, app egress
  only to Postgres on 5432.
- **K4 ✅** App ingress was allowed from a `waf` namespace. With AWS WAF on
  an ALB in IP target mode, traffic arrives from the ALB's IPs in the public
  subnets, not from pods. Ingress is now an `ipBlock` for
  `10.20.101.0/24` and `10.20.102.0/24` on port 5000.
- **K5 ✅** The Role granted `get secrets` and `list pods`. The app never
  calls the Kubernetes API, so it has a service account with no token and no
  Role.
- **K6 ✅** `minAvailable: 1` with a single replica allows zero evictions,
  so node drains and cluster upgrades hang. Now `maxUnavailable: 1`.
- **Also added:** a LimitRange with default limits, and a quota with
  `services.loadbalancers: 0` / `nodeports: 0`, so the app can only be exposed
  through the WAF-protected Ingress.

## Application

### A1. Health check always fails ✅
`HEALTHCHECK` called `curl`, which `python:3.11-slim` doesn't include. Now
uses Python's `urllib`. Also added `--no-install-recommends` (Trivy
DS-0029). Kubernetes ignores `HEALTHCHECK`, so the Deployment still needs
liveness and readiness probes.

### A2. Comments and messages never shown ✅
Rows came back as tuples but the template read `comment.author` /
`comment.content` (always empty), and flashed messages were never rendered.
Fixed, so stored-content behaviour can actually be tested.
**Verified:** built the image, ran it against Postgres with the new script:
home page lists 5 comments, posting a comment works and shows the
confirmation, health check reports healthy.

### A3. Intentional vulnerabilities 🎯
Kept on purpose: they're what the WAF and hardening are measured against.

| Vulnerability | Location | Real fix (code) | Compensating control |
|---|---|---|---|
| SQL injection | `/search` (f-string SQL) | Parameterized query | WAF SQLi rules; read-only DB grants (D3) |
| Stored/reflected XSS | `/posts`, `/user/<id>`, `\|safe` | Template autoescaping, no `\|safe` | WAF XSS rules, CSP header |
| IDOR / info disclosure | `/user/<id>` | Authentication + ownership check | WAF can't fix this; needs code |
| Admin check trusts a client header | `/admin` | Real authentication and roles | ALB/Ingress overwrites forwarding headers; WAF rule blocks client-supplied ones |
| Debug endpoint leaks env and DB config | `/debug` | Remove the route | WAF path block; no secrets in env |
| Hard-coded `secret_key` and DB password | `app.py` | Load from a Secret | Secret via env from Kubernetes |
| Plain-text passwords, no rate limit | `/login`, seed data | bcrypt/argon2, rate limiting | WAF rate-based rule |

A WAF is a compensating control, not a fix. It reduces exploitability of
known patterns, but IDOR and broken authentication need code changes, and
any WAF signature can eventually be bypassed.

## Repository

### G1. Secrets in public git history ✅
`volume/` (LocalStack's data directory) was committed to the public repo,
including `license.json` (with `license_secret`) and LocalStack's local CA
private key. Removed from all history and force-pushed. The LocalStack token
has to be rotated, because the old commits stay reachable on GitHub until
GitHub Support purges them.

## Live verification (2026-10-16)

Run against the deployed cluster (`eks-interview-lab`) with read-only /
admission-level checks. **No exploit payloads were sent to the app** — the
app's own vulnerabilities (A3) are intentional and were not exercised.

### Database (D3, D4/D7, I8)
| Check | Command | Result |
|---|---|---|
| appuser grants | `role_table_grants` | `SELECT` on users/posts/comments/user_posts, `INSERT` on comments only ✅ |
| appuser CREATE on public | `has_schema_privilege('appuser','public','CREATE')` | `f` (after owner fix) ✅ |
| appuser CREATEDB | `pg_roles.rolcreatedb` | `f` ✅ |
| public schema owner | `pg_namespace.nspowner` | `postgres` ✅ |
| no passwords in release | `helm get values postgres` | only `existingSecret` refs ✅ |
| volume encryption | `describe-volumes` | `Encrypted=True`, `gp3`, class `ebs-gp3-encrypted` ✅ |

### Kubernetes hardening (tested against kubernetes/SECURITY_HARDENING.md)
| Control | Test | Result |
|---|---|---|
| PSS restricted | `kubectl run` root pod in `vulnerable-app` | Forbidden: `runAsNonRoot`, `runAsUser=0`, caps, seccomp ✅ |
| PSS restricted | `kubectl run` privileged container | Forbidden: `privileged` + 4 more ✅ |
| Resource quota | create LoadBalancer Service | Forbidden: `services.loadbalancers=0` ✅ |
| LimitRange | defaults for a container with no limits | injects `500m/256Mi` limit, `100m/128Mi` request ✅ |
| App pod hardening | pod spec | `runAsNonRoot=true`, `readOnlyRootFilesystem=true`, `automountServiceAccountToken=false`, caps `drop:[ALL]` ✅ |
| NetworkPolicy enforced | CNI `enable-network-policy-controller` | `true` ✅ |
| NetPol allowed path | app pod → `postgres:5432` | CONNECTED ✅ |
| NetPol egress lockdown | app pod → `1.1.1.1:443` | blocked (timeout) ✅ |
| NetPol ingress lockdown | postgres pod → app `:5000` | blocked ✅ |
| Secrets at rest | `describe-cluster encryptionConfig` | KMS envelope encryption on `secrets` ✅ |
| Audit logging | `describe-cluster logging` | `api`, `audit`, `authenticator` enabled ✅ |

Note: the single `t3.small` node is at its max-pods (ENI/IP) limit, so a
fresh probe pod couldn't be scheduled; the NetworkPolicy paths were tested
from the already-running app and postgres pods instead. A second node (or a
larger instance) is needed to run more workloads.

## Remaining risks

- I7 (AL2023) and I8 (encrypted node disk) are applied and verified live.
- I9 (WAF), M1 (monitoring) and the ECR/node-boundary work are in code,
  applied with the next `terraform apply` (WAF needs the ALB controller
  installed — kubernetes/app/README.md step 5).
- Images aren't pinned by digest. The Bitnami chart defaults to `latest`
  tags; pin `image.digest` for reproducible, verified deploys.
- No CI scanning yet. Planned: Trivy (image and IaC), Bandit (Python),
  pip-audit (dependencies) in GitHub Actions.
- The app itself remains vulnerable by design (A3).
