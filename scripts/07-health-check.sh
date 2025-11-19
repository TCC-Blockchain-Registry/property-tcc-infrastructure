#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"

log_header "Health Check"

TERRAFORM_DIR="$SCRIPT_DIR/../terraform-aws"
ALB_DNS=$(cd "$TERRAFORM_DIR" && terraform output -raw alb_dns_name 2>/dev/null || echo "")

if [ -z "$ALB_DNS" ]; then
    log_error "Could not get ALB DNS"
    exit 1
fi

log_info "ALB: $ALB_DNS"

check_endpoint() {
    local name=$1
    local url=$2
    if curl -sf "$url" >/dev/null 2>&1; then
        log_success "$name: OK"
        return 0
    else
        log_error "$name: Failed"
        return 1
    fi
}

log_step "Checking endpoints"

check_endpoint "Frontend" "http://$ALB_DNS/"
check_endpoint "BFF Health" "http://$ALB_DNS/api/health"

log_step "Checking Besu RPC"
BLOCK=$(curl -sf "http://$ALB_DNS/rpc/validator-1" \
    -X POST -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ -n "$BLOCK" ]; then
    log_success "Besu: Block $BLOCK"
else
    log_error "Besu: No response"
fi

PEERS=$(curl -sf "http://$ALB_DNS/rpc/validator-1" \
    -X POST -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
    | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ "$PEERS" = "0x3" ]; then
    log_success "Peers: 3 connected"
elif [ -n "$PEERS" ]; then
    log_warn "Peers: $PEERS (expected 0x3)"
else
    log_error "Peers: Could not check"
fi

log_success "Health check complete"
