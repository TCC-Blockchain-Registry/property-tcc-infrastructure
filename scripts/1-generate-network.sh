#!/bin/bash
#
# generate-besu-network.sh
#
# Generates a complete Besu QBFT network configuration for AWS deployment
# - Generates 4 validator key pairs
# - Updates static-nodes.json with real enodes
# - Regenerates genesis.json with correct extraData
# - Fixes all config.toml port conflicts
# - Prepares keys for EFS upload
#
# Requirements: besu CLI installed (https://besu.hyperledger.org)
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BESU_AWS_DIR="$(cd "$SCRIPT_DIR/../besu-aws" && pwd)"
KEYS_OUTPUT_DIR="$SCRIPT_DIR/besu-keys-generated"
TEMP_DIR=$(mktemp -d)

# AWS Configuration
PROJECT_NAME="property-tcc"
CLOUD_MAP_DOMAIN="property-tcc.local"

# Validator count
VALIDATOR_COUNT=4

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v besu &> /dev/null; then
        log_error "Besu CLI not found. Install from: https://besu.hyperledger.org"
        log_error "Or via Homebrew: brew install hyperledger/besu/besu"
        exit 1
    fi

    BESU_VERSION=$(besu --version | head -n1 | awk '{print $2}')
    log_success "Besu CLI found: version $BESU_VERSION"

    if ! command -v jq &> /dev/null; then
        log_error "jq not found. Install via: brew install jq"
        exit 1
    fi

    if ! command -v python3 &> /dev/null; then
        log_error "python3 not found. Please install Python 3"
        exit 1
    fi

    log_success "All prerequisites met"
}

# Generate validator keys
generate_keys() {
    log_info "Generating $VALIDATOR_COUNT validator key pairs..."

    mkdir -p "$KEYS_OUTPUT_DIR"

    for i in $(seq 1 $VALIDATOR_COUNT); do
        VALIDATOR_DIR="$KEYS_OUTPUT_DIR/validator-$i"
        mkdir -p "$VALIDATOR_DIR/key"

        log_info "  Generating key for validator-$i..."

        # Generate key using Besu
        besu --data-path="$VALIDATOR_DIR" \
             public-key export \
             --to="$VALIDATOR_DIR/public-key" \
             2>/dev/null || true

        # Export address
        besu --data-path="$VALIDATOR_DIR" \
             public-key export-address \
             --to="$VALIDATOR_DIR/address" \
             2>/dev/null || true

        if [ ! -f "$VALIDATOR_DIR/key/key" ]; then
            log_error "Failed to generate key for validator-$i"
            exit 1
        fi

        # Read generated values
        PUBKEY=$(cat "$VALIDATOR_DIR/public-key" 2>/dev/null || echo "")
        ADDRESS=$(cat "$VALIDATOR_DIR/address" 2>/dev/null || echo "")

        # Store in arrays for later use
        eval "PUBKEY_$i=\"$PUBKEY\""
        eval "ADDRESS_$i=\"$ADDRESS\""

        log_success "    Public Key: $PUBKEY"
        log_success "    Address: $ADDRESS"
    done

    log_success "All validator keys generated successfully"
}

# Update static-nodes.json
update_static_nodes() {
    log_info "Updating static-nodes.json.template..."

    STATIC_NODES_FILE="$BESU_AWS_DIR/static-nodes.json.template"

    cat > "$STATIC_NODES_FILE" <<EOF
[
  "enode://${PUBKEY_1}@${PROJECT_NAME}-besu-validator-1.${CLOUD_MAP_DOMAIN}:30303",
  "enode://${PUBKEY_2}@${PROJECT_NAME}-besu-validator-2.${CLOUD_MAP_DOMAIN}:30303",
  "enode://${PUBKEY_3}@${PROJECT_NAME}-besu-validator-3.${CLOUD_MAP_DOMAIN}:30303",
  "enode://${PUBKEY_4}@${PROJECT_NAME}-besu-validator-4.${CLOUD_MAP_DOMAIN}:30303"
]
EOF

    log_success "static-nodes.json.template updated with real enodes"
    log_info "  All validators now use port 30303 (matching ECS portMappings)"
}

