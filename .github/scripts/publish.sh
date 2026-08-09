#!/usr/bin/env bash
set -euo pipefail

# Join the arches ./push.sh uploaded into one multi-arch manifest tagged :latest and
# :<version> — the point where the entry becomes deployable from the registry.
# Expects $WORKFLOW and $DIGESTS (a directory holding one file per digest) in the env.
# shellcheck disable=SC1091
. "$(dirname "$0")/resolve.sh"

WORKFLOW="${WORKFLOW:-${1:-}}"
DIGESTS="${DIGESTS:-${2:-digests}}"
resolve

tags=(--tag "$image")
if [[ -n "$version" ]]; then
    tags+=(--tag "${image%:*}:$version")
fi

sources=()
for file in "$DIGESTS"/*; do
    [[ -f "$file" ]] || continue
    sources+=("${image%:*}@sha256:$(basename "$file")")
done

# Every declared arch has to be in, or :latest would answer for fewer arches than
# the entry claims — worse than not publishing at all
expected="$(arches | wc -l | tr -d '[:space:]')"
[[ "${#sources[@]}" -eq "$expected" ]] || fail "$WORKFLOW declares $expected arch, ${#sources[@]} pushed — refusing a partial manifest"

echo "==> publish $image${version:+  (+ :$version)}  [${#sources[@]} arch]"
docker buildx imagetools create "${tags[@]}" "${sources[@]}"
docker buildx imagetools inspect "$image"
