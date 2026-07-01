#!/usr/bin/env bash
#
# Publish one already-built dxflow Hub workflow image to a registry.
# Run ./build.sh <workflow> first (produces .build/<key>.oci.tar).
#
# Pushes the OCI archive as a single manifest (all built arches together):
#     <registry>/<key>:<version>  and  :latest
# Prompts for the target registry.
#
# Requires: skopeo. Authenticate once on the build host before pushing:
#     echo "$GHCR_TOKEN" | docker login ghcr.io -u <github-user> --password-stdin
#   (skopeo reads the docker credentials.)
#
# Usage:
#   ./publish.sh <workflow>                    # e.g. ./publish.sh fastqc  (prompts for registry)
#   REGISTRY=ghcr.io/dxflow-ai ./publish.sh <workflow>   # skip the prompt
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

out="$HUB_DIR/.build/$workflow.oci.tar"
[ -f "$out" ] || { echo "not built: ${out#"$HUB_DIR"/}  (run ./build.sh $workflow)" >&2; exit 1; }

if [ -z "${REGISTRY:-}" ]; then
  read -r -p "Registry [ghcr.io/dxflow-ai]: " REGISTRY
  REGISTRY="${REGISTRY:-ghcr.io/dxflow-ai}"
fi

version="$(grep -m1 'org.opencontainers.image.version' "$dir/Dockerfile" | sed -E 's/.*"([^"]+)".*/\1/' || true)"
image="$REGISTRY/$workflow"
primary="${version:-latest}"

echo "==> publish $workflow  ($image)"
skopeo copy --all "oci-archive:$out" "docker://$image:$primary"
if [ "$primary" != "latest" ]; then
  skopeo copy --all "docker://$image:$primary" "docker://$image:latest"
fi
