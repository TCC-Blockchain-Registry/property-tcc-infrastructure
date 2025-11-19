#!/bin/bash
#
# ecs-helpers.sh
#
# Shared ECS helper functions
#

# Get cluster name from Terraform outputs
get_cluster_name() {
    local terraform_dir="${1:-$SCRIPT_DIR/../terraform-aws}"
    cd "$terraform_dir" && terraform output -raw ecs_cluster_name 2>/dev/null || echo "property-tcc-cluster"
}

# Wait for ECS service to be stable
wait_for_service() {
    local cluster=$1
    local service=$2
    log_info "Waiting for $service to stabilize..."
    aws ecs wait services-stable --cluster "$cluster" --services "$service"
    log_success "$service is stable"
}

# Force new deployment of ECS service
force_deployment() {
    local cluster=$1
    local service=$2
    log_info "Deploying: $service"
    aws ecs update-service \
        --cluster "$cluster" \
        --service "$service" \
        --force-new-deployment \
        --query 'service.serviceName' \
        --output text >/dev/null
}

# Check if service is running
check_service_running() {
    local cluster=$1
    local service=$2
    local running=$(aws ecs describe-services \
        --cluster "$cluster" \
        --services "$service" \
        --query 'services[0].runningCount' \
        --output text)
    echo "$running"
}

# Get AWS account ID
get_aws_account_id() {
    aws sts get-caller-identity --query Account --output text
}

# Get AWS region
get_aws_region() {
    aws configure get region || echo "us-east-1"
}

# Get ECR registry URL
get_ecr_registry() {
    local account_id=$(get_aws_account_id)
    local region=$(get_aws_region)
    echo "${account_id}.dkr.ecr.${region}.amazonaws.com"
}

# Login to ECR
ecr_login() {
    local registry=$(get_ecr_registry)
    local region=$(get_aws_region)
    aws ecr get-login-password --region "$region" | \
        docker login --username AWS --password-stdin "$registry"
}
