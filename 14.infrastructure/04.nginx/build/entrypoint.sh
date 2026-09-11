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

# What is published: the engine volume, or the run directory inside it that this
# workflow is meant to put on the web
site_dir="/volume/$(printf '%s' "${SITE_DIR:-}" | sed 's|^/*||;s|/*$||')"

# Where the configuration is edited. It is walked on a timer, so it stays a
# directory of its own: an empty CONFIG_DIR would point the watch at the volume
# root and digest every artifact on the engine every few seconds.
config_name="$(printf '%s' "${CONFIG_DIR:-}" | sed 's|^/*||;s|/*$||')"
[ -n "${config_name}" ] || config_name=nginx
config_dir="/volume/${config_name}"

# conf.d and server.d are read by nginx and watched; state is written by this
# script and is not, so reporting a reload cannot trigger the next one
mkdir -p "${site_dir}" "${config_dir}/conf.d" "${config_dir}/server.d" "${config_dir}/state"

# Leave a worked example the first time, and never again — it is a .sample, so
# nginx does not read it and an edit of it cannot break anything
if [ ! -f "${config_dir}/example.conf.sample" ]; then
  cp /opt/dxflow/sample.conf "${config_dir}/example.conf.sample"
fi

status_log="${config_dir}/state/status.log"
effective="${config_dir}/state/effective.conf"

# Report next to the configuration being edited, not only in the container log —
# whoever is writing these files is looking at this directory, and may have no
# terminal on the engine at all. Bounded, so a tight edit loop cannot grow it.
report_status() {
  printf '%s  %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" >> "${status_log}"
  tail -n 200 "${status_log}" > "${status_log}.tmp" 2> /dev/null &&
    mv "${status_log}.tmp" "${status_log}"
}

# The workers only ever read, so they run unprivileged. An artifact another step
# wrote 0600 is the one case that needs WORKER_USER=root.
worker_user="${WORKER_USER:-nginx}"
if ! id "${worker_user}" > /dev/null 2>&1; then
  log "no such user ${worker_user} — running the workers as nginx"
  worker_user=nginx
fi

# `auto` asks the kernel, which answers with the host's core count and not the
# share this step was given — 64 workers on a two-core limit. The cgroup knows.
cpu_quota() {
  quota=""
  period=""

  if [ -r /sys/fs/cgroup/cpu.max ]; then
    read -r quota period < /sys/fs/cgroup/cpu.max
  elif [ -r /sys/fs/cgroup/cpu/cpu.cfs_quota_us ] && [ -r /sys/fs/cgroup/cpu/cpu.cfs_period_us ]; then
    quota="$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us)"
    period="$(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us)"
  fi

  case "${quota}" in
    '' | max | *[!0-9]*) nproc; return ;;
  esac
  case "${period}" in
    '' | *[!0-9]*) nproc; return ;;
  esac
  [ "${quota}" -gt 0 ] || { nproc; return; }
  [ "${period}" -gt 0 ] || { nproc; return; }

  count=$(((quota + period - 1) / period))
  [ "${count}" -ge 1 ] || count=1
  echo "${count}"
}

workers="${WORKER_PROCESSES:-auto}"
if [ "${workers}" = "auto" ]; then
  workers="$(cpu_quota)"
fi

# The credential guarding the site, as a snippet the rendered config includes. An
# empty PASSWORD removes the guard rather than setting a blank one — which is what
# a genuinely public web resource wants.
if [ -n "${PASSWORD:-}" ]; then
  htpasswd -bc /etc/nginx/.htpasswd dxflow "${PASSWORD}" > /dev/null 2>&1
  {
    echo 'auth_basic "dxflow";'
    echo 'auth_basic_user_file /etc/nginx/.htpasswd;'
  } > /etc/nginx/dxflow-auth.conf
  log "basic auth enabled for user dxflow"
else
  echo 'auth_basic off;' > /etc/nginx/dxflow-auth.conf
  log "no PASSWORD set — the site is open"
fi

# Cross-origin reads, so a notebook, a dashboard, or a page served from somewhere
# else can fetch an artifact rather than only link to it. Expose-Headers is what
# lets such a reader see the range headers and pull a large file in pieces.
if [ "${CORS:-off}" = "on" ]; then
  {
    echo 'add_header Access-Control-Allow-Origin "*" always;'
    echo 'add_header Access-Control-Allow-Methods "GET, HEAD, OPTIONS" always;'
    echo 'add_header Access-Control-Allow-Headers "Range, Content-Type" always;'
    echo 'add_header Access-Control-Expose-Headers "Accept-Ranges, Content-Length, Content-Range" always;'
    echo 'if ($request_method = OPTIONS) { return 204; }'
  } > /etc/nginx/dxflow-cors.conf
  log "cors enabled for all origins"
else
  echo '# CORS=off' > /etc/nginx/dxflow-cors.conf
fi

