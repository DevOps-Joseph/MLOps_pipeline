# VPN Connection Outputs
output "vpn_connection_id" {
  description = "ID of the Site-to-Site VPN connection"
  value       = aws_vpn_connection.main.id
}

output "vpn_connection_customer_gateway_configuration" {
  description = "Customer gateway configuration for VPN setup"
  value       = aws_vpn_connection.main.customer_gateway_configuration
  sensitive   = true
}

output "customer_gateway_ip" {
  description = "Customer gateway IP address"
  value       = aws_customer_gateway.main.ip_address
}

# Network Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "database_subnet_group_name" {
  description = "Name of the database subnet group"
  value       = aws_db_subnet_group.main.name
}

# Storage Outputs
output "s3_ml_models_bucket" {
  description = "S3 bucket for ML models"
  value       = aws_s3_bucket.ml_models.id
}

output "s3_training_data_bucket" {
  description = "S3 bucket for training data"
  value       = aws_s3_bucket.training_data.id
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

# Security Outputs
output "kms_key_id" {
  description = "ID of the KMS key for encryption"
  value       = aws_kms_key.main.key_id
}

output "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  value       = aws_kms_key.main.arn
}

# Secrets Manager Outputs
output "db_credentials_secret_name" {
  description = "Name of the database credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "api_keys_secret_name" {
  description = "Name of the API keys secret"
  value       = aws_secretsmanager_secret.api_keys.name
}

output "customer_config_secret_name" {
  description = "Name of the customer configuration secret"
  value       = aws_secretsmanager_secret.customer_config.name
}

# Compute Outputs
output "ml_training_asg_name" {
  description = "Name of the ML training Auto Scaling Group"
  value       = aws_autoscaling_group.ml_training.name
}

output "ml_inference_asg_name" {
  description = "Name of the ML inference Auto Scaling Group"
  value       = aws_autoscaling_group.ml_inference.name
}

output "ml_instance_profile_name" {
  description = "Name of the IAM instance profile for ML instances"
  value       = aws_iam_instance_profile.ml_instance_profile.name
}

# Security Group Outputs
output "ml_training_security_group_id" {
  description = "ID of the ML training security group"
  value       = aws_security_group.ml_training.id
}

output "ml_inference_security_group_id" {
  description = "ID of the ML inference security group"
  value       = aws_security_group.ml_inference.id
}

output "database_security_group_id" {
  description = "ID of the database security group"
  value       = aws_security_group.database.id
}

# Monitoring Outputs
output "cloudwatch_dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.ml_pipeline.dashboard_name}"
}

output "security_alerts_topic_arn" {
  description = "ARN of the security alerts SNS topic"
  value       = aws_sns_topic.security_alerts.arn
}

output "operational_alerts_topic_arn" {
  description = "ARN of the operational alerts SNS topic"
  value       = aws_sns_topic.operational_alerts.arn
}

# Infrastructure Summary
output "deployment_summary" {
  description = "Summary of deployed infrastructure"
  value = {
    region                = var.aws_region
    environment          = var.environment
    vpc_id              = aws_vpc.main.id
    vpn_connection_id   = aws_vpn_connection.main.id
    ml_training_asg     = aws_autoscaling_group.ml_training.name
    ml_inference_asg    = aws_autoscaling_group.ml_inference.name
    database_endpoint   = aws_db_instance.main.endpoint
    s3_models_bucket    = aws_s3_bucket.ml_models.id
    s3_data_bucket      = aws_s3_bucket.training_data.id
    kms_key_id          = aws_kms_key.main.key_id
    dashboard_name      = aws_cloudwatch_dashboard.ml_pipeline.dashboard_name
  }
}