FROM hyperledger/besu:23.10.2

# Install required tools
USER root
RUN apt-get update && \
    apt-get install -y curl jq && \
    rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /opt/besu/config /opt/besu/data && \
    chown -R besu:besu /opt/besu

# Copy genesis file
COPY genesis.json /opt/besu/genesis.json

# Copy all validator configs
COPY config/validator-1/config.toml /opt/besu/config/validator-1.toml
COPY config/validator-2/config.toml /opt/besu/config/validator-2.toml
COPY config/validator-3/config.toml /opt/besu/config/validator-3.toml
COPY config/validator-4/config.toml /opt/besu/config/validator-4.toml

# Copy static nodes template
COPY static-nodes.json.template /opt/besu/static-nodes.json.template

# Copy entrypoint script
COPY entrypoint.sh /opt/besu/entrypoint.sh
RUN chmod +x /opt/besu/entrypoint.sh && \
    chown besu:besu /opt/besu/entrypoint.sh

# Set permissions
RUN chown -R besu:besu /opt/besu

# Switch to besu user
USER besu

# Working directory
WORKDIR /opt/besu

# Entrypoint
ENTRYPOINT ["/opt/besu/entrypoint.sh"]
