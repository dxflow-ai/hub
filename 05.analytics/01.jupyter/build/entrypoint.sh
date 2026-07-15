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

# Start JupyterLab on the working directory under /volume
workdir="/volume/$(printf '%s' "${WORKING_DIR:-}" | sed 's|^/||')"
mkdir -p "${workdir}"
log "starting jupyterlab on :8888 at ${workdir}"
jupyter lab \
  --ip=0.0.0.0 \
  --port=8888 \
  --allow-root \
  --no-browser \
  --NotebookApp.token='' \
  --notebook-dir="${workdir}" > /var/log/jupyterlab.log 2>&1 &
JUPYTER_PID=$!

# Run postpare hook
run_hook postpare

log "ready"

# Wait until stopped
trap 'log "stopping"; kill "$JUPYTER_PID" 2>/dev/null; exit 0' TERM INT
wait "$JUPYTER_PID"
