# Property Tokenization Platform - AWS Infrastructure

Complete AWS infrastructure deployment using Terraform and ECS Fargate for the blockchain-based property tokenization platform (TCC project).

[![Terraform](https://img.shields.io/badge/Terraform-1.5+-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-ECS_Fargate-FF9900?logo=amazon-aws)](https://aws.amazon.com/ecs/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 🏗️ Architecture Overview

This infrastructure deploys a complete microservices architecture for property tokenization using ERC-3643 security tokens on a private Hyperledger Besu blockchain.

### Components Deployed

- **7 Application Services**: Frontend, BFF Gateway, Orchestrator, Offchain API, Queue Worker, RabbitMQ, Blockchain (4 Besu validators)
- **Multi-AZ Deployment**: Services distributed across us-east-1a and us-east-1b for high availability
- **Managed Services**: RDS PostgreSQL, EFS storage, Application Load Balancers, CloudWatch Logs
- **Security**: AWS Secrets Manager, VPC isolation, Security Groups, IAM roles

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    AWS Cloud (us-east-1)                │
├──────────────────────┬──────────────────────────────────┤
│   us-east-1a         │       us-east-1b                 │
├──────────────────────┼──────────────────────────────────┤
│ • Besu Validator 1   │ • Besu Validator 3               │
│ • Besu Validator 2   │ • Besu Validator 4               │
│ • BFF Gateway (1/2)  │ • BFF Gateway (2/2)              │
│ • Orchestrator (1/2) │ • Orchestrator (2/2)             │
│ • Frontend (1/2)     │ • Frontend (2/2)                 │
│ • Offchain API (1/2) │ • Offchain API (2/2)             │
└──────────────────────┴──────────────────────────────────┘
         │                        │
         └────────┬───────────────┘
                  │
         ┌────────▼────────┐
         │  Load Balancer  │ ◄─── Internet
         └─────────────────┘
```

---

## 💰 Cost Estimate

**3-Day Demo**: ~$26 USD

| Resource | Daily Cost | 3-Day Total |
|----------|-----------|-------------|
| ECS Fargate Tasks (small) | ~$3 | ~$9 |
| ECS Fargate Tasks (medium) | ~$7 | ~$21 |
| RDS db.t4g.micro | Free Tier | $0 |
| Application Load Balancers (2) | ~$1.08 | ~$3.24 |
| NAT Gateway (1) | ~$1.08 | ~$3.24 |
| EFS Storage | ~$0.01 | ~$0.03 |
| Data Transfer | ~$0.50 | ~$1.50 |

**⚠️ IMPORTANT**: Run `./deploy-scripts/99-destroy-all.sh` when done to avoid ongoing charges!

---

## 🚀 Quick Start

### Prerequisites

- **AWS Account** with ~$100 available credits
- **AWS CLI** v2.x installed and configured
- **Terraform** v1.5+ installed
- **Docker** v20+ installed
- **jq** installed (for JSON processing)

### Installation

```bash
# 1. Clone this repository
git clone https://github.com/TCC-Blockchain-Registry/property-tcc-infrastructure.git
cd property-tcc-infrastructure

# 2. Verify prerequisites
./deploy-scripts/01-setup-aws-cli.sh

# 3. Deploy infrastructure (~5-7 min)
./deploy-scripts/02-terraform-apply.sh

# 4. Build and push Docker images (~10-15 min)
# NOTE: Requires application source code
./deploy-scripts/03-build-push-images.sh

# 5. Deploy Besu blockchain (~3-5 min)
./deploy-scripts/04-deploy-besu.sh

# 6. Deploy smart contracts (interactive)
./deploy-scripts/05-deploy-contracts.sh

# 7. Deploy application services (~5-10 min)
./deploy-scripts/06-deploy-services.sh

# 8. Verify deployment
./deploy-scripts/07-health-check.sh

# 9. Get access URLs
./deploy-scripts/08-show-urls.sh
```

**Total deployment time**: ~30-45 minutes

---

## 📂 Repository Structure

```
infrastructure/
├── README.md                    # This file
├── .gitignore                   # Git ignore patterns
├── terraform-aws/               # Terraform configuration
│   ├── main.tf                  # Provider and backend
│   ├── variables.tf             # Variable definitions
│   ├── terraform.tfvars.example # Example variable values
│   ├── vpc.tf                   # Network infrastructure
│   ├── security-groups.tf       # Security groups
│   ├── iam.tf                   # IAM roles and policies
│   ├── ecr.tf                   # Container registries
│   ├── rds.tf                   # PostgreSQL database
│   ├── efs.tf                   # File system for Besu
│   ├── ecs-cluster.tf           # ECS cluster
│   ├── ecs-services.tf          # Service definitions
│   ├── alb.tf                   # Load balancers
│   ├── cloudwatch.tf            # Logging
│   ├── secrets.tf               # Secrets Manager
│   └── outputs.tf               # Output values
├── besu-aws/                    # Besu configuration
│   ├── Dockerfile               # Multi-validator image
│   ├── entrypoint.sh            # Dynamic config selector
│   ├── genesis.json             # QBFT genesis
│   ├── static-nodes.json.template
│   ├── config/
│   │   ├── validator-1/
│   │   ├── validator-2/
│   │   ├── validator-3/
│   │   └── validator-4/
│   └── README.md
└── deploy-scripts/              # Deployment automation
    ├── 01-setup-aws-cli.sh      # Prerequisites check
    ├── 02-terraform-apply.sh    # Infrastructure deployment
    ├── 03-build-push-images.sh  # Docker build/push
    ├── 04-deploy-besu.sh        # Blockchain deployment
    ├── 05-deploy-contracts.sh   # Smart contract deployment
    ├── 06-deploy-services.sh    # App services deployment
    ├── 07-health-check.sh       # System health check
    ├── 08-show-urls.sh          # Display access info
    └── 99-destroy-all.sh        # Complete cleanup
```

---

## ⚙️ Configuration

### 1. Copy and customize Terraform variables

```bash
cd terraform-aws
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings
```

### 2. Key configuration options

```hcl
# Project settings
project_name       = "property-tcc"
environment        = "demo"
aws_region         = "us-east-1"
availability_zones = ["us-east-1a", "us-east-1b"]

# Task sizes (adjust for cost optimization)
frontend_cpu    = 256   # 0.25 vCPU
frontend_memory = 512   # 512 MB

bff_cpu         = 256
bff_memory      = 512

orchestrator_cpu    = 512  # 0.5 vCPU
orchestrator_memory = 1024 # 1 GB

# Desired counts (clustering)
frontend_desired_count      = 2  # 2 tasks for HA
bff_desired_count          = 2  # 2 tasks (clustered)
orchestrator_desired_count = 2  # 2 tasks (clustered)
```

---

## 🔐 Security

### Secrets Management

All sensitive data is stored in AWS Secrets Manager:

- **JWT Secret**: Auto-generated 32-character string
- **Database Password**: Auto-generated or from tfvars
- **RabbitMQ Password**: Auto-generated
- **Besu Private Keys**: ⚠️ **PLACEHOLDER - UPDATE MANUALLY**

**Update Besu keys before production:**

```bash
aws secretsmanager update-secret \
  --secret-id property-tcc/besu/admin-private-key \
  --secret-string "0xYOUR_ACTUAL_PRIVATE_KEY"
```

### Network Security

- **Public Subnets**: Only ALBs and NAT Gateway
- **Private Subnets**: All application containers
- **Security Groups**: Least-privilege access
- **RDS**: Not publicly accessible
- **Besu**: RPC not exposed to internet

---

## 🔍 Monitoring & Debugging

### View CloudWatch Logs

```bash
# Frontend logs
aws logs tail /ecs/property-tcc-frontend --follow

# Orchestrator logs
aws logs tail /ecs/property-tcc-orchestrator --follow

# Besu validator logs
aws logs tail /ecs/property-tcc-besu-validator-1 --follow
```

### Check Service Status

```bash
# List all services
aws ecs list-services --cluster property-tcc-cluster

# Describe specific service
aws ecs describe-services \
  --cluster property-tcc-cluster \
  --services property-tcc-orchestrator
```

### Connect to Running Container

```bash
# Get task ARN
TASK=$(aws ecs list-tasks \
  --cluster property-tcc-cluster \
  --service property-tcc-orchestrator \
  --query 'taskArns[0]' \
  --output text)

# Connect
aws ecs execute-command \
  --cluster property-tcc-cluster \
  --task $TASK \
  --container orchestrator \
  --interactive \
  --command /bin/bash
```

---

## 🧪 Testing

### Health Check All Services

```bash
./deploy-scripts/07-health-check.sh
```

This checks:
- ✓ External HTTP endpoints (Frontend, BFF, Orchestrator)
- ✓ ECS service status (all tasks running)
- ✓ Target group health
- ✓ RDS database availability
- ✓ Recent CloudWatch logs

### Manual Testing

```bash
# Get ALB URL
ALB_URL=$(cd terraform-aws && terraform output -raw alb_url)

# Test frontend
curl $ALB_URL

# Test BFF API
curl $ALB_URL/api/health

# Test orchestrator
curl $ALB_URL/actuator/health
```

---

## 🧹 Cleanup

### Complete Infrastructure Deletion

```bash
./deploy-scripts/99-destroy-all.sh
```

**⚠️ WARNING**: This permanently deletes:
- All ECS services and tasks
- RDS database (**DATA LOSS**)
- EFS file system (**BLOCKCHAIN DATA LOSS**)
- Load balancers
- VPC and networking
- ECR repositories
- CloudWatch logs
- Secrets Manager secrets

**Duration**: ~5-10 minutes

### Verify Cleanup

After running destroy script, check AWS Console:
- ECS: No clusters
- RDS: No databases
- VPC: No VPCs tagged "property-tcc"
- ECR: No repositories

---

## 🐛 Troubleshooting

### Services Not Starting

**Check logs:**
```bash
aws logs tail /ecs/property-tcc-<service-name> --follow
```

**Common issues:**
- Missing environment variables
- Secrets not accessible
- Database not ready
- Besu validators not in consensus

### Database Connection Failed

**Check RDS status:**
```bash
aws rds describe-db-instances \
  --db-instance-identifier property-tcc-postgres
```

**Verify security groups:**
```bash
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=*property-tcc*"
```

### Besu Validators Not Forming Consensus

**Requirements:**
- At least 3 of 4 validators must be running
- Static nodes must be configured correctly
- Security groups must allow TCP/UDP 30303-30306

**Check validator connectivity:**
```bash
# From inside VPC (via ECS Exec)
curl http://property-tcc-besu-validator-1.property-tcc.local:8545 \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### High AWS Costs

**Check current spending:**
```bash
aws ce get-cost-and-usage \
  --time-period Start=2025-11-01,End=2025-11-30 \
  --granularity DAILY \
  --metrics BlendedCost
```

**Immediate action:**
```bash
./deploy-scripts/99-destroy-all.sh
```

---

## 📚 Documentation

- **Terraform Documentation**: [terraform.io/docs](https://www.terraform.io/docs)
- **AWS ECS Best Practices**: [docs.aws.amazon.com/ecs](https://docs.aws.amazon.com/ecs/)
- **Hyperledger Besu**: [besu.hyperledger.org](https://besu.hyperledger.org/)
- **Besu AWS Configuration**: See `besu-aws/README.md`

---

## 🤝 Contributing

This infrastructure is part of a TCC (undergraduate thesis) project. Contributions are welcome for:

- Cost optimization improvements
- Security enhancements
- Deployment automation
- Monitoring improvements

---

## 📄 License

MIT License - see LICENSE file for details

---

## 👥 Authors

TCC Blockchain Registry Team
- **Project**: Property Tokenization Platform
- **Institution**: [Your University]
- **Year**: 2025

---

## 🙏 Acknowledgments

- Hyperledger Besu community
- AWS ECS documentation
- Terraform AWS provider maintainers
- ERC-3643 (T-REX) security token standard

---

## 📞 Support

For issues or questions:
1. Check the [Troubleshooting](#-troubleshooting) section
2. Review CloudWatch logs
3. Open an issue on GitHub
4. Contact the TCC team

---

**Built with ❤️ for decentralized property tokenization**
