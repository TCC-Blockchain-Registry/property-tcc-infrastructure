#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"

log_header "Access URLs"

TERRAFORM_DIR="$SCRIPT_DIR/../terraform-aws"

ALB_DNS=$(cd "$TERRAFORM_DIR" && terraform output -raw alb_dns_name 2>/dev/null || echo "N/A")
RDS_ENDPOINT=$(cd "$TERRAFORM_DIR" && terraform output -raw rds_endpoint 2>/dev/null || echo "N/A")
EFS_ID=$(cd "$TERRAFORM_DIR" && terraform output -raw efs_id 2>/dev/null || echo "N/A")

echo "Application:"
echo "  Frontend:    http://$ALB_DNS/"
echo "  BFF API:     http://$ALB_DNS/api/"
echo ""
echo "Besu RPC:"
echo "  Validator 1: http://$ALB_DNS/rpc/validator-1"
echo ""
echo "Infrastructure:"
echo "  RDS:         $RDS_ENDPOINT"
echo "  EFS:         $EFS_ID"
echo ""
echo "Logs:"
echo "  aws logs tail /ecs/property-tcc/orchestrator --follow"
echo "  aws logs tail /ecs/property-tcc/besu-validator-1 --follow"
