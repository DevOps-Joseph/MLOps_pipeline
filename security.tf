# KMS Key for encryption at rest
resource "aws_kms_key" "main" {
  description             = "KMS key for ${var.project_name} encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = var.kms_key_rotation_enabled

  tags = {
    Name = "${var.project_name}-kms-key"
    Purpose = "healthcare-data-encryption"
  }
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project_name}-key"
  target_key_id = aws_kms_key.main.key_id
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.project_name}-vpc-endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-vpc-endpoints-sg"
    Type = "vpc-endpoints"
  }
}

# Security Group for ML Training Instances
resource "aws_security_group" "ml_training" {
  name_prefix = "${var.project_name}-ml-training"
  vpc_id      = aws_vpc.main.id

  # SSH access from customer network only
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
    description = "SSH from customer network via VPN"
  }

  # Allow communication between ML instances
  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.ml_training.id]
    description     = "Inter-ML-instance communication"
  }

  # HTTPS to VPC endpoints
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS to VPC endpoints"
  }

  # Database access
  egress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.database.id]
    description     = "PostgreSQL to database"
  }

  tags = {
    Name = "${var.project_name}-ml-training-sg"
    Type = "ml-workload"
  }
}

# Security Group for ML Inference Instances
resource "aws_security_group" "ml_inference" {
  name_prefix = "${var.project_name}-ml-inference"
  vpc_id      = aws_vpc.main.id

  # SSH access from customer network only
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
    description = "SSH from customer network via VPN"
  }

  # API access from customer network
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
    description = "ML API from customer network"
  }

  # HTTPS to VPC endpoints
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS to VPC endpoints"
  }

  # Database access
  egress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.database.id]
    description     = "PostgreSQL to database"
  }

  tags = {
    Name = "${var.project_name}-ml-inference-sg"
    Type = "ml-inference"
  }
}

# Security Group for RDS Database
resource "aws_security_group" "database" {
  name_prefix = "${var.project_name}-database"
  vpc_id      = aws_vpc.main.id

  # PostgreSQL access from ML instances only
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ml_training.id, aws_security_group.ml_inference.id]
    description     = "PostgreSQL from ML instances"
  }

  tags = {
    Name = "${var.project_name}-database-sg"
    Type = "database-access"
  }
}

# IAM Role for ML EC2 instances
resource "aws_iam_role" "ml_instance_role" {
  name = "${var.project_name}-ml-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ml-instance-role"
    Type = "ml-compute-role"
  }
}

# IAM Policy for ML instances
resource "aws_iam_role_policy" "ml_instance_policy" {
  name = "${var.project_name}-ml-instance-policy"
  role = aws_iam_role.ml_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.ml_models.arn,
          "${aws_s3_bucket.ml_models.arn}/*",
          aws_s3_bucket.training_data.arn,
          "${aws_s3_bucket.training_data.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.db_credentials.arn,
          aws_secretsmanager_secret.api_keys.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ml_instance_profile" {
  name = "${var.project_name}-ml-instance-profile"
  role = aws_iam_role.ml_instance_role.name
}