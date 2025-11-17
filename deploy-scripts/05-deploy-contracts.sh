#!/bin/bash

# Script 05: Deploy Smart Contracts to Besu
# This script deploys ERC-3643 contracts to the Besu network

set -e

echo "=========================================="
echo "Deploy Smart Contracts"
echo "=========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BESU_DIR="$PROJECT_ROOT/besu-property-ledger"

cd "$BESU_DIR"

echo "Working directory: $(pwd)"
echo ""

# Check if Foundry is installed
echo -n "Checking Foundry installation... "
if ! command -v forge &> /dev/null; then
    echo -e "${RED}FAILED${NC}"
    echo "Foundry is not installed. Install with:"
    echo "  curl -L https://foundry.paradigm.xyz | bash"
    echo "  foundryup"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

# Get RPC endpoint from ECS task
echo ""
echo -e "${YELLOW}Step 1: Finding Besu RPC endpoint${NC}"
echo ""
echo "NOTE: For ECS deployment, you need to access Besu through a bastion host"
echo "or configure a Network Load Balancer for RPC access."
echo ""
echo "Alternative approaches:"
echo "  1. Deploy contracts locally and copy DEPLOYED_ADDRESSES.txt"
echo "  2. Use AWS Systems Manager Session Manager to access Besu from inside VPC"
echo "  3. Create a temporary NLB for Besu RPC (costs ~$0.03/hour)"
echo ""

read -p "Have you already deployed contracts and have DEPLOYED_ADDRESSES.txt? (yes/no): " HAS_ADDRESSES

if [ "$HAS_ADDRESSES" = "yes" ]; then
    echo ""
    echo "Please ensure DEPLOYED_ADDRESSES.txt exists in:"
    echo "  $BESU_DIR/DEPLOYED_ADDRESSES.txt"
    echo ""

    if [ ! -f "DEPLOYED_ADDRESSES.txt" ]; then
        echo -e "${RED}ERROR: DEPLOYED_ADDRESSES.txt not found${NC}"
        echo "Please create it with the following format:"
        echo ""
        cat <<EOF
PROPERTY_TITLE_TREX=0x...
APPROVALS_MODULE=0x...
REGISTRY_MD_COMPLIANCE=0x...
EOF
        exit 1
    fi

    echo -e "${GREEN}✓ DEPLOYED_ADDRESSES.txt found${NC}"
    cat DEPLOYED_ADDRESSES.txt

else
    echo ""
    echo -e "${YELLOW}Option 1: Deploy from local Besu network${NC}"
    echo "  1. Start local Besu: cd besu-property-ledger && ./script/setup/setup-network.sh"
    echo "  2. Deploy contracts: ./script/setup/deploy-contracts.sh"
    echo "  3. Copy DEPLOYED_ADDRESSES.txt to this location"
    echo ""
    echo -e "${YELLOW}Option 2: Create temporary NLB for AWS Besu${NC}"
    echo "  1. Create NLB pointing to Besu validator 1"
    echo "  2. Set RPC_URL to NLB endpoint"
    echo "  3. Run deployment script"
    echo "  4. Delete NLB after deployment"
    echo ""
    echo -e "${YELLOW}Option 3: Use ECS Exec${NC}"
    echo "  1. Enable ECS Exec on orchestrator task"
    echo "  2. Connect to orchestrator container"
    echo "  3. Install foundry in container"
    echo "  4. Deploy from inside VPC"
    echo ""

    read -p "Choose deployment method (1/2/3): " METHOD

    case $METHOD in
        1)
            echo ""
            echo "Starting local Besu network..."
            cd "$BESU_DIR"
            ./script/setup/setup-network.sh

            echo ""
            echo "Compiling contracts..."
            forge build

            echo ""
            echo "Deploying contracts..."
            ./script/setup/deploy-contracts.sh

            echo ""
            echo -e "${GREEN}✓ Contracts deployed locally${NC}"
            echo ""
            echo "DEPLOYED_ADDRESSES.txt:"
            cat DEPLOYED_ADDRESSES.txt
            ;;
        2)
            echo ""
            echo -e "${RED}Manual NLB creation required${NC}"
            echo ""
            echo "Steps:"
            echo "  1. Go to AWS Console > EC2 > Load Balancers"
            echo "  2. Create Network Load Balancer"
            echo "  3. Add listener: TCP port 8545"
            echo "  4. Target: property-tcc-besu-validator-1 ECS service"
            echo "  5. Set RPC_URL=http://<nlb-dns>:8545"
            echo "  6. Run: forge script script/Deploy.s.sol --rpc-url \$RPC_URL --broadcast"
            echo ""
            exit 0
            ;;
        3)
            echo ""
            echo "ECS Exec deployment steps:"
            echo ""
            echo "  # Find orchestrator task"
            echo "  TASK_ARN=\$(aws ecs list-tasks --cluster property-tcc-cluster --service-name property-tcc-orchestrator --query 'taskArns[0]' --output text)"
            echo ""
            echo "  # Connect to container"
            echo "  aws ecs execute-command --cluster property-tcc-cluster --task \$TASK_ARN --container orchestrator --interactive --command /bin/bash"
            echo ""
            echo "  # Inside container:"
            echo "  apt-get update && apt-get install -y curl git"
            echo "  curl -L https://foundry.paradigm.xyz | bash"
            echo "  source ~/.bashrc"
            echo "  foundryup"
            echo "  cd /tmp && git clone <your-repo>"
            echo "  cd besu-property-ledger"
            echo "  forge script script/Deploy.s.sol --rpc-url http://property-tcc-besu-validator-1.property-tcc.local:8545 --broadcast"
            echo ""
            exit 0
            ;;
        *)
            echo "Invalid option"
            exit 1
            ;;
    esac
fi

echo ""
echo -e "${GREEN}=========================================="
echo "Smart Contracts: DEPLOYED"
echo "==========================================${NC}"
echo ""
echo "Contract addresses saved in:"
echo "  $BESU_DIR/DEPLOYED_ADDRESSES.txt"
echo ""
echo -e "${YELLOW}IMPORTANT: Update contract addresses in Secrets Manager${NC}"
echo ""
echo "Run this to update the offchain API configuration:"
echo "  aws secretsmanager create-secret --name property-tcc/contracts --secret-string file://DEPLOYED_ADDRESSES.txt"
echo ""
echo -e "${GREEN}Next step:${NC}"
echo "  ./06-deploy-services.sh"
echo ""
