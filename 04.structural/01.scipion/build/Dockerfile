FROM ghcr.io/dxflow-ai/ubuntu:latest

LABEL org.opencontainers.image.title="Scipion"
LABEL org.opencontainers.image.description="Integrated image processing framework for cryo-electron microscopy"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Install build dependencies
RUN apt-get update -q && \
    apt-get install -y -q --no-install-recommends --reinstall --fix-missing gcc-10 g++-10 libopenmpi-dev python3-pip && \
    rm -rf /var/lib/apt/lists/*

# Install Miniconda
RUN wget -q --no-check-certificate "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh" -O /tmp/miniconda.sh && \
    sh /tmp/miniconda.sh -b -u -p /opt/miniconda3 && \
    ln -sf /opt/miniconda3/bin/* /usr/bin && \
    rm -rf /tmp/miniconda.sh

# Use conda-forge and avoid the Anaconda default channels (which now require ToS)
RUN conda config --system --remove channels defaults 2>/dev/null || true && \
    conda config --system --add channels conda-forge && \
    conda config --system --set channel_priority strict

# Install Scipion
RUN pip3 install --user scipion-installer && \
    python3 -m scipioninstaller -conda -noXmipp -noAsk /opt/scipion && \
    ln -s /opt/scipion/scipion3 /usr/bin/scipion3 && \
    scipion3 config --overwrite --unattended

# Setup scripts
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY launch.sh /opt/dxflow/launch.sh

# Keep the panel (Scipion is a multi-window app), hide the taskbar
ENV PANEL="show"
ENV TASKBAR="hide"
