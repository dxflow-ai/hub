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

# Start the Ollama server
log "starting ollama server on :11434"
OLLAMA_HOST=0.0.0.0:11434 OLLAMA_ORIGINS=* ollama serve > /var/log/ollama.log 2>&1 &
OLLAMA_PID=$!

# Wait for the API to answer
i=0
while [ "$i" -lt 30 ] && ! curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1; do
  i=$((i + 1))
  sleep 1
done

# Pull the startup model
model="${STARTUP_MODEL:-smollm2:135m}"
log "pulling startup model ${model}"
ollama pull "${model}" > /var/log/pull.log 2>&1 || log "failed to pull ${model} (continuing)"

# Start the web interface
log "starting web interface on :8080"
nginx -g 'daemon off;' > /var/log/nginx.log 2>&1 &
NGINX_PID=$!

# Run postpare hook
run_hook postpare

log "ready"

# Wait until stopped
trap 'log "stopping"; kill "$NGINX_PID" "$OLLAMA_PID" 2>/dev/null; exit 0' TERM INT
wait "$NGINX_PID"
