# Version pins — refresh them with .github/scripts/version.sh
ARG VERSION=7.16.2
ARG PHP_VERSION=8.3.33-fpm-bookworm

FROM php:${PHP_VERSION}

LABEL org.opencontainers.image.title="FileGator"
LABEL org.opencontainers.image.description="Web file manager for the engine volume"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Bring the pins into the stage (a pin declared above FROM only reaches FROM)
ARG VERSION

ENV DEBIAN_FRONTEND="noninteractive"

# Install packages (retry flaky mirrors, esp. arm64 ports)
RUN apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 update -q && \
    apt-get install -y -q --no-install-recommends \
        ca-certificates curl nginx unzip libzip-dev && \
    rm -rf /var/lib/apt/lists/*

# Install the zip extension — the archiver reads and writes zip in place, which is
# what lets a dataset be packed or unpacked on the engine instead of on a laptop
RUN docker-php-ext-install -j "$(nproc)" zip

# Install FileGator from the release build upstream publishes, which already carries
# vendor/ and the compiled dist/ — so nothing here needs composer or node, and the
# same pure-php tree runs on both arches.
# The exact version is named on purpose: a build that has moved on fails the build
# rather than quietly shipping something other than what this entry claims.
RUN curl -fsSL -o /tmp/filegator.zip \
        "https://github.com/filegator/static/raw/master/builds/filegator_v${VERSION}.zip" && \
    unzip -q /tmp/filegator.zip -d /var/www && \
    rm -f /tmp/filegator.zip && \
    rm -rf /var/www/filegator/repository \
        /var/www/filegator/configuration.php \
        /var/www/filegator/Dockerfile* \
        /var/www/filegator/docker-compose*.yml

# Private state — accounts, sessions, logs, and the chunks a resumable upload
# arrives in — belongs on the volume, so an account added in the admin UI outlives
# the container. The app reaches it under its own name through a symlink; the image
# keeps the pristine copy to seed an empty mount from.
RUN mkdir -p /opt/dxflow && \
    mv /var/www/filegator/private /opt/dxflow/private && \
    ln -s /data /var/www/filegator/private

COPY configuration.php /var/www/filegator/configuration.php

# nginx serves dist/ — the compiled front end, and the only entry point meant for
# production. The browsed directory is /volume, which is never under the document
# root, so nothing in it is reachable except through the app's own download route.
COPY nginx.conf /etc/nginx/nginx.conf

# The pool listens on a socket rather than the image's default tcp port, and keeps
# the container environment, which is how a hook reaches the same settings php does
COPY php-fpm.conf /usr/local/etc/php-fpm.d/zz-dxflow.conf

# Setup scripts
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY entrypoint.sh /opt/dxflow/entrypoint.sh
RUN chmod +x /opt/dxflow/entrypoint.sh

ENV USERNAME="admin"
ENV PASSWORD="dxflow"
ENV ROOT_DIR=""
ENV GUEST_PERMISSIONS=""
ENV UPLOAD_MAX_SIZE="10240"
ENV UPLOAD_CHUNK_SIZE="8"
ENV OVERWRITE_ON_UPLOAD="false"
ENV APP_NAME="dxflow Artifacts"
ENV TIMEZONE="UTC"
ENV RUN_AS="root"

EXPOSE 8080

VOLUME [ "/volume" ]
VOLUME [ "/data" ]

ENTRYPOINT [ "/opt/dxflow/entrypoint.sh" ]
