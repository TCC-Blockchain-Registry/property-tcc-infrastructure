#!/bin/bash
#
# 2-create-secrets.sh
#
# Generates Ethereum private keys and creates AWS Secrets Manager secrets
# Must be run BEFORE terraform apply
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"

PROJECT_NAME="property-tcc"
AWS_REGION="us-east-1"

# Generate random Ethereum private key
generate_private_key() {
    # Generate 32 random bytes and convert to hex
    local key="0x$(openssl rand -hex 32)"
    echo "$key"
}

# Derive Ethereum address from private key
derive_address() {
    local private_key=$1
    # Remove 0x prefix
    local key_no_prefix="${private_key#0x}"

    # Use Python to derive address (requires eth-keys or web3)
    python3 -c "
try:
    from eth_keys import keys
    pk = keys.PrivateKey(bytes.fromhex('$key_no_prefix'))
    print('0x' + pk.public_key.to_address())
except ImportError:
    print('Install eth-keys: pip3 install eth-keys')
    exit(1)
" 2>/dev/null || echo "ERROR: Install eth-keys library"
}

main() {
    log_header "Besu Private Keys Generator"

    # Check if eth-keys is installed
    if ! python3 -c "import eth_keys" 2>/dev/null; then
        log_warn "Python library 'eth-keys' not found"
        log_info "Installing eth-keys..."
        pip3 install -q eth-keys
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity &>/dev/null; then
        log_error "AWS credentials not configured. Run: aws configure"
        exit 1
    fi

    log_success "AWS credentials configured"
    echo ""

    # Generate keys
    log_step "Generating 3 Ethereum private keys..."
    echo ""

    ADMIN_KEY=$(generate_private_key)
    ADMIN_ADDR=$(derive_address "$ADMIN_KEY")

    ORCHESTRATOR_KEY=$(generate_private_key)
    ORCHESTRATOR_ADDR=$(derive_address "$ORCHESTRATOR_KEY")

    REGISTRAR_KEY=$(generate_private_key)
    REGISTRAR_ADDR=$(derive_address "$REGISTRAR_KEY")

    log_success "Keys generated successfully!"
    echo ""

    # Display keys
    log_header "Generated Keys"
    echo -e "${CYAN}Admin Role:${NC}"
    echo "  Private Key: $ADMIN_KEY"
    echo "  Address:     $ADMIN_ADDR"
    echo ""

    echo -e "${CYAN}Orchestrator Role:${NC}"
    echo "  Private Key: $ORCHESTRATOR_KEY"
    echo "  Address:     $ORCHESTRATOR_ADDR"
    echo ""

    echo -e "${CYAN}Registrar Role:${NC}"
    echo "  Private Key: $REGISTRAR_KEY"
    echo "  Address:     $REGISTRAR_ADDR"
    echo ""

    # Save to file
    KEYS_FILE="$SCRIPT_DIR/generated/private-keys.txt"
    mkdir -p "$SCRIPT_DIR/generated"

    cat > "$KEYS_FILE" <<EOF
# Besu Private Keys
# Generated: $(date)
# DO NOT COMMIT THIS FILE TO GIT!

ADMIN_PRIVATE_KEY=$ADMIN_KEY
ADMIN_ADDRESS=$ADMIN_ADDR

ORCHESTRATOR_PRIVATE_KEY=$ORCHESTRATOR_KEY
ORCHESTRATOR_ADDRESS=$ORCHESTRATOR_ADDR

REGISTRAR_PRIVATE_KEY=$REGISTRAR_KEY
REGISTRAR_ADDRESS=$REGISTRAR_ADDR
EOF

    log_success "Keys saved to: $KEYS_FILE"
    log_warn "IMPORTANT: Keep this file secure and do NOT commit to git!"
    echo ""

    # Create AWS secrets
    log_header "Creating AWS Secrets"
    echo ""

    if ! confirm "Create secrets in AWS Secrets Manager?" "y"; then
        log_warn "Skipped AWS Secrets creation"
        log_info "You can create them manually later with these commands:"
        echo ""
        echo "aws secretsmanager create-secret \\"
        echo "  --name $PROJECT_NAME/besu/admin-private-key \\"
        echo "  --secret-string \"$ADMIN_KEY\" \\"
        echo "  --region $AWS_REGION"
        echo ""
        echo "aws secretsmanager create-secret \\"
        echo "  --name $PROJECT_NAME/besu/orchestrator-private-key \\"
        echo "  --secret-string \"$ORCHESTRATOR_KEY\" \\"
        echo "  --region $AWS_REGION"
        echo ""
        echo "aws secretsmanager create-secret \\"
        echo "  --name $PROJECT_NAME/besu/registrar-private-key \\"
        echo "  --secret-string \"$REGISTRAR_KEY\" \\"
        echo "  --region $AWS_REGION"
        echo ""
        exit 0
    fi

    echo ""

    # Create Admin secret
    log_info "Creating admin-private-key secret..."
    if aws secretsmanager create-secret \
        --name "$PROJECT_NAME/besu/admin-private-key" \
        --secret-string "$ADMIN_KEY" \
        --region "$AWS_REGION" \
        &>/dev/null; then
        log_success "Created: $PROJECT_NAME/besu/admin-private-key"
    else
        if aws secretsmanager update-secret \
            --secret-id "$PROJECT_NAME/besu/admin-private-key" \
            --secret-string "$ADMIN_KEY" \
            --region "$AWS_REGION" \
            &>/dev/null; then
            log_success "Updated: $PROJECT_NAME/besu/admin-private-key"
        else
            log_error "Failed to create/update admin-private-key"
        fi
    fi

    # Create Orchestrator secret
    log_info "Creating orchestrator-private-key secret..."
    if aws secretsmanager create-secret \
        --name "$PROJECT_NAME/besu/orchestrator-private-key" \
        --secret-string "$ORCHESTRATOR_KEY" \
        --region "$AWS_REGION" \
        &>/dev/null; then
        log_success "Created: $PROJECT_NAME/besu/orchestrator-private-key"
    else
        if aws secretsmanager update-secret \
            --secret-id "$PROJECT_NAME/besu/orchestrator-private-key" \
            --secret-string "$ORCHESTRATOR_KEY" \
            --region "$AWS_REGION" \
            &>/dev/null; then
            log_success "Updated: $PROJECT_NAME/besu/orchestrator-private-key"
        else
            log_error "Failed to create/update orchestrator-private-key"
        fi
    fi

    # Create Registrar secret
    log_info "Creating registrar-private-key secret..."
    if aws secretsmanager create-secret \
        --name "$PROJECT_NAME/besu/registrar-private-key" \
        --secret-string "$REGISTRAR_KEY" \
        --region "$AWS_REGION" \
        &>/dev/null; then
        log_success "Created: $PROJECT_NAME/besu/registrar-private-key"
    else
        if aws secretsmanager update-secret \
            --secret-id "$PROJECT_NAME/besu/registrar-private-key" \
            --secret-string "$REGISTRAR_KEY" \
            --region "$AWS_REGION" \
            &>/dev/null; then
            log_success "Updated: $PROJECT_NAME/besu/registrar-private-key"
        else
            log_error "Failed to create/update registrar-private-key"
        fi
    fi

    echo ""
    log_success "✅ All secrets created successfully!"
    echo ""

    log_info "Next steps:"
    echo "  1. Review generated keys in: $KEYS_FILE"
    echo "  2. Run: ./scripts/3-terraform-deploy.sh"
}

main "$@"
