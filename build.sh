#!/usr/bin/env bash
#
# Build one Hub workflow into a multi-arch OCI archive: .build/<key>.oci.tar
#
# Reads folder NN.<key>: needs a Dockerfile and an index.md whose JSON config
# has the target arches, e.g. { "arch": ["amd64", "arm64"] }. Publish separately
# with ./publish.sh. Setup once with ./prepare.sh.
#
# Usage:
#   ./build.sh <workflow>                                    # arch from index.md
#   PLATFORM=linux/amd64,linux/arm64 ./build.sh <workflow>   # override
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
[ -f "$dir/index.md" ] || { echo "no index.md in ${dir#"$HUB_DIR"/}" >&2; exit 1; }

# Build context is the Dockerfile's directory: prefer build/, fall back to the workflow root
if [ -f "$dir/build/Dockerfile" ]; then
  context="$dir/build"
elif [ -f "$dir/Dockerfile" ]; then
  context="$dir"
else
  echo "no Dockerfile in ${dir#"$HUB_DIR"/}" >&2; exit 1
fi
dockerfile="$context/Dockerfile"

# Target platforms: from index.md's "arch" array unless PLATFORM overrides
if [ -z "${PLATFORM:-}" ]; then
  archs="$(grep -m1 'arch' "$dir/index.md" | grep -oE 'amd64|arm64' || true)"
  [ -n "$archs" ] || { echo "no arch in ${dir#"$HUB_DIR"/}/index.md" >&2; exit 1; }
  PLATFORM=""
  for a in $archs; do PLATFORM="${PLATFORM:+$PLATFORM,}linux/$a"; done
fi

# Image tag from the Dockerfile's version label (falls back to latest)
version="$(grep -m1 'org.opencontainers.image.version' "$dockerfile" | grep -oE '[0-9][0-9.]*' | head -1 || true)"

# Build all arches into one multi-arch OCI archive
mkdir -p "$HUB_DIR/.build"
out="$HUB_DIR/.build/$workflow.oci.tar"

echo "==> build $workflow  ($workflow:${version:-latest})  [$PLATFORM]"
docker buildx build --pull --platform "$PLATFORM" \
  --tag "$workflow:${version:-latest}" \
  --output "type=oci,dest=$out" \
  --file "$dockerfile" "$context"

echo "wrote ${out#"$HUB_DIR"/}"
