FROM ghcr.io/void-linux/void-glibc:20250112R1

LABEL org.opencontainers.image.title="Coder"
LABEL org.opencontainers.image.description="Self-hosted cloud development environment in the browser"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Update xbps itself before installing (the pinned base lags the rolling repo)
RUN xbps-install -Suy xbps

# Install packages
RUN xbps-install -Sy bash curl wget tar gzip procps-ng python3 git zsh && \
    xbps-remove -O && \
    rm -rf /var/cache/xbps/*

# Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh && \
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
