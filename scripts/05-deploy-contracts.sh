#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"

log_header "Deploy Smart Contracts"

PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BESU_DIR="$PROJECT_ROOT/besu-property-ledger"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform-aws"

ALB_DNS=$(cd "$TERRAFORM_DIR" && terraform output -raw alb_dns_name 2>/dev/null || echo "")
if [ -z "$ALB_DNS" ]; then
    log_error "Could not get ALB DNS from Terraform"
    exit 1
fi

RPC_URL="http://${ALB_DNS}/rpc/validator-1"
log_info "RPC URL: $RPC_URL"

cd "$BESU_DIR"

log_step "Deploying contracts"
forge script script/Deploy.s.sol --rpc-url "$RPC_URL" --broadcast

log_success "Contracts deployed"
echo ""
echo "Update terraform.tfvars with contract addresses and run:"
echo "  cd terraform-aws && terraform apply"
