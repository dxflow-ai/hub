# Version pins — refresh them with .github/scripts/version.sh
ARG VERSION=1.30.4

FROM nginx:${VERSION}

LABEL org.opencontainers.image.title="Nginx"
LABEL org.opencontainers.image.description="Publish workflow artifacts as web resources, and edit the nginx configuration live"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

ENV DEBIAN_FRONTEND="noninteractive"

# Install packages — htpasswd writes the credential, curl is for a hook to reach
# whatever this is serving (retry flaky mirrors, esp. arm64 ports)
RUN apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 update -q && \
    apt-get install -y -q --no-install-recommends apache2-utils ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

# The image's own default site and template entrypoint are both replaced: the
# configuration this serves is rendered from the environment on every start, and
# from then on it is whatever the volume holds
RUN rm -f /etc/nginx/conf.d/default.conf /docker-entrypoint.d/*

# Setup scripts
RUN mkdir -p /opt/dxflow
COPY sample.conf /opt/dxflow/sample.conf
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY entrypoint.sh /opt/dxflow/entrypoint.sh
RUN chmod +x /opt/dxflow/entrypoint.sh

ENV SITE_DIR=""
ENV CONFIG_DIR="nginx"
ENV AUTOINDEX="on"
ENV CORS="off"
ENV GZIP="on"
ENV WORKER_PROCESSES="auto"
ENV WORKER_USER="nginx"
ENV RELOAD_INTERVAL="5"

EXPOSE 8080

VOLUME [ "/volume" ]

ENTRYPOINT [ "/opt/dxflow/entrypoint.sh" ]
