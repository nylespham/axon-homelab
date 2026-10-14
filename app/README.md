# Vulnerable Flask Application

This directory contains the intentionally vulnerable Flask application for security testing.

## Files

- **`app.py`** - Main Flask application with security vulnerabilities
- **`requirements.txt`** - Python dependencies
- **`Dockerfile`** - Container configuration

## Vulnerabilities Included

- SQL injection in search functionality
- Cross-Site Scripting (XSS) in comment system
- Authentication bypass in admin panel
- Information disclosure in debug endpoints
- Weak session management
- Plain text password storage

## Usage

1. Build the Docker image:
   ```bash
   docker build -t vulnerable-flask:latest .
   ```

2. Deploy to Kubernetes with proper database connection

3. Test vulnerabilities as described in the main interview instructions

## Security Warning

⚠️ **This application contains intentional security vulnerabilities and should NEVER be used in production environments.**
