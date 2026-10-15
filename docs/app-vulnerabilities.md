# App vulnerabilities (`app/`)

`app/` is a deliberately vulnerable Flask app (`app.py`) used as a target for
security testing / DevSecOps interview exercises. The README warning exists
because the flaws below are intentional. Reviewed 2026-10-15.

## Vulnerabilities in `app/app.py`

| # | Issue | Where | Why it's a problem |
|---|-------|-------|--------------------|
| 1 | **SQL injection** | `/search`, line 175 | `q` is put into the SQL with an f-string. psycopg2 also runs multiple `;`-separated statements, so an attacker can read or modify any table, not just `posts`. |
| 2 | **Stored XSS** | `/posts` (lines 313–321), `/user/<id>` (238–246) | DB values are inserted into HTML f-strings with no escaping. The index template also marks comments `\|safe` (line 101). |
| 3 | **Broken access control (IDOR)** | `/user/<id>`, line 232 | Anyone can view any user's email and admin flag by changing the ID. No login check. |
| 4 | **Admin auth bypass** | `/admin`, line 256 | Access is granted when the `X-Forwarded-For` header is `127.0.0.1`, which the client controls. |
| 5 | **Plain-text passwords** | `/login`, line 287 | Passwords are stored and compared in plain text. No hashing, no rate limiting, so brute force is unlimited. |
| 6 | **Hard-coded secret key** | line 16 | `app.secret_key` is a known string, so anyone can forge Flask session cookies (e.g. set `is_admin`). |
| 7 | **Hard-coded DB credentials** | lines 19–25 | Default password `apppass` in the source. |
| 8 | **Debug info disclosure** | `/debug`, lines 327–339 | Dumps every environment variable (secrets included), request headers and the DB config, without auth. |
| 9 | **Error message leaks** | every route's `except` | `f"Error: {e}"` returns raw DB errors to the client, which makes SQL injection easier. |
| 10 | **Debug mode** | line 342 | `debug=True` exposes the Werkzeug debugger (remote code execution) when run with `python app.py`. The Dockerfile uses gunicorn, so this only applies to direct runs. |
| 11 | **No CSRF protection** | `/comment`, `/login` | POST forms have no CSRF tokens. |

## Supporting files

- `database/init-db.sql`: seeds users with plain-text passwords
  (`password123`, `secret_password`, ...) and a post containing a DB connection
  string, as data for the injection and disclosure exercises.
- `database/postgres-values.yaml`: hard-coded Postgres passwords (`postgres`,
  `apppass`).
- `app/requirements.txt`: pinned, older versions (Flask 2.3.3,
  gunicorn 21.2.0) for dependency-scanning exercises.

## Things that don't work as intended (not security issues)

- **Comments never show on the home page:** comments are fetched as tuples
  (line 156), but the template reads `comment.author` / `comment.content`, which
  Jinja resolves to empty. So the `|safe` XSS on the home page doesn't fire;
  the XSS still works via `/posts` and `/user/<id>`.
- **Container is always unhealthy:** the Dockerfile `HEALTHCHECK` calls `curl`,
  which `python:3.11-slim` doesn't include.
- **Flash messages never shown:** `flash()` is called, but no template renders
  them.

## What's done right

- Dockerfile runs as a non-root user (`appuser`, UID 1000).
- `/comment`, `/user`, `/login` use parameterized queries (only `/search` is
  injectable).
- `render_template_string` autoescapes, so the reflected `q` value on
  `/search` is escaped.

## Safety

Only run it in an isolated lab (local Podman/k3d, LocalStack). Never expose it
on a public network: `/debug` alone leaks every secret in the environment.
