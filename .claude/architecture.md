# Architecture

How the pieces fit together, from AWS down to the pods. Mermaid diagrams
render on GitHub and in most IDEs. Dashed lines / grey nodes = defined in
code but **not deployed** in the homelab (the public WAF+ALB path).

- **AWS:** account `205098647215`, region `us-west-2`
- **Cluster:** EKS `eks-interview-lab`, Kubernetes 1.32
- Source of each box is noted as `(file.tf)` / `(file.yaml)`.

---

## 1. Network & AWS topology

```mermaid
flowchart TB
    dev["Developer / kubectl<br/>(IP allow-listed)"]
    igw["Internet Gateway"]

    subgraph aws["AWS · us-west-2 · account 205098647215"]
        direction TB
        kms["KMS key<br/>envelope-encrypts K8s Secrets<br/>(eks.tf module default)"]
        ecr["ECR (private)<br/>vulnerable-flask<br/>immutable · scan-on-push<br/>(ecr.tf)"]
        cw["CloudWatch Logs<br/>EKS audit/api · WAF logs<br/>(eks.tf, waf.tf)"]
        sns["SNS security-alerts<br/>+ CloudWatch alarms<br/>(monitoring.tf)"]
        waf["WAFv2 web ACL<br/>managed rules + rate limit<br/>(waf.tf) — reference only"]:::ref

        subgraph vpc["VPC 10.20.0.0/16 (vpc.tf)"]
            direction TB
            subgraph pub["Public subnets<br/>10.20.101.0/24 · 10.20.102.0/24"]
                nat["NAT gateway (single)"]
                alb["ALB (internet-facing)<br/>created by LB Controller<br/>(ingress.yaml) — reference only"]:::ref
            end
            subgraph priv["Private subnets<br/>10.20.1.0/24 · 10.20.2.0/24"]
                eks["EKS control plane<br/>API: private + allow-listed CIDRs<br/>(eks.tf)"]
                node["Managed node group<br/>t3.small · AL2023<br/>encrypted gp3 root disk<br/>IAM boundary: ECR pull = app repo only<br/>(eks.tf)"]
            end
        end
    end

    dev -->|"HTTPS to EKS API<br/>(allow-listed)"| eks
    dev -. "port-forward (actual app access)" .-> node
    dev -. "internet → ALB → app<br/>(not deployed)" .-> igw
    igw -. not deployed .-> alb
    alb -. inspected by .-> waf
    alb -. not deployed .-> node
    node -->|"image pull"| ecr
    node -->|"egress via"| nat --> igw
    node -->|logs| cw
    eks -->|audit logs| cw
    cw --> sns
    eks --- kms

    classDef ref fill:#eee,stroke:#999,stroke-dasharray:5 5,color:#555;
```

**Reads as:** you reach the cluster API over an IP-allow-listed public
endpoint and the app via `kubectl port-forward`. Nodes live in private
subnets, pull the app image from private ECR, and reach the internet only
outbound through the NAT gateway. The public **ALB + WAF** path is coded but
left undeployed so the vulnerable app isn't exposed (see `waf.tf`,
`ingress.yaml`).

---

## 2. Inside the cluster (namespaces, workloads, network policy)

```mermaid
flowchart TB
    subgraph ks["kube-system"]
        dns["CoreDNS"]
        cni["VPC CNI<br/>enableNetworkPolicy=true"]
        ebs["EBS CSI driver<br/>(Pod Identity)"]
    end

    subgraph app["namespace: vulnerable-app<br/>PodSecurity = restricted"]
        appsa["SA app-service-account<br/>no API token, no RBAC"]
        apppod["Deployment vulnerable-flask ×2<br/>non-root · RO rootfs · drop ALL<br/>(deployment.yaml)"]
        appsvc["Service vulnerable-flask<br/>ClusterIP :80→5000"]
        appsecret["Secret app-db-credentials<br/>(appuser password)"]
    end

    subgraph db["namespace: database<br/>PodSecurity = restricted"]
        dbpod["StatefulSet postgres-postgresql<br/>Bitnami · non-root · RO rootfs<br/>(postgres-values.yaml)"]
        dbpvc["PVC 10Gi<br/>StorageClass ebs-gp3-encrypted"]
        dbsecret["Secret postgres-credentials<br/>(superuser + appuser)"]
    end

    apppod -->|"DNS :53"| dns
    apppod -->|"TCP 5432 (only allowed egress)"| dbpod
    appsvc --> apppod
    apppod -. reads .-> appsecret
    dbpod -. reads .-> dbsecret
    dbpod --> dbpvc
    ebs -. provisions .-> dbpvc

    note["NetworkPolicies (kubernetes-security-examples.yaml + Helm):<br/>• both ns: default-deny-all + allow-dns<br/>• app: ingress from ALB CIDRs:5000, egress only to postgres:5432<br/>• db: ingress only from app pods:5432 (chart policy)"]
    note -.-> app
    note -.-> db
```

