# Version pins — refresh them with .github/scripts/version.sh
ARG PACKAGE_AMD64_VERSION=1.4.3_6
ARG PACKAGE_ARM64_VERSION=1.4.3_6

FROM ghcr.io/dxflow-ai/void:latest

LABEL org.opencontainers.image.title="Inkscape"
LABEL org.opencontainers.image.description="Vector graphics editor for illustrations and diagrams"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Bring the pins into the stage (a pin declared above FROM only reaches FROM)
ARG PACKAGE_AMD64_VERSION
ARG PACKAGE_ARM64_VERSION

# Install inkscape on a base brought in step with the rolling repo
# The exact version is named on purpose: a repository that has moved on fails the
# build rather than quietly shipping something other than what this entry claims.
# Void does not hold the same version for both arches, so each takes its own pin
RUN case "$(uname -m)" in \
        x86_64) PACKAGE="inkscape-${PACKAGE_AMD64_VERSION}" ;; \
        aarch64) PACKAGE="inkscape-${PACKAGE_ARM64_VERSION}" ;; \
        *) echo "no inkscape pin for $(uname -m)" >&2 && exit 1 ;; \
    esac && \
    xbps-install -Suy xbps && \
    xbps-install -Suy && \
    xbps-install -Sy "$PACKAGE" && \
    xbps-remove -O && \
    rm -rf /var/cache/xbps/*

# Setup scripts
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY launch.sh /opt/dxflow/launch.sh

# Give the app the full screen by hiding the window decorations and taskbar
ENV PANEL="hide"
ENV TASKBAR="hide"
