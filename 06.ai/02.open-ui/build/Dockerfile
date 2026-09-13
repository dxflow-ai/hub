# Version pins — refresh them with .github/scripts/version.sh
ARG VERSION=0.11.3

# The -ollama variant carries the model server alongside the interface, so one
# container holds the models, the accounts, and the gate in front of both. The
# entry is deployed on the machine with the card, so the server belongs with it.
FROM ghcr.io/open-webui/open-webui:v${VERSION}-ollama

LABEL org.opencontainers.image.title="Open UI"
LABEL org.opencontainers.image.description="Accounts, groups and per-model permissions in front of local large language models"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# The readiness waits and the administrator bootstrap in the entrypoint are curl
# and python3, both of which the base already carries — it installs curl for its
# own HEALTHCHECK, and it is built on python:3.11-slim. So nothing is installed
# here, and no apt mirror is asked for anything at build time. No model is baked
# in either: pulling one is a decision about a particular card, made once from
# the interface, and a model in the image is weight every deploy pays to carry.

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

# The entrypoint starts the model server itself, so upstream's start.sh must not.
# OLLAMA_BASE_URL is settled there too: the bundled server when nothing else is
# named, or cleared when OLLAMA_BASE_URLS points at machines of their own.
ENV USE_OLLAMA_DOCKER="false"
ENV OLLAMA_BASE_URL=""
ENV OLLAMA_BASE_URLS=""

# The workflow definition is the source of truth for settings, not the database
ENV ENABLE_PERSISTENT_CONFIG="False"

# Access defaults: no open signup, new accounts wait for approval, keys on, and
# every call recorded. Model access control is never bypassed.
ENV ENABLE_SIGNUP="False"
ENV DEFAULT_USER_ROLE="pending"
ENV ENABLE_API_KEYS="True"
ENV USER_PERMISSIONS_FEATURES_API_KEYS="True"
ENV AUDIT_LOG_LEVEL="METADATA"
ENV BYPASS_MODEL_ACCESS_CONTROL="False"
ENV ENABLE_EVALUATION_ARENA_MODELS="False"
ENV WEBUI_NAME="Open UI"

# The first account, created on a fresh volume. Its password defaults in the
# entrypoint rather than here, so the image carries no credential and a build log
# has none to warn about.
ENV ADMIN_EMAIL="open-ui@dxflow.ai"
ENV ADMIN_NAME="Admin"

EXPOSE 8080

VOLUME [ "/volume" ]

ENTRYPOINT [ "/opt/dxflow/entrypoint.sh" ]
