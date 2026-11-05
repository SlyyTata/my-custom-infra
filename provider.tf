terraform {
  # ➔ Native S3 lockfiles require a modern Terraform CLI version (v1.10.0 or later)
  required_version = ">= 1.16.6" 

  # ➔ Configure the S3 Remote Backend with Native Locking
  backend "s3" {
    bucket       = "slyy-tata-bck-remote" # Replace with your exact S3 bucket name
    key          = "ecs-fargate/terraform.tfstate"       # The path file structure inside the bucket
    region       = "eu-west-2"                           # Matches your provider region
    
    # ➔ This parameter activates S3 native locking (No DynamoDB required!)
    use_lockfile = true                                  

    encrypt      = true                                  # Highly recommended: encrypt state files at rest
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}
