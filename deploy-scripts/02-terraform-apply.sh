#!/bin/bash

# Script 02: Apply Terraform Infrastructure
# This script initializes and applies the Terraform configuration

set -e

echo "=========================================="
echo "Terraform Infrastructure Deployment"
echo "=========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Change to terraform directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform-aws"

if [ ! -d "$TERRAFORM_DIR" ]; then
    echo -e "${RED}ERROR: Terraform directory not found: $TERRAFORM_DIR${NC}"
    exit 1
fi

cd "$TERRAFORM_DIR"

echo "Working directory: $(pwd)"
echo ""

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}WARNING: terraform.tfvars not found${NC}"
    echo "Creating terraform.tfvars from example..."

    cat > terraform.tfvars <<EOF
# Auto-generated terraform.tfvars
aws_region = "us-east-1"
project_name = "property-tcc"
environment = "demo"
availability_zones = ["us-east-1a", "us-east-1b"]

# Database
db_instance_class = "db.t4g.micro"
db_allocated_storage = 20

# Task sizes (cost-optimized)
frontend_cpu = 256
frontend_memory = 512
bff_cpu = 256
bff_memory = 512
orchestrator_cpu = 512
orchestrator_memory = 1024
offchain_cpu = 512
offchain_memory = 1024
worker_cpu = 256
worker_memory = 512
besu_cpu = 1024
besu_memory = 2048

# Desired counts
frontend_desired_count = 2
bff_desired_count = 2
orchestrator_desired_count = 2
offchain_desired_count = 2
worker_desired_count = 1
EOF
fi

# Initialize Terraform
echo -e "${GREEN}Step 1: Terraform Init${NC}"
terraform init

echo ""
echo -e "${GREEN}Step 2: Terraform Validate${NC}"
terraform validate

echo ""
echo -e "${GREEN}Step 3: Terraform Plan${NC}"
terraform plan -out=tfplan

echo ""
echo -e "${YELLOW}=========================================="
echo "Review the plan above"
echo "==========================================${NC}"
echo ""
read -p "Do you want to apply this plan? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled."
    rm -f tfplan
    exit 0
fi

echo ""
echo -e "${GREEN}Step 4: Terraform Apply${NC}"
terraform apply tfplan

rm -f tfplan

echo ""
echo -e "${GREEN}=========================================="
echo "Terraform Apply: COMPLETE"
echo "==========================================${NC}"
echo ""

# Save important outputs
echo "Saving outputs to terraform-outputs.json..."
terraform output -json > terraform-outputs.json

# Display summary
echo ""
echo "Infrastructure Summary:"
echo "-----------------------"
terraform output alb_url
terraform output rds_endpoint
terraform output ecs_cluster_name

echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo "  1. Build and push Docker images: ./03-build-push-images.sh"
echo "  2. Deploy Besu validators: ./04-deploy-besu.sh"
echo "  3. Deploy smart contracts: ./05-deploy-contracts.sh"
echo "  4. Deploy services: ./06-deploy-services.sh"
echo ""
