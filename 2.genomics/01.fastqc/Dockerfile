FROM staphb/fastqc:0.12.1

LABEL org.opencontainers.image.title="FastQC"
LABEL org.opencontainers.image.description="Quality control tool for high throughput sequencing data"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"
LABEL org.opencontainers.image.version="0.12.1"

RUN apt-get update \
    && apt-get install -y --no-install-recommends parallel \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /data
VOLUME [ "/data" ]
