# Version pins — refresh them with .github/scripts/version.sh
ARG PACKAGE_AMD64_VERSION=4.1-1build1
ARG PACKAGE_ARM64_VERSION=4.1-1build1

FROM ghcr.io/dxflow-ai/ubuntu:latest

LABEL org.opencontainers.image.title="Veusz"
LABEL org.opencontainers.image.description="Scientific plotting package for publication-quality figures"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Bring the pins into the stage (a pin declared above FROM only reaches FROM)
ARG PACKAGE_AMD64_VERSION
ARG PACKAGE_ARM64_VERSION

# Install veusz from the Ubuntu universe archive
# The exact version is named on purpose: a repository that has moved on fails the
# build rather than quietly shipping something other than what this entry claims.
# amd64 is served by archive.ubuntu.com and arm64 by ports.ubuntu.com, two indexes
# that can move apart, so each arch takes its own pin
RUN case "$(uname -m)" in \
        x86_64) PACKAGE="veusz=${PACKAGE_AMD64_VERSION}" ;; \
        aarch64) PACKAGE="veusz=${PACKAGE_ARM64_VERSION}" ;; \
        *) echo "no veusz pin for $(uname -m)" >&2 && exit 1 ;; \
    esac && \
    apt-get update -q && \
    apt-get install -y -q --no-install-recommends --reinstall --fix-missing "$PACKAGE" && \
    rm -rf /var/lib/apt/lists/*

# Setup scripts
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY launch.sh /opt/dxflow/launch.sh

# Give the app the full screen by hiding the window decorations and taskbar
ENV PANEL="hide"
ENV TASKBAR="hide"
