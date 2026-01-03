# Secure ML/LLM Pipeline for Japan-Based Pharmacy Client

This Terraform configuration deploys a secure, end-to-end ML/LLM pipeline on AWS specifically designed for a Japan-based pharmacy client handling sensitive healthcare data. The architecture ensures complete network isolation through VPN connectivity, comprehensive encryption, and compliance with healthcare data regulations.

## Architecture Overview

### Security Features
- **Site-to-Site VPN**: Encrypted connection between Japan office and AWS VPC
- **No Public Internet Access**: All resources in private subnets, accessed only via VPN
- **End-to-End Encryption**: Data encrypted in transit and at rest using AWS KMS
- **Secrets Management**: AWS Secrets Manager for credentials and API keys
- **Network Isolation**: Security groups restrict access to necessary communications only
- **Compliance Ready**: 7-year data retention and comprehensive audit logging

### Infrastructure Components

#### Network Layer
- **VPC**: Isolated virtual network in Tokyo region (ap-northeast-1)
- **Private Subnets**: GPU-enabled ML instances with no internet access
- **Database Subnets**: Isolated PostgreSQL database layer
- **VPC Endpoints**: Secure access to AWS services without internet routing
- **Site-to-Site VPN**: Encrypted tunnel to Japan office

#### Compute Layer
- **ML Training**: Auto Scaling Group with p3.2xlarge instances (NVIDIA V100)
- **ML Inference**: Auto Scaling Group with g4dn.xlarge instances (NVIDIA T4)
- **Deep Learning AMI**: Pre-configured with PyTorch, transformers, and ML libraries

#### Storage Layer
- **S3 Buckets**: Encrypted storage for models and training data
- **RDS PostgreSQL**: Encrypted database for metadata and results
- **KMS Encryption**: Customer-managed keys with automatic rotation

#### Security Layer
- **IAM Roles**: Least-privilege access for ML workloads
- **Security Groups**: Network access controls
- **Secrets Manager**: Encrypted credential storage
- **CloudWatch**: Comprehensive logging and monitoring

## Prerequisites

1. **AWS Account**: With appropriate permissions for VPC, EC2, RDS, S3, KMS, and IAM
2. **Terraform**: Version 1.5 or higher
3. **Japan Office Network**: Static public IP for VPN connection
4. **Network Planning**: Determine office CIDR blocks for VPN routing

## Quick Start

### 1. Clone and Configure

```bash
# Navigate to your infrastructure directory
cd /path/to/infrastructure

# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit with your specific values
nano terraform.tfvars
```

### 2. Required Variables

Update `terraform.tfvars` with your specific values:

```hcl
# VPN Configuration (CRITICAL - Must be updated)
customer_gateway_ip  = "YOUR_OFFICE_PUBLIC_IP"     # Japan office public IP
allowed_ssh_cidr     = "YOUR_OFFICE_CIDR"          # Internal office network

# Example:
customer_gateway_ip  = "203.0.113.12"
allowed_ssh_cidr     = "192.168.1.0/24"
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Deploy the infrastructure
terraform apply
```

### 4. Configure VPN Connection

After deployment, configure your Japan office VPN gateway using the provided configuration:

```bash
# Get VPN configuration (sensitive output)
terraform output vpn_connection_customer_gateway_configuration
```

## Post-Deployment Setup

### 1. Update Secrets

After deployment, update the placeholder secrets with real values:

```bash
# Get secret names
terraform output api_keys_secret_name
terraform output customer_config_secret_name

# Update via AWS Console or CLI
aws secretsmanager update-secret \
  --secret-id "pharmacy-ml/api/keys" \
  --secret-string '{"huggingface_token":"your_token","openai_api_key":"your_key"}'
```

### 2. Start ML Instances

```bash
# Scale up training instances when needed
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name $(terraform output -raw ml_training_asg_name) \
  --desired-capacity 1

# Inference instances start automatically
```

### 3. Access ML Pipeline

- **Training**: SSH to training instances via VPN for Jupyter notebooks
- **Inference**: API available at instance IP:8080 via VPN
- **Monitoring**: CloudWatch dashboard (check outputs for URL)

## Security Configuration

### Network Security
- All instances in private subnets
- No internet gateways or NAT gateways
- VPC endpoints for AWS service access
- Security groups with minimal required access

### Data Encryption
- KMS encryption for all storage (S3, RDS, EBS)
- Automatic key rotation enabled
- Secrets Manager for credential protection
- TLS encryption for all data in transit

### Access Control
- IAM roles with least-privilege principles
- SSH access only from Japan office via VPN
- API access restricted to customer network
- Comprehensive audit logging

## Monitoring and Compliance

### CloudWatch Integration
- **Dashboard**: Real-time metrics for ML pipeline
- **Alarms**: Security and operational alerts
- **Logs**: Centralized logging with encryption
- **Flow Logs**: VPC network monitoring

### Compliance Features
- **Data Retention**: 7-year retention for healthcare compliance
- **Audit Trails**: Complete CloudTrail integration
- **Encryption**: All data encrypted at rest and in transit
- **Network Isolation**: No public internet access

## Cost Management

### Optimized Instance Usage
- **Training**: Scale down to 0 when not in use
- **Inference**: Right-sized for production load
- **Storage**: Lifecycle policies for cost optimization

### Monitoring Costs
```bash
# Check current costs
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY --metrics BlendedCost
```

## Troubleshooting

### VPN Connection Issues
1. Verify customer gateway IP is correct
2. Check BGP ASN configuration
3. Ensure firewall allows IPsec traffic
4. Review VPN logs in CloudWatch

### ML Instance Access
1. Confirm VPN connection is established
2. Verify security group rules
3. Check instance status in EC2 console
4. Review user-data execution logs

### API Connectivity
1. Ensure inference instances are running
2. Verify security group allows port 8080
3. Check FastAPI service status via SSH
4. Review application logs

## Security Best Practices

### Regular Maintenance
- **Patch Management**: Keep AMIs and packages updated
- **Key Rotation**: Monitor KMS key rotation
- **Access Review**: Regular IAM permission audits
- **Security Scanning**: Monitor for vulnerabilities

### Incident Response
- **Alerts**: Configure SNS notifications
- **Logging**: Enable comprehensive audit trails
- **Backup**: Regular RDS snapshots and S3 versioning
- **Recovery**: Document disaster recovery procedures

## Support and Maintenance

### Scaling Operations
- **Training Workloads**: Adjust ASG size based on workload
- **Inference Load**: Monitor and scale inference instances
- **Storage Growth**: Plan for data volume increases

### Updates and Upgrades
- **Terraform**: Keep configuration updated
- **AMIs**: Regular Deep Learning AMI updates
- **Dependencies**: Update ML libraries and frameworks

For technical support, contact your infrastructure team with:
- Terraform output values
- CloudWatch logs and metrics
- Specific error messages
- Network configuration details