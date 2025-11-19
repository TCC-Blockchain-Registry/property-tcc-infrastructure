#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/ecs-helpers.sh"

log_header "Deploy Besu Validators"

CLUSTER=$(get_cluster_name "$SCRIPT_DIR/../terraform-aws")
log_info "Cluster: $CLUSTER"

log_step "Deploying validators"
for i in 1 2 3 4; do
    force_deployment "$CLUSTER" "property-tcc-besu-validator-$i"
done

log_step "Waiting for stability"
for i in 1 2 3 4; do
    wait_for_service "$CLUSTER" "property-tcc-besu-validator-$i"
done

log_step "Checking status"
for i in 1 2 3 4; do
    count=$(check_service_running "$CLUSTER" "property-tcc-besu-validator-$i")
    if [ "$count" -eq 1 ]; then
        log_success "Validator $i: Running"
    else
        log_error "Validator $i: Not running"
    fi
done

log_success "Besu validators deployed"
echo ""
echo "Check logs: aws logs tail /ecs/property-tcc/besu-validator-1 --follow"
