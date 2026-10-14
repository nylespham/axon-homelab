# DevSecOps Interview Lab

This repository contains a hands-on interview test for DevSecOps candidates. You'll start with basic infrastructure and progressively add security components.

## Repository Structure

```
devsecops-homelab/
├── README.md                    # This file
├── app/                        # Vulnerable Flask application
│   ├── app.py                  # Main application code
│   ├── requirements.txt        # Python dependencies
│   └── Dockerfile             # Container configuration
├── database/                   # Database configuration
│   ├── init-db.sql            # Database initialization script
│   └── postgres-values.yaml    # Helm values for PostgreSQL
├── terraform/                  # Infrastructure as Code
│   ├── eks.tf                 # EKS cluster configuration
│   ├── vpc.tf                 # VPC configuration
│   ├── variables.tf           # Terraform variables
│   ├── output.tf              # Terraform outputs
│   ├── versions.tf            # Provider versions
│   ├── backend.example.tf     # Backend configuration example
│   ├── aws-waf-example.tf     # AWS WAF configuration example
│   ├── security-examples.tf   # Security configuration examples
│   └── terraform.tfvars.example # Configuration examples
├── kubernetes/                 # Kubernetes security examples
│   ├── kubernetes-security-examples.yaml # Security manifests
│   ├── SECURITY_HARDENING.md  # Security hardening guide
│   └── README.md              # Kubernetes security documentation
└── docs/                      # Documentation
    ├── INTERVIEW_INSTRUCTIONS.md  # For interviewers
    ├── TEST_DATA.md          # Test data overview
    ├── TROUBLESHOOTING.md    # Troubleshooting guide
    └── README.md             # Detailed interview instructions
```

## Quick Start

1. **Fork this repository** to your own GitHub account
2. **Clone your fork** locally
3. **Follow the tasks in `docs/README.md`** in order
4. **Document your approach** as you go
5. **Be prepared to explain** your decisions and trade-offs

## Interview Overview

This test evaluates your ability to:
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
**Start with infrastructure** - Deploy EKS cluster using Terraform
**Deploy database** - Use Helm to deploy PostgreSQL

## 
1. **Deploy application** - Build and deploy the vulnerable Flask app
2. **Test vulnerabilities** - Identify and test security issues
3. **Implement WAF** - Deploy and configure WAF solution
4. **Security hardening** - Add additional security measures

## Detailed Instructions

See `docs/README.md` for complete interview instructions and tasks.

## Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Helm Documentation](https://helm.sh/docs/)
- [Bitnami PostgreSQL Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
- [AWS WAF Documentation](https://docs.aws.amazon.com/waf/)
- [AWS WAF Managed Rules](https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups.html)
- [OWASP Web Application Security](https://owasp.org/www-project-web-security-testing-guide/)
- [ModSecurity Documentation](https://github.com/SpiderLabs/ModSecurity)

## Cleanup

When you're done, clean up resources manually:

```bash
# Delete Kubernetes resources
kubectl delete namespace waf --ignore-not-found=true
kubectl delete namespace vulnerable-app --ignore-not-found=true
kubectl delete namespace database --ignore-not-found=true

# Destroy infrastructure
cd terraform/
terraform destroy -auto-approve
```

## Support

- Review `docs/INTERVIEW_INSTRUCTIONS.md` for interviewer guidance
- Check `docs/TEST_DATA.md` for database test data overview
- See `docs/README.md` for detailed task instructions
