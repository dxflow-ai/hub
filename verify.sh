#!/usr/bin/env bash
#
# Verify a Hub workflow end-to-end through the dxflow engine: deploy and start
# the real workflow from index.md using the step images ./build.sh already
# loaded locally, feed it the tool's fixtures, and run the tool's own success
# check. Build every step's image with ./build.sh first. Needs a reachable
# dxflow engine and the `dxflow` CLI on PATH (plus docker to check the images).
#
# Each tool provides a verify/ folder next to its build/ sources:
#   verify/check.sh   required — the success check. Sourced after the workflow
#                     starts, so it runs in this script's shell: call the helpers
#                     below and read $IDENTITY / $INPUT_DIR / $OUTPUT_DIR / $TIMEOUT.
#   verify/input/     optional — files uploaded to the input volume before start.
#   verify/config.sh  optional — sourced settings: input=<dir> output=<dir> timeout=<seconds>.
#
# Helpers available to check.sh:
#   wait_exit                    block until the step exits; fail on a non-zero code
#   wait_running [stable]        block until the step is up and stays up (default 5s)
#   expect_file <path>...        assert each artifact path exists (globs allowed in the name)
#   expect_output <glob>...      assert each glob appears in the output volume
#   expect_http <port> [path]    assert the service answers HTTP on a published port
#   expect_port <port>           assert a TCP port is open (non-HTTP, e.g. VNC)
#
# A batch tool checks its outputs; a long-running service (desktop, IDE, notebook)
# checks its endpoint. For example:
#   batch    →  wait_exit;       expect_output '<glob>' '<glob>'
#   service  →  wait_running 10; expect_http <web-port>; expect_port <tcp-port>
#
# PRECONDITION: the engine passes volume host paths verbatim to `docker run -v`
# with no --workdir, so a relative host path like ./input resolves against the
# engine process's CWD. Artifact uploads land under the engine's volume dir, so
# the engine MUST be started with CWD = its volume dir (else the container sees
# an empty /data/input). Relative -v sources also need Docker >= 23. Endpoint
# checks assume the engine is local (override the host with VERIFY_HOST).
#
# Usage:
#   ./verify.sh <workflow>
#
set -euo pipefail

HUB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

have() { command -v "$1" >/dev/null 2>&1; }
log() { echo "==> $*"; }
die() { echo "$*" >&2; exit 1; }
fail() { echo "  FAIL  $*" >&2; dxflow workflow logs "$identity" 2>/dev/null || true; exit 1; }

# Checks available to verify/check.sh.

# Retry `cmd` every 2s until it succeeds or `secs` elapse.
_retry() {
  local secs="$1" waited=0
  shift
  until "$@"; do
    [ "$waited" -lt "$secs" ] || return 1
    sleep 2
    waited=$((waited + 2))
  done
}

# The step status table has no failed state: a step is `running` then `exited`,
# with the real result in EXIT_CODE. Columns are whitespace-separated (no
# borders), so from the STATUS field the value we want is a fixed offset away.
_step_has() { dxflow workflow steps "$identity" 2>/dev/null | grep -qw "$1"; }
_exit_code() {
  dxflow workflow steps "$identity" 2>/dev/null |
    awk '{ for (i = 1; i <= NF; i++) if ($i == "exited") { print $(i + 2); exit } }'
}

wait_exit() {
  local code="" waited=0
  while [ "$waited" -lt "$TIMEOUT" ]; do
    code="$(_exit_code)"
    [ -n "$code" ] && break
    sleep 2
    waited=$((waited + 2))
  done
  [ -n "$code" ] || fail "step did not exit within ${TIMEOUT}s"
  [ "$code" = "0" ] || fail "step exited with code $code"
  echo "  ok    step exited 0"
}

wait_running() {
  local stable="${1:-5}"
  _retry "$TIMEOUT" _step_has running || fail "step not running within ${TIMEOUT}s"
  sleep "$stable"
  _step_has running || fail "step did not stay running for ${stable}s"
  echo "  ok    step running"
}

# Assert each artifact path exists (a glob is allowed in the file name).
expect_file() {
  local path dir base
  for path in "$@"; do
    dir="$(dirname "$path")"
    base="$(basename "$path")"
    if dxflow artifact list "$dir/" --pattern "$base" 2>/dev/null | grep -q .; then
      echo "  ok    file $path"
    else
      fail "missing file: $path"
    fi
  done
}

