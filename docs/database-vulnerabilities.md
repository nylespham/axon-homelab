# Database init script review (`database/init-db.sql`)

Reviewed 2026-10-15. Both results below come from actually running the script
in throwaway containers (`postgres:16-alpine` and `mysql:8.4`), not just from
reading it.

## 1. The script doesn't work on PostgreSQL (blocker)

The app uses PostgreSQL (`psycopg2`, `bitnami/postgresql` in
`postgres-values.yaml`), but `init-db.sql` is written in **MySQL** syntax:

| Line | MySQL-only syntax |
|------|-------------------|
| 6 | `CREATE DATABASE IF NOT EXISTS` |
| 7–9 | `CREATE USER 'appuser'@'%'`, `GRANT ... ON vulnerable_app.*`, `FLUSH PRIVILEGES` |
| 12 | `USE vulnerable_app;` |
| 16, 26, 36 | `INT AUTO_INCREMENT` (Postgres: `SERIAL` / `GENERATED ... AS IDENTITY`) |
| 109–116 | `DELIMITER //` + MySQL `CREATE PROCEDURE` body |
| 119 | `GRANT EXECUTE ON PROCEDURE ... TO 'appuser'@'%'` |

**Result on Postgres:** every statement errors, **no tables are created**, yet
the script still prints `Database initialization completed successfully!`
(`psql` keeps going after errors unless run with `-v ON_ERROR_STOP=1`). The
Flask app then fails on every page with `relation "..." does not exist`.

## 2. Data bugs (even on MySQL)

Running it on MySQL (the dialect it's written in) gives 2 errors:

- **Line 78: posts insert fails with a foreign key error.** It uses
  `author_id` 6, 7, 8 assuming they are john/jane/bob, but users 1–4 come
  first, so those three are IDs 5, 6, 7, and user 8 doesn't exist yet. The
  whole 3-row insert ("API Security", "Authentication Methods",
  "Session Management") is rejected.
- **Line 83: their comments fail too**, since posts 6–8 never got created.
- **IDs are shifted after that:** the failed insert used up IDs 6–8, so the
  sensitive posts become 9–11 and load-test posts 12–14. The load-test
  comments (lines 133–139) point at post IDs 9–11, so they land on
  "Internal Document" / "Confidential Information" / "System Configuration"
  instead of the load-test posts.
- **Final counts:** 9 users, 11 posts, 16 comments. `database/README.md` says
  "10 test users" and "20+ comments".

## 3. Security issues

Like the app, most of these are intentional test data for the lab.

| # | Issue | Where | Why it matters |
|---|-------|-------|----------------|
| 1 | **Plain-text passwords** | `users.password`, lines 45–49, 73–76, 98–100 | No hashing. Anyone who can read the table (e.g. via the app's SQL injection) gets every password. |
| 2 | **Weak, guessable credentials** | `admin/admin123`, `testuser/testpass`, `john123`, ... | Trivial to brute force, and `/login` has no rate limiting. |
| 3 | **Two admin accounts** | `admin` (line 46), `admin_backup` (line 100) | A hidden backup admin with a weak password is an extra way in. |
| 4 | **Hard-coded DB password** | line 7 (`apppass`) | Same password as `app.py` defaults and `postgres-values.yaml`; committed to the repo. |
| 5 | **App user has full privileges** | line 8 (`GRANT ALL PRIVILEGES`) | Breaks least privilege. Combined with the app's SQL injection, an attacker can `DROP` tables, `UPDATE users SET is_admin = TRUE`, etc. The app only needs `SELECT`/`INSERT`. |
| 6 | **App user can connect from any host** | `'appuser'@'%'` (lines 7, 8, 119) | No restriction on where the DB login can be used from. |
| 7 | **Stored XSS payloads** | comments on lines 65–66 | `<script>` and `<img onerror>` payloads stored in the DB, to test the app's output escaping. |
| 8 | **Secrets in content** | post on line 106 | A DB connection string with credentials (`postgresql://admin:password@...`) stored as a post, readable via `/posts`. |
| 9 | **Real-looking personal data** | `email` column | Emails with no access control (the app's `/user/<id>` exposes them). |
| 10 | **No audit columns or constraints** | schema | No `updated_at`, no `ON DELETE` rules, no `CHECK` on emails, no role table; `is_admin` is a plain boolean an attacker can flip. |

## 4. Related: `database/postgres-values.yaml`

- **Weak superuser password:** `postgresPassword: "postgres"` (line 9), plus
  `apppass` for the app user, in plain text in the values file. Should come
  from a Kubernetes Secret (`auth.existingSecret`).
- **Network policy off:** `networkPolicy.enabled: false` (line 55), so any pod
  in the cluster can reach Postgres on 5432.
- **No TLS** configured between the app and Postgres.
- **Metrics off** (`metrics.enabled: false`), so no monitoring of suspicious
  activity.
- **Storage class `gp2`:** whether the volume is encrypted depends on that
  class's settings (not set here).

## 5. README import steps (`database/README.md`)

- The import runs as the `postgres` superuser (`psql -U postgres`). On
  Postgres, tables created that way are owned by `postgres`, so `appuser`
  (what the app logs in as) gets `permission denied` unless grants are added.
- No `-v ON_ERROR_STOP=1`, which is why a failed import looks successful.
