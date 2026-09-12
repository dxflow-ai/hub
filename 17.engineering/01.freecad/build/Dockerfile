# Version pins — refresh them with .github/scripts/version.sh
ARG PACKAGE_AMD64_VERSION=1.1.3_1
ARG PACKAGE_ARM64_VERSION=1.1.3_1

FROM ghcr.io/dxflow-ai/void:latest

LABEL org.opencontainers.image.title="FreeCAD"
LABEL org.opencontainers.image.description="General purpose parametric 3D CAD modeller"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Bring the pins into the stage (a pin declared above FROM only reaches FROM)
ARG PACKAGE_AMD64_VERSION
ARG PACKAGE_ARM64_VERSION

# Install freecad on a base brought in step with the rolling repo
# The exact version is named on purpose: a repository that has moved on fails the
# build rather than quietly shipping something other than what this entry claims.
# Void does not hold the same version for both arches, so each takes its own pin
# mesa-dri comes along unpinned: no runner has a card, so the app renders
# through Mesa's software driver, which is the base's business rather than a
# version this entry claims
RUN case "$(uname -m)" in \
        x86_64) PACKAGE="freecad-${PACKAGE_AMD64_VERSION}" ;; \
        aarch64) PACKAGE="freecad-${PACKAGE_ARM64_VERSION}" ;; \
        *) echo "no freecad pin for $(uname -m)" >&2 && exit 1 ;; \
    esac && \
    xbps-install -Suy xbps && \
    xbps-install -Suy && \
    xbps-install -Sy "$PACKAGE" mesa-dri && \
    xbps-remove -O && \
    rm -rf /var/cache/xbps/*

# Setup scripts
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY launch.sh /opt/dxflow/launch.sh

# Give the app the full screen by hiding the window decorations and taskbar
ENV PANEL="hide"
ENV TASKBAR="hide"
