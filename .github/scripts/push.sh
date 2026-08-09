#!/usr/bin/env bash
set -euo pipefail

# Push the arch this runner just verified as an untagged image and record its digest
# for ./publish.sh to join. The layers are already in the builder cache from
# ./build.sh, so this only exports them. Expects $WORKFLOW and $ARCH in the env.
# shellcheck disable=SC1091
. "$(dirname "$0")/resolve.sh"

WORKFLOW="${WORKFLOW:-${1:-}}"
ARCH="${ARCH:-${2:-}}"
resolve

[[ -n "$ARCH" ]] || fail "no arch given — set \$ARCH or pass it as the second argument"

digests="${RUNNER_TEMP:-/tmp}/digests"
metadata="${RUNNER_TEMP:-/tmp}/metadata.json"

# push-by-digest leaves the tags to the manifest, so nothing answers to :latest until
# every arch has passed verify
args=(--pull --platform "linux/$ARCH" --provenance=false --sbom=false)
if [[ -n "$version" ]]; then
    args+=(--label "org.opencontainers.image.version=$version")
fi

echo "==> push ${image%:*}  [linux/$ARCH]"
docker buildx build "${args[@]}" \
    --output "type=image,name=${image%:*},push-by-digest=true,name-canonical=true,push=true" \
    --metadata-file "$metadata" \
    --file "$context/Dockerfile" "$context"

digest="$(jq -r '."containerimage.digest"' "$metadata")"
mkdir -p "$digests"
touch "$digests/${digest#sha256:}"

echo "==> pushed ${image%:*}@$digest"
