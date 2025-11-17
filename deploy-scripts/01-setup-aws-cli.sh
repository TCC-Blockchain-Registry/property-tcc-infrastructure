#!/bin/bash

# Script 01: Setup and verify AWS CLI
# This script checks AWS CLI installation and credentials

set -e

echo "=========================================="
echo "AWS CLI Setup Verification"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if AWS CLI is installed
echo -n "Checking AWS CLI installation... "
if ! command -v aws &> /dev/null; then
    echo -e "${RED}FAILED${NC}"
    echo ""
    echo "AWS CLI is not installed. Please install it:"
    echo "  macOS: brew install awscli"
    echo "  Linux: sudo apt-get install awscli"
    echo "  Or visit: https://aws.amazon.com/cli/"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

# Check AWS CLI version
AWS_VERSION=$(aws --version 2>&1 | awk '{print $1}' | cut -d/ -f2)
echo "AWS CLI Version: $AWS_VERSION"

# Check if credentials are configured
echo -n "Checking AWS credentials... "
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}FAILED${NC}"
    echo ""
    echo "AWS credentials are not configured. Please run:"
    echo "  aws configure"
    echo ""
    echo "You will need:"
    echo "  - AWS Access Key ID"
    echo "  - AWS Secret Access Key"
    echo "  - Default region (us-east-1)"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

# Display current identity
echo ""
echo "Current AWS Identity:"
aws sts get-caller-identity

# Check default region
echo ""
echo -n "Checking default region... "
DEFAULT_REGION=$(aws configure get region)
if [ -z "$DEFAULT_REGION" ]; then
    echo -e "${YELLOW}WARNING${NC}"
    echo "No default region configured. Setting to us-east-1..."
    aws configure set region us-east-1
    DEFAULT_REGION="us-east-1"
fi
echo -e "${GREEN}$DEFAULT_REGION${NC}"

if [ "$DEFAULT_REGION" != "us-east-1" ]; then
    echo -e "${YELLOW}WARNING: Your default region is $DEFAULT_REGION, but this project uses us-east-1${NC}"
    echo "You can change it with: aws configure set region us-east-1"
fi

# Check if terraform is installed
echo ""
echo -n "Checking Terraform installation... "
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}FAILED${NC}"
    echo ""
    echo "Terraform is not installed. Please install it:"
    echo "  macOS: brew install terraform"
    echo "  Linux: https://learn.hashicorp.com/tutorials/terraform/install-cli"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
echo "Terraform Version: $TERRAFORM_VERSION"

# Check if jq is installed
echo ""
echo -n "Checking jq installation... "
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}WARNING${NC}"
    echo "jq is not installed. Some scripts may not work properly."
    echo "Install with: brew install jq (macOS) or apt-get install jq (Linux)"
else
    echo -e "${GREEN}OK${NC}"
fi

# Check AWS budget (optional)
echo ""
echo "=========================================="
echo "Checking AWS Account Limits (optional)"
echo "=========================================="

# Try to get account limits
echo "Fetching ECS service quotas..."
aws service-quotas get-service-quota \
    --service-code ecs \
    --quota-code L-9EF96962 2>/dev/null || echo "Could not fetch ECS quotas (requires permissions)"

echo ""
echo -e "${GREEN}=========================================="
echo "AWS CLI Setup: COMPLETE"
echo "==========================================${NC}"
echo ""
echo "You can now proceed with:"
echo "  ./02-terraform-apply.sh"
echo ""
