#!/bin/bash

# Script 08: Show Access URLs
# This script displays all important access URLs and commands

set -e

echo "=========================================="
echo "Property Tokenization Platform - Access Info"
echo "=========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get Terraform outputs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform-aws"

if [ ! -d "$TERRAFORM_DIR" ]; then
    echo -e "${RED}ERROR: Terraform directory not found${NC}"
    exit 1
fi

cd "$TERRAFORM_DIR"

# Check if terraform state exists
if ! terraform output > /dev/null 2>&1; then
    echo -e "${RED}ERROR: No Terraform state found. Run ./02-terraform-apply.sh first${NC}"
    exit 1
fi

# Get outputs
ALB_URL=$(terraform output -raw alb_url 2>/dev/null || echo "N/A")
ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "N/A")
INTERNAL_ALB=$(terraform output -raw internal_alb_dns_name 2>/dev/null || echo "N/A")
RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null || echo "N/A")
ECS_CLUSTER=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "N/A")
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "N/A")

echo ""
echo -e "${GREEN}=========================================="
echo "Application URLs"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}Frontend (React):${NC}"
echo "  $ALB_URL"
echo ""
echo -e "${BLUE}BFF Gateway API:${NC}"
echo "  $ALB_URL/api"
echo "  $ALB_URL/api/health"
echo ""
echo -e "${BLUE}Orchestrator API:${NC}"
echo "  $ALB_URL/actuator/health"
echo "  $ALB_URL/actuator/info"
echo ""

echo -e "${GREEN}=========================================="
echo "Internal Services"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}Internal ALB (Offchain API):${NC}"
echo "  http://$INTERNAL_ALB"
echo ""
echo -e "${BLUE}Service Discovery (inside VPC):${NC}"
echo "  property-tcc-orchestrator.property-tcc.local:8081"
echo "  property-tcc-offchain-api.property-tcc.local:3001"
echo "  property-tcc-rabbitmq.property-tcc.local:5672"
echo "  property-tcc-besu-validator-1.property-tcc.local:8545"
echo "  property-tcc-besu-validator-2.property-tcc.local:8546"
echo "  property-tcc-besu-validator-3.property-tcc.local:8547"
echo "  property-tcc-besu-validator-4.property-tcc.local:8548"
echo ""

echo -e "${GREEN}=========================================="
echo "Infrastructure Details"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}RDS PostgreSQL:${NC}"
echo "  Endpoint: $RDS_ENDPOINT"
echo "  Database: core_orchestrator_db"
echo "  User: postgres"
echo ""
echo -e "${BLUE}ECS Cluster:${NC}"
echo "  Name: $ECS_CLUSTER"
echo "  Region: us-east-1"
echo ""
echo -e "${BLUE}VPC:${NC}"
echo "  ID: $VPC_ID"
echo "  AZs: us-east-1a, us-east-1b"
echo ""

echo -e "${GREEN}=========================================="
echo "Useful AWS CLI Commands"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}List ECS Services:${NC}"
echo "  aws ecs list-services --cluster $ECS_CLUSTER"
echo ""
echo -e "${BLUE}View Service Status:${NC}"
echo "  aws ecs describe-services --cluster $ECS_CLUSTER --services property-tcc-frontend"
echo ""
echo -e "${BLUE}View CloudWatch Logs:${NC}"
echo "  aws logs tail /ecs/property-tcc-frontend --follow"
echo "  aws logs tail /ecs/property-tcc-bff-gateway --follow"
echo "  aws logs tail /ecs/property-tcc-orchestrator --follow"
echo "  aws logs tail /ecs/property-tcc-besu-validator-1 --follow"
echo ""
echo -e "${BLUE}Connect to Container (ECS Exec):${NC}"
echo "  TASK=\$(aws ecs list-tasks --cluster $ECS_CLUSTER --service property-tcc-orchestrator --query 'taskArns[0]' --output text)"
echo "  aws ecs execute-command --cluster $ECS_CLUSTER --task \$TASK --container orchestrator --interactive --command /bin/bash"
echo ""
echo -e "${BLUE}Check RDS Status:${NC}"
echo "  aws rds describe-db-instances --db-instance-identifier property-tcc-postgres"
echo ""

echo -e "${GREEN}=========================================="
echo "Cost Monitoring"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}Check current AWS costs:${NC}"
echo "  aws ce get-cost-and-usage \\"
echo "    --time-period Start=2025-11-01,End=2025-11-30 \\"
echo "    --granularity MONTHLY \\"
echo "    --metrics BlendedCost \\"
echo "    --group-by Type=SERVICE"
echo ""
echo -e "${YELLOW}Estimated cost: ~\$26 for 3 days (with planned cleanup)${NC}"
echo ""

echo -e "${GREEN}=========================================="
echo "Next Steps"
echo "==========================================${NC}"
echo ""
echo "1. Open the frontend in your browser:"
echo "   $ALB_URL"
echo ""
echo "2. Configure MetaMask for Besu network:"
echo "   - Network Name: Property TCC"
echo "   - RPC URL: (requires VPN or bastion for private access)"
echo "   - Chain ID: 1337"
echo ""
echo "3. Monitor application health:"
echo "   ./07-health-check.sh"
echo ""
echo "4. When done, destroy infrastructure:"
echo "   ./99-destroy-all.sh"
echo ""

echo -e "${GREEN}=========================================="
echo "Documentation"
echo "==========================================${NC}"
echo ""
echo "  README: $SCRIPT_DIR/../README.md"
echo "  Besu AWS Config: $SCRIPT_DIR/../besu-aws/README.md"
echo "  Terraform: $TERRAFORM_DIR/"
echo ""
