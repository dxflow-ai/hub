FROM ghcr.io/void-linux/void-glibc:latest

LABEL org.opencontainers.image.title="RStudio Server"
LABEL org.opencontainers.image.description="Browser-based IDE for R statistical computing and graphics"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Install packages
RUN xbps-install -Sy bash shadow binutils findutils tar gzip curl xbps xz libcrypto1.1 libssl1.1 && \
    xbps-remove -O && \
    rm -rf /var/cache/xbps/*

# Install xdeb
RUN curl -L -o /tmp/xdeb https://github.com/xdeb-org/xdeb/releases/latest/download/xdeb && \
    chmod +x /tmp/xdeb

# Install rstudio-server
RUN curl -L -o /tmp/rstudio-server.deb https://download2.rstudio.org/server/bionic/amd64/rstudio-server-1.4.1717-amd64.deb && \
    cd /tmp && \
    /tmp/xdeb -Sd /tmp/rstudio-server.deb && \
    xbps-install -y -R /tmp/binpkgs rstudio-server-1.4.1717_1 && \
    chmod +x /usr/lib/rstudio-server/bin/rserver

# Cleanup
RUN xbps-remove -O && \
    rm -rf /var/cache/xbps/* && \
    rm -rf /tmp/*

# Setup scripts
RUN mkdir -p /opt/dxflow
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY entrypoint.sh /opt/dxflow/entrypoint.sh
RUN chmod +x /opt/dxflow/entrypoint.sh

ENV USER="diphyx"

EXPOSE 8787

VOLUME [ "/volume" ]

ENTRYPOINT [ "/opt/dxflow/entrypoint.sh" ]
