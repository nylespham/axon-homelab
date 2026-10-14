# Infrastructure as Code

This directory contains Terraform configuration for the EKS infrastructure.

## Files

- **`eks.tf`** - EKS cluster configuration
- **`vpc.tf`** - VPC with public/private subnets
- **`variables.tf`** - Terraform variables
- **`output.tf`** - Terraform outputs
- **`versions.tf`** - Provider versions
- **`backend.example.tf`** - Backend configuration example
- **`aws-waf-example.tf`** - AWS WAF configuration example

## Usage

1. Configure backend (optional):
   ```bash
   cp backend.example.tf backend.tf
   # Edit backend.tf with your S3 bucket details
   ```

2. Deploy infrastructure:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. Configure kubectl:
   ```bash
   aws eks update-kubeconfig --region us-west-2 --name eks-interview-lab
   ```

4. Cleanup:
   ```bash
   terraform destroy
   ```

## Prerequisites

- AWS CLI configured
- Terraform >= 1.0
- Appropriate AWS permissions for EKS, VPC, and IAM
