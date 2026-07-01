#!/usr/bin/env bash
#
# Build one dxflow Hub workflow image into a local OCI archive.
#
# The workflow key is required; its folder (NN.<key>) must contain a Dockerfile.
# Prompts for target architecture(s) — amd64, arm64, or both. All selected arches
# are written into a single OCI archive (one asset, multi-arch manifest inside):
#     .build/<key>.oci.tar
# Pushing to a registry is handled separately by ./publish.sh
#
# Requires: docker buildx. For cross-arch builds, install the QEMU emulators once:
#     docker run --privileged --rm tonistiigi/binfmt --install all
#
# Usage:
#   ./build.sh <workflow>                                    # e.g. ./build.sh fastqc  (prompts for arch)
#   PLATFORM=linux/amd64,linux/arm64 ./build.sh <workflow>   # skip the prompt
#
set -euo pipefail

HUB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

workflow="${1:-}"
[ -n "$workflow" ] || { echo "usage: $0 <workflow>   (e.g. $0 fastqc)" >&2; exit 1; }

dir=""
while IFS= read -r d; do
  name="$(basename "$d")"
  if [ "${name#*.}" = "$workflow" ]; then dir="$d"; break; fi
done < <(find "$HUB_DIR" -mindepth 2 -maxdepth 2 -type d -not -path '*/.*' | sort)

[ -n "$dir" ] || { echo "unknown workflow: $workflow" >&2; exit 1; }
[ -f "$dir/Dockerfile" ] || { echo "no Dockerfile in ${dir#"$HUB_DIR"/}" >&2; exit 1; }

if [ -z "${PLATFORM:-}" ]; then
  echo "Select target architecture(s):"
  select choice in "linux/amd64" "linux/arm64" "linux/amd64,linux/arm64"; do
    [ -n "${choice:-}" ] && { PLATFORM="$choice"; break; }
    echo "invalid choice"
  done
fi

version="$(grep -m1 'org.opencontainers.image.version' "$dir/Dockerfile" | sed -E 's/.*"([^"]+)".*/\1/' || true)"

mkdir -p "$HUB_DIR/.build"
out="$HUB_DIR/.build/$workflow.oci.tar"

echo "==> build $workflow  ($workflow:${version:-latest})  [$PLATFORM]"
docker buildx build --pull --platform "$PLATFORM" \
  --tag "$workflow:${version:-latest}" \
  --output "type=oci,dest=$out" \
  --file "$dir/Dockerfile" "$dir"

echo "wrote ${out#"$HUB_DIR"/}"
