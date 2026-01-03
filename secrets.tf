# Secrets Manager for database credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.project_name}/database/credentials"
  description = "Database credentials for ML pipeline"
  kms_key_id  = aws_kms_key.main.arn

  tags = {
    Name = "${var.project_name}-db-credentials"
    Type = "database-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = aws_db_instance.main.username
    password = random_password.rds_password.result
    host     = aws_db_instance.main.endpoint
    port     = aws_db_instance.main.port
    dbname   = aws_db_instance.main.db_name
    engine   = "postgres"
  })
}

# Secrets Manager for API keys and ML model keys
resource "aws_secretsmanager_secret" "api_keys" {
  name        = "${var.project_name}/api/keys"
  description = "API keys and tokens for ML services"
  kms_key_id  = aws_kms_key.main.arn

  tags = {
    Name = "${var.project_name}-api-keys"
    Type = "service-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "api_keys" {
  secret_id = aws_secretsmanager_secret.api_keys.id
  secret_string = jsonencode({
    huggingface_token = "PLACEHOLDER_UPDATE_MANUALLY"
    openai_api_key    = "PLACEHOLDER_UPDATE_MANUALLY"
    wandb_api_key     = "PLACEHOLDER_UPDATE_MANUALLY"
    mlflow_token      = "PLACEHOLDER_UPDATE_MANUALLY"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Secrets Manager for customer-specific configuration
resource "aws_secretsmanager_secret" "customer_config" {
  name        = "${var.project_name}/customer/config"
  description = "Customer-specific configuration and credentials"
  kms_key_id  = aws_kms_key.main.arn

  tags = {
    Name = "${var.project_name}-customer-config"
    Type = "customer-configuration"
  }
}

resource "aws_secretsmanager_secret_version" "customer_config" {
  secret_id = aws_secretsmanager_secret.customer_config.id
  secret_string = jsonencode({
    pharmacy_api_endpoint = "PLACEHOLDER_UPDATE_MANUALLY"
    pharmacy_api_key      = "PLACEHOLDER_UPDATE_MANUALLY"
    data_classification   = "healthcare-sensitive"
    compliance_region     = "japan"
    retention_policy      = "7_years"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}