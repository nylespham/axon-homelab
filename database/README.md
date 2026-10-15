# Database Configuration

This directory contains PostgreSQL database configuration and test data.

## Files

- **`init-db.sql`** - Database initialization script with test data (PostgreSQL)
- **`postgres-values.yaml`** - Helm values for PostgreSQL deployment

## Test Data Included

- **Users** - 9 test users including 2 admin accounts
- **Posts** - 14 test posts with security-focused content
- **Comments** - 22 test comments including XSS payloads
- **Additional objects** - A view, a function (`get_user_posts`) and indexes

## Usage

1. Create the storage class and namespace, then the credentials Secret
   (passwords are generated, never written to a file):
   ```bash
   kubectl apply -f kubernetes/storageclass.yaml
   kubectl create namespace database
   kubectl -n database create secret generic postgres-credentials \
     --from-literal=postgres-password="$(openssl rand -base64 24)" \
     --from-literal=password="$(openssl rand -base64 24)"
   ```

2. Deploy PostgreSQL using Helm:
   ```bash
   helm install postgres oci://registry-1.docker.io/bitnamicharts/postgresql \
     -n database -f database/postgres-values.yaml
   ```

3. Import test data as the `postgres` superuser. `ON_ERROR_STOP` makes a
   failure abort instead of printing "completed successfully":
   ```bash
   kubectl -n database cp database/init-db.sql postgres-postgresql-0:/tmp/init-db.sql
   kubectl -n database exec -it postgres-postgresql-0 -- sh -c \
     'PGPASSWORD="$(cat $POSTGRES_POSTGRES_PASSWORD_FILE)" psql -v ON_ERROR_STOP=1 -U postgres -d vulnerable_app -f /tmp/init-db.sql'
   ```

4. Verify data import as the application user:
   ```bash
   kubectl -n database exec -it postgres-postgresql-0 -- sh -c \
     'PGPASSWORD="$(cat $POSTGRES_PASSWORD_FILE)" psql -U appuser -d vulnerable_app -c "SELECT COUNT(*) FROM users;"'
   ```

## Privileges

The script creates the tables as `postgres` and grants `appuser` only what
the app needs: `SELECT` on the tables and `INSERT` on `comments`. SQL
injection through the app can read data but can't `DROP`, `UPDATE` or
`DELETE`.

## Security Note

The test data contains intentionally vulnerable content (plain-text
passwords, XSS payloads, a leaked connection string) for security testing
purposes. See `docs/FINDINGS.md`.
