FROM hyperledger/besu:23.10.2

USER root
RUN apt-get update && \
    apt-get install -y curl jq && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/besu/config /opt/besu/data && \
    chown -R besu:besu /opt/besu

COPY genesis.json /opt/besu/genesis.json
COPY config/validator-1/config.toml /opt/besu/config/validator-1.toml
COPY config/validator-2/config.toml /opt/besu/config/validator-2.toml
COPY config/validator-3/config.toml /opt/besu/config/validator-3.toml
COPY config/validator-4/config.toml /opt/besu/config/validator-4.toml
COPY static-nodes.json.template /opt/besu/static-nodes.json.template

COPY entrypoint.sh /opt/besu/entrypoint.sh
RUN chmod +x /opt/besu/entrypoint.sh && \
    chown -R besu:besu /opt/besu

USER besu
WORKDIR /opt/besu

ENTRYPOINT ["/opt/besu/entrypoint.sh"]
