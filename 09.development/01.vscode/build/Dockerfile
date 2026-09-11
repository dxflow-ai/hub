# Version pins — refresh them with .github/scripts/version.sh
ARG PACKAGE_AMD64_VERSION=1.137.0-1788902055
ARG PACKAGE_ARM64_VERSION=1.137.0-1788902074

FROM ghcr.io/dxflow-ai/ubuntu:latest

LABEL org.opencontainers.image.title="Visual Studio Code"
LABEL org.opencontainers.image.description="Visual Studio Code in a remote desktop session"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Bring the pins into the stage (a pin declared above FROM only reaches FROM)
ARG PACKAGE_AMD64_VERSION
ARG PACKAGE_ARM64_VERSION

# Install VS Code from the Microsoft apt repo
# The exact version is named on purpose: a repository that has moved on fails the
# build rather than quietly shipping something other than what this entry claims.
# The arches are indexed under their own packaging timestamps, so each takes its
# own pin
RUN case "$(uname -m)" in \
        x86_64) PACKAGE="code=${PACKAGE_AMD64_VERSION}" ;; \
        aarch64) PACKAGE="code=${PACKAGE_ARM64_VERSION}" ;; \
        *) echo "no code pin for $(uname -m)" >&2 && exit 1 ;; \
    esac && \
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg && \
    install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg && \
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | tee /etc/apt/sources.list.d/vscode.list > /dev/null && \
    rm -f packages.microsoft.gpg && \
    apt-get update -q && \
    apt-get install -y -q --no-install-recommends --reinstall --fix-missing "$PACKAGE" && \
    rm -rf /var/lib/apt/lists/*

# Setup scripts
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY launch.sh /opt/dxflow/launch.sh

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
    /bin/bash -c "source /opt/miniconda/bin/activate && conda init" && \
    /opt/miniconda/bin/conda clean -afy

# Update PATH to include Miniconda
ENV PATH="/opt/miniconda/bin:$PATH"

# Use conda-forge and avoid the Anaconda default channels (which now require ToS)
RUN conda config --system --remove channels defaults 2>/dev/null || true && \
    conda config --system --add channels conda-forge && \
    conda config --system --set channel_priority strict

# Give the editor the full screen by hiding the window decorations and taskbar
ENV PANEL="hide"
ENV TASKBAR="hide"
