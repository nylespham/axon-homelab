# Example Terraform Backend Configuration
# Copy this to backend.tf and update with your values

terraform {
  backend "s3" {
    # Replace with your S3 bucket name
    bucket = "platform-ops"

    # Path to store the state file
    key = "devsecops-interview-lab/terraform.tfstate"

    # AWS region
    region = "us-west-2"

    # State locking via an S3 lock file (replaces the DynamoDB table)
    use_lockfile = true

    # Optional: Enable encryption
    encrypt = true

    # The bucket has Object Lock enabled (GOVERNANCE, 7 days), so every
    # state version is retained and cannot be deleted during that window.

    # LocalStack settings
    access_key                  = "test"
    secret_key                  = "test"
    endpoints                   = { s3 = "http://localhost:4566" }
    use_path_style              = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
  }
}

# Alternative: Local backend for interview
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }
