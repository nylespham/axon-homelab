# Example Terraform Backend Configuration
# Copy this to backend.tf and update with your values

terraform {
  backend "s3" {
    # Replace with your S3 bucket name
    bucket = "your-terraform-state-bucket"
    
    # Path to store the state file
    key = "devsecops-interview-lab/terraform.tfstate"
    
    # AWS region
    region = "us-west-2"
    
    # Optional: Enable state locking with DynamoDB
    # dynamodb_table = "terraform-state-lock"
    
    # Optional: Enable encryption
    # encrypt = true
  }
}

# Alternative: Local backend for interview
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }
