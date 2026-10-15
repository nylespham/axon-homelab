terraform {
  backend "s3" {
    # Real AWS account 205098647215 (versioned, encrypted, public access blocked)
    bucket = "platform-ops-tfstate-205098647215"

    # Path to store the state file
    key = "devsecops-interview-lab/terraform.tfstate"

    # AWS region
    region = "us-west-2"

    # State locking via an S3 lock file (replaces the DynamoDB table)
    use_lockfile = true

    # Enable encryption
    encrypt = true
  }
}
