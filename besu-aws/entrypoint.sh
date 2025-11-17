#!/bin/bash
set -e

echo "Starting Besu Validator: ${BESU_NODE_ID}"

VALIDATOR_NUM=$(echo "${BESU_NODE_ID}" | grep -oE '[0-9]+$')

if [ -z "$VALIDATOR_NUM" ]; then
  echo "ERROR: BESU_NODE_ID must be set (e.g., 'validator-1')"
  exit 1
fi

CONFIG_FILE="/opt/besu/config/validator-${VALIDATOR_NUM}.toml"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: Config file not found: $CONFIG_FILE"
  exit 1
fi

if [ ! -f "/opt/besu/data/static-nodes.json" ]; then
  cp /opt/besu/static-nodes.json.template /opt/besu/data/static-nodes.json
fi

mkdir -p /opt/besu/data/key

if [ ! -f "/opt/besu/data/key/key" ]; then
  echo "WARNING: Node key not found. Besu will generate a new one."
  echo "For production, pre-generate keys and mount them via EFS."
fi

echo "Config: $CONFIG_FILE"
echo "Starting Besu..."

exec /opt/besu/bin/besu --config-file="$CONFIG_FILE"
