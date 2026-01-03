terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "pharmacy-ml-pipeline"
      Environment = var.environment
      Owner       = "pharmacy-ml-team"
      Compliance  = "healthcare-data"
      Region      = "japan"
    }
  }
}

# Data sources for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Generate random password for RDS
resource "random_password" "rds_password" {
  length  = 32
  special = true
}