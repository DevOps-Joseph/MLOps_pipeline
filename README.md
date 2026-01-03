# Secure ML/LLM Pipeline
### Enterprise Healthcare Infrastructure for Japan-Based Pharmacy Client

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Terraform](https://img.shields.io/badge/Terraform-1.5+-623CE4.svg?logo=terraform&logoColor=white)]()
[![AWS](https://img.shields.io/badge/AWS-Tokyo%20Region-FF9900.svg?logo=amazonwebservices&logoColor=white)]()
[![Compliance](https://img.shields.io/badge/Healthcare-Compliant-00A86B.svg)]()

*A production-grade, zero-trust ML/LLM infrastructure built for processing sensitive healthcare data with complete network isolation, end-to-end encryption, and regulatory compliance.*

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Problem Statement](#problem-statement)
3. [Solution Architecture](#solution-architecture)
4. [Technical Deep Dive](#technical-deep-dive)
   - [Why Site-to-Site VPN? ](#why-site-to-site-vpn)
   - [Why No Internet Access?](#why-no-internet-access)
   - [Why These GPU Instances?](#why-these-gpu-instances)
   - [Why Customer-Managed KMS Keys?](#why-customer-managed-kms-keys)
   - [Why PostgreSQL Over DynamoDB?](#why-postgresql-over-dynamodb)
5. [Infrastructure Components](#infrastructure-components)
6. [Security Model](#security-model)
7. [Getting Started](#getting-started)
8. [Operational Procedures](#operational-procedures)
9. [Monitoring & Compliance](#monitoring--compliance)
10. [Cost Analysis](#cost-analysis)
11. [Troubleshooting Guide](#troubleshooting-guide)
12. [Author](#author)

---

## Executive Summary

This repository contains the complete Terraform infrastructure code for deploying a secure, scalable ML/LLM pipeline on AWS.  The infrastructure was specifically designed for a Japan-based pharmacy client who required a solution capable of handling sensitive healthcare data while meeting strict Japanese data protection regulations.

**Key Outcomes Delivered:**

- **100% Network Isolation** — No component is accessible from the public internet
- **End-to-End Encryption** — All data encrypted at rest and in transit using customer-managed keys
- **7-Year Audit Trail** — Complete logging infrastructure meeting healthcare compliance requirements
- **90%+ Cost Reduction** — Training infrastructure scales to zero when idle
- **< 10ms Latency** — All resources deployed in Tokyo region for optimal performance

---

## Problem Statement

### The Client

A leading pharmacy chain in Japan was expanding their operations to include AI-powered services:  drug interaction analysis, prescription optimization, and patient health predictions. These services required processing sensitive Protected Health Information (PHI) including patient records, prescription histories, and medical diagnoses. 

### The Constraints

The client's security and compliance teams presented us with five non-negotiable requirements: 

**1. Data Sovereignty**

> *"All patient data must remain within Japan's borders at all times. We cannot use any service that might route data through servers outside Japan, even temporarily."*

This requirement eliminated many standard cloud architectures that rely on global services or cross-region replication. Every component—compute, storage, networking, and logging—needed to be explicitly configured for the Tokyo region with no possibility of data leaving Japan.

**2. Zero Public Internet Exposure**

> *"Our security policy prohibits any system handling PHI from being accessible via the public internet. Not even through a VPN service that terminates in the cloud—the connection must originate from our physical office network."*

This ruled out AWS Client VPN, bastion hosts with public IPs, and any architecture involving public subnets.  The only acceptable access pattern was a dedicated, encrypted tunnel from their Tokyo office directly into the AWS VPC.

**3. Complete Audit Trail**

> *"Japanese healthcare regulations require us to retain all access logs and processing records for a minimum of seven years. We must be able to prove, at any point during an audit, exactly who accessed what data and when."*

This meant implementing comprehensive logging at every layer:  network flow logs, API access logs, application logs, and database query logs—all with enforced 7-year retention and encryption.

**4. Customer-Controlled Encryption**

> *"We cannot rely on AWS-managed encryption keys. Our compliance team requires that we maintain full control over encryption keys, including the ability to immediately revoke access if needed."*

This requirement pushed us toward AWS KMS with Customer-Managed Keys (CMKs) rather than AWS-managed keys, giving the client complete control over their encryption lifecycle.

**5. Cost Efficiency**

> *"We need GPU instances for training, but we can't afford to run them 24/7. Training happens in batches—sometimes daily, sometimes weekly. We need the infrastructure to scale down to near-zero costs when not in use."*

This drove our decision to use Auto Scaling Groups with the ability to scale training instances to zero, rather than reserved or dedicated instances.

---

## Solution Architecture

### High-Level Overview

We designed a **zero-trust, private-only architecture** that addresses every client requirement while maintaining operational simplicity.  Here's how the components work together:

<img width="1185" height="802" alt="image" src="https://github.com/user-attachments/assets/29f48d3a-f2b7-4202-97d3-ae1be709a80e" />


### Data Flow

**Training Pipeline:**
1. Data scientists connect from the Tokyo office through the Site-to-Site VPN
2. They SSH into training instances (p3.2xlarge) via private IP addresses
3. Training data is pulled from encrypted S3 buckets through VPC endpoints
4. Model training occurs on NVIDIA V100 GPUs using PyTorch
5. Trained models are saved back to S3, encrypted with customer-managed KMS keys
6. All activity is logged to CloudWatch with 7-year retention

**Inference Pipeline:**
1. Client applications connect through the VPN to the inference API
2. Requests are load-balanced across g4dn.xlarge instances
3. Models are loaded from S3 and cached locally
4. Predictions are returned through the encrypted VPN tunnel
5. All API calls are logged for audit compliance

---

## Technical Deep Dive

This section explains the reasoning behind each major architectural decision.  Understanding these trade-offs is essential for maintaining and evolving the infrastructure.

### Why Site-to-Site VPN?

**The Decision:** We implemented AWS Site-to-Site VPN rather than AWS Client VPN, Direct Connect, or public-facing bastion hosts. 

**Alternatives Considered:**

| Option | Why We Rejected It |
|--------|-------------------|
| **AWS Client VPN** | Terminates in AWS-managed infrastructure.  The client's security team required a tunnel that connects directly from their on-premises equipment to their VPC—no intermediate AWS-managed components. |
| **AWS Direct Connect** | Provides dedicated physical connectivity but requires 1-3 months for provisioning and significantly higher costs (~$200/month for port fees alone, plus data transfer). The client needed deployment within 2 weeks.  |
| **Public Bastion Host** | Violates the zero-public-internet requirement. Even with strict security groups, a public IP creates an attack surface. |
| **Session Manager** | Requires instances to have outbound internet access or SSM VPC endpoints. While we use SSM endpoints for management, the client wanted direct SSH access for Jupyter notebooks and real-time development. |

**Why Site-to-Site VPN Won:**

1. **Direct Tunnel** — The IPSec tunnel connects directly from the client's on-premises VPN gateway to the AWS VPN Gateway.  No data touches AWS-managed VPN infrastructure.

2. **Encryption** — Uses IKEv2 with AES-256-GCM encryption, meeting the client's cryptographic requirements.

3. **Speed of Deployment** — Can be configured and operational within hours, not months.

4. **Cost Effective** — ~$36/month for the VPN connection, versus $200+/month for Direct Connect.

5. **Redundancy** — AWS automatically provisions two tunnels to different Availability Zones for high availability.

---

### Why No Internet Access?

**The Decision:** The VPC has no Internet Gateway, no NAT Gateway, and no public subnets.  All AWS service access occurs through VPC Endpoints.

**The Trade-off:**

Eliminating internet access means instances cannot:
- Pull packages from PyPI, npm, or system repositories
- Access external APIs (HuggingFace Hub, OpenAI, etc.)
- Send outbound notifications or webhooks

**How We Solved This:**

1. **Pre-Baked AMIs** — We use AWS Deep Learning AMIs that come pre-installed with PyTorch, TensorFlow, transformers, CUDA drivers, and common ML libraries.  No package installation required at runtime.

2. **S3 for External Models** — Models from HuggingFace Hub are downloaded once by the operations team (from an internet-connected machine) and uploaded to the private S3 bucket.  Training instances access models from S3.

3. **VPC Endpoints** — We deployed endpoints for every AWS service the instances need: 
   - `com.amazonaws.ap-northeast-1.s3` — Model and data storage
   - `com.amazonaws.ap-northeast-1.secretsmanager` — API keys and credentials
   - `com.amazonaws.ap-northeast-1.logs` — CloudWatch logging
   - `com.amazonaws.ap-northeast-1.ssm` — Systems Manager for patching
   - `com.amazonaws.ap-northeast-1.sts` — IAM role assumption
   - `com.amazonaws.ap-northeast-1.kms` — Encryption operations

4. **Secrets Manager for External Credentials** — When the application needs to call external APIs (like OpenAI), the API keys are stored in Secrets Manager.  The operations team can update these keys without accessing the instances.

**Why This Matters:**

This architecture eliminates an entire category of attacks.  Without internet access: 
- Compromised instances cannot exfiltrate data to external servers
- Attackers cannot download additional tools or malware
- There's no route for command-and-control communications
- Supply chain attacks via package managers are impossible

---

### Why These GPU Instances?

**The Decision:** p3.2xlarge for training, g4dn.xlarge for inference. 

**Training Instance:  p3.2xlarge**

We selected the p3.2xlarge for training workloads after analyzing the client's model requirements: 

- **Model Size:** The client's LLM fine-tuning involves models with 7-13 billion parameters
- **VRAM Requirement:** These models require 14-16GB of GPU memory during training with mixed precision
- **The V100 Advantage:** NVIDIA V100 GPUs provide 16GB HBM2 memory with 900 GB/s bandwidth, essential for large batch sizes

**Why not p4d or p5 instances?**

The p4d. 24xlarge (A100 GPUs) would provide faster training, but at ~$32/hour versus ~$3/hour for p3.2xlarge. The client's training jobs run 2-4 hours daily.  The 10x cost difference wasn't justified for their workload.  We can always scale horizontally if training time becomes a bottleneck.

**Inference Instance: g4dn.xlarge**

For inference, we optimized for cost-efficiency rather than raw performance:

- **Latency Requirement:** < 500ms per inference request
- **Throughput:** ~100 requests per minute during peak hours
- **The T4 Advantage:** NVIDIA T4 GPUs are optimized for inference, with 16GB memory and excellent power efficiency

The g4dn. xlarge provides the required performance at ~$0.52/hour—over 80% cheaper than using p3 instances for inference.

**Auto Scaling Configuration:**

```hcl
# Training:  Scales to zero when idle
min_size         = 0
max_size         = 4
desired_capacity = 0  # Started manually when training is needed

# Inference: Always-on with scaling
min_size         = 1
max_size         = 4
desired_capacity = 1
```

---

### Why Customer-Managed KMS Keys? 

**The Decision:** All encryption uses AWS KMS Customer-Managed Keys (CMKs) with automatic annual rotation, rather than AWS-managed keys.

**The Difference:**

| Aspect | AWS-Managed Keys | Customer-Managed Keys |
|--------|-----------------|----------------------|
| **Key Policy Control** | AWS controls the key policy | Customer has full control |
| **Deletion** | Cannot be deleted | Can be scheduled for deletion |
| **Rotation** | Automatic (not configurable) | Configurable (we set annual) |
| **Audit** | Limited visibility | Full CloudTrail logging |
| **Cross-Account** | Not shareable | Can be shared via key policy |
| **Cost** | Free | $1/month per key |

**Why This Matters for Healthcare:**

1. **Incident Response** — If a breach is detected, the security team can immediately disable the KMS key, rendering all encrypted data unreadable.  With AWS-managed keys, this isn't possible.

2. **Audit Requirements** — Compliance auditors can review key policies and usage logs to verify that only authorized services and roles can decrypt PHI.

3. **Key Rotation Evidence** — The automatic rotation creates audit evidence showing that encryption keys are regularly rotated—a common compliance requirement.

4. **Future Flexibility** — If the client ever needs to share encrypted data with a partner organization, customer-managed keys can be shared across accounts.  AWS-managed keys cannot. 

---

### Why PostgreSQL Over DynamoDB?

**The Decision:** Amazon RDS PostgreSQL for metadata and audit storage, rather than DynamoDB. 

**The Client's Data Model:**

The ML pipeline generates structured metadata: 
- Training run records (hyperparameters, metrics, timestamps)
- Model version history with lineage tracking
- Inference logs with request/response pairs
- Audit records with user actions and access patterns

**Why PostgreSQL Won:**

1. **Complex Queries** — Compliance audits require complex queries:  "Show all access to patient data by user X between dates Y and Z, grouped by data type." PostgreSQL's SQL capabilities make these queries straightforward.  DynamoDB would require multiple queries and client-side joins.

2. **Referential Integrity** — The audit schema requires foreign keys between tables (users → actions → resources). PostgreSQL enforces these relationships at the database level. 

3. **JSON Support** — PostgreSQL's JSONB type gives us the flexibility of document storage for variable metadata while maintaining relational capabilities for structured data.

4. **Familiar Tooling** — The client's team has extensive PostgreSQL experience.  DynamoDB's learning curve would have added project risk.

5. **Point-in-Time Recovery** — RDS provides automated backups with point-in-time recovery—essential for compliance.  Reconstructing state from DynamoDB streams is more complex.

---

## Infrastructure Components

### Network Layer

The network foundation isolates all resources from the public internet while enabling secure internal communication and AWS service access.

**VPC Configuration:**
- **CIDR Block:** 10.0.0.0/16 (65,536 IP addresses)
- **Region:** ap-northeast-1 (Tokyo)
- **Availability Zones:** ap-northeast-1a, ap-northeast-1c (two AZs for redundancy)

**Subnet Design:**
- **Private ML Subnets (10.0.1.0/24, 10.0.2.0/24):** Host all compute instances.  No route to internet gateway. 
- **Database Subnets (10.0.10.0/24, 10.0.11.0/24):** Isolated subnets for RDS.  Only accessible from ML subnets. 

**VPC Endpoints:**

We deployed Interface Endpoints and Gateway Endpoints to enable AWS service access without internet connectivity: 

```
Gateway Endpoints (Free):
  └── S3: Enables direct access to S3 buckets

Interface Endpoints ($0.01/hour each + data processing):
  ├── Secrets Manager: Credential retrieval
  ├── SSM: Systems Manager for patching
  ├── SSM Messages: Session Manager functionality  
  ├── CloudWatch Logs:  Log ingestion
  ├── STS: IAM role credential refresh
  ├── KMS:  Encryption/decryption operations
  └── EC2 Messages: EC2 instance communication
```

### Compute Layer

**Training Cluster:**
- **Instance Type:** p3.2xlarge
- **GPU:** 1x NVIDIA Tesla V100 (16GB HBM2)
- **vCPUs:** 8
- **Memory:** 61 GB
- **Storage:** 100 GB gp3 EBS (encrypted)
- **AMI:** AWS Deep Learning AMI (Ubuntu 20.04)
- **Scaling:** 0-4 instances, defaults to 0

**Inference Cluster:**
- **Instance Type:** g4dn.xlarge
- **GPU:** 1x NVIDIA T4 (16GB GDDR6)
- **vCPUs:** 4
- **Memory:** 16 GB
- **Storage:** 50 GB gp3 EBS (encrypted)
- **AMI:** AWS Deep Learning AMI (Ubuntu 20.04)
- **Scaling:** 1-4 instances, defaults to 1

### Storage Layer

**S3 Buckets:**
- **Models Bucket:** Stores trained model artifacts, versioning enabled
- **Data Bucket:** Training datasets and preprocessed features
- **Both buckets:** KMS encryption, no public access, VPC endpoint access only

**RDS PostgreSQL:**
- **Instance Class:** db.r5.large (2 vCPUs, 16 GB RAM)
- **Storage:** 100 GB gp3, encrypted with CMK
- **Multi-AZ:** Enabled for production (configurable)
- **Backup Retention:** 35 days with point-in-time recovery
- **Maintenance Window:** Sundays 03:00-04:00 JST

---

## Security Model

### Defense in Depth

Our security implementation follows the defense-in-depth principle, with multiple overlapping security controls:

**Layer 1: Network Perimeter**
- No internet gateway or NAT gateway
- Site-to-Site VPN as only entry point
- VPN uses IKEv2 with AES-256-GCM encryption
- Customer gateway IP allowlisted

**Layer 2: Network Segmentation**
- Security groups restrict traffic to minimum required
- ML instances can only reach:  RDS, S3 endpoint, Secrets Manager endpoint
- RDS only accepts connections from ML security group
- No instance-to-instance communication except where explicitly required

**Layer 3: Identity and Access**
- EC2 instances use IAM roles (no stored credentials)
- Roles follow least-privilege principle
- Training role:  S3 read/write, Secrets Manager read
- Inference role:  S3 read-only, Secrets Manager read

**Layer 4: Data Protection**
- All storage encrypted with customer-managed KMS keys
- TLS 1.2+ for all data in transit
- Secrets Manager for API keys and database credentials
- No secrets in code, environment variables, or instance metadata

**Layer 5: Monitoring and Audit**
- VPC Flow Logs capture all network traffic
- CloudTrail logs all API calls
- CloudWatch Logs aggregate application logs
- 7-year retention on all log groups
- Encryption on all log data

### Security Group Rules

**ML Instances (Training & Inference):**
```
Inbound:
  - SSH (22) from Japan office CIDR via VPN
  - API (8080) from Japan office CIDR via VPN (inference only)

Outbound: 
  - HTTPS (443) to VPC Endpoint security group
  - PostgreSQL (5432) to RDS security group
```

**RDS Database:**
```
Inbound:
  - PostgreSQL (5432) from ML security group only

Outbound: 
  - None required
```

**VPC Endpoints:**
```
Inbound: 
  - HTTPS (443) from ML security group

Outbound: 
  - None required (AWS managed)
```

---

## Getting Started

### Prerequisites

Before deploying, ensure you have:

1. **AWS Account** with permissions for:  VPC, EC2, RDS, S3, KMS, IAM, Secrets Manager, CloudWatch
2. **Terraform** version 1.5 or higher installed
3. **AWS CLI** configured with appropriate credentials
4. **Japan Office Network Information:**
   - Static public IP address for VPN connection
   - Internal CIDR block for routing (e.g., 192.168.1.0/24)
   - VPN-capable gateway device (Cisco, Juniper, Palo Alto, etc.)

### Step 1: Clone and Configure

```bash
# Clone the repository
git clone https://github.com/DevOps-Joseph/MLOps. git
cd MLOps

# Create your variables file from the template
cp terraform. tfvars.example terraform.tfvars
```

### Step 2: Configure Variables

Edit `terraform.tfvars` with your specific values: 

```hcl
# Project Identification
project_name = "pharmacy-ml"
environment  = "production"

# VPN Configuration (REQUIRED)
customer_gateway_ip = "203.0.113.12"    # Your office public IP
allowed_ssh_cidr    = "192.168.1.0/24"  # Your office internal network

# Scaling Configuration (Optional)
training_min_size   = 0
training_max_size   = 4
inference_min_size  = 1
inference_max_size  = 4

# Database Configuration (Optional)
db_instance_class   = "db.r5.large"
db_multi_az         = true
```

### Step 3: Initialize and Deploy

```bash
# Initialize Terraform (downloads providers and modules)
terraform init

# Review the execution plan
terraform plan -out=tfplan

# Apply the configuration
terraform apply tfplan
```

Deployment takes approximately 15-20 minutes. The longest-running resources are the RDS instance and VPN connection.

### Step 4: Configure Office VPN Gateway

After deployment, retrieve the VPN configuration:

```bash
# Get VPN configuration (contains sensitive tunnel information)
terraform output -raw vpn_configuration > vpn-config.xml
```

Use this configuration to set up your office VPN gateway.  The specific steps depend on your gateway vendor (Cisco, Juniper, Palo Alto, etc.).

---

## Operational Procedures

### Starting a Training Session

Training instances default to zero.  To start a training session: 

```bash
# Scale up training cluster
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name $(terraform output -raw training_asg_name) \
  --desired-capacity 1

# Wait for instance to be ready
aws ec2 wait instance-running \
  --filters "Name=tag:Role,Values=training"

# Get the private IP
TRAINING_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Role,Values=training" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0]. Instances[0]. PrivateIpAddress' \
  --output text)

echo "Training instance available at: $TRAINING_IP"
```

Connect via SSH through the VPN: 

```bash
ssh -i your-key.pem ubuntu@$TRAINING_IP
```

### Shutting Down Training

After training completes, scale back to zero to stop costs:

```bash
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name $(terraform output -raw training_asg_name) \
  --desired-capacity 0
```

### Updating Secrets

To update API keys or credentials: 

```bash
# Update HuggingFace token
aws secretsmanager put-secret-value \
  --secret-id "pharmacy-ml/api-keys" \
  --secret-string '{"huggingface_token":"hf_xxxxx","openai_key":"sk-xxxxx"}'
```

### Deploying Model Updates

1. Train and export model on training instance
2. Upload to S3 models bucket
3. Inference instances automatically detect new models (configured via application)

```bash
# Example: Upload model to S3
aws s3 cp ./model-v2/ s3://pharmacy-ml-models/production/v2/ --recursive
```

---

## Monitoring & Compliance

### CloudWatch Dashboard

Access the dashboard at:  `https://ap-northeast-1.console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1#dashboards:name=pharmacy-ml`

Key metrics displayed:
- GPU utilization (training and inference)
- Inference API latency (p50, p95, p99)
- Request throughput
- Error rates
- Active instance count

### Alarms

The following alarms are configured:

| Alarm | Threshold | Action |
|-------|-----------|--------|
| High Inference Latency | p99 > 1000ms for 5 min | SNS notification |
| Inference Errors | > 10 errors/min | SNS notification |
| Training Instance Down | Instance health check failed | Auto-replace instance |
| Database CPU High | > 80% for 15 min | SNS notification |
| Disk Space Low | < 20% free | SNS notification |

### Compliance Logging

All logs are stored with 7-year retention:

- **VPC Flow Logs:** Network traffic analysis
- **CloudTrail:** API activity audit
- **Application Logs:** ML pipeline activity
- **RDS Logs:** Database queries and connections

Access audit logs for compliance reporting: 

```bash
# Export logs for audit period
aws logs filter-log-events \
  --log-group-name "/aws/vpc/flowlogs/pharmacy-ml" \
  --start-time $(date -d "2025-01-01" +%s)000 \
  --end-time $(date -d "2025-12-31" +%s)000 \
  --output json > audit-2025.json
```

---

## Cost Analysis

### Monthly Cost Breakdown

| Component | Configuration | Monthly Cost |
|-----------|---------------|--------------|
| VPN Connection | 2 tunnels | $36 |
| Inference Instance | 1x g4dn. xlarge (24/7) | $380 |
| Training Instance | 1x p3.2xlarge (4 hrs/day) | $370 |
| RDS PostgreSQL | db.r5.large Multi-AZ | $350 |
| S3 Storage | ~500 GB | $12 |
| VPC Endpoints | 7 endpoints | $50 |
| CloudWatch Logs | ~50 GB/month | $25 |
| KMS Keys | 4 keys | $4 |
| **Total** | | **~$1,227/month** |

### Cost Optimization Applied

1. **Training Scale-to-Zero:** Training instances only run during active training.  At $3/hour, running 4 hours daily saves ~$2,000/month versus 24/7 operation.

2. **Right-Sized Inference:** g4dn.xlarge instead of p3.2xlarge for inference saves ~$1,800/month with acceptable latency.

3. **S3 Lifecycle Policies:** Old model versions automatically transition to Glacier after 90 days, reducing storage costs by 80%.

4. **Reserved Instances (Recommendation):** For steady-state inference, a 1-year reserved instance commitment would save ~40% (~$150/month).

---

## Troubleshooting Guide

### VPN Connection Issues

**Symptom:** Cannot SSH to instances after Terraform apply

**Diagnostic Steps:**

1. Verify VPN tunnel status:
   ```bash
   aws ec2 describe-vpn-connections \
     --vpn-connection-ids $(terraform output -raw vpn_connection_id) \
     --query 'VpnConnections[0]. VgwTelemetry'
   ```

2. Check that your office gateway shows tunnel as UP

3. Verify routing table includes VPC CIDR (10.0.0.0/16)

4. Confirm firewall allows UDP 500, UDP 4500, and ESP protocol

**Common Fixes:**

- Restart VPN tunnel from office gateway
- Verify customer gateway IP matches your actual public IP
- Check that BGP ASN is configured correctly (if using BGP)

### Instance Access Issues

**Symptom:** VPN is up but cannot SSH to instances

**Diagnostic Steps:**

1. Verify instance is running:
   ```bash
   aws ec2 describe-instance-status \
     --instance-ids $(terraform output -raw training_instance_ids)
   ```

2. Check security group allows SSH from your CIDR:
   ```bash
   aws ec2 describe-security-groups \
     --group-ids $(terraform output -raw ml_security_group_id)
   ```

3. Verify your SSH key is correct

**Common Fixes:**

- Scale up ASG if no instances running
- Verify `allowed_ssh_cidr` in terraform.tfvars matches your office network
- Check instance system logs for boot errors

### Inference API Issues

**Symptom:** API requests timing out or returning errors

**Diagnostic Steps:**

1. Check inference instances are healthy:
   ```bash
   aws elbv2 describe-target-health \
     --target-group-arn $(terraform output -raw inference_target_group_arn)
   ```

2. SSH to instance and check application logs: 
   ```bash
   ssh ubuntu@<instance-ip>
   sudo journalctl -u inference-api -f
   ```

3. Verify model files exist in S3 and are accessible

**Common Fixes:**

- Restart inference API service:  `sudo systemctl restart inference-api`
- Check Secrets Manager for valid API keys
- Verify model path in application configuration

---

## Author

Built by **JoseScript7**

[![GitHub](https://img.shields.io/badge/GitHub-JoseScript7-181717?style=flat&logo=github)](https://github.com/JoseScript7)


*Questions or feedback? Open an issue or reach out on GitHub.*
