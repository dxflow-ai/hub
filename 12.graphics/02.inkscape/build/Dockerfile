FROM ghcr.io/dxflow-ai/void:latest

LABEL org.opencontainers.image.title="Inkscape"
LABEL org.opencontainers.image.description="Vector graphics editor for illustrations and diagrams"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Install inkscape on a base brought in step with the rolling repo
RUN xbps-install -Suy xbps && \
    xbps-install -Suy && \
    xbps-install -Sy inkscape && \
    xbps-remove -O && \
    rm -rf /var/cache/xbps/*

# Setup scripts
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY launch.sh /opt/dxflow/launch.sh

# Give the app the full screen by hiding the window decorations and taskbar
ENV PANEL="hide"
ENV TASKBAR="hide"
