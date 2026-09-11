# Version pins — refresh them with .github/scripts/version.sh
ARG VERSION=10
ARG PARAVIEW_VERSION=510

FROM openfoam/openfoam${VERSION}-paraview${PARAVIEW_VERSION}:latest

LABEL org.opencontainers.image.title="OpenFOAM"
LABEL org.opencontainers.image.description="Open source computational fluid dynamics (CFD) software"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

ENV DEBIAN_FRONTEND="noninteractive"

# Install dependencies (base runs as a non-root uid without sudo)
USER root
RUN apt-get update -q && \
    apt-get install -y -q --no-install-recommends unzip && \
    rm -rf /var/lib/apt/lists/*

# Restore the base uid
USER 98765

WORKDIR /data
VOLUME [ "/data" ]