**Reads as:** two locked-down namespaces. The app can talk to DNS and to
Postgres on 5432 and nothing else; Postgres only accepts the app. Each pod
reads only its own namespace's Secret, runs non-root with a read-only root
filesystem, and carries no Kubernetes API token.

---

## 3. Build & deploy flow

```mermaid
flowchart LR
    src["app/ source<br/>Flask + Dockerfile"]
    mk["make push<br/>(Makefile)"]
    ecr["ECR vulnerable-flask<br/>:git-sha (immutable)"]
    scan["ECR scan-on-push"]
    kust["make deploy<br/>kustomize sets image<br/>(kubernetes/app)"]
    node["EKS nodes pull<br/>(IAM boundary: this repo only)"]

    src --> mk -->|"build linux/amd64 + push"| ecr --> scan
    kust -->|kubectl apply -k| node
    node -->|pull image| ecr
```

**Reads as:** `make push` builds the amd64 image and pushes an immutable
`:git-sha` tag to private ECR (scanned on push); `make deploy` stamps that
tag into the manifests and applies them; nodes pull it — and the node IAM
permissions boundary lets them pull from *only* this repo and AWS's EKS
add-on registry.

---

## 4. Security controls & monitoring

```mermaid
flowchart TB
    subgraph identity["Identity (least privilege)"]
        pi["EKS Pod Identity associations<br/>EBS CSI · (ALB controller)<br/>(eks.tf, alb-controller.tf)"]
        nb["Node IAM permissions boundary<br/>ECR pulls scoped to app repo<br/>(ecr.tf)"]
    end
    subgraph data["Data protection"]
        kms["KMS: K8s Secrets at rest"]
        ebsenc["Encrypted gp3: node + Postgres volumes"]
        secns["Secrets namespaced, no cross-ns, no SA token"]
    end
    subgraph detect["Detection & alerting (monitoring.tf)"]
        audit["EKS audit log → CloudWatch"]
        wafl["WAF logs → CloudWatch<br/>(auth/cookie redacted)"]
        mf["Metric filters:<br/>pod exec/attach · Secret reads · 403s"]
        al["CloudWatch alarms → SNS<br/>WAF blocks · rate-limit · exec · secrets · authz"]
    end
    audit --> mf --> al
    wafl --> al
```

**Reads as:** identities are least-privilege (Pod Identity per controller, a
boundary on the node role); data is encrypted at rest and Secrets are
tightly scoped; and the audit/WAF logs feed metric filters and alarms that
notify an SNS topic. The exec/secret-read/403 metric pipeline is verified
live (see `docs/FINDINGS.md` → Live verification).

---

## Where things live

| Concern | Files |
|---|---|
| Network / VPC | `terraform/vpc.tf` |
| EKS, nodes, add-ons, KMS, disk | `terraform/eks.tf` |
| Private registry + node boundary | `terraform/ecr.tf` |
| WAF (reference) | `terraform/waf.tf`, `alb-controller.tf`, `kubernetes/app/ingress.yaml` |
| Monitoring & alerting | `terraform/monitoring.tf` |
| K8s baseline (ns, netpol, SA, quota) | `kubernetes/kubernetes-security-examples.yaml` |
| App workload | `kubernetes/app/` |
| Database (Helm values, schema) | `database/` |
| Build/deploy | `Makefile`, `kubernetes/app/kustomization.yaml` |
| Full findings & verification | `docs/FINDINGS.md` |
| Secrets & monitoring detail | `docs/SECRETS_AND_MONITORING.md` |