# Assert each glob appears in the output volume (sugar over expect_file).
expect_output() {
  local glob
  for glob in "$@"; do
    expect_file "$OUTPUT_DIR/$glob"
  done
}

expect_http() {
  local port="$1" path="${2:-/}" host="${VERIFY_HOST:-localhost}"
  if _retry 30 curl -fsS -o /dev/null --max-time 5 "http://$host:$port$path"; then
    echo "  ok    http $host:$port$path"
  else
    fail "no HTTP response on $host:$port$path"
  fi
}

expect_port() {
  local port="$1" host="${VERIFY_HOST:-localhost}"
  if _retry 30 bash -c "exec 3<>/dev/tcp/$host/$port" 2>/dev/null; then
    echo "  ok    port $host:$port open"
  else
    fail "port $host:$port not open"
  fi
}

# Resolve the workflow.

workflow="${1:-}"
[ -n "$workflow" ] || die "usage: $0 <workflow>"

have dxflow || die "dxflow CLI not found on PATH"
have docker || die "docker not found on PATH"

# Find the workflow folder by matching the part after the NN. prefix
dir=""
while IFS= read -r d; do
  name="$(basename "$d")"
  if [ "${name#*.}" = "$workflow" ]; then dir="$d"; break; fi
done < <(find "$HUB_DIR" -mindepth 2 -maxdepth 2 -type d -not -path '*/.*' | sort)

[ -n "$dir" ] || die "unknown workflow: $workflow"
[ -f "$dir/index.md" ] || die "no index.md in ${dir#"$HUB_DIR"/}"

# The tool's verify fixtures
verify="$dir/verify"
[ -f "$verify/check.sh" ] || die "no verify/check.sh in ${dir#"$HUB_DIR"/}"

# Settings (defaults; verify/config.sh may override)
input_dir="input"
output_dir="output"
TIMEOUT="${TIMEOUT:-240}"
if [ -f "$verify/config.sh" ]; then
  # shellcheck disable=SC1091
  . "$verify/config.sh"
  input_dir="${input:-$input_dir}"
  output_dir="${output:-$output_dir}"
  TIMEOUT="${timeout:-$TIMEOUT}"
fi

# Extract the workflow YAML (first ```yaml block under ## Configuration).
# Keep the .yml name — the CLI keys off the extension to treat it as a workflow file.
workdir="$(mktemp -d)"
yaml="$workdir/workflow.yml"
awk '/^```yaml/{flag=1; next} /^```/{if (flag) exit} flag' "$dir/index.md" >"$yaml"
[ -s "$yaml" ] || die "no yaml config block in ${dir#"$HUB_DIR"/}/index.md"

# Every image the workflow's steps use must already be built locally (./build.sh
# in each image's own tool), so the engine runs them via pull: missing without
# pulling from the registry
images="$(grep -oE 'image:[[:space:]]*[^[:space:]]+' "$yaml" | sed 's/image:[[:space:]]*//')"
[ -n "$images" ] || die "no image in the workflow yaml"
while IFS= read -r img; do
  docker image inspect "$img" >/dev/null 2>&1 || die "image not built locally: $img  (run ./build.sh for its tool first)"
done <<< "$images"

identity="verify-$workflow"

cleanup() {
  dxflow workflow remove "$identity" >/dev/null 2>&1 || true
  dxflow artifact delete "$input_dir/" >/dev/null 2>&1 || true
  dxflow artifact delete "$output_dir/" >/dev/null 2>&1 || true
  rm -rf "$workdir"
}
trap cleanup EXIT

# Run the workflow.

# Start from a clean slate
dxflow workflow remove "$identity" >/dev/null 2>&1 || true
dxflow artifact delete "$input_dir/" >/dev/null 2>&1 || true
dxflow artifact delete "$output_dir/" >/dev/null 2>&1 || true

log "create $identity"
dxflow workflow create --identity "$identity" "$yaml"

if [ -d "$verify/input" ]; then
  log "upload input -> $input_dir/"
  for f in "$verify/input"/*; do
    [ -e "$f" ] || continue
    dxflow artifact upload "$f" "$input_dir/"
  done
fi

log "start $identity"
dxflow workflow start "$identity"

log "check $workflow"
IDENTITY="$identity"
INPUT_DIR="$input_dir"
OUTPUT_DIR="$output_dir"
# shellcheck disable=SC1091
. "$verify/check.sh"

log "$workflow verified"
