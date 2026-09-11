# nginx is a long-running service: the server stays up and publishes the volume.

# verify.sh helper: block until the step is up and stays up
wait_running 10

# verify.sh helper: the artifact site answers, behind its basic auth
expect_http_auth 8080

# The entry's own claim, checked rather than asserted: a configuration dropped on
# the volume after the fact is picked up without a restart. This snippet opens one
# path the password does not guard, which the running server does not do yet — so
# an answer on it is the reload, and nothing else.
snippet="$(mktemp -d)/health.conf"
cat > "$snippet" << 'CONF'
location = /health {
    auth_basic off;
    default_type text/plain;
    return 200 "ok";
}
CONF
dxflow artifact upload "$snippet" nginx/server.d/

# verify.sh helper: retries for 30s, which is the reload interval several times over
expect_http 8080 /health

# verify.sh helper: the reload reports back where the editing happens, not only in
# the container log — and the resolved configuration is written out beside it
expect_file nginx/state/status.log
expect_file nginx/state/effective.conf
