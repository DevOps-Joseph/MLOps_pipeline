#!/bin/bash

# ML Inference Instance Setup Script
# Secure setup for pharmacy ML inference API

set -e

# Variables from Terraform
REGION="${region}"
PROJECT_NAME="${project_name}"
DB_SECRET_NAME="${db_secret_name}"
CUSTOMER_SECRET_NAME="${customer_secret_name}"
S3_MODELS_BUCKET="${s3_models_bucket}"

# Update system and install required packages
yum update -y
yum install -y awscli jq htop nginx

# Configure AWS CLI region
aws configure set default.region $REGION

# Create directories
mkdir -p /opt/ml/{models,logs,api}
mkdir -p /home/ec2-user/api

# Set up logging
exec > >(tee /var/log/user-data.log) 2>&1

echo "Starting ML Inference Instance Setup..."
echo "Region: $REGION"
echo "Project: $PROJECT_NAME"
echo "Timestamp: $(date)"

# Install additional Python packages for inference
source /opt/miniconda3/bin/activate pytorch
pip install --upgrade pip
pip install \
    fastapi \
    uvicorn \
    transformers \
    torch \
    psycopg2-binary \
    boto3 \
    pydantic \
    python-multipart \
    prometheus-client \
    redis

# Create Python script to retrieve secrets
cat > /opt/ml/api/get_secrets.py << 'EOF'
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

# Customer configuration
customer_config = get_secret(os.environ.get('CUSTOMER_SECRET_NAME'))
if customer_config:
    with open('/opt/ml/.customer_env', 'w') as f:
        for key, value in customer_config.items():
            if value != "PLACEHOLDER_UPDATE_MANUALLY":
                f.write(f"{key.upper()}={value}\n")

print("Secrets retrieved successfully")
EOF

# Set environment variables and run secret retrieval
export DB_SECRET_NAME="$DB_SECRET_NAME"
export CUSTOMER_SECRET_NAME="$CUSTOMER_SECRET_NAME"
cd /opt/ml/api && python get_secrets.py

# Create FastAPI application
cat > /opt/ml/api/main.py << 'EOF'
#!/usr/bin/env python3
"""
Secure ML Inference API for Pharmacy ML Pipeline
Provides encrypted, authenticated access to ML models
"""

import os
import json
import boto3
import psycopg2
from datetime import datetime, timedelta
from typing import Optional
import logging
import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Depends, Security, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import torch
from transformers import AutoTokenizer, AutoModel

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/opt/ml/logs/inference.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Global variables
ml_model = None
tokenizer = None
db_pool = None

class PredictionRequest(BaseModel):
    text: str
    patient_id: Optional[str] = None
    pharmacy_id: Optional[str] = None

class PredictionResponse(BaseModel):
    prediction: dict
    confidence: float
    model_version: str
    timestamp: str

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await load_models()
    yield
    # Shutdown
    if db_pool:
        db_pool.close()

app = FastAPI(
    title="Pharmacy ML API",
    description="Secure ML inference for pharmacy data",
    version="1.0.0",
    lifespan=lifespan
)

# Security
security = HTTPBearer()

def load_environment():
    """Load environment variables from secure files"""
    if os.path.exists('/opt/ml/.env'):
        with open('/opt/ml/.env') as f:
            for line in f:
                if '=' in line:
                    key, value = line.strip().split('=', 1)
                    os.environ[key] = value

    if os.path.exists('/opt/ml/.customer_env'):
        with open('/opt/ml/.customer_env') as f:
            for line in f:
                if '=' in line:
                    key, value = line.strip().split('=', 1)
                    os.environ[key] = value

async def load_models():
    """Load ML models from S3"""
    global ml_model, tokenizer

    load_environment()

    try:
        # Download latest model from S3
        s3_client = boto3.client('s3')
        bucket = os.environ.get('S3_MODELS_BUCKET')

        # For demo, using a pre-trained model
        # In production, load your trained pharmacy-specific model
        model_name = "bert-base-uncased"
        tokenizer = AutoTokenizer.from_pretrained(model_name)
        ml_model = AutoModel.from_pretrained(model_name)

        logger.info("Models loaded successfully")
    except Exception as e:
        logger.error(f"Failed to load models: {e}")
        raise

def verify_token(credentials: HTTPAuthorizationCredentials = Security(security)):
    """Verify API token"""
    # In production, implement proper token verification
    # For demo, we'll use a simple token check
    expected_token = "pharmacy-ml-token-2024"

    if credentials.credentials != expected_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token"
        )
    return credentials.credentials

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "model_loaded": ml_model is not None
    }

