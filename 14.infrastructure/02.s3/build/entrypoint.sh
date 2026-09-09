#!/bin/sh

# EXTRA is split on whitespace, and a pattern in it (--exclude *.bam) must reach
# the CLI as written rather than match the volume, so globbing stays off.
set -euf

# Defaults, so the image is usable as a step of a workflow that declares only the
# few variables it cares about
SOURCE="${SOURCE:-}"
TARGET="${TARGET:-}"
MODE="${MODE:-sync}"
ENDPOINT="${ENDPOINT:-}"
REGION="${REGION:-us-east-1}"
ACCESS_KEY="${ACCESS_KEY:-}"
SECRET_KEY="${SECRET_KEY:-}"
SESSION_TOKEN="${SESSION_TOKEN:-}"
DELETE="${DELETE:-false}"
EXTRA="${EXTRA:-}"

fail() {
    echo "[s3] $*" >&2
    exit 1
}

# The image's own command, so a step can reach a running container: stay up and
# leave the transfer to the invocation the step's command makes.
if [ "${1:-}" = "idle" ]; then
    echo "[s3] ready — the transfer runs as the step's command"
    exec tail -f /dev/null
fi

[ -n "$SOURCE" ] || fail "SOURCE is empty — set it to an s3:// uri or a local path"
[ -n "$TARGET" ] || fail "TARGET is empty — set it to an s3:// uri or a local path"

export AWS_DEFAULT_REGION="$REGION"

# Half a pair is a misconfiguration, not a public bucket — say so, rather than
# reach for the object unsigned and report the AccessDenied that follows.
if [ -n "$ACCESS_KEY" ] && [ -z "$SECRET_KEY" ]; then
    fail "ACCESS_KEY is set but SECRET_KEY is empty"
fi
if [ -z "$ACCESS_KEY" ] && [ -n "$SECRET_KEY" ]; then
    fail "SECRET_KEY is set but ACCESS_KEY is empty"
fi

# An empty pair means the bucket is public: send the request unsigned, rather
# than let the CLI fail looking for a profile that is not there.
auth="--no-sign-request"
if [ -n "$ACCESS_KEY" ]; then
    export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
    auth=""
fi
if [ -n "$SESSION_TOKEN" ]; then
    export AWS_SESSION_TOKEN="$SESSION_TOKEN"
fi

# A compatible service is addressed by path: its host does not answer to
# <bucket>.<host>, the way S3 itself does.
endpoint=""
if [ -n "$ENDPOINT" ]; then
    endpoint="--endpoint-url $ENDPOINT"
    export AWS_CONFIG_FILE=/tmp/aws-config
    aws configure set default.s3.addressing_style path
fi

# The direction is whichever side carries the s3:// uri — the CLI reads both the
# same way, so a transfer down and a transfer up are the same call
case "$MODE" in
    sync)
        set -- sync "$SOURCE" "$TARGET"
        if [ "$DELETE" = "true" ]; then
            set -- "$@" --delete
        fi
        ;;
    copy)
        set -- cp "$SOURCE" "$TARGET"
        case "$SOURCE" in
            */) set -- "$@" --recursive ;;
        esac
        ;;
    *)
        fail "MODE must be sync or copy (got '$MODE')"
        ;;
esac

echo "[s3] $MODE $SOURCE -> $TARGET"
aws $endpoint s3 "$@" $auth $EXTRA
echo "[s3] done"
