#!/bin/bash

# Script 99: Destroy All Infrastructure
# WARNING: This script will delete ALL resources created by Terraform

set -e

echo "=========================================="
echo "DESTROY ALL INFRASTRUCTURE"
echo "=========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${RED}⚠️  WARNING WARNING WARNING ⚠️${NC}"
echo ""
echo "This script will permanently delete:"
echo "  • All ECS services and tasks"
echo "  • RDS PostgreSQL database (with all data)"
echo "  • EFS file system (with all Besu blockchain data)"
echo "  • Load balancers"
echo "  • VPC and networking"
echo "  • CloudWatch logs"
echo "  • ECR repositories (with Docker images)"
echo "  • Secrets Manager secrets"
echo "  • IAM roles"
echo ""
echo -e "${RED}THIS ACTION CANNOT BE UNDONE!${NC}"
echo ""

read -p "Are you ABSOLUTELY SURE you want to destroy everything? (type 'destroy' to confirm): " CONFIRM

if [ "$CONFIRM" != "destroy" ]; then
    echo "Destruction cancelled. No changes made."
    exit 0
fi

echo ""
read -p "Second confirmation - Type 'YES DELETE EVERYTHING' to proceed: " CONFIRM2

if [ "$CONFIRM2" != "YES DELETE EVERYTHING" ]; then
    echo "Destruction cancelled. No changes made."
    exit 0
fi

echo ""
echo -e "${YELLOW}=========================================="
echo "Starting destruction process..."
echo "==========================================${NC}"

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

# Step 1: Stop all ECS services (speeds up deletion)
echo -e "${GREEN}Step 1: Stopping all ECS services...${NC}"
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "property-tcc-cluster")

SERVICES=$(aws ecs list-services --cluster $CLUSTER_NAME --query 'serviceArns[*]' --output text 2>/dev/null || echo "")

if [ -n "$SERVICES" ]; then
    for SERVICE_ARN in $SERVICES; do
        SERVICE_NAME=$(basename $SERVICE_ARN)
        echo "Updating $SERVICE_NAME to 0 tasks..."
        aws ecs update-service \
            --cluster $CLUSTER_NAME \
            --service $SERVICE_NAME \
            --desired-count 0 \
            > /dev/null 2>&1 || true
    done
    echo "Waiting 30 seconds for tasks to drain..."
    sleep 30
else
    echo "No services found or cluster doesn't exist"
fi

# Step 2: Empty ECR repositories (required before deletion)
echo ""
echo -e "${GREEN}Step 2: Emptying ECR repositories...${NC}"

REPOS=(
    "property-tcc-frontend"
    "property-tcc-bff-gateway"
    "property-tcc-orchestrator"
    "property-tcc-offchain-api"
    "property-tcc-queue-worker"
    "property-tcc-rabbitmq"
    "property-tcc-besu-validator"
)

for REPO in "${REPOS[@]}"; do
    echo "Deleting images from $REPO..."
    aws ecr batch-delete-image \
        --repository-name $REPO \
        --image-ids "$(aws ecr list-images --repository-name $REPO --query 'imageIds[*]' --output json 2>/dev/null || echo '[]')" \
        > /dev/null 2>&1 || echo "  (repository doesn't exist or already empty)"
done

# Step 3: Terraform destroy
echo ""
echo -e "${GREEN}Step 3: Running Terraform destroy...${NC}"
echo -e "${YELLOW}This will take 5-10 minutes...${NC}"
echo ""

terraform destroy -auto-approve

# Step 4: Clean up local files
echo ""
echo -e "${GREEN}Step 4: Cleaning up local files...${NC}"
rm -f terraform.tfstate*
rm -f terraform-outputs.json
rm -f tfplan
rm -rf .terraform/

echo ""
echo -e "${GREEN}=========================================="
echo "Verification"
echo "==========================================${NC}"
echo ""

# Verify ECS cluster is gone
echo -n "ECS Cluster: "
if aws ecs describe-clusters --clusters $CLUSTER_NAME --query 'clusters[0].status' --output text 2>/dev/null | grep -q "ACTIVE"; then
    echo -e "${YELLOW}Still exists (may take a few minutes)${NC}"
else
    echo -e "${GREEN}Deleted${NC}"
fi

# Verify RDS is gone
echo -n "RDS Database: "
if aws rds describe-db-instances --db-instance-identifier property-tcc-postgres 2>/dev/null > /dev/null; then
    echo -e "${YELLOW}Still exists (may take 5-10 minutes)${NC}"
else
    echo -e "${GREEN}Deleted${NC}"
fi

# Verify VPC is gone
echo -n "VPC: "
if aws ec2 describe-vpcs --filters "Name=tag:Name,Values=property-tcc-vpc" --query 'Vpcs[0].VpcId' --output text 2>/dev/null | grep -q "vpc-"; then
    echo -e "${YELLOW}Still exists${NC}"
else
    echo -e "${GREEN}Deleted${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "DESTRUCTION COMPLETE"
echo "==========================================${NC}"
echo ""
echo "All infrastructure has been destroyed."
echo ""
echo "Resources that may still exist:"
echo "  • CloudWatch Logs (auto-deleted after retention period)"
echo "  • S3 buckets (if any were created manually)"
echo "  • Route53 records (if any were created manually)"
echo ""
echo "To verify complete cleanup, check AWS Console:"
echo "  • ECS: https://console.aws.amazon.com/ecs/home?region=us-east-1"
echo "  • RDS: https://console.aws.amazon.com/rds/home?region=us-east-1"
echo "  • VPC: https://console.aws.amazon.com/vpc/home?region=us-east-1"
echo "  • ECR: https://console.aws.amazon.com/ecr/repositories?region=us-east-1"
echo ""
echo -e "${YELLOW}Check your AWS bill to ensure no unexpected charges.${NC}"
echo ""