# The configuration rendered from the environment: the artifact site, plus the two
# places the volume's own configuration joins it. Written to the path named in $1
# rather than straight to the live file, so a candidate is tested before it
# replaces one that works.
render_config() {
  cat > "$1" <<EOF
# Rendered by the dxflow entrypoint from the step's environment on every start.
# Additions belong in conf.d/ and server.d/ on the volume, next to where this came
# from; to take the whole file over instead, put your own nginx.conf there.

user ${worker_user};
worker_processes ${workers};
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

    # A large artifact is read in pieces, or resumed after a dropped connection
    max_ranges 100;

    # Straight to the container's stdout and stderr, which is what the engine shows
    access_log /dev/stdout;
    error_log /dev/stderr warn;

    gzip ${GZIP:-on};
    gzip_vary on;
    gzip_proxied any;
    gzip_min_length 1024;
    gzip_comp_level 5;
    gzip_types text/plain text/css text/csv text/tab-separated-values text/xml
               application/json application/xml application/javascript image/svg+xml;

    # http level — whole server blocks, upstreams, maps, rate limits
    include ${config_dir}/conf.d/*.conf;

    server {
        listen 8080 default_server;
        server_name _;

        root ${site_dir};
        index index.html index.htm;
        autoindex ${AUTOINDEX:-on};
        autoindex_exact_size off;
        autoindex_localtime on;

        include /etc/nginx/dxflow-auth.conf;
        include /etc/nginx/dxflow-cors.conf;

        # server level — extra locations, proxy routes, redirects
        include ${config_dir}/server.d/*.conf;

        # A run leaves behind extensions the mime table has never heard of, and an
        # octet-stream downloads where it could have opened. default_type only
        # applies where the table is silent, so a type it does know still wins.
        location ~* \.(log|out|err|dat|in|inp|nml|mdp|top|itp|gro|cfg|conf|ini|ya?ml|toml|tsv|md)\$ {
            default_type text/plain;
            charset utf-8;
        }

        location ~* \.csv\$ {
            default_type text/csv;
            charset utf-8;
        }

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

# Exactly the files nginx reads, as one string that changes when any of them does.
# Content rather than timestamps, so a rewrite inside one second still counts and a
# touch that changes nothing does not. state/ is deliberately outside this.
config_digest() {
  find "${config_dir}/conf.d" "${config_dir}/server.d" -type f -exec md5sum {} + 2> /dev/null | sort
  if [ -f "${config_dir}/nginx.conf" ]; then
    md5sum "${config_dir}/nginx.conf"
  fi
}

candidate=/tmp/nginx-candidate.conf
report=/tmp/nginx-test.log

# Install the candidate if nginx accepts it, and say where it went wrong if it does
# not. A rejected candidate never reaches /etc, so what is on disk always loads and
# the running server keeps serving what it already read.
install_config() {
  build_candidate "$candidate"

  if ! nginx -t -c "$candidate" > "$report" 2>&1; then
    log "configuration rejected — the running one is kept"
    sed 's/^/  /' "$report"
    report_status "rejected: $(grep -m1 'emerg' "$report" || tail -n 1 "$report")"
    return 1
  fi

  cp "$candidate" /etc/nginx/nginx.conf
  return 0
}

# The configuration as nginx resolved it, includes and all, written where it was
# edited. In a session spent finding out what a directive does, this is the answer
# to "what is actually loaded right now".
dump_effective() {
  nginx -T > "${effective}.tmp" 2> /dev/null && mv "${effective}.tmp" "${effective}"
}

# Watch what nginx reads and hand it anything new that passes the test. This is why
# the configuration lives on the volume: an edit lands in seconds, and a mistake
# costs a line in a log file rather than the server.
watch_config() {
  interval="$1"
  previous="$(config_digest)"

  while sleep "${interval}"; do
    current="$(config_digest)"
    [ "${current}" = "${previous}" ] && continue
    previous="${current}"

    log "configuration changed"
    install_config || continue

    if nginx -s reload; then
      log "configuration reloaded"
      report_status "reloaded"
      dump_effective
    else
      log "reload failed — see the error log above"
      report_status "reload failed — see the workflow log"
    fi
  done
}

# The first configuration has nothing to fall back to, so a volume carrying a
# broken nginx.conf gets the rendered default and a loud line, rather than a step
# that will not start
if ! install_config; then
  log "falling back to the rendered configuration"
  report_status "falling back to the rendered configuration"
  render_config "$candidate"
  nginx -t -c "$candidate" > "$report" 2>&1 || {
    log "the rendered configuration is broken too — giving up"
    cat "$report"
    exit 1
  }
  cp "$candidate" /etc/nginx/nginx.conf
fi

log "starting nginx on :8080 serving ${site_dir} with ${workers} worker(s) as ${worker_user}"
nginx -g 'daemon off;' &
NGINX_PID=$!

report_status "started — serving ${site_dir}"
dump_effective

# Watch for configuration changes, unless asked not to. A non-numeric interval is
# an unwatched server that looks watched, so it becomes the default rather than
# ending the loop on the first sleep.
interval="${RELOAD_INTERVAL:-5}"
case "${interval}" in
  *[!0-9]* | "") interval=5 ;;
esac

WATCH_PID=""
if [ "${interval}" != "0" ]; then
  log "watching ${config_dir} every ${interval}s"
  watch_config "${interval}" &
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
