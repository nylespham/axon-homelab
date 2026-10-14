# DevSecOps Interview Lab

This repository contains a hands-on interview test for DevSecOps candidates. You'll start with basic infrastructure and progressively add security components.

## Interview Overview

You have **2-3 hours** to complete the following tasks. This test evaluates your ability to:
- Deploy and manage Kubernetes infrastructure
- Implement security best practices
- Deploy and configure security tools
- Troubleshoot and optimize systems

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- kubectl
- Docker
- Helm (or ability to install it)
- Knowledge of Kubernetes, security concepts, and infrastructure
- S3 bucket for Terraform state (or use local state)

## Getting Started

1. **Fork this repository** to your own GitHub account
2. **Clone your fork** locally
3. **Follow the tasks below** in order
4. **Document your approach** as you go
5. **Be prepared to explain** your decisions and trade-offs

### Setup home lab

### Infrastructure Setup
**Objective:** Deploy basic EKS infrastructure

1. **Configure Terraform backend (if required):**
   ```bash
   # Edit backend.tf with your S3 bucket details
   # Or use local state for the interview
   ```

2. **Deploy the provided Terraform configuration:**
   ```bash
   cd terraform/
   terraform init
   terraform plan
   terraform apply
   ```

2. **Configure kubectl access:**
   ```bash
   aws eks update-kubeconfig --region us-west-2 --name eks-interview-lab
   ```

3. **Verify cluster is working:**
   ```bash
   kubectl get nodes
   kubectl get pods -A
   ```

**Deliverable:** Working EKS cluster with kubectl access

---

### Database Deployment
**Objective:** Deploy a stateful PostgreSQL database using Helm

1. **Install Helm (if not already installed):**
   ```bash
   # Install Helm
   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
   ```

2. **Add PostgreSQL Helm repository:**
   ```bash
   helm repo add bitnami https://charts.bitnami.com/bitnami
   helm repo update
   ```

3. **Deploy PostgreSQL using Helm with:**
   - Use the provided `database/postgres-values.yaml` as a starting point
   - Customize values for your requirements
   - Persistent storage (at least 10GB)
   - Custom database name and user
   - Proper secrets management
   - Health checks enabled

4. **Import test data:**
   ```bash
   # Copy the init script to the pod
   kubectl cp database/init-db.sql <postgres-pod>:/tmp/init-db.sql
   
   # Execute the initialization script
   kubectl exec -it <postgres-pod> -- psql -U postgres -d vulnerable_app -f /tmp/init-db.sql
   ```

5. **Test database connectivity and verify data:**
   ```bash
   # Test connection
   kubectl exec -it <postgres-pod> -- psql -U <username> -d <database> -c "SELECT version();"
   
   # Verify test data was imported
   kubectl exec -it <postgres-pod> -- psql -U <username> -d <database> -c "SELECT COUNT(*) FROM users;"
   kubectl exec -it <postgres-pod> -- psql -U <username> -d <database> -c "SELECT COUNT(*) FROM posts;"
   kubectl exec -it <postgres-pod> -- psql -U <username> -d <database> -c "SELECT COUNT(*) FROM comments;"
   ```

**Deliverable:** Working PostgreSQL database deployed via Helm with persistent storage

---
## Interview Tasks
### 1: Vulnerable Application (60 minutes)
**Objective:** Deploy and test a vulnerable web application

1. **Deploy the provided vulnerable Flask application:**
   - Build the Docker image from `app/` directory
   - Create Kubernetes manifests
   - Connect to the PostgreSQL database
   - Expose the application

2. **Test the application:**
   ```bash
   kubectl port-forward svc/<app-service> 5000:80
   curl http://localhost:5000
   ```

3. **Identify and test vulnerabilities:**
   
   **SQL Injection Testing:**
   ```bash
   # Test basic SQL injection in search
   curl "http://localhost:5000/search?q=' OR '1'='1"
   curl "http://localhost:5000/search?q=' UNION SELECT 1,2,3,4--"
   curl "http://localhost:5000/search?q='; DROP TABLE users;--"
   ```
   
   **XSS Testing:**
   ```bash
   # Test stored XSS in comments
   curl -X POST "http://localhost:5000/comment" \
     -d "author=test&content=<script>alert('XSS')</script>"
   curl -X POST "http://localhost:5000/comment" \
     -d "author=test&content=<img src=x onerror=alert('XSS')>"
   ```
   
   **Authentication Bypass:**
   ```bash
   # Test IP-based admin bypass
   curl "http://localhost:5000/admin" -H "X-Forwarded-For: 127.0.0.1"
   curl "http://localhost:5000/admin" -H "X-Real-IP: 127.0.0.1"
   ```
   
   **Information Disclosure:**
   ```bash
   # Test debug endpoint
   curl "http://localhost:5000/debug"
   
   # Test user information access
   curl "http://localhost:5000/user/1"
   curl "http://localhost:5000/user/2"
   ```
   
   **Document your findings:**
   - Which vulnerabilities did you find?
   - What attack vectors work?
   - What data can you access?
   - How would you exploit these in a real scenario?

**Deliverable:** Working vulnerable application with identified security issues

## Submission Requirements

1. **Working environment** with all components deployed
2. **Documentation** of your approach and decisions
3. **Security testing results** showing vulnerabilities and protection
4. **WAF configuration** with explanation of rules
5. **Cleanup script** to destroy resources

## Tips for Success

1. **Start simple** and build complexity gradually
2. **Document everything** as you go
3. **Test frequently** to catch issues early
4. **Research WAF options** before implementing (open source vs AWS WAF)
5. **Consider your environment** - AWS WAF for cloud-native, open source for flexibility
6. **Focus on security** over features
7. **Be prepared to explain** your decisions

## Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Helm Documentation](https://helm.sh/docs/)
- [Bitnami PostgreSQL Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
- [AWS WAF Documentation](https://docs.aws.amazon.com/waf/)
- [AWS WAF Managed Rules](https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups.html)
- [OWASP Web Application Security](https://owasp.org/www-project-web-security-testing-guide/)
- [ModSecurity Documentation](https://github.com/SpiderLabs/ModSecurity)
