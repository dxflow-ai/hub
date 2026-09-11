# Version pins — refresh them with .github/scripts/version.sh
ARG VERSION=1.30.4

FROM nginx:${VERSION}

LABEL org.opencontainers.image.title="Nginx"
LABEL org.opencontainers.image.description="Web server and reverse proxy that reloads itself when its configuration changes"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

ENV DEBIAN_FRONTEND="noninteractive"

# Install packages — htpasswd writes the credential, curl is for a hook to reach
# whatever this is fronting (retry flaky mirrors, esp. arm64 ports)
RUN apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 update -q && \
    apt-get install -y -q --no-install-recommends apache2-utils ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

# The image's own default site and template entrypoint are both replaced: the
# configuration this serves is rendered from the environment on every start, and
# then owned by whatever the volume holds
RUN rm -f /etc/nginx/conf.d/default.conf /docker-entrypoint.d/*

# Setup scripts
RUN mkdir -p /opt/dxflow
COPY sample.conf /opt/dxflow/sample.conf
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY entrypoint.sh /opt/dxflow/entrypoint.sh
RUN chmod +x /opt/dxflow/entrypoint.sh

ENV ROOT_DIR=""
ENV CONFIG_DIR="nginx"
ENV USERNAME="dxflow"
ENV PASSWORD="dxflow"
ENV AUTOINDEX="on"
ENV CLIENT_MAX_BODY_SIZE="0"
ENV SERVER_NAME="_"
ENV RELOAD_INTERVAL="5"
ENV WORKER_PROCESSES="auto"
ENV RUN_AS="root"

EXPOSE 8080 8081

VOLUME [ "/volume" ]

ENTRYPOINT [ "/opt/dxflow/entrypoint.sh" ]
