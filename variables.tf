# Core Configuration
variable "aws_region" {
  description = "AWS region for Japan-based deployment"
  type        = string
  default     = "ap-northeast-1" # Tokyo region
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "pharmacy-ml"
}

# Network Configuration
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

# VPN Configuration
variable "customer_gateway_ip" {
  description = "Public IP address of customer gateway in Japan"
  type        = string
}

variable "customer_bgp_asn" {
  description = "BGP ASN for customer gateway"
  type        = number
  default     = 65000
}

# ML Infrastructure Configuration
variable "ml_instance_type" {
  description = "EC2 instance type for ML training (GPU-enabled)"
  type        = string
  default     = "p3.2xlarge" # NVIDIA V100 GPU
}

variable "ml_inference_instance_type" {
  description = "EC2 instance type for ML inference"
  type        = string
  default     = "g4dn.xlarge" # NVIDIA T4 GPU
}

variable "model_storage_retention_days" {
  description = "Number of days to retain model artifacts"
  type        = number
  default     = 2555 # ~7 years for healthcare compliance
}

# Security Configuration
variable "allowed_ssh_cidr" {
  description = "CIDR block allowed for SSH access (customer office)"
  type        = string
}

variable "kms_key_rotation_enabled" {
  description = "Enable automatic rotation of KMS keys"
  type        = bool
  default     = true
}

# Database Configuration
variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.r5.large"
}

variable "rds_backup_retention_period" {
  description = "Number of days to retain RDS backups"
  type        = number
  default     = 35 # Extended retention for healthcare compliance
}