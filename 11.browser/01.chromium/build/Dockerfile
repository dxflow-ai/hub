FROM ghcr.io/dxflow-ai/void:latest

LABEL org.opencontainers.image.title="Chromium"
LABEL org.opencontainers.image.description="Open-source Chromium web browser in a remote desktop session"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Install chromium on a base brought in step with the rolling repo
RUN xbps-install -Suy xbps && \
    xbps-install -Suy && \
    xbps-install -Sy chromium && \
    xbps-remove -O && \
    rm -rf /var/cache/xbps/*

# Setup scripts
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY launch.sh /opt/dxflow/launch.sh

# Give the browser the full screen by hiding the window decorations and taskbar
ENV PANEL="hide"
ENV TASKBAR="hide"
