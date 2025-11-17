#!/bin/bash
#
# upload-keys-to-efs.sh
#
# Uploads Besu validator keys to EFS Access Points
# Must be run AFTER terraform apply creates EFS
#
# Methods:
# 1. Via AWS ECS Exec (recommended - no bastion needed)
# 2. Via EC2 Bastion (if ECS Exec not enabled)
# 3. Via temporary ECS task
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYS_DIR="$SCRIPT_DIR/besu-keys-generated/efs-upload"
PROJECT_NAME="property-tcc"
AWS_REGION="us-east-1"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if [ ! -d "$KEYS_DIR" ]; then
        log_error "Keys directory not found: $KEYS_DIR"
        log_error "Run generate-besu-network.sh first!"
        exit 1
    fi

    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Install from: https://aws.amazon.com/cli/"
        exit 1
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity &>/dev/null; then
        log_error "AWS credentials not configured. Run: aws configure"
        exit 1
    fi

    log_success "Prerequisites met"
}

# Get EFS filesystem ID
get_efs_id() {
    log_info "Finding EFS filesystem..."

    EFS_ID=$(aws efs describe-file-systems \
        --region "$AWS_REGION" \
        --query "FileSystems[?Name=='$PROJECT_NAME-besu-data'].FileSystemId" \
        --output text 2>/dev/null || echo "")

    if [ -z "$EFS_ID" ]; then
        log_error "EFS filesystem not found. Run terraform apply first!"
        exit 1
    fi

    log_success "Found EFS: $EFS_ID"
}

