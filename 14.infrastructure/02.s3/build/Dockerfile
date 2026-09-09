FROM amazon/aws-cli:2.36.41

LABEL org.opencontainers.image.title="S3 Sync"
LABEL org.opencontainers.image.description="Sync data between S3-compatible object storage and a workflow volume"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Setup scripts
COPY entrypoint.sh /opt/dxflow/entrypoint.sh
RUN chmod +x /opt/dxflow/entrypoint.sh

WORKDIR /data
VOLUME [ "/data" ]

# The base image runs `aws` as its entrypoint. Reset it and hand the transfer to a
# command instead, so a pipeline step can name the script and still run to
# completion under `mode: sequential`, which has no step without a command.
ENTRYPOINT [ ]
CMD [ "/opt/dxflow/entrypoint.sh" ]
