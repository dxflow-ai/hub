# Version pins — refresh them with .github/scripts/version.sh
ARG VERSION=3.1.3.1
ARG BUILD_VERSION=appveyor1974
ARG PYTHON_VERSION=3.10

FROM ghcr.io/dxflow-ai/ubuntu:latest

LABEL org.opencontainers.image.title="PyMOL"
LABEL org.opencontainers.image.description="Molecular visualization of structures and trajectories"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Bring the pins into the stage (a pin declared above FROM only reaches FROM)
ARG VERSION
ARG BUILD_VERSION
ARG PYTHON_VERSION

# Install packages
RUN apt-get update -q && \
    apt-get install -y -q --no-install-recommends --reinstall --fix-missing bzip2 && \
    rm -rf /var/lib/apt/lists/*

# Install PyMOL
RUN PYTHON="$(echo "${PYTHON_VERSION}" | tr -d .)" && \
    wget -q --tries=5 --waitretry=5 --retry-connrefused --no-check-certificate "https://storage.googleapis.com/pymol-storage/installers/PyMOL-${VERSION}_${BUILD_VERSION}-Linux-x86_64-py${PYTHON}.tar.bz2" -O /tmp/pymol.tar.bz2 && \
    bzip2 -d /tmp/pymol.tar.bz2 && \
    tar -xf /tmp/pymol.tar -C /opt/ && \
    ln -sf /opt/pymol/bin/* /usr/bin && \
    rm -rf /tmp/pymol.tar

# Setup scripts
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY launch.sh /opt/dxflow/launch.sh

# Keep the panel (PyMOL is a multi-window app), hide the taskbar
ENV PANEL="show"
ENV TASKBAR="hide"
