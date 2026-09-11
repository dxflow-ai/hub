# Version pins — refresh them with .github/scripts/version.sh
ARG VERSION=4.137.0
ARG VOID_VERSION=20260901R1

FROM ghcr.io/void-linux/void-glibc:${VOID_VERSION}

LABEL org.opencontainers.image.title="Coder"
LABEL org.opencontainers.image.description="Self-hosted cloud development environment in the browser"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Bring the pins into the stage (a pin declared above FROM only reaches FROM)
ARG VERSION

# Update xbps itself before installing (the pinned base lags the rolling repo)
RUN xbps-install -Suy xbps

# Install packages
RUN xbps-install -Sy bash curl wget tar gzip procps-ng python3 git zsh && \
    xbps-remove -O && \
    rm -rf /var/cache/xbps/*

# Install code-server
# The exact version is named on purpose: a repository that has moved on fails the
# build rather than quietly shipping something other than what this entry claims.
RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- --version="${VERSION}" && \
    rm -rf /root/.cache

# Setup code-server settings
RUN mkdir -p /root/.local/share/code-server/User
COPY settings.json /root/.local/share/code-server/User/settings.json

# Setup scripts
RUN mkdir -p /opt/dxflow
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY entrypoint.sh /opt/dxflow/entrypoint.sh
RUN chmod +x /opt/dxflow/entrypoint.sh

ENV WORKING_DIR="/"
ENV SHELL="/bin/zsh"

EXPOSE 8080

VOLUME [ "/volume" ]

ENTRYPOINT [ "/opt/dxflow/entrypoint.sh" ]
