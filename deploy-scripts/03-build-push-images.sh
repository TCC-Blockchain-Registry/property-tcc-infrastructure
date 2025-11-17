#!/bin/bash

# Script 03: Build and Push Docker Images to ECR
# This script builds all Docker images and pushes them to ECR

set -e

echo "=========================================="
echo "Build and Push Docker Images"
echo "=========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region || echo "us-east-1")
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "AWS Account: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
echo "ECR Registry: $ECR_REGISTRY"
echo ""

# Get project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Project root: $PROJECT_ROOT"
echo ""

# Login to ECR
echo -e "${GREEN}Step 1: Login to ECR${NC}"
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

# Function to build and push image
build_and_push() {
    local SERVICE_NAME=$1
    local SERVICE_DIR=$2
    local DOCKERFILE=$3
    local ECR_REPO="${ECR_REGISTRY}/property-tcc-${SERVICE_NAME}"

    echo ""
    echo -e "${GREEN}=========================================="
    echo "Building: $SERVICE_NAME"
    echo "==========================================${NC}"

    cd "$PROJECT_ROOT/$SERVICE_DIR"

    # Build image
    echo "Building Docker image..."
    docker build -f "$DOCKERFILE" -t "$SERVICE_NAME:latest" .

    # Tag for ECR
    docker tag "$SERVICE_NAME:latest" "$ECR_REPO:latest"

    # Push to ECR
    echo "Pushing to ECR..."
    docker push "$ECR_REPO:latest"

    echo -e "${GREEN}✓ $SERVICE_NAME pushed successfully${NC}"
}

# Build and push all images
echo ""
echo -e "${YELLOW}Starting image builds...${NC}"

# 1. Frontend
build_and_push "frontend" "wallet-property-fed" "Dockerfile"

# 2. BFF Gateway
build_and_push "bff-gateway" "bff-gateway" "Dockerfile"

# 3. Orchestrator
build_and_push "orchestrator" "core-orchestrator-srv" "Dockerfile"

# 4. Offchain API
build_and_push "offchain-api" "offchain-consumer-srv" "Dockerfile"

# 5. Queue Worker
build_and_push "queue-worker" "queue-worker" "Dockerfile"

# 6. RabbitMQ
build_and_push "rabbitmq" "message-queue" "Dockerfile"

# 7. Besu Validator
build_and_push "besu-validator" "infrastructure/besu-aws" "Dockerfile"

echo ""
echo -e "${GREEN}=========================================="
echo "All Images Built and Pushed!"
echo "==========================================${NC}"
echo ""
echo "Images available in ECR:"
echo "  - ${ECR_REGISTRY}/property-tcc-frontend:latest"
echo "  - ${ECR_REGISTRY}/property-tcc-bff-gateway:latest"
echo "  - ${ECR_REGISTRY}/property-tcc-orchestrator:latest"
echo "  - ${ECR_REGISTRY}/property-tcc-offchain-api:latest"
echo "  - ${ECR_REGISTRY}/property-tcc-queue-worker:latest"
echo "  - ${ECR_REGISTRY}/property-tcc-rabbitmq:latest"
echo "  - ${ECR_REGISTRY}/property-tcc-besu-validator:latest"
echo ""
echo -e "${GREEN}Next step:${NC}"
echo "  ./04-deploy-besu.sh"
echo ""
