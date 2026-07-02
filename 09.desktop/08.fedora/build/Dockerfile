FROM fedora:41

LABEL org.opencontainers.image.title="Fedora Desktop"
LABEL org.opencontainers.image.description="Full Fedora Linux desktop accessible from your browser"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"
LABEL org.opencontainers.image.version="41"

ENV LANG="C.UTF-8"

# Install packages
RUN dnf install -y --setopt=install_weak_deps=False --allowerasing \
    bash grep gzip xz zip file sed unzip gawk less which tar man-pages shadow-utils procps-ng ncurses tzdata sudo util-linux nano vim iputils wget curl git python3 xorg-x11-server-Xorg xorg-x11-xauth xorg-x11-xinit openbox feh dejavu-sans-fonts qterminal wmctrl alsa-lib alsa-utils pulseaudio pulseaudio-utils && \
    dnf clean all && \
    rm -rf /var/cache/dnf/*

# Install turbovnc
RUN wget -q -O /etc/yum.repos.d/TurboVNC.repo https://raw.githubusercontent.com/TurboVNC/repo/main/TurboVNC.repo && \
    dnf install -y --setopt=install_weak_deps=False --allowerasing turbovnc && \
    ln -s /opt/TurboVNC/bin/Xvnc /usr/bin/Xvnc && \
    ln -s /opt/TurboVNC/bin/vncpasswd /usr/bin/vncpasswd && \
    ln -s /opt/TurboVNC/bin/vncserver /usr/bin/vncserver && \
    ln -s /opt/TurboVNC/bin/webserver /usr/bin/webserver && \
    rm -rf /var/cache/dnf/*

# Install tint2
RUN dnf install -y --setopt=install_weak_deps=False --allowerasing make cmake gcc-c++ cairo pango glib2 imlib2-devel gtk3-devel libXinerama-devel libXrender-devel libXcomposite-devel libXdamage-devel libX11-devel libXrandr-devel librsvg2-devel && \
    wget https://gitlab.com/o9000/tint2/-/archive/v17.0.2/tint2-v17.0.2.tar.gz -O /tmp/tint2.tar.gz && \
    tar -zxf /tmp/tint2.tar.gz -C /tmp && \
    cd /tmp/tint2-v17.0.2/ && cmake -D ENABLE_BATTERY=OFF -D ENABLE_TINT2CONF=OFF -D ENABLE_SN=OFF -B build && make -C build && make -C build install && \
    rm -rf /tmp/* && \
    rm -rf /var/cache/dnf/*

# Install autocutsel
RUN dnf install -y --setopt=install_weak_deps=False --allowerasing make libX11-devel libXtst-devel libXaw-devel && \
    wget https://github.com/sigmike/autocutsel/releases/download/0.10.1/autocutsel-0.10.1.tar.gz -O /tmp/autocutsel.tar.gz && \
    tar -zxf /tmp/autocutsel.tar.gz -C /tmp && \
    cd /tmp/autocutsel-0.10.1/ && sh configure && make && make install && \
    rm -rf /tmp/* && \
    rm -rf /var/cache/dnf/*

# Install qtfm
RUN dnf install -y --setopt=install_weak_deps=False --allowerasing make cmake gcc-c++ qt5-qtbase-devel && \
    wget https://github.com/rodlie/qtfm/archive/refs/tags/6.2.1.tar.gz -O /tmp/qtfm.tar.gz && \
    tar -zxf /tmp/qtfm.tar.gz -C /tmp && \
    cd /tmp/qtfm-6.2.1/ && qmake-qt5 && make && make install && \
    rm -rf /tmp/* && \
    rm -rf /var/cache/dnf/*

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
