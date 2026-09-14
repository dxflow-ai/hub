# Version pins — refresh them with .github/scripts/version.sh
ARG VERSION=2026.09.0-174

FROM ghcr.io/void-linux/void-glibc:latest

LABEL org.opencontainers.image.title="RStudio Server"
LABEL org.opencontainers.image.description="Browser-based IDE for R statistical computing and graphics"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Bring the pins into the stage (a pin declared above FROM only reaches FROM)
ARG VERSION

# Install packages (R runs the sessions, pam authenticates the sign-in)
RUN xbps-install -Sy bash shadow pam binutils findutils tar gzip curl xbps xz openssl R && \
    xbps-remove -O && \
    rm -rf /var/cache/xbps/*

# Install xdeb
RUN curl -L -o /tmp/xdeb https://github.com/xdeb-org/xdeb/releases/latest/download/xdeb && \
    chmod +x /tmp/xdeb

# Install rstudio-server (current build, compatible with modern R).
# The deb -> xbps conversion drops the executable bit, so restore it across the whole
# bin tree: rserver forks rserver-pam to check the password and rsession to open the
# IDE, and a non-executable helper reads back as a rejected sign-in.
RUN curl -L -o /tmp/rstudio-server.deb https://download2.rstudio.org/server/jammy/amd64/rstudio-server-${VERSION}-amd64.deb && \
    cd /tmp && \
    /tmp/xdeb -Sd --not-deps="musl1.1" /tmp/rstudio-server.deb && \
    xbps-install -y -R /tmp/binpkgs rstudio-server && \
    chmod -R a+x /usr/lib/rstudio-server/bin

# Cleanup
RUN xbps-remove -O && \
    rm -rf /var/cache/xbps/* && \
    rm -rf /tmp/*

# Create the RStudio session user (rsession runs as a real user, not root).
# pwconv makes sure /etc/shadow is the file the password lands in, so PAM finds it
RUN useradd -d /volume/dxflow -s /bin/bash dxflow && \
    pwconv

# Give sign-in a PAM profile to authenticate against (the converted deb omits /etc/pam.d)
RUN mkdir -p /etc/pam.d && \
    if [ ! -f /etc/pam.d/rstudio ]; then \
        printf 'auth     required pam_unix.so\naccount  required pam_unix.so\npassword required pam_unix.so\nsession  required pam_unix.so\n' > /etc/pam.d/rstudio; \
    fi

# Setup scripts
RUN mkdir -p /opt/dxflow
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY entrypoint.sh /opt/dxflow/entrypoint.sh
RUN chmod +x /opt/dxflow/entrypoint.sh

ENV USER="dxflow"

EXPOSE 8787

VOLUME [ "/volume" ]

ENTRYPOINT [ "/opt/dxflow/entrypoint.sh" ]
