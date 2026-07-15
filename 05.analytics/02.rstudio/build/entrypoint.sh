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

# Give the RStudio user a home under /volume so sessions persist
USER="${USER:-diphyx}"
export USER
export HOME="/volume/${USER}"
mkdir -p "${HOME}"
chown -R "${USER}:${USER}" "${HOME}" 2>/dev/null || true

# Start RStudio Server
log "starting rstudio-server on :8787"
/usr/lib/rstudio-server/bin/rserver \
  --server-user=root \
  --server-daemonize=0 \
  --auth-none=1 \
  --www-address=0.0.0.0 \
  --www-port=8787 \
  --www-verify-user-agent=0 \
  --www-root-path=/ > /var/log/rstudio-server.log 2>&1 &
RSTUDIO_PID=$!

# Run postpare hook
run_hook postpare

log "ready"

# Wait until stopped
trap 'log "stopping"; kill "$RSTUDIO_PID" 2>/dev/null; exit 0' TERM INT
wait "$RSTUDIO_PID"
