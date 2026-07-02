#!/bin/sh

set -u

log() {
  echo "[runner] $*";
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

# Start the VNC server
log "starting VNC server on :1"
vncserver -xstartup /root/.vnc/xstartup -name dxflow -geometry 1920x1080 -depth 24 :1 > /var/log/vnc.log 2>&1

# Start the noVNC proxy
log "starting noVNC proxy on :6082"
/opt/novnc/utils/novnc_proxy --vnc 127.0.0.1:5901 --listen 0.0.0.0:6082 --file-only > /var/log/novnc.log 2>&1 &
NOVNC_PID=$!

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
