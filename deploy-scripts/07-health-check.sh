#!/bin/bash

# Script 07: Health Check All Services
# This script checks the health of all deployed services

set -e

echo "=========================================="
echo "System Health Check"
echo "=========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get Terraform outputs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform-aws"
CLUSTER_NAME=$(cd "$TERRAFORM_DIR" && terraform output -raw ecs_cluster_name 2>/dev/null || echo "property-tcc-cluster")
ALB_DNS=$(cd "$TERRAFORM_DIR" && terraform output -raw alb_dns_name 2>/dev/null || echo "")

echo "ECS Cluster: $CLUSTER_NAME"
echo "Load Balancer: $ALB_DNS"
echo ""

# Function to check HTTP endpoint
check_http() {
    local NAME=$1
    local URL=$2
    local EXPECTED=$3

    echo -n "Checking $NAME... "

    if RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$URL" 2>/dev/null); then
        if [ "$RESPONSE" = "$EXPECTED" ]; then
            echo -e "${GREEN}✓ OK (HTTP $RESPONSE)${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Warning (HTTP $RESPONSE, expected $EXPECTED)${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ FAILED (no response)${NC}"
        return 1
    fi
}

# Function to check ECS service
check_ecs_service() {
    local SERVICE_NAME=$1

    DESIRED=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services $SERVICE_NAME \
        --query 'services[0].desiredCount' \
        --output text 2>/dev/null)

    RUNNING=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services $SERVICE_NAME \
        --query 'services[0].runningCount' \
        --output text 2>/dev/null)

    echo -n "  ECS Service: "
    if [ "$RUNNING" = "$DESIRED" ] && [ "$RUNNING" != "0" ]; then
        echo -e "${GREEN}✓ $RUNNING/$DESIRED tasks running${NC}"
        return 0
    else
        echo -e "${RED}✗ $RUNNING/$DESIRED tasks running${NC}"
        return 1
    fi
}

echo -e "${GREEN}=========================================="
echo "1. External Services (via ALB)"
echo "==========================================${NC}"
echo ""

EXTERNAL_HEALTHY=0
EXTERNAL_TOTAL=3

check_http "Frontend" "http://$ALB_DNS/" "200" && ((EXTERNAL_HEALTHY++)) || true
check_http "BFF API" "http://$ALB_DNS/api/health" "200" && ((EXTERNAL_HEALTHY++)) || true
check_http "Orchestrator" "http://$ALB_DNS/actuator/health" "200" && ((EXTERNAL_HEALTHY++)) || true

echo ""
echo -e "${GREEN}=========================================="
echo "2. ECS Services Status"
echo "==========================================${NC}"
echo ""

SERVICES=(
    "property-tcc-frontend"
    "property-tcc-bff-gateway"
    "property-tcc-orchestrator"
    "property-tcc-offchain-api"
    "property-tcc-queue-worker"
    "property-tcc-rabbitmq"
    "property-tcc-besu-validator-1"
    "property-tcc-besu-validator-2"
    "property-tcc-besu-validator-3"
    "property-tcc-besu-validator-4"
)

ECS_HEALTHY=0
ECS_TOTAL=${#SERVICES[@]}

for SERVICE in "${SERVICES[@]}"; do
    echo "$SERVICE:"
    check_ecs_service "$SERVICE" && ((ECS_HEALTHY++)) || true
    echo ""
done

echo -e "${GREEN}=========================================="
echo "3. Target Group Health"
echo "==========================================${NC}"
echo ""

# Get target group ARNs
TG_FRONTEND=$(cd "$TERRAFORM_DIR" && terraform output -json | jq -r '.access_commands.value.logs_frontend' 2>/dev/null | grep -o 'property-tcc-frontend-tg' || echo "")
TG_BFF=$(cd "$TERRAFORM_DIR" && terraform output -json | jq -r '.access_commands.value.logs_bff' 2>/dev/null | grep -o 'property-tcc-bff-tg' || echo "")
TG_ORCH=$(cd "$TERRAFORM_DIR" && terraform output -json | jq -r '.access_commands.value.logs_orchestrator' 2>/dev/null | grep -o 'property-tcc-orchestrator-tg' || echo "")

echo "Note: Target group health check requires AWS CLI and proper permissions"
echo ""

echo -e "${GREEN}=========================================="
echo "4. RDS Database"
echo "==========================================${NC}"
echo ""

RDS_ENDPOINT=$(cd "$TERRAFORM_DIR" && terraform output -raw rds_endpoint 2>/dev/null || echo "")
RDS_STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier property-tcc-postgres \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || echo "unknown")

echo -n "PostgreSQL Database: "
if [ "$RDS_STATUS" = "available" ]; then
    echo -e "${GREEN}✓ Available${NC}"
    echo "  Endpoint: $RDS_ENDPOINT"
else
    echo -e "${RED}✗ Status: $RDS_STATUS${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "5. CloudWatch Logs"
echo "==========================================${NC}"
echo ""

echo "Recent errors in services:"
for SERVICE in "frontend" "bff-gateway" "orchestrator"; do
    echo ""
    echo "Last 5 log entries for $SERVICE:"
    aws logs tail "/ecs/property-tcc-$SERVICE" --since 5m --format short 2>/dev/null | tail -5 || echo "  No recent logs"
done

echo ""
echo -e "${GREEN}=========================================="
echo "Health Check Summary"
echo "==========================================${NC}"
echo ""
echo "External Services: $EXTERNAL_HEALTHY/$EXTERNAL_TOTAL healthy"
echo "ECS Services:      $ECS_HEALTHY/$ECS_TOTAL healthy"
echo "Database:          $([ "$RDS_STATUS" = "available" ] && echo "✓ Available" || echo "✗ $RDS_STATUS")"
echo ""

TOTAL_HEALTHY=$((EXTERNAL_HEALTHY + ECS_HEALTHY))
TOTAL=$((EXTERNAL_TOTAL + ECS_TOTAL))
HEALTH_PERCENTAGE=$((TOTAL_HEALTHY * 100 / TOTAL))

if [ $HEALTH_PERCENTAGE -ge 90 ]; then
    echo -e "${GREEN}Overall Health: EXCELLENT ($HEALTH_PERCENTAGE%)${NC}"
elif [ $HEALTH_PERCENTAGE -ge 70 ]; then
    echo -e "${YELLOW}Overall Health: GOOD ($HEALTH_PERCENTAGE%)${NC}"
else
    echo -e "${RED}Overall Health: POOR ($HEALTH_PERCENTAGE%)${NC}"
fi

echo ""
echo "For detailed logs, run:"
echo "  aws logs tail /ecs/property-tcc-<service-name> --follow"
echo ""
