#!/usr/bin/env bash
set -euo pipefail

# Verify an entry end-to-end through the engine: deploy the real workflow from its
# index.md, feed it the tool's fixtures, and run the tool's own success check
# against the image ./build.sh loaded. Needs ./prepare.sh and ./boot.sh first.
# Expects $WORKFLOW in the env, or the key as the first argument.
#
# Each tool provides a verify/ folder next to its build/ sources:
#   verify/check.sh   required — the success check. Sourced after the workflow
#                     starts, so it runs in this script's shell: call the helpers
#                     below and read $IDENTITY / $INPUT_DIR / $OUTPUT_DIR / $TIMEOUT.
#   verify/input/     optional — files uploaded to the input volume before start.
#   verify/config.sh  optional — sourced settings: input=<dir> output=<dir> timeout=<seconds>.
#
# Helpers available to check.sh:
#   wait_exit                       block until the step exits; fail on a non-zero code
#   wait_running [stable]           block until the step is up and stays up (default 5s)
#   expect_file <path>...           assert each artifact path exists (globs allowed in the name)
#   expect_output <glob>...         assert each glob appears in the output volume
#   expect_http <port> [path]       assert the service answers HTTP on a published port
#   expect_http_auth <port> [path]  assert it answers and asks for a credential
#   expect_port <port>              assert a TCP port is open (non-HTTP, e.g. VNC)
#
# A batch tool checks its outputs; a long-running service (desktop, IDE, notebook)
# checks its endpoint. For example:
#   batch    →  wait_exit;       expect_output '<glob>' '<glob>'
#   service  →  wait_running 10; expect_http <web-port>; expect_port <tcp-port>
#
# Endpoint checks assume the engine is on this host (override with $VERIFY_HOST).
# A gpu resource is dropped before the run — no runner has a card to give.
# shellcheck disable=SC1091
. "$(dirname "$0")/resolve.sh"

WORKFLOW="${WORKFLOW:-${1:-}}"
resolve

# A failed check is worth the workflow's own logs
fail() {
    echo "::error::$*"
    [[ -n "${identity:-}" ]] && dxflow workflow logs "$identity" 2>/dev/null
    exit 1
}

# Checks available to verify/check.sh.

# Retry `cmd` every 2s until it succeeds or `secs` elapse.
_retry() {
    local secs="$1" waited=0
    shift
    until "$@"; do
        [[ "$waited" -lt "$secs" ]] || return 1
        sleep 2
        waited=$((waited + 2))
    done
}

# Read the table in rather than piping it: grep quits on the first match, and the
# SIGPIPE that follows would surface as a failed check under pipefail
_step_has() {
    grep -qw "$1" <<< "$(dxflow workflow steps "$identity" 2>/dev/null)"
}

# The step status table has no failed state: a step is `running` then `exited`, with
# the real result in EXIT_CODE. Columns are whitespace-separated (no borders), so
# from the STATUS field the value we want is a fixed offset away.
_exit_code() {
    dxflow workflow steps "$identity" 2>/dev/null |
        awk '{ for (i = 1; i <= NF; i++) if ($i == "exited") { print $(i + 2); exit } }'
}

wait_exit() {
    local code="" waited=0
    while [[ "$waited" -lt "$TIMEOUT" ]]; do
        code="$(_exit_code)"
        [[ -n "$code" ]] && break
        sleep 2
        waited=$((waited + 2))
    done

    [[ -n "$code" ]] || fail "step did not exit within ${TIMEOUT}s"
    [[ "$code" == "0" ]] || fail "step exited with code $code"

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
        if grep -q . <<< "$(dxflow artifact list "$dir/" --pattern "$base" 2>/dev/null)"; then
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

# A guarded endpoint answers a credential-less request with a challenge (401/403) or
# a redirect to its own sign-in page (302/303).
_http_guarded() {
    case "$(curl -s -o /dev/null --max-time 5 -w '%{http_code}' "http://$1:$2$3")" in
        302 | 303 | 401 | 403) return 0 ;;
        *) return 1 ;;
    esac
}

