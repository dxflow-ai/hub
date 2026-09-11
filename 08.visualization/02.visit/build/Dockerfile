# Version pins — refresh them with .github/scripts/version.sh
ARG VERSION=3.5.0

FROM ghcr.io/dxflow-ai/ubuntu:latest

LABEL org.opencontainers.image.title="VisIt"
LABEL org.opencontainers.image.description="Interactive visualization and analysis of simulation data"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Bring the pins into the stage (a pin declared above FROM only reaches FROM)
ARG VERSION

# Install packages (cpio is required by the VisIt installer)
RUN apt-get update -q && \
    apt-get install -y -q --no-install-recommends --reinstall --fix-missing cpio && \
    rm -rf /var/lib/apt/lists/*

# Install VisIt
RUN RELEASE="$(echo "${VERSION}" | tr . _)" && \
    wget -q --tries=5 --waitretry=5 --retry-connrefused --no-check-certificate "https://github.com/visit-dav/visit/releases/download/v${VERSION}/visit-install${RELEASE}" -O /tmp/visit.install.sh && \
    wget -q --tries=5 --waitretry=5 --retry-connrefused --no-check-certificate "https://github.com/visit-dav/visit/releases/download/v${VERSION}/visit${RELEASE}.linux-x86_64-ubuntu22.tar.gz" -O "/tmp/visit${RELEASE}.linux-x86_64-ubuntu22.tar.gz" && \
    cd /tmp && sh /tmp/visit.install.sh -c none "${VERSION}" linux-x86_64-ubuntu22 /opt/visit && \
    ln -s /opt/visit/bin/* /usr/bin && \
    rm -rf /tmp/visit.install.sh "/tmp/visit${RELEASE}.linux-x86_64-ubuntu22.tar.gz"

# Setup scripts
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY launch.sh /opt/dxflow/launch.sh

# Keep the panel (VisIt is a multi-window app), hide the taskbar
ENV PANEL="show"
ENV TASKBAR="hide"
