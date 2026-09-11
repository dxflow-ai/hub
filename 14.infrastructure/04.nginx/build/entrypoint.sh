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

# The two directories this works over: what it serves, and the configuration it is
# handed. Both live on the engine volume, so either can be changed from the console,
# from `dxflow artifact upload`, or from a file manager pointed at the same volume.
root="/volume/$(printf '%s' "${ROOT_DIR:-}" | sed 's|^/*||;s|/*$||')"

# The config directory is walked on a timer, so it has to stay a directory of its
# own: an empty CONFIG_DIR would point it at the volume root and digest every
# artifact on the engine every few seconds
config_name="$(printf '%s' "${CONFIG_DIR:-}" | sed 's|^/*||;s|/*$||')"
[ -n "${config_name}" ] || config_name=nginx
config_dir="/volume/${config_name}"
mkdir -p "${root}" "${config_dir}/conf.d" "${config_dir}/server.d"

# Leave a worked example the first time, and never again — it is a .sample, so
# nginx does not read it and an edit of it cannot break anything
if [ ! -f "${config_dir}/example.conf.sample" ]; then
  cp /opt/dxflow/sample.conf "${config_dir}/example.conf.sample"
fi

# The workers reach the volume as this user. Every other step runs as root and
# leaves root-owned files behind, and a mode the owner alone can read is a file
# nginx would answer with a 403 — hence the default.
run_user="${RUN_AS:-root}"
if ! id "${run_user}" > /dev/null 2>&1; then
  log "no such user ${run_user} — running as root"
  run_user=root
fi

# The credential guarding the default server, as a snippet the rendered config
# includes. An empty PASSWORD turns the guard off rather than setting a blank one.
if [ -n "${PASSWORD:-}" ]; then
  htpasswd -bc /etc/nginx/.htpasswd "${USERNAME:-dxflow}" "${PASSWORD}" > /dev/null 2>&1
  {
    echo 'auth_basic "dxflow";'
    echo 'auth_basic_user_file /etc/nginx/.htpasswd;'
  } > /etc/nginx/dxflow-auth.conf
  log "basic auth enabled for ${USERNAME:-dxflow}"
else
  echo 'auth_basic off;' > /etc/nginx/dxflow-auth.conf
  log "no PASSWORD set — the default server is open"
fi

# The configuration rendered from the environment: an indexed, optionally guarded
# server over the volume, with two places for the volume's own configuration to
# join it. Written to the path named in $1 rather than straight to the live file,
# so a candidate can be tested before it replaces one that works.
render_config() {
  cat > "$1" <<EOF
# Rendered by the dxflow entrypoint from the step's environment on every start.
# Additions belong in conf.d/ and server.d/ next to this file's source on the
# volume; to take the whole file over instead, put your own nginx.conf there.

user ${run_user};
worker_processes ${WORKER_PROCESSES:-auto};
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    tcp_nopush on;
    server_tokens off;

    # Straight to the container's stdout and stderr, which is what the engine shows
    access_log /dev/stdout;
    error_log /dev/stderr warn;

    client_max_body_size ${CLIENT_MAX_BODY_SIZE:-0};

    # http level — whole server blocks, upstreams, maps, rate limits
    include ${config_dir}/conf.d/*.conf;

    server {
        listen 8080 default_server;
        server_name ${SERVER_NAME:-_};

        root ${root};
        index index.html index.htm;
        autoindex ${AUTOINDEX:-on};
        autoindex_exact_size off;
        autoindex_localtime on;

        include /etc/nginx/dxflow-auth.conf;

        # server level — extra locations, proxy routes, redirects
        include ${config_dir}/server.d/*.conf;

        location / {
            try_files \$uri \$uri/ =404;
        }
    }
}
EOF
}

# What the volume asks for, as a candidate at $1: its own nginx.conf if it has one,
# and otherwise the rendered default.
build_candidate() {
  if [ -f "${config_dir}/nginx.conf" ]; then
    cp "${config_dir}/nginx.conf" "$1"
  else
    render_config "$1"
  fi
}

# Every file under the config directory, as one string that changes when any of them
# does. Content rather than timestamps: an editor that rewrites a file in the same
# second still moves the digest, and a touch that changes nothing does not.
config_digest() {
  find "${config_dir}" -type f -exec md5sum {} + 2> /dev/null | sort
}

candidate=/tmp/nginx-candidate.conf
report=/tmp/nginx-test.log

# Install the candidate if nginx accepts it, and say so if it does not. A rejected
# candidate is never written to /etc, so what is on disk is always something that
# loads — the running server keeps serving from what it already read.
install_config() {
  build_candidate "$candidate"

  if ! nginx -t -c "$candidate" > "$report" 2>&1; then
    log "configuration rejected — the running one is kept"
    sed 's/^/  /' "$report"
    return 1
  fi

  cp "$candidate" /etc/nginx/nginx.conf
  return 0
}

# Watch the config directory and hand nginx anything new that passes the test. This
# is the reason the config lives on the volume: an edit lands in seconds, and a
# mistake costs a line in the log rather than the server.
watch_config() {
  interval="$1"
  previous="$(config_digest)"

  while sleep "$interval"; do
    current="$(config_digest)"
    [ "$current" = "$previous" ] && continue
    previous="$current"

    log "configuration changed"
    if install_config; then
      if nginx -s reload; then
        log "configuration reloaded"
      else
        log "reload failed — see the error log above"
      fi
    fi
  done
}

# The first configuration has nothing to fall back to, so a volume that carries a
# broken nginx.conf gets the rendered default and a loud line, rather than a step
# that will not start
if ! install_config; then
  log "falling back to the rendered configuration"
  render_config "$candidate"
  nginx -t -c "$candidate" > "$report" 2>&1 || {
    log "the rendered configuration is broken too — giving up"
    cat "$report"
    exit 1
  }
  cp "$candidate" /etc/nginx/nginx.conf
fi

log "starting nginx on :8080 serving ${root} as ${run_user}"
nginx -g 'daemon off;' &
NGINX_PID=$!

# Watch for configuration changes, unless asked not to. A non-numeric interval is
# an unwatched server that looks watched, so it becomes the default rather than
# killing the loop on the first sleep.
interval="${RELOAD_INTERVAL:-5}"
case "$interval" in
  *[!0-9]* | "") interval=5 ;;
esac

WATCH_PID=""
if [ "$interval" != "0" ]; then
  log "watching ${config_dir} every ${interval}s"
  watch_config "$interval" &
  WATCH_PID=$!
else
  log "config watching disabled"
fi

# Run postpare hook
run_hook postpare

log "ready"

# Wait until stopped
trap 'log "stopping"; kill $WATCH_PID "$NGINX_PID" 2>/dev/null; exit 0' TERM INT
wait "$NGINX_PID"
