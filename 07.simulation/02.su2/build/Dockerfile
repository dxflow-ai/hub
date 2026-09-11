# Version pins — refresh them with .github/scripts/version.sh
ARG VERSION=8.5.0

FROM ubuntu:22.04

LABEL org.opencontainers.image.title="SU2"
LABEL org.opencontainers.image.description="Open-source CFD suite for aerodynamic analysis and optimization"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Bring the pins into the stage (a pin declared above FROM only reaches FROM)
ARG VERSION

ENV DEBIAN_FRONTEND="noninteractive"

# Install dependencies
RUN apt-get update -q && \
    apt-get install -y -q --no-install-recommends ca-certificates wget unzip python3 openmpi-bin libopenmpi-dev && \
    rm -rf /var/lib/apt/lists/*

# Install pip and numpy
RUN wget -q --no-check-certificate "https://bootstrap.pypa.io/get-pip.py" -O /tmp/get-pip.py && \
    python3 /tmp/get-pip.py && \
    pip install numpy && \
    rm -rf /tmp/get-pip.py

# Install SU2. The release carries an MPI build and an OpenMP one, and this image
# is the MPI one — it installs openmpi and the page documents `mpirun -np N`. The
# asset is a zip holding one zip, so it comes out in two goes, and the inner one
# opens onto the bin/ the environment below points at.
RUN mkdir -p /models /tmp/su2 && \
    wget -q -O /tmp/su2.zip https://github.com/su2code/SU2/releases/download/v${VERSION}/SU2-v${VERSION}-linux64-mpi.zip && \
    unzip -q /tmp/su2.zip -d /tmp/su2 && \
    unzip -q /tmp/su2/*.zip -d /models/SU2-v${VERSION}-linux64 && \
    rm -rf /tmp/su2.zip /tmp/su2

# SU2 environment
ENV SU2_RUN="/models/SU2-v${VERSION}-linux64/bin"
ENV PATH="/models/SU2-v${VERSION}-linux64/bin:$PATH"
ENV PYTHONPATH="/models/SU2-v${VERSION}-linux64/bin"
ENV OMPI_ALLOW_RUN_AS_ROOT=1
ENV OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1

WORKDIR /data
VOLUME [ "/data" ]