# Assert the service answers and refuses to serve without a credential.
expect_http_auth() {
    local port="$1" path="${2:-/}" host="${VERIFY_HOST:-localhost}"
    if _retry 30 _http_guarded "$host" "$port" "$path"; then
        echo "  ok    http $host:$port$path asks for a credential"
    else
        fail "no credential asked for on $host:$port$path"
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

# Set the run up.

verify="$dir/verify"
[[ -f "$verify/check.sh" ]] || fail "$WORKFLOW has no verify/check.sh — it is a draft"

# Settings (defaults; verify/config.sh may override)
input_dir="input"
output_dir="output"
TIMEOUT="${TIMEOUT:-240}"
if [[ -f "$verify/config.sh" ]]; then
    . "$verify/config.sh"
    input_dir="${input:-$input_dir}"
    output_dir="${output:-$output_dir}"
    TIMEOUT="${timeout:-$TIMEOUT}"
fi

# Keep the .yml name — the CLI keys off the extension to treat it as a workflow file
workdir="$(mktemp -d)"
yaml="$workdir/workflow.yml"
config="$(block yaml)"
[[ -n "$config" ]] || fail "no yaml config block in $dir/index.md"

# No runner carries an NVIDIA card, and the engine hands a gpu resource on to
# `docker run --gpus`, which the daemon turns down for want of a device driver. The
# image is what is under test here, not the hardware, so deploy it without the line.
grep -vE '^[[:space:]]*gpu:' <<< "$config" > "$yaml"

# The engine runs every step image via pull: missing. This entry's own image comes
# from ./build.sh; one it reuses from another tool has to be fetched here.
while IFS= read -r step; do
    docker image inspect "$step" > /dev/null 2>&1 && continue
    echo "==> pull $step"
    docker pull "$step"
done < <(images)

identity="$(identity vf)"

cleanup() {
    dxflow workflow stop "$identity" > /dev/null 2>&1 || true
    dxflow workflow remove "$identity" > /dev/null 2>&1 || true
    dxflow artifact delete "$input_dir/" > /dev/null 2>&1 || true
    dxflow artifact delete "$output_dir/" > /dev/null 2>&1 || true
    rm -rf "$workdir"
}
trap cleanup EXIT INT TERM

# Run the workflow.

# Start from a clean slate. The engine tears a workflow down asynchronously
# (containers and state are removed in the background), so a remove followed
# immediately by a create can race and report "already exists". Stop and remove
# first, then retry the create until the engine has fully released the identity.
dxflow workflow stop "$identity" > /dev/null 2>&1 || true
dxflow workflow remove "$identity" > /dev/null 2>&1 || true
dxflow artifact delete "$input_dir/" > /dev/null 2>&1 || true
dxflow artifact delete "$output_dir/" > /dev/null 2>&1 || true

echo "==> create $identity"
tries=0
until dxflow workflow create --identity "$identity" "$yaml"; do
    tries=$((tries + 1))
    [[ "$tries" -ge 15 ]] && fail "could not create $identity — engine still holds the identity after cleanup"
    echo "==> identity busy — retrying cleanup ($tries)"
    dxflow workflow remove "$identity" > /dev/null 2>&1 || true
    sleep 2
done

if [[ -d "$verify/input" ]]; then
    echo "==> upload input → $input_dir/"
    for file in "$verify/input"/*; do
        [[ -e "$file" ]] || continue
        dxflow artifact upload "$file" "$input_dir/"
    done
fi

echo "==> start $identity"
dxflow workflow start "$identity"

echo "==> check $WORKFLOW"
IDENTITY="$identity"
INPUT_DIR="$input_dir"
OUTPUT_DIR="$output_dir"
. "$verify/check.sh"

echo "==> $WORKFLOW verified"
