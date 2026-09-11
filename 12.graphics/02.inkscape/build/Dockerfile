# Version pins — refresh them with .github/scripts/version.sh
ARG PACKAGE_VERSION=1.4.3_6

FROM ghcr.io/dxflow-ai/void:latest

LABEL org.opencontainers.image.title="Inkscape"
LABEL org.opencontainers.image.description="Vector graphics editor for illustrations and diagrams"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Bring the pins into the stage (a pin declared above FROM only reaches FROM)
ARG PACKAGE_VERSION

# Install inkscape on a base brought in step with the rolling repo
# The exact version is named on purpose: a repository that has moved on fails the
# build rather than quietly shipping something other than what this entry claims.
RUN xbps-install -Suy xbps && \
    xbps-install -Suy && \
    xbps-install -Sy "inkscape-${PACKAGE_VERSION}" && \
    xbps-remove -O && \
    rm -rf /var/cache/xbps/*

# Setup scripts
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY launch.sh /opt/dxflow/launch.sh

# Give the app the full screen by hiding the window decorations and taskbar
ENV PANEL="hide"
ENV TASKBAR="hide"
