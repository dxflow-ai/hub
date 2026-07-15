FROM ghcr.io/dxflow-ai/ubuntu:latest

LABEL org.opencontainers.image.title="PyMOL"
LABEL org.opencontainers.image.description="Molecular visualization of structures and trajectories"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Install packages
RUN apt-get update -q && \
    apt-get install -y -q --no-install-recommends --reinstall --fix-missing bzip2 && \
    rm -rf /var/lib/apt/lists/*

# Install PyMOL
RUN wget -q --tries=5 --waitretry=5 --retry-connrefused --no-check-certificate "https://storage.googleapis.com/pymol-storage/installers/PyMOL-3.1.3.1_appveyor1974-Linux-x86_64-py310.tar.bz2" -O /tmp/pymol.tar.bz2 && \
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
