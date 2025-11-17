#!/bin/bash
#
# verify-besu-config.sh
#
# Verifies Besu QBFT network is operational after AWS deployment
# - Checks RPC endpoints
# - Validates peer connections
# - Verifies consensus (blocks progressing)
# - Checks validator participation
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_NAME="property-tcc"
AWS_REGION="us-east-1"
VALIDATOR_COUNT=4

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

# RPC call helper
rpc_call() {
    local endpoint=$1
    local method=$2
    local params=${3:-"[]"}

    curl -s -X POST "$endpoint" \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"$method\",\"params\":$params,\"id\":1}" \
        2>/dev/null || echo '{"error":"connection failed"}'
}

# Get ALB endpoint
get_alb_endpoint() {
    log_info "Finding ALB endpoint..."

    ALB_DNS=$(aws elbv2 describe-load-balancers \
        --region "$AWS_REGION" \
        --query "LoadBalancers[?contains(LoadBalancerName, '$PROJECT_NAME')].DNSName" \
        --output text 2>/dev/null || echo "")

    if [ -z "$ALB_DNS" ]; then
        log_warn "ALB not found. Using internal endpoints (requires VPN/Bastion)"
        USE_INTERNAL=true
    else
        log_success "ALB endpoint: $ALB_DNS"
        ALB_ENDPOINT="http://$ALB_DNS"
    fi
}

