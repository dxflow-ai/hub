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

# Start code-server on the working directory under /volume
workdir="/volume/$(printf '%s' "${WORKING_DIR:-/}" | sed 's|^/||')"
log "starting code-server on :8080 at ${workdir}"
/root/.local/bin/code-server \
  --bind-addr=0.0.0.0:8080 \
  --auth=none \
  --disable-telemetry \
  --disable-update-check \
  --disable-workspace-trust \
  --disable-getting-started-override \
  "${workdir}" > /var/log/coder.log 2>&1 &
CODE_PID=$!

# Run postpare hook
run_hook postpare

log "ready"

# Wait until stopped
trap 'log "stopping"; kill "$CODE_PID" 2>/dev/null; exit 0' TERM INT
wait "$CODE_PID"
