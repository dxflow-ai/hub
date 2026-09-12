# Version pins — refresh them with .github/scripts/version.sh
ARG VERSION=0.11.3

# The -ollama variant carries the model server alongside the interface, so one
# container holds the models, the accounts, and the gate in front of both
FROM ghcr.io/open-webui/open-webui:v${VERSION}-ollama

LABEL org.opencontainers.image.title="Gatehouse"
LABEL org.opencontainers.image.description="Accounts, groups and per-model permissions in front of local large language models"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

ENV DEBIAN_FRONTEND="noninteractive"

ARG STARTUP_MODEL="smollm2:135m"

# curl drives the readiness waits and the administrator bootstrap in the entrypoint
RUN apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 update -q && \
    apt-get install -y -q --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Preload the default model into a seed store the entrypoint copies out — the
# live store lives on the volume, whose mount would shadow anything baked here
RUN set -e; \
    OLLAMA_MODELS=/opt/dxflow/models nohup ollama serve > /tmp/ollama.log 2>&1 & \
    server=$!; \
    i=0; \
    while [ "$i" -lt 30 ] && ! curl -sf http://127.0.0.1:11434/api/tags > /dev/null 2>&1; do \
        i=$((i + 1)); \
        sleep 1; \
    done; \
    ollama pull "${STARTUP_MODEL}"; \
    kill "$server" 2> /dev/null || true

# Setup scripts
RUN mkdir -p /opt/dxflow
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY entrypoint.sh /opt/dxflow/entrypoint.sh
RUN chmod +x /opt/dxflow/entrypoint.sh

# Accounts, groups, keys, chats and the audit log live on the volume; so do the
# models. The cache paths the image bakes are absolute, so moving DATA_DIR
# leaves the preloaded embedding model where it was put.
ENV DATA_DIR="/volume/data"
ENV OLLAMA_MODELS="/volume/models"

# The entrypoint starts the model server itself, so upstream's start.sh must not
ENV USE_OLLAMA_DOCKER="false"
ENV OLLAMA_BASE_URL=""
ENV OLLAMA_BASE_URLS=""
ENV STARTUP_MODELS="${STARTUP_MODEL}"

# The workflow definition is the source of truth for settings, not the database
ENV ENABLE_PERSISTENT_CONFIG="False"

# Access defaults: no open signup, new accounts wait for approval, keys on, and
# every call recorded. Model access control is never bypassed.
ENV ENABLE_SIGNUP="False"
ENV DEFAULT_USER_ROLE="pending"
ENV ENABLE_API_KEYS="True"
ENV AUDIT_LOG_LEVEL="METADATA"
ENV BYPASS_MODEL_ACCESS_CONTROL="False"
ENV WEBUI_NAME="Gatehouse"
ENV WEBUI_SECRET_KEY=""

# The first account, created on a fresh volume
ENV ADMIN_EMAIL="gatehouse@dxflow.ai"
ENV ADMIN_PASSWORD="dxflow"
ENV ADMIN_NAME="Admin"

EXPOSE 8080

VOLUME [ "/volume" ]

ENTRYPOINT [ "/opt/dxflow/entrypoint.sh" ]