# Check validator RPC
check_validator_rpc() {
    local validator_num=$1
    local endpoint

    if [ "$USE_INTERNAL" = true ]; then
        endpoint="http://$PROJECT_NAME-besu-validator-$validator_num.$PROJECT_NAME.local:8545"
    else
        # Via ALB (if configured)
        endpoint="$ALB_ENDPOINT/rpc/validator-$validator_num"
    fi

    log_info "Checking validator-$validator_num RPC..."

    # Test eth_blockNumber
    RESPONSE=$(rpc_call "$endpoint" "eth_blockNumber")

    if echo "$RESPONSE" | jq -e '.result' >/dev/null 2>&1; then
        BLOCK_HEX=$(echo "$RESPONSE" | jq -r '.result')
        BLOCK_NUM=$((16#${BLOCK_HEX#0x}))

        if [ "$BLOCK_NUM" -gt 0 ]; then
            log_success "  RPC responding - Current block: $BLOCK_NUM"
            eval "BLOCK_$validator_num=$BLOCK_NUM"
            return 0
        else
            log_warn "  RPC responding but stuck at block 0"
            return 1
        fi
    else
        log_error "  RPC not responding"
        return 1
    fi
}

# Check peer count
check_peer_count() {
    local validator_num=$1
    local endpoint

    if [ "$USE_INTERNAL" = true ]; then
        endpoint="http://$PROJECT_NAME-besu-validator-$validator_num.$PROJECT_NAME.local:8545"
    else
        endpoint="$ALB_ENDPOINT/rpc/validator-$validator_num"
    fi

    RESPONSE=$(rpc_call "$endpoint" "net_peerCount")

    if echo "$RESPONSE" | jq -e '.result' >/dev/null 2>&1; then
        PEER_HEX=$(echo "$RESPONSE" | jq -r '.result')
        PEER_COUNT=$((16#${PEER_HEX#0x}))

        if [ "$PEER_COUNT" -eq $((VALIDATOR_COUNT - 1)) ]; then
            log_success "  Peers: $PEER_COUNT/$((VALIDATOR_COUNT - 1)) (all validators connected)"
        elif [ "$PEER_COUNT" -gt 0 ]; then
            log_warn "  Peers: $PEER_COUNT/$((VALIDATOR_COUNT - 1)) (partial connectivity)"
        else
            log_error "  Peers: 0 (no connections)"
        fi
    else
        log_error "  Failed to get peer count"
    fi
}

# Check if blocks are progressing
check_block_progression() {
    log_info "Checking if blocks are progressing..."

    local endpoint
    if [ "$USE_INTERNAL" = true ]; then
        endpoint="http://$PROJECT_NAME-besu-validator-1.$PROJECT_NAME.local:8545"
    else
        endpoint="$ALB_ENDPOINT/rpc/validator-1"
    fi

    # Get initial block
    RESPONSE=$(rpc_call "$endpoint" "eth_blockNumber")
    BLOCK1_HEX=$(echo "$RESPONSE" | jq -r '.result // "0x0"')
    BLOCK1=$((16#${BLOCK1_HEX#0x}))

    log_info "  Initial block: $BLOCK1"
    log_info "  Waiting 10 seconds..."
    sleep 10

    # Get block after wait
    RESPONSE=$(rpc_call "$endpoint" "eth_blockNumber")
    BLOCK2_HEX=$(echo "$RESPONSE" | jq -r '.result // "0x0"')
    BLOCK2=$((16#${BLOCK2_HEX#0x}))

    log_info "  Block after 10s: $BLOCK2"

    if [ "$BLOCK2" -gt "$BLOCK1" ]; then
        BLOCKS_MINED=$((BLOCK2 - BLOCK1))
        log_success "  ✅ Consensus working! Mined $BLOCKS_MINED blocks in 10 seconds"
        return 0
    else
        log_error "  ✗ No blocks mined (consensus NOT working)"
        return 1
    fi
}

# Check validator status
check_validator_status() {
    local endpoint
    if [ "$USE_INTERNAL" = true ]; then
        endpoint="http://$PROJECT_NAME-besu-validator-1.$PROJECT_NAME.local:8545"
    else
        endpoint="$ALB_ENDPOINT/rpc/validator-1"
    fi

    log_info "Checking validator set..."

    # Get latest block with full transactions
    RESPONSE=$(rpc_call "$endpoint" "eth_getBlockByNumber" '["latest", true]')

    if echo "$RESPONSE" | jq -e '.result.miner' >/dev/null 2>&1; then
        MINER=$(echo "$RESPONSE" | jq -r '.result.miner')
        log_success "  Latest block mined by: $MINER"
    else
        log_warn "  Could not determine miner"
    fi
}

# Check ECS task status
check_ecs_tasks() {
    log_info "Checking ECS task status..."

    CLUSTER_NAME=$(aws ecs list-clusters \
        --region "$AWS_REGION" \
        --query "clusterArns[?contains(@, '$PROJECT_NAME')]" \
        --output text | awk -F'/' '{print $NF}')

    if [ -z "$CLUSTER_NAME" ]; then
        log_error "ECS cluster not found"
        return 1
    fi

    for i in $(seq 1 $VALIDATOR_COUNT); do
        SERVICE_NAME="$PROJECT_NAME-besu-validator-$i"

        RUNNING_COUNT=$(aws ecs describe-services \
            --region "$AWS_REGION" \
            --cluster "$CLUSTER_NAME" \
            --services "$SERVICE_NAME" \
            --query 'services[0].runningCount' \
            --output text 2>/dev/null || echo "0")

        DESIRED_COUNT=$(aws ecs describe-services \
            --region "$AWS_REGION" \
            --cluster "$CLUSTER_NAME" \
            --services "$SERVICE_NAME" \
            --query 'services[0].desiredCount' \
            --output text 2>/dev/null || echo "0")

        if [ "$RUNNING_COUNT" = "$DESIRED_COUNT" ] && [ "$RUNNING_COUNT" != "0" ]; then
            log_success "  validator-$i: $RUNNING_COUNT/$DESIRED_COUNT tasks running"
        else
            log_error "  validator-$i: $RUNNING_COUNT/$DESIRED_COUNT tasks running"
        fi
    done
}

# Check CloudWatch logs for errors
check_logs_for_errors() {
    log_info "Checking recent logs for errors..."

    LOG_GROUP="/ecs/$PROJECT_NAME/besu-validator-1"

    ERRORS=$(aws logs filter-log-events \
        --region "$AWS_REGION" \
        --log-group-name "$LOG_GROUP" \
        --filter-pattern "ERROR" \
        --max-items 5 \
        --query 'events[].message' \
        --output text 2>/dev/null || echo "")

    if [ -z "$ERRORS" ]; then
        log_success "  No recent errors in logs"
    else
        log_warn "  Recent errors found:"
        echo "$ERRORS" | head -5 | sed 's/^/    /'
    fi
}

# Generate report
generate_report() {
    local output_file="$1"

    cat > "$output_file" <<EOF
# Besu Network Verification Report

**Timestamp**: $(date)
**Project**: $PROJECT_NAME
**Region**: $AWS_REGION

## Summary

EOF

    if [ "$CONSENSUS_WORKING" = true ]; then
        echo "✅ **Status**: Consensus is WORKING" >> "$output_file"
    else
        echo "❌ **Status**: Consensus is NOT WORKING" >> "$output_file"
    fi

    cat >> "$output_file" <<EOF

## Details

### RPC Endpoints

EOF

    for i in $(seq 1 $VALIDATOR_COUNT); do
        eval "BLOCK=\$BLOCK_$i"
        if [ -n "$BLOCK" ]; then
            echo "- Validator $i: Block $BLOCK ✅" >> "$output_file"
        else
            echo "- Validator $i: Not responding ❌" >> "$output_file"
        fi
    done

    cat >> "$output_file" <<EOF

### Next Steps

EOF

    if [ "$CONSENSUS_WORKING" = true ]; then
        cat >> "$output_file" <<EOF
Network is operational. You can now:
1. Deploy smart contracts
2. Configure application services
3. Run end-to-end tests
EOF
    else
        cat >> "$output_file" <<EOF
Troubleshooting required:
1. Check ECS task logs: \`aws logs tail /ecs/$PROJECT_NAME/besu-validator-1 --follow\`
2. Verify keys uploaded to EFS correctly
3. Check static-nodes.json has correct enodes
4. Verify security groups allow P2P traffic (port 30303)
5. Check CloudWatch for errors
EOF
    fi
}

# Main
main() {
    echo ""
    echo "=========================================="
    echo "  Besu Network Verification"
    echo "=========================================="
    echo ""

    CONSENSUS_WORKING=false

    get_alb_endpoint
    echo ""

    check_ecs_tasks
    echo ""

    # Check each validator
    for i in $(seq 1 $VALIDATOR_COUNT); do
        check_validator_rpc "$i"
        check_peer_count "$i"
        echo ""
    done

    check_block_progression && CONSENSUS_WORKING=true
    echo ""

    check_validator_status
    echo ""

    check_logs_for_errors
    echo ""

    # Generate report
    REPORT_FILE="besu-verification-report-$(date +%Y%m%d-%H%M%S).md"
    generate_report "$REPORT_FILE"

    log_success "Report saved to: $REPORT_FILE"
    echo ""

    if [ "$CONSENSUS_WORKING" = true ]; then
        log_success "🎉 Network is operational!"
    else
        log_error "❌ Network is not working. Check logs for details."
        exit 1
    fi
}

main "$@"