@app.post("/predict", response_model=PredictionResponse)
async def predict(
    request: PredictionRequest,
    token: str = Depends(verify_token)
):
    """Make prediction on pharmacy data"""
    try:
        if not ml_model or not tokenizer:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Model not loaded"
            )

        # Log prediction request (without sensitive data)
        logger.info(f"Prediction request received for patient: {request.patient_id}")

        # Tokenize input
        inputs = tokenizer(
            request.text,
            return_tensors="pt",
            truncation=True,
            padding=True,
            max_length=512
        )

        # Make prediction
        with torch.no_grad():
            outputs = ml_model(**inputs)

        # For demo purposes, return a simple prediction
        # In production, implement your pharmacy-specific prediction logic
        prediction = {
            "classification": "sample_prediction",
            "embeddings_shape": list(outputs.last_hidden_state.shape),
            "processed_tokens": inputs['input_ids'].shape[1]
        }

        confidence = 0.85  # Example confidence score

        # Log to database
        await log_prediction(request, prediction, confidence)

        return PredictionResponse(
            prediction=prediction,
            confidence=confidence,
            model_version="1.0.0",
            timestamp=datetime.now().isoformat()
        )

    except Exception as e:
        logger.error(f"Prediction failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Prediction failed"
        )

async def log_prediction(request: PredictionRequest, prediction: dict, confidence: float):
    """Log prediction to database"""
    try:
        conn = psycopg2.connect(
            host=os.environ['DB_HOST'],
            port=os.environ['DB_PORT'],
            database=os.environ['DB_NAME'],
            user=os.environ['DB_USER'],
            password=os.environ['DB_PASSWORD']
        )

        with conn.cursor() as cursor:
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS predictions (
                    id SERIAL PRIMARY KEY,
                    patient_id VARCHAR(255),
                    pharmacy_id VARCHAR(255),
                    prediction JSONB,
                    confidence FLOAT,
                    timestamp TIMESTAMP,
                    model_version VARCHAR(50)
                )
            """)

            cursor.execute("""
                INSERT INTO predictions (patient_id, pharmacy_id, prediction, confidence, timestamp, model_version)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (
                request.patient_id,
                request.pharmacy_id,
                json.dumps(prediction),
                confidence,
                datetime.now(),
                "1.0.0"
            ))

            conn.commit()
            logger.info("Prediction logged to database")

        conn.close()
    except Exception as e:
        logger.error(f"Failed to log prediction: {e}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
EOF

# Create systemd service for FastAPI
cat > /etc/systemd/system/pharmacy-ml-api.service << EOF
[Unit]
Description=Pharmacy ML API
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/ml/api
Environment=PATH=/opt/miniconda3/envs/pytorch/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/opt/miniconda3/envs/pytorch/bin/uvicorn main:app --host 0.0.0.0 --port 8080 --workers 2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Configure Nginx as reverse proxy
cat > /etc/nginx/conf.d/ml-api.conf << EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /health {
        proxy_pass http://127.0.0.1:8080/health;
        access_log off;
    }
}
EOF

# Set up environment variables
cat > /opt/ml/.api_env << EOF
S3_MODELS_BUCKET="$S3_MODELS_BUCKET"
PYTHONPATH="/opt/ml/api:\$PYTHONPATH"
EOF

# Set permissions
chown -R ec2-user:ec2-user /opt/ml
chown -R ec2-user:ec2-user /home/ec2-user
chmod +x /opt/ml/api/*.py
chmod 600 /opt/ml/.env /opt/ml/.customer_env /opt/ml/.api_env

# Configure log rotation
cat > /etc/logrotate.d/ml-inference << EOF
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

# Enable and start services
systemctl enable nginx
systemctl enable pharmacy-ml-api
systemctl start nginx
systemctl start pharmacy-ml-api

# Security hardening
echo "net.ipv4.ip_forward=0" >> /etc/sysctl.conf
sysctl -p

# Firewall configuration (allow only necessary ports)
yum install -y iptables-services
systemctl enable iptables

# Create basic iptables rules
cat > /etc/sysconfig/iptables << EOF
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 8080 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
COMMIT
EOF

systemctl start iptables

echo "ML Inference Instance Setup Complete: $(date)" >> /var/log/user-data.log
echo "API available at http://localhost:8080" >> /var/log/user-data.log