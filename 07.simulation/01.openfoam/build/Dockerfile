FROM openfoam/openfoam10-paraview510:latest

LABEL org.opencontainers.image.title="OpenFOAM"
LABEL org.opencontainers.image.description="Open source computational fluid dynamics (CFD) software"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

ENV DEBIAN_FRONTEND="noninteractive"

# Install dependencies (the base image runs as a non-root user with passwordless sudo)
RUN sudo apt-get update -q && \
    sudo apt-get install -y -q --no-install-recommends unzip && \
    sudo rm -rf /var/lib/apt/lists/*

WORKDIR /data
VOLUME [ "/data" ]
