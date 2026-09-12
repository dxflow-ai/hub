# Version pins — refresh them with .github/scripts/version.sh
ARG VERSION=0.11.3

# The plain variant, not the -ollama one: this entry is the gate, and the model
# servers it fronts run on the machines that have the cards. Bundling a server
# would double the image for a copy most deployments never reach.
FROM ghcr.io/open-webui/open-webui:v${VERSION}

LABEL org.opencontainers.image.title="Gatehouse"
LABEL org.opencontainers.image.description="Accounts, groups and per-model permissions in front of the model servers on your GPU machines"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# The readiness wait and the administrator bootstrap in the entrypoint are curl
# and python3, both of which the base already carries — it installs curl for its
# own HEALTHCHECK, and it is built on python:3.11-slim. So nothing is installed
# here, and no apt mirror is asked for anything at build time.

# Setup scripts
RUN mkdir -p /opt/dxflow
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY entrypoint.sh /opt/dxflow/entrypoint.sh
RUN chmod +x /opt/dxflow/entrypoint.sh

# Accounts, groups, keys, chats and the audit log live on the volume. The cache
# paths the image bakes are absolute, so moving DATA_DIR leaves the preloaded
# embedding model where it was put.
ENV DATA_DIR="/volume/data"

# The model servers to serve from. The base defaults OLLAMA_BASE_URL to the
# sentinel /ollama, which means "the one in this container" — there is none, so
# it is cleared and OLLAMA_BASE_URLS is what a deployment sets.
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
ENV WEBUI_NAME="Gatehouse"

# The first account, created on a fresh volume. Its password defaults in the
# entrypoint rather than here, so the image carries no credential and a build log
# has none to warn about.
ENV ADMIN_EMAIL="gatehouse@dxflow.ai"
ENV ADMIN_NAME="Admin"

EXPOSE 8080

VOLUME [ "/volume" ]

ENTRYPOINT [ "/opt/dxflow/entrypoint.sh" ]
