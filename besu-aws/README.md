# Besu AWS ECS Configuration

This directory contains the configuration files for deploying 4 Hyperledger Besu validators across 2 AWS Availability Zones using ECS Fargate.

## Architecture

- **Validator 1 & 2**: Deployed in us-east-1a
- **Validator 3 & 4**: Deployed in us-east-1b
- **Storage**: EFS (Elastic File System) with separate access points for each validator
- **Networking**: AWS Service Discovery for inter-validator communication

## Files

### Core Configuration
- `genesis.json` - QBFT consensus genesis file (chain ID 1337)
- `static-nodes.json.template` - Template for peer discovery using Service Discovery DNS names
- `Dockerfile` - Multi-validator Besu image
- `entrypoint.sh` - Dynamic configuration selector based on `BESU_NODE_ID`

### Validator Configs
- `config/validator-1/config.toml` - Validator 1 (ports 8545/30303)
- `config/validator-2/config.toml` - Validator 2 (ports 8546/30304)
- `config/validator-3/config.toml` - Validator 3 (ports 8547/30305)
- `config/validator-4/config.toml` - Validator 4 (ports 8548/30306)

## Building the Docker Image

```bash
cd infrastructure/besu-aws
docker build -t besu-validator:latest .
```

## Pushing to ECR

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Tag image
docker tag besu-validator:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/property-tcc-besu-validator:latest

# Push image
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/property-tcc-besu-validator:latest
```

## Environment Variables

Each ECS task definition must set:

```
BESU_NODE_ID=validator-1  # or validator-2, validator-3, validator-4
```

This tells the entrypoint script which configuration to use.

## Service Discovery DNS Names

The validators discover each other using AWS Cloud Map:

- `property-tcc-besu-validator-1.property-tcc.local`
- `property-tcc-besu-validator-2.property-tcc.local`
- `property-tcc-besu-validator-3.property-tcc.local`
- `property-tcc-besu-validator-4.property-tcc.local`

## Important Notes

### Node Keys
The current setup will **auto-generate** node keys on first run. For production:

1. Pre-generate keys locally:
   ```bash
   besu --data-path=validator-1 public-key export --to=validator-1-pubkey
   ```

2. Extract the public key and update `static-nodes.json.template` with actual enode addresses

3. Upload the `key` files to EFS before starting the validators

### Static Nodes
The `static-nodes.json.template` contains placeholder `NODE*_PUBKEY` values. You must:

1. Generate node keys for all 4 validators
2. Replace placeholders with actual public keys
3. Update the template before building the Docker image

Example enode format:
```
enode://a5d9c9e...@property-tcc-besu-validator-1.property-tcc.local:30303
```

### Genesis ExtraData
The `extraData` field in `genesis.json` contains the initial validator set. The current value includes 4 validator addresses:
- 0x18a4e9b398c0fd1f8204d8354d486920c3f44fa0
- 0x4279afebc3fe9cde783c9bc983e461425252c5e0
- 0x46b0f11bf2e76b6ae67d333f688f2bf2bd3c4f4a
- 0x48d0f34e5078d585af0576479549be3949681472

These must match the accounts derived from the validator node keys.

## Testing Locally

You can test a validator configuration locally:

```bash
docker run -it \
  -e BESU_NODE_ID=validator-1 \
  -p 8545:8545 \
  -p 30303:30303 \
  besu-validator:latest
```

## Troubleshooting

### Validators Not Connecting
- Check Security Groups allow TCP/UDP on ports 30303-30306
- Verify Service Discovery DNS resolution: `nslookup property-tcc-besu-validator-1.property-tcc.local`
- Check ECS task logs in CloudWatch

### Consensus Not Starting
- Ensure all 4 validators are running (QBFT requires at least 3 of 4)
- Verify `extraData` in genesis matches validator addresses
- Check node keys are correctly generated

### EFS Permission Errors
- Verify EFS access points have correct POSIX user (UID 1000, GID 1000 for besu user)
- Check EFS mount targets exist in all AZs

## Network Parameters

- **Chain ID**: 1337
- **Consensus**: QBFT (Byzantine Fault Tolerant)
- **Block Time**: 2 seconds
- **Gas Limit**: 0x1fffffffffffff (unlimited for private network)
- **Gas Price**: 0 (zero fees)
- **Epoch Length**: 30000 blocks
