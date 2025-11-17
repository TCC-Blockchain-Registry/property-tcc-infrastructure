#!/bin/bash
set -e

echo "=========================================="
echo "Starting Besu Validator: ${BESU_NODE_ID}"
echo "=========================================="

# Determine validator number from BESU_NODE_ID (e.g., "validator-1" -> "1")
VALIDATOR_NUM=$(echo "${BESU_NODE_ID}" | grep -oE '[0-9]+$')

if [ -z "$VALIDATOR_NUM" ]; then
  echo "ERROR: BESU_NODE_ID must be set (e.g., 'validator-1')"
  exit 1
fi

# Select the correct config file
CONFIG_FILE="/opt/besu/config/validator-${VALIDATOR_NUM}.toml"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: Config file not found: $CONFIG_FILE"
  exit 1
fi

echo "Using config: $CONFIG_FILE"

# Copy static nodes template to data directory
if [ ! -f "/opt/besu/data/static-nodes.json" ]; then
  echo "Copying static-nodes.json template..."
  cp /opt/besu/static-nodes.json.template /opt/besu/data/static-nodes.json
fi

# Create key directory if it doesn't exist
mkdir -p /opt/besu/data/key

# Check if node key exists, if not generate one
if [ ! -f "/opt/besu/data/key/key" ]; then
  echo "WARNING: Node key not found. Besu will generate a new one."
  echo "For production, you should pre-generate keys and mount them via EFS."
fi

# Print configuration summary
echo "=========================================="
echo "Configuration Summary:"
echo "  Validator: ${BESU_NODE_ID}"
echo "  Config: $CONFIG_FILE"
echo "  Data Path: /opt/besu/data"
echo "  Genesis: /opt/besu/genesis.json"
echo "  Static Nodes: /opt/besu/data/static-nodes.json"
echo "=========================================="

# Start Besu with the selected configuration
exec /opt/besu/bin/besu --config-file="$CONFIG_FILE"
