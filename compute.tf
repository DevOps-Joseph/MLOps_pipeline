# Launch Template for ML Training Instances
resource "aws_launch_template" "ml_training" {
  name_prefix   = "${var.project_name}-ml-training"
  image_id      = data.aws_ami.deep_learning.id
  instance_type = var.ml_instance_type

  vpc_security_group_ids = [aws_security_group.ml_training.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ml_instance_profile.name
  }

  user_data = base64encode(templatefile("${path.module}/user_data/ml_training_setup.sh", {
    region = var.aws_region
    project_name = var.project_name
    db_secret_name = aws_secretsmanager_secret.db_credentials.name
    api_secret_name = aws_secretsmanager_secret.api_keys.name
    s3_models_bucket = aws_s3_bucket.ml_models.id
    s3_data_bucket = aws_s3_bucket.training_data.id
  }))

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 500
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = aws_kms_key.main.arn
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "${var.project_name}-ml-training-template"
    Type = "ml-training"
  }
}

# Launch Template for ML Inference Instances
resource "aws_launch_template" "ml_inference" {
  name_prefix   = "${var.project_name}-ml-inference"
  image_id      = data.aws_ami.deep_learning.id
  instance_type = var.ml_inference_instance_type

  vpc_security_group_ids = [aws_security_group.ml_inference.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ml_instance_profile.name
  }

  user_data = base64encode(templatefile("${path.module}/user_data/ml_inference_setup.sh", {
    region = var.aws_region
    project_name = var.project_name
    db_secret_name = aws_secretsmanager_secret.db_credentials.name
    customer_secret_name = aws_secretsmanager_secret.customer_config.name
    s3_models_bucket = aws_s3_bucket.ml_models.id
  }))

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 200
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = aws_kms_key.main.arn
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "${var.project_name}-ml-inference-template"
    Type = "ml-inference"
  }
}

# Auto Scaling Group for ML Training (for batch processing)
resource "aws_autoscaling_group" "ml_training" {
  name                = "${var.project_name}-ml-training-asg"
  vpc_zone_identifier = aws_subnet.private[*].id
  min_size            = 0
  max_size            = 4
  desired_capacity    = 0

  launch_template {
    id      = aws_launch_template.ml_training.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-ml-training-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Type"
    value               = "ml-training"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

# Auto Scaling Group for ML Inference
resource "aws_autoscaling_group" "ml_inference" {
  name                = "${var.project_name}-ml-inference-asg"
  vpc_zone_identifier = aws_subnet.private[*].id
  min_size            = 1
  max_size            = 3
  desired_capacity    = 1

  launch_template {
    id      = aws_launch_template.ml_inference.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-ml-inference-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Type"
    value               = "ml-inference"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

# Data source for Deep Learning AMI
data "aws_ami" "deep_learning" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Deep Learning AMI GPU PyTorch *"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}