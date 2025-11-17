#!/bin/bash

# Script 04: Deploy Besu Validators
# This script updates ECS services to deploy Besu validators

set -e

echo "=========================================="
echo "Deploy Besu Validators"
echo "=========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get cluster name from Terraform outputs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform-aws"
CLUSTER_NAME=$(cd "$TERRAFORM_DIR" && terraform output -raw ecs_cluster_name 2>/dev/null || echo "property-tcc-cluster")

echo "ECS Cluster: $CLUSTER_NAME"
echo ""

# Function to wait for service to be stable
wait_for_service() {
    local SERVICE_NAME=$1
    echo "Waiting for $SERVICE_NAME to stabilize..."
    aws ecs wait services-stable --cluster $CLUSTER_NAME --services $SERVICE_NAME
    echo -e "${GREEN}✓ $SERVICE_NAME is stable${NC}"
}

# Function to force new deployment
force_deployment() {
    local SERVICE_NAME=$1
    echo ""
    echo -e "${YELLOW}Deploying: $SERVICE_NAME${NC}"

    aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $SERVICE_NAME \
        --force-new-deployment \
        --query 'service.serviceName' \
        --output text

    echo "Deployment initiated for $SERVICE_NAME"
}

echo -e "${GREEN}Step 1: Force new deployment for all Besu validators${NC}"
echo ""

# Deploy all 4 validators
force_deployment "property-tcc-besu-validator-1"
force_deployment "property-tcc-besu-validator-2"
force_deployment "property-tcc-besu-validator-3"
force_deployment "property-tcc-besu-validator-4"

echo ""
echo -e "${GREEN}Step 2: Waiting for all validators to become stable${NC}"
echo -e "${YELLOW}This may take 3-5 minutes...${NC}"
echo ""

# Wait for all validators
wait_for_service "property-tcc-besu-validator-1"
wait_for_service "property-tcc-besu-validator-2"
wait_for_service "property-tcc-besu-validator-3"
wait_for_service "property-tcc-besu-validator-4"

echo ""
echo -e "${GREEN}Step 3: Verify validators are running${NC}"
echo ""

# Check running tasks
for i in 1 2 3 4; do
    SERVICE_NAME="property-tcc-besu-validator-$i"
    RUNNING_COUNT=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services $SERVICE_NAME \
        --query 'services[0].runningCount' \
        --output text)

    if [ "$RUNNING_COUNT" -eq 1 ]; then
        echo -e "${GREEN}✓ Validator $i: Running${NC}"
    else
        echo -e "${RED}✗ Validator $i: Not running (count: $RUNNING_COUNT)${NC}"
    fi
done

echo ""
echo -e "${GREEN}Step 4: Display validator endpoints${NC}"
echo ""
echo "Validators are accessible via Service Discovery:"
echo "  - Validator 1: property-tcc-besu-validator-1.property-tcc.local:8545"
echo "  - Validator 2: property-tcc-besu-validator-2.property-tcc.local:8546"
echo "  - Validator 3: property-tcc-besu-validator-3.property-tcc.local:8547"
echo "  - Validator 4: property-tcc-besu-validator-4.property-tcc.local:8548"

echo ""
echo -e "${YELLOW}=========================================="
echo "IMPORTANT: Check CloudWatch Logs"
echo "==========================================${NC}"
echo ""
echo "Verify validators are forming consensus:"
echo "  aws logs tail /ecs/property-tcc-besu-validator-1 --follow"
echo "  aws logs tail /ecs/property-tcc-besu-validator-2 --follow"
echo "  aws logs tail /ecs/property-tcc-besu-validator-3 --follow"
echo "  aws logs tail /ecs/property-tcc-besu-validator-4 --follow"
echo ""
echo "Look for: 'Imported block' or 'Produced block' messages"
echo ""

echo -e "${GREEN}=========================================="
echo "Besu Validators: DEPLOYED"
echo "==========================================${NC}"
echo ""
echo -e "${GREEN}Next step:${NC}"
echo "  ./05-deploy-contracts.sh"
echo ""
