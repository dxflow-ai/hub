# Version pins — refresh them with .github/scripts/version.sh
ARG PACKAGE_VERSION=2.5.2-0.13_snap20220518.fc44

FROM ghcr.io/dxflow-ai/fedora:latest

LABEL org.opencontainers.image.title="Gabedit"
LABEL org.opencontainers.image.description="Graphical user interface to computational chemistry packages"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

# Bring the pins into the stage (a pin declared above FROM only reaches FROM)
ARG PACKAGE_VERSION

# Install gabedit from the Fedora repositories
# The exact version is named on purpose: a repository that has moved on fails the
# build rather than quietly shipping something other than what this entry claims.
# Fedora builds every arch from one source build, so one pin covers both
# mesa-dri-drivers comes along unpinned: no runner has a card, so the app renders
# through Mesa's software driver, which is the base's business rather than a
# version this entry claims
RUN dnf install -y --setopt=install_weak_deps=False --allowerasing \
    "gabedit-${PACKAGE_VERSION}" mesa-dri-drivers && \
    dnf clean all && \
    rm -rf /var/cache/dnf/*

# Setup scripts
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY launch.sh /opt/dxflow/launch.sh

# Give the app the full screen by hiding the window decorations and taskbar
ENV PANEL="hide"
ENV TASKBAR="hide"
