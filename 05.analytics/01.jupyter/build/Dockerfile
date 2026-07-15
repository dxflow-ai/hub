FROM ghcr.io/void-linux/void-glibc:20250112R1

LABEL org.opencontainers.image.title="Jupyter Lab"
LABEL org.opencontainers.image.description="Interactive development environment for notebooks, code, and data"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Update xbps itself before installing (the pinned base lags the rolling repo)
RUN xbps-install -Suy xbps

# Install packages
RUN xbps-install -Sy bash curl wget tar gzip procps-ng python3 && \
    xbps-remove -O && \
    rm -rf /var/cache/xbps/*

# Install Miniconda
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        CONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        CONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh"; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1; \
    fi && \
    wget -q $CONDA_URL -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p /opt/miniconda && \
    rm -rf /tmp/miniconda.sh && \
    /opt/miniconda/bin/conda clean -afy

# Update PATH to include Miniconda
ENV PATH="/opt/miniconda/bin:$PATH"

# Install JupyterLab
RUN conda install -y -c conda-forge jupyterlab && \
    conda clean -afy

# Setup scripts
RUN mkdir -p /opt/dxflow
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY entrypoint.sh /opt/dxflow/entrypoint.sh
RUN chmod +x /opt/dxflow/entrypoint.sh

ENV WORKING_DIR=""

EXPOSE 8888

VOLUME [ "/volume" ]

ENTRYPOINT [ "/opt/dxflow/entrypoint.sh" ]
