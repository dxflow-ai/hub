FROM ghcr.io/dxflow-ai/void:latest

LABEL org.opencontainers.image.title="Inkscape"
LABEL org.opencontainers.image.description="Vector graphics editor for illustrations and diagrams"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Update xbps itself before installing (the base image lags the rolling repo)
RUN xbps-install -Suy xbps

# Install inkscape
RUN xbps-install -Sy inkscape && \
    xbps-remove -O && \
    rm -rf /var/cache/xbps/*

# Setup scripts
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY launch.sh /opt/dxflow/launch.sh

# Give the app the full screen by hiding the window decorations and taskbar
ENV PANEL="hide"
ENV TASKBAR="hide"
