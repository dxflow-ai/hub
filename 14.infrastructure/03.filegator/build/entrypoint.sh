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

# Seed the private state directory from the copy the image kept. An existing one is
# left as it is — accounts, sessions, and logs are the point of putting it on the
# volume, and re-seeding would throw them away on every restart.
mkdir -p /data
cp -rn /opt/dxflow/private/. /data/ 2> /dev/null || true
mkdir -p /data/logs /data/sessions /data/tmp /data/tmp/nginx

# The CSRF key signs the session, so it is generated once and kept: a fresh key on
# every start would sign every reader out whenever the step restarts.
if [ ! -f /data/csrf.key ]; then
  head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > /data/csrf.key
fi

# The directory FileGator browses: the engine volume, or a path inside it
root="/volume/$(printf '%s' "${ROOT_DIR:-}" | sed 's|^/*||;s|/*$||')"
mkdir -p "${root}"

# A resumable upload arrives one chunk per request, so php's per-request ceilings
# only ever have to hold a chunk — sized from the same setting the browser is given,
# rather than from the size of the file being uploaded.
chunk="${UPLOAD_CHUNK_SIZE:-8}"
case "$chunk" in
  *[!0-9]* | "") chunk=8 ;;
esac
{
  echo "upload_max_filesize = $((chunk * 2))M"
  echo "post_max_size = $((chunk * 2 + 8))M"
  echo "memory_limit = 512M"
  echo "max_execution_time = 3600"
  echo "max_input_time = 3600"
  echo "max_file_uploads = 100"
} > /usr/local/etc/php/conf.d/dxflow.ini

# Hand configuration.php the settings it reads. Written as a php array rather than
# spliced into the config, so a password or an app name carrying a quote is quoted
# by var_export instead of ending the string it sits in.
log "writing settings for ${root}"
FILEGATOR_ROOT="${root}" php -r '
  $megabytes = function ($key, $fallback) {
    $value = (int) getenv($key);
    return ($value > 0 ? $value : $fallback) * 1024 * 1024;
  };

  $settings = [
    "app_name" => getenv("APP_NAME") ?: "FileGator",
    "timezone" => getenv("TIMEZONE") ?: "UTC",
    "root" => getenv("FILEGATOR_ROOT"),
    "upload_max_size" => $megabytes("UPLOAD_MAX_SIZE", 10240),
    "upload_chunk_size" => $megabytes("UPLOAD_CHUNK_SIZE", 8),
    "overwrite_on_upload" => getenv("OVERWRITE_ON_UPLOAD") === "true",
    "csrf_key" => trim((string) file_get_contents("/data/csrf.key")),
  ];

  file_put_contents("/data/settings.php", "<?php return " . var_export($settings, true) . ";");
'

# Keep the admin account and the guest account in step with the environment, and
# leave every other account alone: the admin UI is how a collaborator is given a
# home directory of their own, and that account has no business being reset by a
# restart. The admin is matched by role rather than by name, so changing USERNAME
# renames the existing account instead of adding a second administrator.
log "reconciling accounts from the environment"
php -r '
  $file = "/data/users.json";
  $users = is_file($file) ? json_decode((string) file_get_contents($file), true) : null;
  if (! is_array($users)) {
    $users = [];
  }

  $admin = [
    "username" => getenv("USERNAME") ?: "admin",
    "name" => "Admin",
    "role" => "admin",
    "homedir" => "/",
    "permissions" => "read|write|upload|download|batchdownload|zip|chmod",
    "password" => password_hash(getenv("PASSWORD") ?: "dxflow", PASSWORD_BCRYPT),
  ];

  // An empty permission list is what keeps anonymous readers out: the guest account
  // exists either way, and holds nothing until the step is started with some.
  $guest = [
    "username" => "guest",
    "name" => "Guest",
    "role" => "guest",
    "homedir" => "/",
    "permissions" => (string) getenv("GUEST_PERMISSIONS"),
    "password" => "",
  ];

  $seen = ["admin" => false, "guest" => false];
  foreach ($users as $key => $user) {
    if (($user["username"] ?? "") === "guest") {
      $users[$key] = $guest;
      $seen["guest"] = true;
      continue;
    }
    if (($user["role"] ?? "") === "admin" && ! $seen["admin"]) {
      $users[$key] = $admin;
      $seen["admin"] = true;
    }
  }

  if (! $seen["admin"]) {
    $users[] = $admin;
  }
  if (! $seen["guest"]) {
    $users[] = $guest;
  }

  file_put_contents($file, json_encode($users));
'

# The nginx workers and the php pool reach the volume as this user. Every other step
# runs as root and leaves root-owned files behind, so a server running as anyone
# else could list them and not rename or delete one — hence the default.
run_user="${RUN_AS:-root}"
if ! id "${run_user}" > /dev/null 2>&1; then
  log "no such user ${run_user} — running as root"
  run_user=root
fi

sed -i "s|^user .*;|user ${run_user};|" /etc/nginx/nginx.conf
{
  echo "[www]"
  echo "user = ${run_user}"
  echo "group = ${run_user}"
  echo "listen.owner = ${run_user}"
  echo "listen.group = ${run_user}"
} > /usr/local/etc/php-fpm.d/zz-dxflow-user.conf

if [ "${run_user}" != "root" ]; then
  chown -R "${run_user}:${run_user}" /data
fi

# php-fpm turns down a root pool unless it is asked to allow one, which is exactly
# the thing being asked for here
log "starting php-fpm as ${run_user}"
if [ "${run_user}" = "root" ]; then
  php-fpm --allow-to-run-as-root --nodaemonize &
else
  php-fpm --nodaemonize &
fi
FPM_PID=$!

# Wait for the pool to open its socket, so the first request is not a 502
i=0
while [ "$i" -lt 30 ] && [ ! -S /run/php-fpm.sock ]; do
  i=$((i + 1))
  sleep 1
done

# nginx logs to the container's stdout and stderr, and php's warnings reach the
# same place through the pool's catch_workers_output
log "starting filegator on :8080 at ${root}"
nginx -g 'daemon off;' &
NGINX_PID=$!

# Run postpare hook
run_hook postpare

log "ready"

# Wait until stopped
trap 'log "stopping"; kill "$NGINX_PID" "$FPM_PID" 2>/dev/null; exit 0' TERM INT
wait "$NGINX_PID"
