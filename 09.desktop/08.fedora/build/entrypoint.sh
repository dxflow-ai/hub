#!/bin/sh

set -u

log() {
  echo "[entrypoint] $*";
}

run_hook() {
  script="/opt/dxflow/$1.sh"
  if [ -f "$script" ]; then
    log "$1"
    /bin/sh "$script" > "/var/log/$1.log" 2>&1 || log "$1 failed (continuing)"
  fi
}

# Run prepare hook
run_hook prepare

# Set VNC password once
if [ ! -f /tmp/.password_created ]; then
  printf '%s' "${VNC_PASSWORD:-anonymous}" | vncpasswd -f > /root/.vnc/passwd
  chmod 600 /root/.vnc/passwd
  touch /tmp/.password_created
fi

# Clear any previous session
pkill -f novnc_proxy 2>/dev/null || true
vncserver -kill :1 2>/dev/null || true

# Start PulseAudio before the desktop so its apps route sound into the null sink
# (the desktop runs as root, so PulseAudio runs system-wide). PULSE_SERVER is
# exported here so the VNC session, parec, and pactl all find the same daemon.
audio="${AUDIO:-off}"
if [ "$audio" = "on" ]; then
  log "starting PulseAudio"
  export PULSE_SERVER="unix:/run/pulse/native"
  pulseaudio --system --daemonize --exit-idle-time=-1 --disallow-exit > /var/log/pulseaudio.log 2>&1 || log "pulseaudio failed (continuing without audio)"
  pactl load-module module-null-sink sink_name=virtual > /dev/null 2>&1 || true
  pactl set-default-sink virtual > /dev/null 2>&1 || true
fi

# Start the VNC server (inherits PULSE_SERVER when audio is on)
log "starting VNC server on :1"
vncserver -xstartup /root/.vnc/xstartup -name dxflow -geometry 1920x1080 -depth 24 :1 > /var/log/vnc.log 2>&1

# Start the noVNC proxy
log "starting noVNC proxy on :6082"
/opt/novnc/utils/novnc_proxy --vnc 127.0.0.1:5901 --listen 0.0.0.0:6082 --file-only > /var/log/novnc.log 2>&1 &
NOVNC_PID=$!

# Start the browser audio proxy and point the client at it
if [ "$audio" = "on" ]; then
  log "starting audio proxy on :${AUDIO_PORT:-6100}"
  sed -i \
    -e 's/const ENABLE = false;/const ENABLE = true;/' \
    -e "s/const CHANNELS = 1;/const CHANNELS = ${AUDIO_CHANNELS:-1};/" \
    -e "s/const RATE = 22050;/const RATE = ${AUDIO_RATE:-22050};/" \
    /opt/novnc/app/audio.js 2>/dev/null || true
  sed -i "s|-6100/|-${AUDIO_PORT:-6100}/|" /opt/novnc/app/ui.js 2>/dev/null || true
  python3 /opt/dxflow/audio.py > /var/log/audio.log 2>&1 &
else
  log "audio disabled"
fi

# Run postpare hook
run_hook postpare

# Launch the app
if [ -f /opt/dxflow/launch.sh ]; then
  log "launch"
  /bin/sh /opt/dxflow/launch.sh > /var/log/launch.log 2>&1 &
fi

log "ready"

# Wait until stopped
trap 'log "stopping"; vncserver -kill :1 2>/dev/null; exit 0' TERM INT
wait "$NOVNC_PID"