# Method 1: Upload via temporary ECS task (recommended)
upload_via_ecs_task() {
    log_info "Creating temporary ECS task for upload..."

    # Get cluster name
    CLUSTER_NAME=$(aws ecs list-clusters \
        --region "$AWS_REGION" \
        --query "clusterArns[?contains(@, '$PROJECT_NAME')]" \
        --output text | awk -F'/' '{print $NF}')

    if [ -z "$CLUSTER_NAME" ]; then
        log_error "ECS cluster not found"
        return 1
    fi

    log_info "  Cluster: $CLUSTER_NAME"

    # Get subnet (use first private subnet)
    SUBNET_ID=$(aws ec2 describe-subnets \
        --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=$PROJECT_NAME-private-us-east-1a" \
        --query "Subnets[0].SubnetId" \
        --output text)

    # Get security group
    SG_ID=$(aws ec2 describe-security-groups \
        --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=$PROJECT_NAME-efs-sg" \
        --query "SecurityGroups[0].GroupId" \
        --output text)

    log_info "Creating task definition for upload..."

    # Create task definition JSON
    TASK_DEF_JSON=$(cat <<EOF
{
  "family": "$PROJECT_NAME-efs-upload",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [
    {
      "name": "uploader",
      "image": "amazon/aws-cli:latest",
      "essential": true,
      "command": ["sleep", "3600"],
      "mountPoints": [
        {"sourceVolume": "efs-validator-1", "containerPath": "/efs/validator-1"},
        {"sourceVolume": "efs-validator-2", "containerPath": "/efs/validator-2"},
        {"sourceVolume": "efs-validator-3", "containerPath": "/efs/validator-3"},
        {"sourceVolume": "efs-validator-4", "containerPath": "/efs/validator-4"}
      ]
    }
  ],
  "volumes": [
    {
      "name": "efs-validator-1",
      "efsVolumeConfiguration": {
        "fileSystemId": "$EFS_ID",
        "transitEncryption": "ENABLED",
        "authorizationConfig": {
          "accessPointId": "$(aws efs describe-access-points --region $AWS_REGION --query "AccessPoints[?Name=='$PROJECT_NAME-besu-validator-1-ap'].AccessPointId" --output text)"
        }
      }
    },
    {
      "name": "efs-validator-2",
      "efsVolumeConfiguration": {
        "fileSystemId": "$EFS_ID",
        "transitEncryption": "ENABLED",
        "authorizationConfig": {
          "accessPointId": "$(aws efs describe-access-points --region $AWS_REGION --query "AccessPoints[?Name=='$PROJECT_NAME-besu-validator-2-ap'].AccessPointId" --output text)"
        }
      }
    },
    {
      "name": "efs-validator-3",
      "efsVolumeConfiguration": {
        "fileSystemId": "$EFS_ID",
        "transitEncryption": "ENABLED",
        "authorizationConfig": {
          "accessPointId": "$(aws efs describe-access-points --region $AWS_REGION --query "AccessPoints[?Name=='$PROJECT_NAME-besu-validator-3-ap'].AccessPointId" --output text)"
        }
      }
    },
    {
      "name": "efs-validator-4",
      "efsVolumeConfiguration": {
        "fileSystemId": "$EFS_ID",
        "transitEncryption": "ENABLED",
        "authorizationConfig": {
          "accessPointId": "$(aws efs describe-access-points --region $AWS_REGION --query "AccessPoints[?Name=='$PROJECT_NAME-besu-validator-4-ap'].AccessPointId" --output text)"
        }
      }
    }
  ]
}
EOF
)

    # Register task definition
    TASK_DEF_ARN=$(echo "$TASK_DEF_JSON" | aws ecs register-task-definition \
        --region "$AWS_REGION" \
        --cli-input-json file:///dev/stdin \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text)

    log_success "Task definition registered: $TASK_DEF_ARN"

    # Run task
    log_info "Starting upload task..."
    TASK_ARN=$(aws ecs run-task \
        --region "$AWS_REGION" \
        --cluster "$CLUSTER_NAME" \
        --task-definition "$TASK_DEF_ARN" \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SG_ID]}" \
        --enable-execute-command \
        --query 'tasks[0].taskArn' \
        --output text)

    log_success "Task started: $TASK_ARN"
    log_info "Waiting for task to reach RUNNING state..."

    # Wait for task to be running
    aws ecs wait tasks-running \
        --region "$AWS_REGION" \
        --cluster "$CLUSTER_NAME" \
        --tasks "$TASK_ARN"

    log_success "Task is running"

    # Upload files via ECS Exec
    for i in {1..4}; do
        log_info "Uploading validator-$i keys..."

        # Create directory
        aws ecs execute-command \
            --region "$AWS_REGION" \
            --cluster "$CLUSTER_NAME" \
            --task "$TASK_ARN" \
            --container uploader \
            --interactive \
            --command "mkdir -p /efs/validator-$i/key"

        # Copy key file (we'll need to do this via tarball)
        tar -czf /tmp/validator-$i.tar.gz -C "$KEYS_DIR/validator-$i" .

        # Upload tarball to S3 temporarily
        S3_BUCKET="$PROJECT_NAME-temp-upload-$(date +%s)"
        aws s3 mb "s3://$S3_BUCKET" --region "$AWS_REGION"
        aws s3 cp "/tmp/validator-$i.tar.gz" "s3://$S3_BUCKET/validator-$i.tar.gz"

        # Download and extract in container
        aws ecs execute-command \
            --region "$AWS_REGION" \
            --cluster "$CLUSTER_NAME" \
            --task "$TASK_ARN" \
            --container uploader \
            --interactive \
            --command "aws s3 cp s3://$S3_BUCKET/validator-$i.tar.gz /tmp/ && tar -xzf /tmp/validator-$i.tar.gz -C /efs/validator-$i && chown -R 1000:1000 /efs/validator-$i"

        # Cleanup
        aws s3 rm "s3://$S3_BUCKET/validator-$i.tar.gz"
        rm "/tmp/validator-$i.tar.gz"
    done

    # Cleanup S3 bucket
    aws s3 rb "s3://$S3_BUCKET" --force

    # Stop task
    aws ecs stop-task \
        --region "$AWS_REGION" \
        --cluster "$CLUSTER_NAME" \
        --task "$TASK_ARN" \
        >/dev/null

    log_success "Upload complete! Task stopped."
}

# Method 2: Manual upload instructions
show_manual_instructions() {
    log_warn "Automated upload via ECS Exec requires additional setup."
    log_info "Follow these manual steps instead:"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  MANUAL EFS UPLOAD INSTRUCTIONS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "Option 1: Use AWS Transfer Family (SFTP)"
    echo "  1. Create Transfer Family server with EFS integration"
    echo "  2. Upload files via SFTP client"
    echo ""

    echo "Option 2: Use EC2 Bastion"
    echo "  1. Launch t2.micro EC2 in private subnet"
    echo "  2. Mount EFS:"
    echo "     sudo mount -t nfs4 -o nfsvers=4.1 $EFS_ID.efs.$AWS_REGION.amazonaws.com:/ /mnt/efs"
    echo "  3. Copy files via SCP:"
    echo "     scp -r $KEYS_DIR/* ec2-user@<bastion-ip>:/tmp/"
    echo "     ssh ec2-user@<bastion-ip>"
    echo "     sudo cp -r /tmp/validator-* /mnt/efs/"
    echo "     sudo chown -R 1000:1000 /mnt/efs/validator-*"
    echo ""

    echo "Option 3: Include in Docker Image (DEV ONLY - INSECURE)"
    echo "  ⚠️  NOT RECOMMENDED FOR PRODUCTION"
    echo "  1. Copy keys to besu-aws/keys/"
    echo "  2. Update Dockerfile to COPY keys"
    echo "  3. Update entrypoint.sh to copy from image to EFS if not exists"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Main
main() {
    echo ""
    echo "=========================================="
    echo "  Besu Keys → EFS Uploader"
    echo "=========================================="
    echo ""

    check_prerequisites
    get_efs_id
    echo ""

    log_info "Choose upload method:"
    echo "  1. Via temporary ECS task (automated, requires ECS Exec)"
    echo "  2. Manual upload (show instructions)"
    echo ""
    read -p "Enter choice [1/2]: " CHOICE

    case $CHOICE in
        1)
            upload_via_ecs_task
            ;;
        2)
            show_manual_instructions
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac

    echo ""
    log_success "✅ Done!"
}

main "$@"
