# CloudWatch Log Groups for ML Pipeline
resource "aws_cloudwatch_log_group" "ml_training" {
  name              = "/aws/ec2/${var.project_name}/ml-training"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.main.arn

  tags = {
    Name = "${var.project_name}-ml-training-logs"
    Type = "training-logs"
  }
}

resource "aws_cloudwatch_log_group" "ml_inference" {
  name              = "/aws/ec2/${var.project_name}/ml-inference"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.main.arn

  tags = {
    Name = "${var.project_name}-ml-inference-logs"
    Type = "inference-logs"
  }
}

resource "aws_cloudwatch_log_group" "vpn_logs" {
  name              = "/aws/vpn/${var.project_name}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.main.arn

  tags = {
    Name = "${var.project_name}-vpn-logs"
    Type = "network-logs"
  }
}

# CloudWatch Alarms for Security Monitoring
resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  alarm_name          = "${var.project_name}-unauthorized-api-calls"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnauthorizedAPICalls"
  namespace           = "CWLogs"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors unauthorized API calls"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    LogGroupName = aws_cloudwatch_log_group.ml_inference.name
  }

  tags = {
    Name = "${var.project_name}-security-alarm"
    Type = "security-monitoring"
  }
}

resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "${var.project_name}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ErrorRate"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "0.1"
  alarm_description   = "This metric monitors high error rate in ML API"
  alarm_actions       = [aws_sns_topic.operational_alerts.arn]

  tags = {
    Name = "${var.project_name}-error-rate-alarm"
    Type = "operational-monitoring"
  }
}

# SNS Topics for Alerts
resource "aws_sns_topic" "security_alerts" {
  name         = "${var.project_name}-security-alerts"
  display_name = "Pharmacy ML Security Alerts"
  kms_master_key_id = aws_kms_key.main.arn

  tags = {
    Name = "${var.project_name}-security-alerts"
    Type = "security-notifications"
  }
}

resource "aws_sns_topic" "operational_alerts" {
  name         = "${var.project_name}-operational-alerts"
  display_name = "Pharmacy ML Operational Alerts"
  kms_master_key_id = aws_kms_key.main.arn

  tags = {
    Name = "${var.project_name}-operational-alerts"
    Type = "operational-notifications"
  }
}

# CloudWatch Dashboard for ML Pipeline Monitoring
resource "aws_cloudwatch_dashboard" "ml_pipeline" {
  dashboard_name = "${var.project_name}-ml-pipeline-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.ml_training.name],
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.ml_inference.name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ML Instance CPU Utilization"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.main.id],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.main.id]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Database Performance"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/S3", "BucketRequestsGet", "BucketName", aws_s3_bucket.ml_models.id],
            ["AWS/S3", "BucketRequestsPut", "BucketName", aws_s3_bucket.ml_models.id]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "S3 Model Storage Activity"
          period  = 300
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          query   = "SOURCE '${aws_cloudwatch_log_group.ml_inference.name}' | fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 20"
          region  = var.aws_region
          title   = "Recent API Errors"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-dashboard"
    Type = "monitoring-dashboard"
  }
}

# VPC Flow Logs for Network Monitoring
resource "aws_flow_log" "vpc_flow_logs" {
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-vpc-flow-logs"
    Type = "network-monitoring"
  }
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${var.project_name}/flowlogs"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.main.arn

  tags = {
    Name = "${var.project_name}-vpc-flow-logs"
    Type = "network-logs"
  }
}

resource "aws_iam_role" "flow_log" {
  name = "${var.project_name}-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-flow-log-role"
  }
}

resource "aws_iam_role_policy" "flow_log" {
  name = "${var.project_name}-flow-log-policy"
  role = aws_iam_role.flow_log.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}