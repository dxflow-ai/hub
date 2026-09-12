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

data="${DATA_DIR:-/volume/data}"
models="${OLLAMA_MODELS:-/volume/models}"
mkdir -p "$data" "$models"

# Seed the model store on a fresh volume, from the copy baked into the image
if [ ! -d "$models/manifests" ] && [ -d /opt/dxflow/models/manifests ]; then
  log "seeding the model store at ${models}"
  cp -a /opt/dxflow/models/. "$models/"
fi

# Sessions survive a restart only if the key that signs them does, and the
# container is started with --rm, so keep it on the volume, not in the image
if [ -z "${WEBUI_SECRET_KEY:-}" ]; then
  secret="${data}/.secret"
  [ -f "$secret" ] || head -c 32 /dev/urandom | base64 | tr -d '\n' > "$secret"
  WEBUI_SECRET_KEY="$(cat "$secret")"
  export WEBUI_SECRET_KEY
fi

# Serve from the model servers named, or from the one bundled in this image
OLLAMA_PID=""
if [ -n "${OLLAMA_BASE_URLS:-}" ]; then
  log "serving models from ${OLLAMA_BASE_URLS}"
  OLLAMA_BASE_URL=""
  export OLLAMA_BASE_URL OLLAMA_BASE_URLS
else
  OLLAMA_BASE_URL="http://127.0.0.1:11434"
  export OLLAMA_BASE_URL

  # Bound to the loopback: the only way in is port 8080, which asks who is asking
  log "starting the model server on 127.0.0.1:11434"
  OLLAMA_HOST=127.0.0.1:11434 ollama serve > /var/log/ollama.log 2>&1 &
  OLLAMA_PID=$!

  i=0
  while [ "$i" -lt 30 ] && ! curl -sf http://127.0.0.1:11434/api/tags > /dev/null 2>&1; do
    i=$((i + 1))
    sleep 1
  done
fi

# Start the web interface — upstream's launcher, with its own ollama disabled
log "starting the interface on :8080"
bash /app/backend/start.sh > /var/log/webui.log 2>&1 &
WEBUI_PID=$!

# Wait for it to answer
i=0
while [ "$i" -lt 180 ] && ! curl -sf http://127.0.0.1:8080/health > /dev/null 2>&1; do
  i=$((i + 1))
  sleep 1
done

# Register the first account, which Open WebUI makes an administrator. The
# status is what says whether this volume was fresh: a 400 is the account
# already being there, and its password is the one it was created with.
if [ -n "${ADMIN_EMAIL:-}" ]; then
  generated="no"
  if [ -z "${ADMIN_PASSWORD:-}" ]; then
    ADMIN_PASSWORD="$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | cut -c1-20)"
    generated="yes"
  fi
  export ADMIN_PASSWORD

  status="$(python3 -c 'import json, os; print(json.dumps({"email": os.environ["ADMIN_EMAIL"], "password": os.environ["ADMIN_PASSWORD"], "name": os.environ.get("ADMIN_NAME") or "Admin"}))' |
    curl -sS -X POST http://127.0.0.1:8080/api/v1/auths/signup \
      -H "Content-Type: application/json" --data-binary @- \
      -o /var/log/admin.log -w '%{http_code}' 2>> /var/log/admin.log)"

  case "$status" in
    200)
      log "registered the administrator ${ADMIN_EMAIL}"
      [ "$generated" = "yes" ] && log "generated its password: ${ADMIN_PASSWORD}"
      ;;
    400)
      log "the administrator ${ADMIN_EMAIL} is already registered — its password is unchanged"
      ;;
    *)
      log "could not register ${ADMIN_EMAIL} (http ${status:-none}) — see /var/log/admin.log"
      ;;
  esac
fi

# Pull the startup models behind the interface rather than in front of it, so a
# large one does not hold the sign-in page down while it downloads
wanted="$(printf '%s' "${STARTUP_MODELS:-}" | tr ',' ' ')"
if [ -n "$OLLAMA_PID" ] && [ -n "$wanted" ]; then
  (
    for model in $wanted; do
      log "pulling ${model}"
      ollama pull "$model" >> /var/log/pull.log 2>&1 || log "failed to pull ${model} (continuing)"
    done
    log "startup models ready"
  ) &
fi

# Run postpare hook
run_hook postpare

log "ready"

# Wait until stopped
trap 'log "stopping"; kill "$WEBUI_PID" ${OLLAMA_PID:+"$OLLAMA_PID"} 2>/dev/null; exit 0' TERM INT
wait "$WEBUI_PID"
