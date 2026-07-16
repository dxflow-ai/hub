FROM ubuntu:22.04

LABEL org.opencontainers.image.title="SU2"
LABEL org.opencontainers.image.description="Open-source CFD suite for aerodynamic analysis and optimization"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

ENV DEBIAN_FRONTEND="noninteractive"

# Install dependencies
RUN apt-get update -q && \
    apt-get install -y -q --no-install-recommends wget unzip python3 openmpi-bin libopenmpi-dev && \
    rm -rf /var/lib/apt/lists/*

# Install pip and numpy
RUN wget -q --no-check-certificate "https://bootstrap.pypa.io/get-pip.py" -O /tmp/get-pip.py && \
    python3 /tmp/get-pip.py && \
    pip install numpy && \
    rm -rf /tmp/get-pip.py

# Install SU2
RUN mkdir -p /models && \
    wget -q -P /models https://github.com/su2code/SU2/releases/download/v8.0.1/SU2-v8.0.1-linux64.zip && \
    unzip /models/SU2-v8.0.1-linux64.zip -d /models/SU2-v8.0.1-linux64 && \
    rm -rf /models/SU2-v8.0.1-linux64.zip

# SU2 environment
ENV SU2_RUN="/models/SU2-v8.0.1-linux64/bin"
ENV PATH="/models/SU2-v8.0.1-linux64/bin:$PATH"
ENV PYTHONPATH="/models/SU2-v8.0.1-linux64/bin:$PYTHONPATH"
ENV OMPI_ALLOW_RUN_AS_ROOT=1
ENV OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1

WORKDIR /data
VOLUME [ "/data" ]
