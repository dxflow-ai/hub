FROM amazon/aws-cli:2.36.41

LABEL org.opencontainers.image.title="S3 Sync"
LABEL org.opencontainers.image.description="Sync data between S3-compatible object storage and a workflow volume"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Setup scripts
COPY entrypoint.sh /opt/dxflow/entrypoint.sh
RUN chmod +x /opt/dxflow/entrypoint.sh

WORKDIR /volume
VOLUME [ "/volume" ]

# `idle` is what the container starts on: a step that carries a command is started
# detached and the command is executed inside it, so the container has to be up
# before the transfer arrives. The step's command runs this same entrypoint with
# no argument, and that invocation is the one that transfers.
ENTRYPOINT [ "/opt/dxflow/entrypoint.sh" ]
CMD [ "idle" ]
