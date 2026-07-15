FROM ghcr.io/dxflow-ai/ubuntu:latest

LABEL org.opencontainers.image.title="ParaView"
LABEL org.opencontainers.image.description="Parallel scientific visualization for large datasets"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Install ParaView
RUN wget -q --tries=5 --waitretry=5 --retry-connrefused --no-check-certificate "https://www.paraview.org/paraview-downloads/download.php?submit=Download&version=v5.13&type=binary&os=Linux&downloadFile=ParaView-5.13.2-MPI-Linux-Python3.10-x86_64.tar.gz" -O /tmp/paraview.tar.gz && \
    tar -zxf /tmp/paraview.tar.gz -C /opt && \
    mv /opt/ParaView-5.13.2-MPI-Linux-Python3.10-x86_64 /opt/paraview && \
    ln -s /opt/paraview/bin/* /usr/bin && \
    rm -rf /tmp/paraview.tar.gz

# Setup ParaView settings
COPY paraview/ParaView.ini /root/.config/ParaView/ParaView5.13.2.ini

# Setup scripts
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY launch.sh /opt/dxflow/launch.sh

# Give the app the full screen by hiding the window decorations and taskbar
ENV PANEL="hide"
ENV TASKBAR="hide"
