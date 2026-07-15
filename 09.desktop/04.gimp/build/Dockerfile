FROM ghcr.io/dxflow-ai/void:latest

LABEL org.opencontainers.image.title="GIMP"
LABEL org.opencontainers.image.description="GNU Image Manipulation Program for photo editing and graphics"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Update xbps itself before installing (the base image lags the rolling repo)
RUN xbps-install -Suy xbps

# Install gimp
RUN xbps-install -Sy gimp && \
    xbps-remove -O && \
    rm -rf /var/cache/xbps/*

# Setup scripts
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY launch.sh /opt/dxflow/launch.sh

# Give the app the full screen by hiding the window decorations and taskbar
ENV PANEL="hide"
ENV TASKBAR="hide"
