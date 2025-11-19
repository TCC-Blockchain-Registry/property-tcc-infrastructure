# Property TCC - AWS Infrastructure

Infrastructure as Code (IaC) for deploying the Property TCC real estate tokenization system on AWS.

## Prerequisites

Install required tools:

```bash
brew install hyperledger/besu/besu terraform jq
pip3 install rlp
```

Also required:
- [AWS CLI](https://aws.amazon.com/cli/) - configured with credentials
- [Docker](https://www.docker.com/products/docker-desktop)

## Quick Start

```bash
# 1. Generate Besu network configuration
./scripts/01-generate-network.sh

# 2. Build and push Docker images to ECR
./scripts/02-build-push-images.sh

# 3. Upload Besu keys to EFS
./scripts/03-upload-keys.sh

# 4. Deploy Besu validators
./scripts/04-deploy-besu.sh

# 5. Deploy smart contracts
./scripts/05-deploy-contracts.sh

# 6. Deploy application services
./scripts/06-deploy-services.sh

# 7. Verify deployment
./scripts/07-health-check.sh

# 8. Show access URLs
./scripts/08-show-urls.sh
```

**Note:** Before running the scripts, deploy infrastructure with Terraform:
```bash
cd terraform-aws
terraform init
terraform apply
```

## Project Structure

```
property-tcc-infrastructure/
├── scripts/                    # Deployment automation
│   ├── lib/                    # Shared functions
│   │   ├── colors.sh           # Output formatting
│   │   └── ecs-helpers.sh      # ECS utilities
│   ├── 01-generate-network.sh  # Generate Besu keys
│   ├── 02-build-push-images.sh # Build/push Docker
│   ├── 03-upload-keys.sh       # Upload to EFS
│   ├── 04-deploy-besu.sh       # Deploy validators
│   ├── 05-deploy-contracts.sh  # Deploy contracts
│   ├── 06-deploy-services.sh   # Deploy services
│   ├── 07-health-check.sh      # Health checks
│   └── 08-show-urls.sh         # Show URLs
│
├── terraform-aws/              # Terraform configuration
│   ├── main.tf                 # Provider config
│   ├── variables.tf            # Input variables
│   ├── vpc.tf                  # VPC, subnets, NAT
│   ├── ecs-cluster.tf          # ECS cluster
│   ├── ecs-services.tf         # Tasks and services
│   ├── efs.tf                  # Persistent storage
│   ├── rds.tf                  # PostgreSQL
│   ├── alb.tf                  # Load balancer
│   ├── security-groups.tf      # Security groups
│   ├── secrets.tf              # Secrets Manager
│   └── outputs.tf              # Output values
│
└── besu-aws/                   # Besu AWS configuration
    ├── config/                 # Per-validator configs
    ├── genesis.json            # Genesis block
    ├── static-nodes.json.template
    ├── Dockerfile              # Container image
    └── entrypoint.sh           # Startup script
```

## Architecture

```
AWS Cloud (us-east-1)
┌─────────────────────────────────────────────────┐
│                                                  │
│  ┌──────────┐    ┌─────────┐   ┌──────────────┐ │
│  │ Frontend │───▶│   BFF   │──▶│ Orchestrator │ │
│  │  (ECS)   │    │  (ECS)  │   │    (ECS)     │ │
│  └──────────┘    └─────────┘   └──────┬───────┘ │
│       ▲                │              │         │
│       │                │              ▼         │
│   ┌───┴────┐    ┌──────▼───┐    ┌──────────┐   │
│   │  ALB   │    │ Offchain │    │   RDS    │   │
│   └────────┘    │   API    │    │(Postgres)│   │
│                 │  (ECS)   │    └──────────┘   │
│                 └────┬─────┘                    │
│                      │                          │
│              ┌───────▼────────┐                 │
│              │  Besu Network  │                 │
│              │  4 Validators  │                 │
│              │     (ECS)      │                 │
│              └────────────────┘                 │
│                                                  │
└──────────────────────────────────────────────────┘
```

## Troubleshooting

### Check logs

```bash
# Besu validator logs
aws logs tail /ecs/property-tcc/besu-validator-1 --follow

# Application logs
aws logs tail /ecs/property-tcc/orchestrator --follow
```

### Besu validators stuck at block 0

1. Verify keys uploaded to EFS:
```bash
aws ecs execute-command --cluster property-tcc \
  --task <task-id> --container besu-validator-1 \
  --command "ls -la /opt/besu/data/key"
```

2. Re-upload if missing: `./scripts/03-upload-keys.sh`

### 0 peers connected

Check Security Group allows TCP/UDP 30303:
```bash
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=property-tcc-besu-sg" \
  --query 'SecurityGroups[*].IpPermissions'
```

### Test RPC

```bash
curl http://<ALB_DNS>/rpc/validator-1 \
  -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

## Security

**Never commit:**
- `scripts/generated/` - contains private keys
- `terraform-aws/terraform.tfvars` - sensitive configuration
- `terraform-aws/.terraform/` - Terraform cache

These are already in `.gitignore`.

## Cleanup

```bash
cd terraform-aws
terraform destroy
```
