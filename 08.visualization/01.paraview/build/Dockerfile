# Version pins — refresh them with .github/scripts/version.sh
ARG VERSION=6.1.1
ARG PYTHON_VERSION=3.12

FROM ghcr.io/dxflow-ai/ubuntu:latest

LABEL org.opencontainers.image.title="ParaView"
LABEL org.opencontainers.image.description="Parallel scientific visualization for large datasets"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Bring the pins into the stage (a pin declared above FROM only reaches FROM)
ARG VERSION
ARG PYTHON_VERSION

# Install ParaView
RUN wget -q --tries=5 --waitretry=5 --retry-connrefused --no-check-certificate "https://www.paraview.org/paraview-downloads/download.php?submit=Download&version=v${VERSION%.*}&type=binary&os=Linux&downloadFile=ParaView-${VERSION}-MPI-Linux-Python${PYTHON_VERSION}-x86_64.tar.gz" -O /tmp/paraview.tar.gz && \
    tar -zxf /tmp/paraview.tar.gz -C /opt && \
    mv /opt/ParaView-${VERSION}-MPI-Linux-Python${PYTHON_VERSION}-x86_64 /opt/paraview && \
    ln -s /opt/paraview/bin/* /usr/bin && \
    rm -rf /tmp/paraview.tar.gz

# Setup ParaView settings
COPY paraview/ParaView.ini /root/.config/ParaView/ParaView${VERSION}.ini

# Setup scripts
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY launch.sh /opt/dxflow/launch.sh

# Give the app the full screen by hiding the window decorations and taskbar
ENV PANEL="hide"
ENV TASKBAR="hide"
