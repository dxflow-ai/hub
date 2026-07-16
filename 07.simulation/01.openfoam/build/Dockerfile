FROM openfoam/openfoam10-paraview510:latest

LABEL org.opencontainers.image.title="OpenFOAM"
LABEL org.opencontainers.image.description="Open source computational fluid dynamics (CFD) software"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

ENV DEBIAN_FRONTEND="noninteractive"

# Install dependencies
RUN apt-get update -q && \
    apt-get install -y -q --no-install-recommends unzip && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /data
VOLUME [ "/data" ]
