#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/ecs-helpers.sh"

log_header "Deploy Application Services"

CLUSTER=$(get_cluster_name "$SCRIPT_DIR/../terraform-aws")
log_info "Cluster: $CLUSTER"

SERVICES=(
    "property-tcc-rabbitmq"
    "property-tcc-orchestrator"
    "property-tcc-offchain-api"
    "property-tcc-queue-worker"
    "property-tcc-bff-gateway"
    "property-tcc-frontend"
)

log_step "Deploying services"
for service in "${SERVICES[@]}"; do
    force_deployment "$CLUSTER" "$service"
done

log_step "Waiting for stability"
for service in "${SERVICES[@]}"; do
    wait_for_service "$CLUSTER" "$service"
done

log_step "Checking status"
for service in "${SERVICES[@]}"; do
    count=$(check_service_running "$CLUSTER" "$service")
    name=$(echo "$service" | sed 's/property-tcc-//')
    if [ "$count" -ge 1 ]; then
        log_success "$name: Running ($count)"
    else
        log_error "$name: Not running"
    fi
done

log_success "All services deployed"
