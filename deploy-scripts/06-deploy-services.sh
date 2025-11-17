#!/bin/bash

# Script 06: Deploy Application Services
# This script deploys all application services (frontend, BFF, orchestrator, etc.)

set -e

echo "=========================================="
echo "Deploy Application Services"
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

# Deployment order (respects dependencies)
SERVICES=(
    "property-tcc-rabbitmq"           # Message queue (no dependencies)
    "property-tcc-offchain-api"       # Offchain API (depends on Besu)
    "property-tcc-queue-worker"       # Worker (depends on RabbitMQ + Offchain)
    "property-tcc-orchestrator"       # Orchestrator (depends on RabbitMQ + DB)
    "property-tcc-bff-gateway"        # BFF (depends on Orchestrator + Offchain)
    "property-tcc-frontend"           # Frontend (depends on BFF)
)

echo -e "${GREEN}Step 1: Deploying services in order${NC}"
echo ""

for SERVICE in "${SERVICES[@]}"; do
    force_deployment "$SERVICE"
done

echo ""
echo -e "${GREEN}Step 2: Waiting for all services to stabilize${NC}"
echo -e "${YELLOW}This may take 5-10 minutes...${NC}"
echo ""

for SERVICE in "${SERVICES[@]}"; do
    wait_for_service "$SERVICE"
done

echo ""
echo -e "${GREEN}Step 3: Verify all services are running${NC}"
echo ""

ALL_HEALTHY=true

for SERVICE in "${SERVICES[@]}"; do
    DESIRED=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services $SERVICE \
        --query 'services[0].desiredCount' \
        --output text)

    RUNNING=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services $SERVICE \
        --query 'services[0].runningCount' \
        --output text)

    if [ "$RUNNING" -eq "$DESIRED" ]; then
        echo -e "${GREEN}✓ $SERVICE: $RUNNING/$DESIRED running${NC}"
    else
        echo -e "${RED}✗ $SERVICE: $RUNNING/$DESIRED running${NC}"
        ALL_HEALTHY=false
    fi
done

echo ""
if [ "$ALL_HEALTHY" = true ]; then
    echo -e "${GREEN}=========================================="
    echo "All Services: HEALTHY"
    echo "==========================================${NC}"
else
    echo -e "${YELLOW}=========================================="
    echo "WARNING: Some services are not healthy"
    echo "==========================================${NC}"
    echo ""
    echo "Check logs with:"
    echo "  aws logs tail /ecs/property-tcc-<service-name> --follow"
fi

echo ""
echo -e "${GREEN}Step 4: Display access URLs${NC}"
echo ""

ALB_URL=$(cd "$TERRAFORM_DIR" && terraform output -raw alb_url 2>/dev/null || echo "http://<alb-dns>")

echo "Application URLs:"
echo "  Frontend:     $ALB_URL"
echo "  BFF API:      $ALB_URL/api"
echo "  Orchestrator: $ALB_URL/actuator/health"
echo ""

echo -e "${GREEN}=========================================="
echo "Application Services: DEPLOYED"
echo "==========================================${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "  1. Run health checks: ./07-health-check.sh"
echo "  2. View all URLs: ./08-show-urls.sh"
echo ""
