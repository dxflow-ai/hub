FROM staphb/samtools:1.19

LABEL org.opencontainers.image.title="Samtools"
LABEL org.opencontainers.image.description="Tools for manipulating SAM, BAM, and CRAM sequence alignments"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Setup scripts
COPY entrypoint.sh /opt/dxflow/entrypoint.sh
RUN chmod +x /opt/dxflow/entrypoint.sh

WORKDIR /data
VOLUME [ "/data" ]

ENTRYPOINT [ "/opt/dxflow/entrypoint.sh" ]
