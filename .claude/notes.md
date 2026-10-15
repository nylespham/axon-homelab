# Notes

See also: [app-vulnerabilities.md](app-vulnerabilities.md): why `app/` is
flagged as unsafe for production.
See also: [database-vulnerabilities.md](database-vulnerabilities.md): review of
`database/init-db.sql` (it's MySQL syntax and fails on PostgreSQL).

## Current setup: real AWS (since 2026-10-15)

LocalStack was dropped (time limit); the EKS cluster is built in the real AWS
account **<account-id>**, `us-west-2`. Everything LocalStack-related was
reverted or removed. The LocalStack sections further down are kept for
history only.

- **State backend:** `terraform/backend.tf` → S3 bucket
  `platform-ops-tfstate-<account-id>` (key
  `devsecops-interview-lab/terraform.tfstate`, `use_lockfile`, `encrypt`).
  Bucket: versioning on, SSE-S3 (AES256) default encryption, all public access
  blocked, bucket-owner-enforced ownership. `platform-ops` couldn't be used:
  the name is taken by another AWS account. No Object Lock on this bucket.
- **`terraform/backend.example.tf`:** fully commented out. It's a `.tf` file,
  so Terraform loads it; an active block there conflicts with `backend.tf`.
- **Provider:** plain `region = var.aws_region`, so it uses your default AWS
  credentials. LocalStack endpoints, `test` keys and the
  `allowed_account_ids = ["000000000000"]` guard were removed.
- **Node group:** always created again (`create_node_group` variable removed).
  Kept the non-LocalStack fixes: `cluster_name` / `node_group_arn` outputs and
  `desired_size`.
- **Removed:** `docker-compose.yml`, `./volume`, the LocalStack and k3d-eks
  containers, volume and networks. `.env` (LocalStack auth token, gitignored)
  is still there.
- **Verified:** `terraform plan` → 59 to add (incl. the node group), 0 in state.
- **Cost:** EKS control plane + NAT gateway + EC2 node bill hourly. Run
  `terraform destroy` when done.

## LocalStack on Podman (macOS)

Changes made to `docker-compose.yml` to get LocalStack running under Podman:

- **HTTPS port mapped to `127.0.0.1:8443:443`** instead of `127.0.0.1:443:443`.
  macOS only lets non-root processes bind ports < 1024 on the wildcard address
  (`0.0.0.0`), not on a specific IP like `127.0.0.1`. Podman's port forwarder
  (gvproxy) runs as the user, so binding `127.0.0.1:443` fails with
  `bind: permission denied`. LocalStack also serves HTTPS on 4566.
- **Docker socket mount uses the path inside the Podman VM:**
  `/run/podman/podman.sock:/var/run/docker.sock`. The host's
  `/var/run/docker.sock` is a symlink to a macOS socket file, which can't be
  shared into the VM (`statfs ... operation not supported`).
- **`security_opt: label=disable`** so SELinux in the VM allows the container to
  use the Podman socket. Without it: `Permission denied`.

These socket settings only work with Podman. With Docker Desktop, change the
mount back to `/var/run/docker.sock:/var/run/docker.sock`.

Check that LocalStack is healthy:

```bash
podman compose up -d
curl -s localhost:4566/_localstack/health
```

## Terraform state in LocalStack S3

Bucket: `platform-ops` (region `us-west-2`), state key
`devsecops-interview-lab/terraform.tfstate`. Backend config is in
`terraform/backend.tf`.

### Create the bucket

LocalStack accepts any credentials; `test`/`test` is the convention.

```bash
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-west-2
E=--endpoint-url=http://localhost:4566

# Versioning is required for Object Lock
aws $E s3api create-bucket --bucket platform-ops \
  --create-bucket-configuration LocationConstraint=us-west-2 \
  --object-lock-enabled-for-bucket
aws $E s3api put-bucket-versioning --bucket platform-ops \
  --versioning-configuration Status=Enabled

# Default retention: every state version is kept for 7 days
aws $E s3api put-object-lock-configuration --bucket platform-ops \
  --object-lock-configuration '{"ObjectLockEnabled":"Enabled","Rule":{"DefaultRetention":{"Mode":"GOVERNANCE","Days":7}}}'
```

Then `cd terraform && terraform init`.

### Locking: two different things

- **State locking** (`use_lockfile = true` in `backend.tf`): Terraform writes a
  `.tflock` file next to the state so two `apply` runs can't change the state at
  the same time. It replaces the old DynamoDB lock table.
- **S3 Object Lock** (a bucket setting, not part of the backend): each state
  version can't be deleted until its retention period ends.

Tested both together on 2026-10-15: repeated `terraform apply` runs worked, and
deleting a locked state version returned
`AccessDenied ... object protected by object lock`.

### Governance vs. compliance mode

- **GOVERNANCE** (used here): an admin can still delete locked versions with
  `--bypass-governance-retention`.
- **COMPLIANCE**: nobody can delete until retention ends, not even root. Avoid
  in a lab.

Delete all versions under a prefix (governance mode):

```bash
aws $E s3api list-object-versions --bucket platform-ops --prefix <prefix>/ \
  --query '[Versions,DeleteMarkers][][].[Key,VersionId]' --output text |
while read k v; do
  aws $E s3api delete-object --bucket platform-ops --key "$k" --version-id "$v" \
    --bypass-governance-retention
done
```

### Caveats

- **No persistence:** `PERSISTENCE` defaults to `0`, so restarting LocalStack
  wipes the bucket, its Object Lock config, and the state. Set `PERSISTENCE=1`
  in `.env` (needs the LocalStack auth token) or rerun the bucket setup after
  each restart.
- **Lock-file versions pile up:** each run leaves `.tflock` versions that are
  also retained for 7 days. A lifecycle rule that expires noncurrent versions
  keeps the bucket small.
- **Provider points at LocalStack (fixed 2026-10-15):** `provider "aws"` in
  `terraform/versions.tf` uses dummy `test` credentials, LocalStack endpoints
  for every service the config uses, and
  `allowed_account_ids = ["000000000000"]` (LocalStack's account) so it
  refuses to run against a real account. If you add a resource for a new AWS
  service, add its endpoint too, or it will fail to authenticate.

## EKS node groups don't work in LocalStack on Podman

`terraform apply` failed with
`waiting for EKS Node Group ... unexpected state 'CREATE_FAILED'`.

**Cause:** LocalStack runs EKS as a k3d (k3s) cluster in Podman. To add a
node-group node, k3d copies the server container's settings. Under Podman the
copy reuses the server's own volumes (`/var/lib/rancher/k3s`,
`/var/lib/kubelet`, `/var/lib/cni`), so the agent's containerd hangs on files
the server already has open and the node never registers. (k3d then also fails
to read the agent's logs through Podman's API.) Under Docker the copy gets
fresh volumes, so this is Podman-specific.

**Fix (2026-10-15):**
- `variable "create_node_group"` (default `false`) in
  `terraform/variables.tf`; `eks.tf` only creates the node group when it's
  `true`. Set it to `true` on Docker or real AWS.
- `node_group_arn` output uses `try(..., null)`.
- Workloads run on the k3s server node instead. It has a
  `node-role.kubernetes.io/control-plane:NoSchedule` taint, which has to be
  removed after each cluster create:

```bash
S=$(podman ps --format '{{.Names}}' | grep -- '-server-0$' | grep k3d-eks)
podman exec $S kubectl taint nodes $S node-role.kubernetes.io/control-plane:NoSchedule-
```

If LocalStack leaves an orphaned `k3d-eks-...-agent-...` container behind,
remove it with `podman rm -f <name>` (no `-v`: its volumes are the server's).

## Incident: resources created in real AWS (2026-10-14)

Before the provider fix, `terraform apply` used the default AWS credentials
(account <account-id>) and created the full stack in real
AWS `us-west-2` (EKS cluster `eks-interview-lab`, VPC, NAT gateway, EIP, KMS
keys, IAM roles, ...). The state was saved in the LocalStack bucket. A
`terraform destroy` ran at 2026-10-15 01:30 (UTC+7).

Checked 2026-10-15: nothing left in the account except 2 KMS keys in
`PendingDeletion` (deleted automatically on 2026-10-22 and 2026-11-14).
All state versions were backed up to the session scratchpad.