# Generate genesis extraData
generate_extra_data() {
    log_info "Generating genesis extraData..."

    # Create Python script to generate RLP-encoded extraData
    python3 - <<PYTHON_SCRIPT
import sys

# Install rlp if needed
try:
    import rlp
except ImportError:
    print("Installing rlp library...", file=sys.stderr)
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", "rlp"])
    import rlp

# Validator addresses (without 0x prefix)
addresses = [
    "${ADDRESS_1#0x}",
    "${ADDRESS_2#0x}",
    "${ADDRESS_3#0x}",
    "${ADDRESS_4#0x}"
]

# Convert hex addresses to bytes
address_bytes = [bytes.fromhex(addr) for addr in addresses]

# QBFT extraData format:
# [vanity (32 bytes), validators (RLP list), proposal_seal, committed_seals, round_number]
vanity = bytes(32)  # 32 zero bytes
validators = address_bytes
proposal_seal = b''  # Empty for genesis
committed_seals = []  # Empty list for genesis
round_number = b''  # Empty for genesis

# Encode
extra_data_list = [vanity, validators, proposal_seal, committed_seals, round_number]
encoded = rlp.encode(extra_data_list)

# Output as hex
print("0x" + encoded.hex())
PYTHON_SCRIPT
}

# Update genesis.json
update_genesis() {
    log_info "Updating genesis.json with new extraData..."

    GENESIS_FILE="$BESU_AWS_DIR/genesis.json"
    EXTRA_DATA=$(generate_extra_data)

    if [ -z "$EXTRA_DATA" ] || [ "$EXTRA_DATA" = "0x" ]; then
        log_error "Failed to generate extraData"
        exit 1
    fi

    log_success "  Generated extraData: $EXTRA_DATA"

    # Update genesis.json using jq
    jq --arg extraData "$EXTRA_DATA" \
       '.extraData = $extraData' \
       "$GENESIS_FILE" > "$GENESIS_FILE.tmp"

    mv "$GENESIS_FILE.tmp" "$GENESIS_FILE"

    log_success "genesis.json updated successfully"
}

# Fix config.toml port conflicts
fix_config_toml() {
    local validator_num=$1
    local address=$2
    local config_file="$BESU_AWS_DIR/config/validator-$validator_num/config.toml"

    log_info "  Fixing validator-$validator_num config.toml..."

    # Create updated config
    cat > "$config_file" <<EOF
# Besu Validator $validator_num Configuration
# Auto-generated by generate-besu-network.sh

# Data directory
data-path="/opt/besu/data"

# Genesis file
genesis-file="/opt/besu/genesis.json"

# Network settings
network-id=1337
p2p-host="0.0.0.0"
p2p-port=30303
max-peers=25

# RPC settings (normalized for ECS)
rpc-http-enabled=true
rpc-http-host="0.0.0.0"
rpc-http-port=8545
rpc-http-api=["ETH","NET","WEB3","ADMIN","DEBUG","TXPOOL"]
rpc-http-cors-origins=["*"]

# WebSocket settings
rpc-ws-enabled=true
rpc-ws-host="0.0.0.0"
rpc-ws-port=8546
rpc-ws-api=["ETH","NET","WEB3"]

# Mining (validator)
miner-enabled=true
miner-coinbase="$address"

# Static nodes
static-nodes-file="/opt/besu/data/static-nodes.json"

# Consensus
min-gas-price=0

# Logging
logging="INFO"

# Host allowlist
host-allowlist=["*"]
EOF

    log_success "    ✅ Ports normalized: RPC=8545, WS=8546, P2P=30303"
    log_success "    ✅ Coinbase updated: $address"
}

# Fix all config files
fix_all_configs() {
    log_info "Fixing all config.toml files..."

    for i in $(seq 1 $VALIDATOR_COUNT); do
        eval "ADDRESS=\$ADDRESS_$i"
        fix_config_toml "$i" "$ADDRESS"
    done

    log_success "All config.toml files fixed"
}

# Create EFS upload structure
prepare_efs_structure() {
    log_info "Preparing EFS upload structure..."

    EFS_STRUCTURE_DIR="$KEYS_OUTPUT_DIR/efs-upload"
    mkdir -p "$EFS_STRUCTURE_DIR"

    for i in $(seq 1 $VALIDATOR_COUNT); do
        VALIDATOR_EFS_DIR="$EFS_STRUCTURE_DIR/validator-$i"
        mkdir -p "$VALIDATOR_EFS_DIR/key"

        # Copy key
        cp "$KEYS_OUTPUT_DIR/validator-$i/key/key" "$VALIDATOR_EFS_DIR/key/key"

        # Copy static-nodes.json
        cp "$BESU_AWS_DIR/static-nodes.json.template" "$VALIDATOR_EFS_DIR/static-nodes.json"

        # Set permissions (besu user = uid/gid 1000)
        chmod 600 "$VALIDATOR_EFS_DIR/key/key"
        chmod 755 "$VALIDATOR_EFS_DIR"
        chmod 644 "$VALIDATOR_EFS_DIR/static-nodes.json"
    done

    log_success "EFS upload structure created at: $EFS_STRUCTURE_DIR"
}

