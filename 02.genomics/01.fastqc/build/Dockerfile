FROM staphb/fastqc:0.12.1

LABEL org.opencontainers.image.title="FastQC"
LABEL org.opencontainers.image.description="Quality control tool for high throughput sequencing data"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Setup scripts
COPY entrypoint.sh /opt/dxflow/entrypoint.sh
RUN chmod +x /opt/dxflow/entrypoint.sh

WORKDIR /data
VOLUME [ "/data" ]

ENTRYPOINT [ "/opt/dxflow/entrypoint.sh" ]
