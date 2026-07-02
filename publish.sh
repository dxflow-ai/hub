#!/usr/bin/env bash
#
# Push a built Hub workflow (.build/<key>.oci.tar) to a registry, all arches in
# one manifest, tagged <registry>/<key>:<version> and :latest.
#
# Run ./build.sh <workflow> first. Setup once with ./prepare.sh, then log in:
#   echo "$GHCR_TOKEN" | docker login ghcr.io -u <user> --password-stdin
#
# Usage:
#   ./publish.sh <workflow>                                # prompts for registry
#   REGISTRY=ghcr.io/dxflow-ai ./publish.sh <workflow>     # override
#
set -euo pipefail

# Repo root (this script's directory)
HUB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Workflow key (the <key> in folder NN.<key>)
workflow="${1:-}"
[ -n "$workflow" ] || { echo "usage: $0 <workflow>   (e.g. $0 fastqc)" >&2; exit 1; }

# Find the workflow folder by matching the part after the NN. prefix
dir=""
while IFS= read -r d; do
  name="$(basename "$d")"
  if [ "${name#*.}" = "$workflow" ]; then dir="$d"; break; fi
done < <(find "$HUB_DIR" -mindepth 2 -maxdepth 2 -type d -not -path '*/.*' | sort)

[ -n "$dir" ] || { echo "unknown workflow: $workflow" >&2; exit 1; }

# Dockerfile holds the version label: prefer build/, fall back to the workflow root
if [ -f "$dir/build/Dockerfile" ]; then
  dockerfile="$dir/build/Dockerfile"
elif [ -f "$dir/Dockerfile" ]; then
  dockerfile="$dir/Dockerfile"
else
  echo "no Dockerfile in ${dir#"$HUB_DIR"/}" >&2; exit 1
fi

# The archive ./build.sh produced
out="$HUB_DIR/.build/$workflow.oci.tar"
[ -f "$out" ] || { echo "not built: ${out#"$HUB_DIR"/}  (run ./build.sh $workflow)" >&2; exit 1; }

# Target registry (prompt unless REGISTRY overrides)
if [ -z "${REGISTRY:-}" ]; then
  read -r -p "Registry [ghcr.io/dxflow-ai]: " REGISTRY
  REGISTRY="${REGISTRY:-ghcr.io/dxflow-ai}"
fi

# Version tag from the Dockerfile's label (falls back to latest)
version="$(grep -m1 'org.opencontainers.image.version' "$dockerfile" | grep -oE '[0-9][0-9.]*' | head -1 || true)"
image="$REGISTRY/$workflow"
primary="${version:-latest}"

# Push the archive, then mirror the version tag to :latest
echo "==> publish $workflow  ($image)"
skopeo copy --all "oci-archive:$out" "docker://$image:$primary"
if [ "$primary" != "latest" ]; then
  skopeo copy --all "docker://$image:$primary" "docker://$image:latest"
fi