# Generate summary report
generate_summary() {
    log_info "Generating configuration summary..."

    SUMMARY_FILE="$KEYS_OUTPUT_DIR/NETWORK_SUMMARY.md"

    cat > "$SUMMARY_FILE" <<EOF
# Besu Network Configuration Summary

**Generated**: $(date)
**Project**: $PROJECT_NAME
**Validators**: $VALIDATOR_COUNT

## Validator Information

EOF

    for i in $(seq 1 $VALIDATOR_COUNT); do
        eval "PUBKEY=\$PUBKEY_$i"
        eval "ADDRESS=\$ADDRESS_$i"

        cat >> "$SUMMARY_FILE" <<EOF
### Validator $i
- **Address**: \`$ADDRESS\`
- **Public Key**: \`$PUBKEY\`
- **Enode**: \`enode://$PUBKEY@$PROJECT_NAME-besu-validator-$i.$CLOUD_MAP_DOMAIN:30303\`
- **RPC Port**: 8545 (normalized)
- **WebSocket Port**: 8546 (normalized)
- **P2P Port**: 30303 (normalized)

EOF
    done

    cat >> "$SUMMARY_FILE" <<EOF
## Files Updated

- ✅ \`besu-aws/static-nodes.json.template\` - Real enodes with correct ports
- ✅ \`besu-aws/genesis.json\` - Updated extraData with validator addresses
- ✅ \`besu-aws/config/validator-{1-4}/config.toml\` - Fixed port conflicts and coinbase addresses

## Next Steps

1. **Rebuild Docker Image**:
   \`\`\`bash
   cd besu-property-ledger
   docker build -t besu-validator:latest .
   \`\`\`

2. **Upload Keys to EFS** (after \`terraform apply\`):
   \`\`\`bash
   ./scripts/upload-keys-to-efs.sh
   \`\`\`

3. **Deploy to AWS**:
   \`\`\`bash
   cd terraform-aws
   terraform apply
   \`\`\`

4. **Verify Consensus**:
   \`\`\`bash
   ./scripts/verify-besu-config.sh
   \`\`\`

## Security Notes

⚠️ **IMPORTANT**: Private keys are stored in:
- \`$KEYS_OUTPUT_DIR/validator-{1-4}/key/key\`

**DO NOT commit these to git!**
**DO NOT share these keys!**

These keys control validator identities on the blockchain.

## Troubleshooting

If validators don't form consensus:

1. Check logs: \`docker logs <container>\`
2. Verify peer count: \`curl http://localhost:8545 -d '{"method":"net_peerCount","id":1}'\`
3. Check static-nodes.json loaded: Look for "StaticNodesParserTask" in logs
4. Verify addresses match genesis: Compare miner-coinbase to genesis extraData

EOF

    log_success "Summary report saved to: $SUMMARY_FILE"
}

# Cleanup
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

# Main execution
main() {
    echo ""
    echo "=========================================="
    echo "  Besu QBFT Network Generator for AWS"
    echo "=========================================="
    echo ""

    check_prerequisites
    echo ""

    generate_keys
    echo ""

    update_static_nodes
    echo ""

    update_genesis
    echo ""

    fix_all_configs
    echo ""

    prepare_efs_structure
    echo ""

    generate_summary
    echo ""

    log_success "✅ Network configuration complete!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_info "Generated files location:"
    echo "  📁 Keys: $KEYS_OUTPUT_DIR"
    echo "  📄 Summary: $KEYS_OUTPUT_DIR/NETWORK_SUMMARY.md"
    echo ""
    log_warn "⚠️  SECURITY: Keep private keys secure!"
    echo ""
    log_info "Next steps:"
    echo "  1. Review: cat $KEYS_OUTPUT_DIR/NETWORK_SUMMARY.md"
    echo "  2. Rebuild Besu image with updated configs"
    echo "  3. Run terraform apply"
    echo "  4. Upload keys to EFS using upload-keys-to-efs.sh"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

main "$@"
