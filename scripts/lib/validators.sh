#!/bin/bash
#
# validators.sh
#
# Validation functions for prerequisites and configurations
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check all prerequisites
check_prerequisites() {
    log_header "Checking Prerequisites"

    local all_ok=true

    # Besu CLI
    if command_exists besu; then
        local besu_version=$(besu --version 2>&1 | head -n1 || echo "unknown")
        log_success "Besu CLI: $besu_version"
    else
        log_error "Besu CLI not found. Install: brew install hyperledger/besu/besu"
        all_ok=false
    fi

    # jq
    if command_exists jq; then
        local jq_version=$(jq --version 2>&1 || echo "unknown")
        log_success "jq: $jq_version"
    else
        log_error "jq not found. Install: brew install jq"
        all_ok=false
    fi

    # Python 3
    if command_exists python3; then
        local python_version=$(python3 --version 2>&1 || echo "unknown")
        log_success "Python 3: $python_version"

        # Check for rlp library
        if python3 -c "import rlp" 2>/dev/null; then
            log_success "Python rlp library: installed"
        else
            log_warn "Python rlp library not found. Will be installed automatically if needed."
        fi
    else
        log_error "Python 3 not found. Install: brew install python3"
        all_ok=false
    fi

    # AWS CLI
    if command_exists aws; then
        local aws_version=$(aws --version 2>&1 | cut -d' ' -f1 || echo "unknown")
        log_success "AWS CLI: $aws_version"

        # Check AWS credentials
        if aws sts get-caller-identity &>/dev/null; then
            local aws_account=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown")
            log_success "AWS credentials: configured (Account: $aws_account)"
        else
            log_error "AWS credentials not configured. Run: aws configure"
            all_ok=false
        fi
    else
        log_error "AWS CLI not found. Install from: https://aws.amazon.com/cli/"
        all_ok=false
    fi

    # Terraform
    if command_exists terraform; then
        local tf_version=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || echo "unknown")
        log_success "Terraform: v$tf_version"
    else
        log_error "Terraform not found. Install: brew install terraform"
        all_ok=false
    fi

    # Docker
    if command_exists docker; then
        local docker_version=$(docker --version 2>&1 | cut -d' ' -f3 | tr -d ',' || echo "unknown")
        log_success "Docker: v$docker_version"

        # Check if Docker daemon is running
        if docker ps &>/dev/null; then
            log_success "Docker daemon: running"
        else
            log_warn "Docker daemon not running. Start Docker Desktop."
        fi
    else
        log_error "Docker not found. Install Docker Desktop."
        all_ok=false
    fi

    echo ""

    if [ "$all_ok" = true ]; then
        log_success "All prerequisites met!"
        return 0
    else
        log_error "Some prerequisites are missing. Please install them and try again."
        return 1
    fi
}

# Validate Besu configuration
validate_besu_config() {
    log_header "Validating Besu Configuration"

    local all_ok=true
    local base_dir="/Users/leonardodev/tcc/infrastructure"

    # Check config.toml ports
    for i in {1..4}; do
        local config_file="$base_dir/besu-aws/config/validator-$i/config.toml"

        if [ ! -f "$config_file" ]; then
            log_error "Config file not found: $config_file"
            all_ok=false
            continue
        fi

        local rpc_port=$(grep "rpc-http-port=" "$config_file" | cut -d'=' -f2)
        local p2p_port=$(grep "p2p-port=" "$config_file" | cut -d'=' -f2)

        if [ "$rpc_port" != "8545" ]; then
            log_error "Validator $i: RPC port is $rpc_port (should be 8545)"
            all_ok=false
        else
            log_success "Validator $i: RPC port = 8545"
        fi

        if [ "$p2p_port" != "30303" ]; then
            log_error "Validator $i: P2P port is $p2p_port (should be 30303)"
            all_ok=false
        else
            log_success "Validator $i: P2P port = 30303"
        fi
    done

    # Check static-nodes.json
    local static_nodes="$base_dir/besu-aws/static-nodes.json.template"

    if [ ! -f "$static_nodes" ]; then
        log_error "static-nodes.json.template not found"
        all_ok=false
    else
        if grep -q "NODE1_PUBKEY" "$static_nodes"; then
            log_error "static-nodes.json.template still has placeholders (NODEx_PUBKEY)"
            all_ok=false
        else
            log_success "static-nodes.json.template: has real public keys"
        fi
    fi

    # Check generated keys
    local generated_dir="$base_dir/scripts/generated"

    if [ -d "$generated_dir" ]; then
        local key_count=$(find "$generated_dir" -name "key" -type f 2>/dev/null | wc -l)

        if [ "$key_count" -eq 4 ]; then
            log_success "Generated keys: 4 validators found"
        else
            log_warn "Generated keys: found $key_count validators (expected 4)"
        fi
    else
        log_warn "Generated keys directory not found. Run: ./scripts/1-generate-network.sh"
    fi

    echo ""

    if [ "$all_ok" = true ]; then
        log_success "Besu configuration is valid!"
        return 0
    else
        log_error "Besu configuration has errors. Please fix them."
        return 1
    fi
}

# Validate AWS secrets exist
validate_aws_secrets() {
    log_header "Validating AWS Secrets"

    local all_ok=true
    local project_name="property-tcc"

    local secrets=(
        "$project_name/besu/admin-private-key"
        "$project_name/besu/orchestrator-private-key"
        "$project_name/besu/registrar-private-key"
    )

    for secret_name in "${secrets[@]}"; do
        if aws secretsmanager describe-secret --secret-id "$secret_name" &>/dev/null; then
            log_success "Secret exists: $secret_name"
        else
            log_error "Secret not found: $secret_name"
            all_ok=false
        fi
    done

    echo ""

    if [ "$all_ok" = true ]; then
        log_success "All required secrets exist!"
        return 0
    else
        log_error "Some secrets are missing. Run: ./scripts/2-create-secrets.sh"
        return 1
    fi
}

# Validate EFS state
validate_efs() {
    log_header "Validating EFS"

    local project_name="property-tcc"

    local efs_id=$(aws efs describe-file-systems \
        --query "FileSystems[?Name=='$project_name-besu-data'].FileSystemId" \
        --output text 2>/dev/null || echo "")

    if [ -z "$efs_id" ]; then
        log_warn "EFS filesystem not found. Run terraform apply first."
        return 1
    else
        log_success "EFS filesystem: $efs_id"

        # Check access points
        local ap_count=$(aws efs describe-access-points \
            --file-system-id "$efs_id" \
            --query "length(AccessPoints)" \
            --output text 2>/dev/null || echo "0")

        if [ "$ap_count" -eq 4 ]; then
            log_success "EFS access points: $ap_count validators"
        else
            log_warn "EFS access points: found $ap_count (expected 4)"
        fi
    fi

    echo ""
    return 0
}
