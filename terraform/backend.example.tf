# Example Terraform Backend Configuration
# Copy this to backend.tf and update with your values

# terraform {
#   backend "s3" {
#     # Replace with your S3 bucket name
#     bucket = "platform-ops-tfstate-205098647215"
#
#     # Path to store the state file
#     key = "devsecops-interview-lab/terraform.tfstate"
#
#     # AWS region
#     region = "us-west-2"
#
#     # State locking via an S3 lock file (replaces the DynamoDB table)
#     use_lockfile = true
#
#     # Optional: Enable encryption
#     encrypt = true
#   }
# }

# Alternative: Local backend for interview
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }
