# Version pins — refresh them with .github/scripts/version.sh
ARG PACKAGE_AMD64_VERSION=1.101.0-1
ARG PACKAGE_ARM64_VERSION=1.101.0-1

FROM ghcr.io/dxflow-ai/ubuntu:latest

LABEL org.opencontainers.image.title="Avogadro"
LABEL org.opencontainers.image.description="Molecular editor and visualization tool"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Bring the pins into the stage (a pin declared above FROM only reaches FROM)
ARG PACKAGE_AMD64_VERSION
ARG PACKAGE_ARM64_VERSION

# Install avogadro from the Ubuntu universe archive
# The exact version is named on purpose: a repository that has moved on fails the
# build rather than quietly shipping something other than what this entry claims.
# amd64 is served by archive.ubuntu.com and arm64 by ports.ubuntu.com, two indexes
# that can move apart, so each arch takes its own pin
# libgl1-mesa-dri comes along unpinned: no runner has a card, so the app renders
# through Mesa's software driver, which is the base's business rather than a
# version this entry claims
RUN case "$(uname -m)" in \
        x86_64) PACKAGE="avogadro=${PACKAGE_AMD64_VERSION}" ;; \
        aarch64) PACKAGE="avogadro=${PACKAGE_ARM64_VERSION}" ;; \
        *) echo "no avogadro pin for $(uname -m)" >&2 && exit 1 ;; \
    esac && \
    apt-get update -q && \
    apt-get install -y -q --no-install-recommends --reinstall --fix-missing "$PACKAGE" libgl1-mesa-dri && \
    rm -rf /var/lib/apt/lists/*

# Setup scripts
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY launch.sh /opt/dxflow/launch.sh

# Give the app the full screen by hiding the window decorations and taskbar
ENV PANEL="hide"
ENV TASKBAR="hide"
