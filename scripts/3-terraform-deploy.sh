#!/bin/bash
#
# 3-terraform-deploy.sh
#
# Intelligent Terraform wrapper for deploying AWS infrastructure
# Validates prerequisites, creates tfvars if needed, and executes terraform
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/validators.sh"

TERRAFORM_DIR="/Users/leonardodev/tcc/infrastructure/terraform-aws"
PROJECT_NAME="property-tcc"
AWS_REGION="us-east-1"

# Check if terraform.tfvars exists
check_tfvars() {
    if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
        log_warn "terraform.tfvars not found"

        if confirm "Create terraform.tfvars from example?" "y"; then
            if [ ! -f "$TERRAFORM_DIR/terraform.tfvars.example" ]; then
                log_info "Creating terraform.tfvars.example..."
                create_tfvars_example
            fi

            cp "$TERRAFORM_DIR/terraform.tfvars.example" "$TERRAFORM_DIR/terraform.tfvars"
            log_success "Created terraform.tfvars"
            log_warn "Please review and edit terraform.tfvars before continuing"

            if ! confirm "Continue with terraform init/plan/apply?" "n"; then
                log_info "Exiting. Edit terraform.tfvars and run this script again."
                exit 0
            fi
        else
            log_error "terraform.tfvars is required. Create it manually or run this script again."
            exit 1
        fi
    else
        log_success "terraform.tfvars exists"
    fi
}

# Create terraform.tfvars.example
create_tfvars_example() {
    cat > "$TERRAFORM_DIR/terraform.tfvars.example" <<'EOF'
# Project Configuration
project_name = "property-tcc"
aws_region   = "us-east-1"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"

# Availability Zones
availability_zones = ["us-east-1a", "us-east-1b"]

# Besu Validators
besu_validator_count = 4

# RDS Configuration
db_instance_class = "db.t3.micro"
db_allocated_storage = 20

# ECS Task Sizes
frontend_cpu    = 256
frontend_memory = 512

orchestrator_cpu    = 512
orchestrator_memory = 1024

offchain_cpu    = 512
offchain_memory = 1024

# Contract Addresses (leave empty on first deploy)
# After deploying contracts, update these values and re-run terraform apply
property_title_address = ""
approvals_module_address = ""
registry_md_address = ""
identity_registry_address = ""
identity_registry_storage_address = ""
compliance_address = ""
trusted_issuers_registry_address = ""
claim_topics_registry_address = ""
EOF

    log_success "Created terraform.tfvars.example"
}

# Run terraform
run_terraform() {
    local action="${1:-apply}"

    cd "$TERRAFORM_DIR"

    log_step "Running: terraform $action"
    echo ""

    case "$action" in
        init)
            terraform init
            ;;
        plan)
            terraform plan
            ;;
        apply)
            terraform apply
            ;;
        destroy)
            log_warn "This will destroy ALL infrastructure!"
            if confirm "Are you absolutely sure?" "n"; then
                terraform destroy
            else
                log_info "Destroy cancelled"
                exit 0
            fi
            ;;
        *)
            log_error "Unknown action: $action"
            exit 1
            ;;
    esac
}

# Capture outputs
capture_outputs() {
    log_step "Capturing Terraform outputs..."

    cd "$TERRAFORM_DIR"

    local output_file="$SCRIPT_DIR/generated/terraform-outputs.json"
    terraform output -json > "$output_file" 2>/dev/null || true

    if [ -f "$output_file" ]; then
        log_success "Outputs saved to: $output_file"

        # Display important outputs
        echo ""
        log_info "Important outputs:"

        local efs_id=$(terraform output -raw efs_id 2>/dev/null || echo "N/A")
        local alb_dns=$(terraform output -raw alb_dns_name 2>/dev/null || echo "N/A")
        local rds_endpoint=$(terraform output -raw rds_endpoint 2>/dev/null || echo "N/A")

        echo "  EFS ID:       $efs_id"
        echo "  ALB DNS:      $alb_dns"
        echo "  RDS Endpoint: $rds_endpoint"
    fi
}

main() {
    log_header "Terraform Deploy - Property TCC"

    # Check prerequisites
    if ! command_exists terraform; then
        log_error "Terraform not found. Install: brew install terraform"
        exit 1
    fi

    if ! command_exists aws; then
        log_error "AWS CLI not found. Install from: https://aws.amazon.com/cli/"
        exit 1
    fi

    if ! aws sts get-caller-identity &>/dev/null; then
        log_error "AWS credentials not configured. Run: aws configure"
        exit 1
    fi

    log_success "Prerequisites OK"
    echo ""

    # Check tfvars
    check_tfvars
    echo ""

    # Terraform init
    if [ ! -d "$TERRAFORM_DIR/.terraform" ]; then
        log_info "First time setup detected"
        run_terraform "init"
        echo ""
    fi

    # Terraform plan
    log_info "Running terraform plan..."
    if ! confirm "Review plan?" "y"; then
        log_warn "Skipped terraform plan"
    else
        run_terraform "plan"
        echo ""
    fi

    # Terraform apply
    if confirm "Apply infrastructure changes?" "y"; then
        run_terraform "apply"
        echo ""

        # Capture outputs
        capture_outputs
        echo ""

        log_success "✅ Infrastructure deployed successfully!"
        echo ""

        log_info "Next steps:"
        echo "  1. Upload keys to EFS: ./scripts/4-upload-keys.sh"
        echo "  2. Build and push Docker images"
        echo "  3. Deploy smart contracts to Besu"
        echo "  4. Update terraform.tfvars with contract addresses"
        echo "  5. Re-run terraform apply to update Offchain API"
        echo "  6. Verify deployment: ./scripts/5-verify-network.sh"
    else
        log_info "Apply cancelled"
        exit 0
    fi
}

main "$@"
