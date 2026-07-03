FROM ubuntu:22.04

LABEL org.opencontainers.image.title="Ubuntu Desktop"
LABEL org.opencontainers.image.description="Full Ubuntu Linux desktop accessible from your browser"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

ENV LANG="en_US.utf8"
ENV DEBIAN_FRONTEND="noninteractive"

# Extend the apt http timeout
RUN echo 'Acquire::http::Timeout "120";' > /etc/apt/apt.conf.d/99timeout

# Install packages
RUN apt-get update -q && \
    apt-get install -y -q --no-install-recommends --reinstall --fix-missing \
    bash grep gzip gnupg xz-utils zip file sed unzip gawk less tar manpages passwd procps ncurses-base tzdata sudo nano vim iputils-ping wget curl git python3 xorg xauth xinit openbox feh tint2 fonts-dejavu python3-xdg qterminal autocutsel wmctrl alsa-base alsa-utils pulseaudio pulseaudio-utils && \
    rm -rf /var/lib/apt/lists/*

# Install turbovnc
RUN wget -q -O- https://packagecloud.io/dcommander/turbovnc/gpgkey | gpg --dearmor >/etc/apt/trusted.gpg.d/TurboVNC.gpg && \
    wget -q -O /etc/apt/sources.list.d/TurboVNC.list https://raw.githubusercontent.com/TurboVNC/repo/main/TurboVNC.list && \
    apt-get update -q && \
    apt-get install -y -q --no-install-recommends --reinstall --fix-missing turbovnc && \
    ln -s /opt/TurboVNC/bin/Xvnc /usr/bin/Xvnc && \
    ln -s /opt/TurboVNC/bin/vncpasswd /usr/bin/vncpasswd && \
    ln -s /opt/TurboVNC/bin/vncserver /usr/bin/vncserver && \
    ln -s /opt/TurboVNC/bin/webserver /usr/bin/webserver && \
    rm -rf /var/lib/apt/lists/*

# Install qtfm
RUN apt-get update -q && \
    apt-get install -y -q --no-install-recommends --reinstall --fix-missing make qt5-qmake g++ qtbase5-dev qtbase5-dev-tools && \
    wget https://github.com/rodlie/qtfm/archive/refs/tags/6.2.1.tar.gz -O /tmp/qtfm.tar.gz && \
    tar -zxf /tmp/qtfm.tar.gz -C /tmp && \
    cd /tmp/qtfm-6.2.1/ && qmake && make && make install && rm -rf /tmp/* && \
    rm -rf /var/lib/apt/lists/*

# Install noVNC
RUN wget -q --no-check-certificate "https://github.com/novnc/noVNC/archive/refs/tags/v1.5.0.tar.gz" -O /tmp/novnc.tar.gz && \
    tar -zxf /tmp/novnc.tar.gz -C /opt && \
    mv /opt/noVNC-1.5.0 /opt/novnc && \
    rm -rf /tmp/novnc.tar.gz

# Install websockify
RUN wget -q --no-check-certificate "https://github.com/novnc/websockify/archive/refs/tags/v0.12.0.tar.gz" -O /tmp/websockify.tar.gz && \
    tar -zxf /tmp/websockify.tar.gz -C /opt && \
    mkdir -p /opt/novnc/utils && \
    mv /opt/websockify-0.12.0 /opt/novnc/utils/websockify && \
    rm -rf /tmp/websockify.tar.gz

# Setup user
RUN mkdir -p /volume/app && \
    groupadd app && \
    useradd -r -g app -d /volume/app app && \
    echo "%app ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers.d/app && \
    pwconv

# Allow root (the desktop user) to reach the system-wide PulseAudio
RUN usermod -aG pulse-access root 2>/dev/null || true

# Setup vnc
RUN mkdir -p /root/.vnc
COPY vnc/xstartup /root/.vnc/xstartup
RUN chmod +x /root/.vnc/xstartup

# Setup openbox
RUN mkdir -p /root/.config/openbox
COPY openbox/rc.xml /root/.config/openbox/rc.xml
COPY openbox/menu.xml /root/.config/openbox/menu.xml
COPY openbox/wallpaper.jpg /root/.config/openbox/wallpaper.jpg

# Setup tint2
RUN mkdir -p /root/.config/tint2
COPY tint2/tint2rc /root/.config/tint2/tint2rc

# Setup pulseaudio
RUN mkdir -p /root/.config/pulse
COPY pulseaudio/client.conf /root/.config/pulse/client.conf
COPY pulseaudio/daemon.conf /root/.config/pulse/daemon.conf

# Setup novnc
COPY novnc/index.html /opt/novnc/index.html
RUN mkdir -p /opt/novnc/app
COPY novnc/audio.js /opt/novnc/app/audio.js
COPY novnc/ui.js /opt/novnc/app/ui.js

# Setup qterminal
RUN mkdir -p /root/.config/qterminal.org
COPY qterminal/qterminal.ini /root/.config/qterminal.org/qterminal.ini

# Setup qtfm
RUN mkdir -p /root/.config/qtfm6
COPY qtfm/qtfm6.conf /root/.config/qtfm6/qtfm6.conf

# Setup themes
RUN mkdir -p /root/.themes
COPY themes /root/.themes

# Setup applications
RUN mkdir -p /root/.local/share/applications
COPY applications/qterminal.desktop /root/.local/share/applications/qterminal.desktop
COPY applications/qtfm.desktop /root/.local/share/applications/qtfm.desktop

# Setup icons
RUN mkdir -p /root/.local/share/icons
COPY icons/qterminal.svg /root/.local/share/icons/qterminal.svg
COPY icons/qtfm.svg /root/.local/share/icons/qtfm.svg

# Setup scripts
RUN mkdir -p /opt/dxflow
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY launch.sh /opt/dxflow/launch.sh
COPY audio.py /opt/dxflow/audio.py
COPY entrypoint.sh /opt/dxflow/entrypoint.sh
RUN chmod +x /opt/dxflow/entrypoint.sh

ENV DISPLAY=":1"
ENV WALLPAPER="show"
ENV PANEL="show"
ENV TASKBAR="show"
ENV AUDIO="off"
ENV AUDIO_PORT="6100"
ENV AUDIO_CHANNELS="1"
ENV AUDIO_RATE="22050"

EXPOSE 5901 6082 6100

VOLUME [ "/volume" ]

ENTRYPOINT [ "/opt/dxflow/entrypoint.sh" ]
