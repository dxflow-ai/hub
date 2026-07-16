FROM ghcr.io/dxflow-ai/ubuntu:latest

LABEL org.opencontainers.image.title="VisIt"
LABEL org.opencontainers.image.description="Interactive visualization and analysis of simulation data"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Install packages (cpio is required by the VisIt installer)
RUN apt-get update -q && \
    apt-get install -y -q --no-install-recommends --reinstall --fix-missing cpio && \
    rm -rf /var/lib/apt/lists/*

# Install VisIt
RUN wget -q --tries=5 --waitretry=5 --retry-connrefused --no-check-certificate "https://github.com/visit-dav/visit/releases/download/v3.4.2/visit-install3_4_2" -O /tmp/visit.install.sh && \
    wget -q --tries=5 --waitretry=5 --retry-connrefused --no-check-certificate "https://github.com/visit-dav/visit/releases/download/v3.4.2/visit3_4_2.linux-x86_64-ubuntu22.tar.gz" -O /tmp/visit3_4_2.linux-x86_64-ubuntu22.tar.gz && \
    cd /tmp && sh /tmp/visit.install.sh -c none 3.4.2 linux-x86_64-ubuntu22 /opt/visit && \
    ln -s /opt/visit/bin/* /usr/bin && \
    rm -rf /tmp/visit.install.sh /tmp/visit3_4_2.linux-x86_64-ubuntu22.tar.gz

# Setup scripts
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY launch.sh /opt/dxflow/launch.sh

# Keep the panel (VisIt is a multi-window app), hide the taskbar
ENV PANEL="show"
ENV TASKBAR="hide"
