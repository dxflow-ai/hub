#!/usr/bin/env bash
set -euo pipefail

# Build the entry's own image for this runner's arch and load it into the local
# docker, so ./verify.sh exercises the real thing without a registry round trip.
# ./push.sh re-exports it from the same builder cache. Expects $WORKFLOW in the env,
# or the key as the first argument.
# shellcheck disable=SC1091
. "$(dirname "$0")/resolve.sh"

WORKFLOW="${WORKFLOW:-${1:-}}"
resolve

[[ -f "$context/Dockerfile" ]] || fail "$WORKFLOW has no build/Dockerfile — it is a draft"

# --pull so an entry built on another hub image takes the one just published, not a
# stale copy left on the runner
echo "==> build $image  ($(uname -m))"
docker buildx build --pull --load --tag "$image" --file "$context/Dockerfile" "$context"
