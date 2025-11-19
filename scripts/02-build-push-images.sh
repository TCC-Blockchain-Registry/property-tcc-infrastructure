#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/ecs-helpers.sh"

PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

log_header "Build and Push Docker Images"

ECR_REGISTRY=$(get_ecr_registry)
log_info "ECR Registry: $ECR_REGISTRY"

ecr_login

build_and_push() {
    local name=$1
    local dir=$2
    local repo="${ECR_REGISTRY}/property-tcc-${name}"

    log_step "Building: $name"
    cd "$PROJECT_ROOT/$dir"
    docker build -t "$name:latest" .
    docker tag "$name:latest" "$repo:latest"
    docker push "$repo:latest"
    log_success "$name pushed"
}

build_and_push "frontend" "wallet-property-fed"
build_and_push "bff-gateway" "bff-gateway"
build_and_push "orchestrator" "core-orchestrator-srv"
build_and_push "offchain-api" "offchain-consumer-srv"
build_and_push "queue-worker" "queue-worker"
build_and_push "rabbitmq" "message-queue"

log_success "All images pushed to ECR"
