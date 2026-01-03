#!/bin/bash

# ML Training Instance Setup Script
# Secure setup for pharmacy ML training workloads

set -e

# Variables from Terraform
REGION="${region}"
PROJECT_NAME="${project_name}"
DB_SECRET_NAME="${db_secret_name}"
API_SECRET_NAME="${api_secret_name}"
S3_MODELS_BUCKET="${s3_models_bucket}"
S3_DATA_BUCKET="${s3_data_bucket}"

# Update system and install required packages
yum update -y
yum install -y awscli jq htop iotop tmux git

# Configure AWS CLI region
aws configure set default.region $REGION

# Create directories
mkdir -p /opt/ml/{data,models,logs,scripts}
mkdir -p /home/ec2-user/{notebooks,scripts}

# Set up logging
exec > >(tee /var/log/user-data.log) 2>&1

echo "Starting ML Training Instance Setup..."
echo "Region: $REGION"
echo "Project: $PROJECT_NAME"
echo "Timestamp: $(date)"

# Install additional Python packages for ML
source /opt/miniconda3/bin/activate pytorch
pip install --upgrade pip
pip install \
    transformers \
    datasets \
    accelerate \
    wandb \
    mlflow \
    psycopg2-binary \
    boto3 \
    sagemaker \
    scikit-learn \
    pandas \
    numpy \
    matplotlib \
    seaborn \
    jupyter \
    ipywidgets

# Create Python script to retrieve secrets
cat > /opt/ml/scripts/get_secrets.py << 'EOF'
import boto3
import json
import os

def get_secret(secret_name):
    try:
        client = boto3.client('secretsmanager')
        response = client.get_secret_value(SecretId=secret_name)
        return json.loads(response['SecretString'])
    except Exception as e:
        print(f"Error retrieving secret {secret_name}: {e}")
        return None

# Database credentials
db_creds = get_secret(os.environ.get('DB_SECRET_NAME'))
if db_creds:
    with open('/opt/ml/.env', 'w') as f:
        f.write(f"DB_HOST={db_creds['host']}\n")
        f.write(f"DB_PORT={db_creds['port']}\n")
        f.write(f"DB_NAME={db_creds['dbname']}\n")
        f.write(f"DB_USER={db_creds['username']}\n")
        f.write(f"DB_PASSWORD={db_creds['password']}\n")

# API keys
api_keys = get_secret(os.environ.get('API_SECRET_NAME'))
if api_keys:
    with open('/opt/ml/.api_env', 'w') as f:
        for key, value in api_keys.items():
            if value != "PLACEHOLDER_UPDATE_MANUALLY":
                f.write(f"{key.upper()}={value}\n")

print("Secrets retrieved successfully")
EOF

# Set environment variables and run secret retrieval
export DB_SECRET_NAME="$DB_SECRET_NAME"
export API_SECRET_NAME="$API_SECRET_NAME"
cd /opt/ml/scripts && python get_secrets.py

# Create training script template
cat > /opt/ml/scripts/train_model.py << 'EOF'
#!/usr/bin/env python3
"""
Secure ML Training Script for Pharmacy Data
Handles encrypted data, logs training metrics, stores models securely
"""

