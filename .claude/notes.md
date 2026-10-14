# Notes

See also: [app-vulnerabilities.md](app-vulnerabilities.md): why `app/` is
flagged as unsafe for production.
See also: [database-vulnerabilities.md](database-vulnerabilities.md): review of
`database/init-db.sql` (it's MySQL syntax and fails on PostgreSQL).

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
- **Only the state is in LocalStack:** `provider "aws"` in
  `terraform/versions.tf` still targets real AWS. To create resources in
  LocalStack too, add LocalStack endpoints to the provider or use `tflocal`
  (`pip install terraform-local`).
