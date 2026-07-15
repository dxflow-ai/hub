FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

ARG GMX_VERSION=2025.2

LABEL org.opencontainers.image.title="GROMACS"
LABEL org.opencontainers.image.description="Molecular dynamics simulation package for biomolecular systems"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

ENV DEBIAN_FRONTEND=noninteractive \
    CUDA_HOME=/usr/local/cuda \
    CUDAToolkit_ROOT=/usr/local/cuda

# Build dependencies (MPI + CUDA toolchain)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates gnupg wget curl git build-essential ninja-build pkg-config \
        libopenmpi-dev openmpi-bin && \
    rm -rf /var/lib/apt/lists/*

# Latest CMake (>= 3.28) from the Kitware repo
RUN curl -fsSL https://apt.kitware.com/keys/kitware-archive-latest.asc | \
        gpg --dearmor -o /usr/share/keyrings/kitware-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ jammy main" \
        > /etc/apt/sources.list.d/kitware.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends cmake && \
    rm -rf /var/lib/apt/lists/*

# Download GROMACS
WORKDIR /opt
RUN wget -q https://ftp.gromacs.org/gromacs/gromacs-${GMX_VERSION}.tar.gz && \
    tar -xzf gromacs-${GMX_VERSION}.tar.gz && \
    rm gromacs-${GMX_VERSION}.tar.gz

# Build with both MPI and CUDA (runs on GPU when attached, CPU otherwise)
WORKDIR /opt/gromacs-${GMX_VERSION}/build
RUN cmake .. \
      -DGMX_MPI=ON \
      -DGMX_GPU=CUDA \
      -DGMX_BUILD_OWN_FFTW=ON \
      -DGMX_OPENMP=ON \
      -DGMX_SIMD=AVX2_256 && \
    make -j"$(nproc)" && \
    make install && \
    rm -rf /opt/gromacs-${GMX_VERSION}

ENV GMX_HOME=/usr/local/gromacs \
    PATH="/usr/local/gromacs/bin:${PATH}" \
    GMXDATA="/usr/local/gromacs/share/gromacs" \
    LD_LIBRARY_PATH="/usr/local/cuda/lib64:/usr/local/cuda/extras/CUPTI/lib64:${LD_LIBRARY_PATH}"

# Bash completion / environment for interactive users
RUN echo 'source /usr/local/gromacs/bin/GMXRC' > /etc/profile.d/gmxrc.sh

WORKDIR /volume

VOLUME [ "/volume" ]