import os
import json
import boto3
import psycopg2
from datetime import datetime
import torch
from transformers import AutoTokenizer, AutoModel
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/opt/ml/logs/training.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class SecureMLPipeline:
    def __init__(self):
        self.s3_client = boto3.client('s3')
        self.load_environment()
        self.connect_database()

    def load_environment(self):
        """Load environment variables from secure files"""
        if os.path.exists('/opt/ml/.env'):
            with open('/opt/ml/.env') as f:
                for line in f:
                    if '=' in line:
                        key, value = line.strip().split('=', 1)
                        os.environ[key] = value

        if os.path.exists('/opt/ml/.api_env'):
            with open('/opt/ml/.api_env') as f:
                for line in f:
                    if '=' in line:
                        key, value = line.strip().split('=', 1)
                        os.environ[key] = value

    def connect_database(self):
        """Connect to PostgreSQL database"""
        try:
            self.db_conn = psycopg2.connect(
                host=os.environ['DB_HOST'],
                port=os.environ['DB_PORT'],
                database=os.environ['DB_NAME'],
                user=os.environ['DB_USER'],
                password=os.environ['DB_PASSWORD']
            )
            logger.info("Database connection established")
        except Exception as e:
            logger.error(f"Database connection failed: {e}")
            self.db_conn = None

    def log_training_run(self, model_name, metrics):
        """Log training run to database"""
        if not self.db_conn:
            return

        try:
            with self.db_conn.cursor() as cursor:
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS training_runs (
                        id SERIAL PRIMARY KEY,
                        model_name VARCHAR(255),
                        timestamp TIMESTAMP,
                        metrics JSONB,
                        status VARCHAR(50)
                    )
                """)

                cursor.execute("""
                    INSERT INTO training_runs (model_name, timestamp, metrics, status)
                    VALUES (%s, %s, %s, %s)
                """, (model_name, datetime.now(), json.dumps(metrics), 'completed'))

                self.db_conn.commit()
                logger.info(f"Training run logged for {model_name}")
        except Exception as e:
            logger.error(f"Failed to log training run: {e}")

if __name__ == "__main__":
    pipeline = SecureMLPipeline()
    logger.info("ML Pipeline initialized successfully")
    # Add your training logic here
EOF

# Create inference preparation script
cat > /opt/ml/scripts/prepare_inference.py << 'EOF'
#!/usr/bin/env python3
"""
Prepare trained models for inference deployment
Upload models to S3 and update model registry
"""

import boto3
import json
import os
from datetime import datetime

def upload_model_to_s3(model_path, model_name):
    """Upload trained model to S3 with encryption"""
    s3_client = boto3.client('s3')
    bucket = os.environ.get('S3_MODELS_BUCKET')

    if not bucket:
        print("S3_MODELS_BUCKET environment variable not set")
        return None

    key = f"models/{model_name}/{datetime.now().isoformat()}/model.tar.gz"

    try:
        s3_client.upload_file(
            model_path,
            bucket,
            key,
            ExtraArgs={'ServerSideEncryption': 'aws:kms'}
        )
        print(f"Model uploaded to s3://{bucket}/{key}")
        return f"s3://{bucket}/{key}"
    except Exception as e:
        print(f"Failed to upload model: {e}")
        return None

if __name__ == "__main__":
    print("Model preparation script ready")
EOF

# Set up environment variables for ML scripts
cat > /opt/ml/.bashrc_additions << EOF
export S3_MODELS_BUCKET="$S3_MODELS_BUCKET"
export S3_DATA_BUCKET="$S3_DATA_BUCKET"
export PYTHONPATH="/opt/ml/scripts:\$PYTHONPATH"
source /opt/miniconda3/bin/activate pytorch
EOF

# Append to user bashrc
cat /opt/ml/.bashrc_additions >> /home/ec2-user/.bashrc

# Set permissions
chown -R ec2-user:ec2-user /opt/ml
chown -R ec2-user:ec2-user /home/ec2-user
chmod +x /opt/ml/scripts/*.py
chmod 600 /opt/ml/.env /opt/ml/.api_env

# Create systemd service for ML monitoring
cat > /etc/systemd/system/ml-monitor.service << EOF
[Unit]
Description=ML Training Monitor
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/ml
Environment=PATH=/opt/miniconda3/envs/pytorch/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/bin/bash -c 'source /opt/miniconda3/bin/activate pytorch && python -c "print(\"ML Training instance ready\")"'
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl enable ml-monitor
systemctl start ml-monitor

# Configure log rotation for ML logs
cat > /etc/logrotate.d/ml-training << EOF
/opt/ml/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
}
EOF

# Security hardening
echo "net.ipv4.ip_forward=0" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.send_redirects=0" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.send_redirects=0" >> /etc/sysctl.conf
sysctl -p

# Final setup
echo "ML Training Instance Setup Complete: $(date)" >> /var/log/user-data.log
echo "Instance ready for secure ML training workloads" >> /var/log/user-data.log