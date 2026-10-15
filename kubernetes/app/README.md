# Deploying the Flask app

Manifests: `deployment.yaml`, `service.yaml`, `kustomization.yaml`
(namespace `vulnerable-app`).

## Prerequisites

- Baseline applied (namespaces, NetworkPolicies, service account, quota):
  `kubectl apply -f kubernetes/kubernetes-security-examples.yaml`
- PostgreSQL installed in `database` with its `postgres-credentials` Secret
  (`database/README.md`)
- The private ECR repository from `terraform/ecr.tf` (`terraform apply`).
  The nodes can pull only from this repo and AWS's EKS add-on registry
  (permissions boundary on the node role).

## 1. DB credentials Secret

A pod can only reference Secrets in its own namespace, so the app gets its
own copy of the **`appuser` password only**, named `app-db-credentials`
(what `deployment.yaml` reads). Copy it from the database Secret so the
value is never typed, echoed or saved in shell history:

```bash
kubectl -n vulnerable-app create secret generic app-db-credentials \
  --from-literal=password="$(kubectl -n database get secret postgres-credentials \
    -o jsonpath='{.data.password}' | base64 -d)"
```

Don't:
- Paste literal passwords into the command (they end up in shell history,
  tickets and chat logs). If a value must be shown, redact it:
  `--from-literal=password='<REDACTED>'`.
- Copy `postgres-password` (the superuser) into this namespace. The app
  never uses it, and anyone who can read Secrets here would own the
  database.

Check, showing key names and sizes only:
```bash
kubectl -n vulnerable-app describe secret app-db-credentials
```

After a password rotation, recreate this Secret and restart the app
(`kubectl -n vulnerable-app rollout restart deployment/vulnerable-flask`):
environment variables are read only at container start.

## 2. Build and push the image

From the repo root (uses Podman if installed, else Docker; builds
`linux/amd64` for the x86_64 nodes, also on Apple Silicon):

```bash
make push        # build, log in to ECR, push :<git-sha>, wait for the scan
```

- The tag is the commit SHA and ECR tags are immutable, so each tag is
  exactly one build. `make push` refuses uncommitted changes in `app/`
  (override: `ALLOW_DIRTY=1 TAG=<name>`) and stops if the tag already exists.
- It prints the ECR scan's severity counts. This app is deliberately
  vulnerable; look for findings in the base image and dependencies.
- `make print` shows the resolved image; `make help` lists all targets.

## 3. Deploy

```bash
make deploy      # sets the image in kustomization.yaml, applies, waits
```
Same as `kubectl apply -k kubernetes/app` after editing `images:` by hand.
Commit the updated `kustomization.yaml` so git records what's deployed.

## 4. Access (internal)

The Service is ClusterIP (the namespace quota blocks LoadBalancer and
NodePort). For a quick internal check:
```bash
kubectl -n vulnerable-app port-forward svc/vulnerable-flask 8080:80
# http://localhost:8080  (bypasses the ALB/WAF)
```

## 5. Public exposure through the WAF-protected ALB — REFERENCE ONLY (homelab)

> Not performed in this lab: it would put the deliberately-vulnerable app on
> a public internet-facing ALB. The steps below document how the WAF
> (`terraform/waf.tf`) attaches to a real ALB; in the homelab we reach the
> app via `kubectl port-forward` (step 4). Kept for reference.

Terraform creates the WAF web ACL and the ALB controller's IAM role
(`terraform/waf.tf`, `alb-controller.tf`). Two one-time cluster steps:

```bash
# a) Install the AWS Load Balancer Controller (IAM comes from Pod Identity,
#    so DON'T let Helm create an IRSA annotation; just the SA name must match)
helm repo add eks https://aws.github.io/eks-charts && helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system --version 1.13.0 \
  --set clusterName=eks-interview-lab \
  --set region=us-west-2 \
  --set vpcId="$(cd terraform && terraform output -raw vpc_id)" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller
kubectl -n kube-system rollout status deploy/aws-load-balancer-controller

# b) Create the Ingress with the generated WAF ACL ARN substituted in
ARN=$(cd terraform && terraform output -raw waf_web_acl_arn)
sed "s#__WAF_ACL_ARN__#$ARN#" kubernetes/app/ingress.yaml | kubectl apply -f -

# Wait for the ALB, then open its DNS name
kubectl -n vulnerable-app get ingress vulnerable-flask \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}{"\n"}'
```

Verify the WAF is attached and blocking:
```bash
HOST=$(kubectl -n vulnerable-app get ingress vulnerable-flask -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -s -o /dev/null -w '%{http_code}\n' "http://$HOST/"        # 200
curl -s -o /dev/null -w '%{http_code}\n' "http://$HOST/debug"   # 403 (BlockDebug rule)
curl -s -o /dev/null -w '%{http_code}\n' -H 'X-Forwarded-For: 127.0.0.1' "http://$HOST/admin"  # 403 (BlockXffSpoof)
```
WAF block/allow counts and sampled requests are in the CloudWatch
`AWS/WAFV2` metrics and the `aws-waf-logs-…` log group; alerts are wired in
`terraform/monitoring.tf` (see `docs/SECRETS_AND_MONITORING.md`).

> The WAF reduces exploitability of pattern-based attacks (SQLi/XSS
> signatures, `/debug`, XFF spoofing, rate abuse) but is a compensating
> control: IDOR (`/user/<id>`) and the broken `/admin` auth still need code
> fixes (docs/FINDINGS.md A3).

## Troubleshooting

| Symptom | Cause |
|---|---|
| `CreateContainerConfigError` | `app-db-credentials` missing or misnamed |
| Pod running but not Ready | `/` can't reach Postgres: check the DB pod, `DB_HOST`, and the `database` NetworkPolicy |
| `ImagePullBackOff` | Tag not pushed, or the image isn't in the app repo (the node boundary blocks every other repo in the account) |
| Pod rejected with `violates PodSecurity "restricted"` | A security context field was removed from `deployment.yaml` |
