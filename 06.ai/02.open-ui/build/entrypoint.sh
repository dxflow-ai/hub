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
mkdir -p "$data"

# Sessions survive a restart only if the key that signs them does, and the
# container is started with --rm, so keep it on the volume, not in the image
if [ -z "${WEBUI_SECRET_KEY:-}" ]; then
  secret="${data}/.secret"
  if [ ! -f "$secret" ]; then
    head -c 32 /dev/urandom | base64 | tr -d '\n' > "$secret"
    chmod 600 "$secret"
  fi
  WEBUI_SECRET_KEY="$(cat "$secret")"
  export WEBUI_SECRET_KEY
fi

# The model servers this gate serves from. There is none in the container, and a
# connection added in the interface does not outlive a restart while
# ENABLE_PERSISTENT_CONFIG is off, so the definition is where they belong.
OLLAMA_BASE_URL=""
export OLLAMA_BASE_URL
if [ -n "${OLLAMA_BASE_URLS:-}" ]; then
  log "serving models from ${OLLAMA_BASE_URLS}"
else
  log "no OLLAMA_BASE_URLS set — the interface will come up with no models behind it"
fi

# Start the web interface — upstream's launcher
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
  # The password the first account is created with. Unset means the default;
  # set-but-empty means generate one, which is what a start facing the internet
  # wants. The default lives here rather than in an ENV, so the image carries no
  # credential and a build log has none to warn about.
  password="${ADMIN_PASSWORD-dxflow}"
  generated="no"
  if [ -z "${password}" ]; then
    password="$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | cut -c1-20)"
    generated="yes"
  fi

  status="$(ADMIN_SECRET="${password}" python3 -c 'import json, os; print(json.dumps({"email": os.environ["ADMIN_EMAIL"], "password": os.environ["ADMIN_SECRET"], "name": os.environ.get("ADMIN_NAME") or "Admin"}))' |
    curl -sS -X POST http://127.0.0.1:8080/api/v1/auths/signup \
      -H "Content-Type: application/json" --data-binary @- \
      -o /var/log/admin.log -w '%{http_code}' 2>> /var/log/admin.log)"

  case "$status" in
    200)
      log "registered the administrator ${ADMIN_EMAIL}"
      [ "$generated" = "yes" ] && log "generated its password: ${password}"
      ;;
    400)
      log "the administrator ${ADMIN_EMAIL} is already registered — its password is unchanged"
      ;;
    *)
      log "could not register ${ADMIN_EMAIL} (http ${status:-none}) — see /var/log/admin.log"
      ;;
  esac
fi

# Run postpare hook
run_hook postpare

log "ready"

# Wait until stopped
trap 'log "stopping"; kill "$WEBUI_PID" 2>/dev/null; exit 0' TERM INT
wait "$WEBUI_PID"
