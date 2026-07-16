FROM staphb/pangolin:4.3.1-pdata-1.25.1

LABEL org.opencontainers.image.title="Pangolin"
LABEL org.opencontainers.image.description="Phylogenetic assignment of SARS-CoV-2 lineages"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

ENV DEBIAN_FRONTEND="noninteractive"

# Install dependencies
RUN apt-get update -q && \
    apt-get install -y -q --no-install-recommends unzip && \
    rm -rf /var/lib/apt/lists/*

# Setup scripts
COPY entrypoint.sh /opt/dxflow/entrypoint.sh
RUN chmod +x /opt/dxflow/entrypoint.sh

WORKDIR /data
VOLUME [ "/data" ]

ENTRYPOINT [ "/opt/dxflow/entrypoint.sh" ]
