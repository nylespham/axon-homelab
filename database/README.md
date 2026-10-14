# Database Configuration

This directory contains PostgreSQL database configuration and test data.

## Files

- **`init-db.sql`** - Database initialization script with test data
- **`postgres-values.yaml`** - Helm values for PostgreSQL deployment

## Test Data Included

- **Users** - 10 test users including admin accounts
- **Posts** - 11 test posts with security-focused content
- **Comments** - 20+ test comments including XSS payloads
- **Additional objects** - Views, stored procedures, and indexes

## Usage

1. Deploy PostgreSQL using Helm:
   ```bash
   helm install postgres bitnami/postgresql -f postgres-values.yaml
   ```

2. Import test data:
   ```bash
   kubectl cp init-db.sql <postgres-pod>:/tmp/init-db.sql
   kubectl exec -it <postgres-pod> -- psql -U postgres -d vulnerable_app -f /tmp/init-db.sql
   ```

3. Verify data import:
   ```bash
   kubectl exec -it <postgres-pod> -- psql -U postgres -d vulnerable_app -c "SELECT COUNT(*) FROM users;"
   ```

## Security Note

The test data contains intentionally vulnerable content for security testing purposes.
