#!/usr/bin/env bash
#
# Build a Hub workflow's image for all its target arches and push it to the
# registry as one multi-arch manifest (:latest and :<version>). Set up the host
# once with ./prepare.sh, then log in to the registry:
#   echo "$GHCR_TOKEN" | docker login ghcr.io -u <user> --password-stdin
#
# Usage:
#   ./publish.sh <workflow>    # e.g. ./publish.sh fastqc
#
set -euo pipefail

# Repo root (this script's directory)
HUB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Workflow key (the <key> in folder NN.<key>)
workflow="${1:-}"
[ -n "$workflow" ] || { echo "usage: $0 <workflow>" >&2; exit 1; }

# Find the workflow folder by matching the part after the NN. prefix
dir=""
while IFS= read -r d; do
  name="$(basename "$d")"
  if [ "${name#*.}" = "$workflow" ]; then dir="$d"; break; fi
done < <(find "$HUB_DIR" -mindepth 2 -maxdepth 2 -type d -not -path '*/.*' | sort)

[ -n "$dir" ] || { echo "unknown workflow: $workflow" >&2; exit 1; }
[ -f "$dir/index.md" ] || { echo "no index.md in ${dir#"$HUB_DIR"/}" >&2; exit 1; }

# Build context is the Dockerfile's directory: prefer build/, fall back to the root
if [ -f "$dir/build/Dockerfile" ]; then
  context="$dir/build"
elif [ -f "$dir/Dockerfile" ]; then
  context="$dir"
else
  echo "no Dockerfile in ${dir#"$HUB_DIR"/}" >&2; exit 1
fi

# Target image this folder publishes, from the json "image" field
json="$(awk '/^```json/{flag=1; next} /^```/{if (flag) exit} flag' "$dir/index.md")"
re='"image"[[:space:]]*:[[:space:]]*"([^"]+)"'
[[ "$json" =~ $re ]] || { echo "no \"image\" in ${dir#"$HUB_DIR"/}/index.md json" >&2; exit 1; }
image="${BASH_REMATCH[1]}"

# Target platforms from the json "arch" array
archs="$(printf '%s' "$json" | grep -oE 'amd64|arm64' || true)"
[ -n "$archs" ] || { echo "no arch in ${dir#"$HUB_DIR"/}/index.md json" >&2; exit 1; }
platform=""
for a in $archs; do platform="${platform:+$platform,}linux/$a"; done

# Version from the json — adds the :<version> tag and the OCI version label
re='"version"[[:space:]]*:[[:space:]]*"([^"]+)"'
version=""
[[ "$json" =~ $re ]] && version="${BASH_REMATCH[1]}"
args=(--tag "$image")
if [ -n "$version" ]; then
  args+=(--tag "${image%:*}:$version" --label "org.opencontainers.image.version=$version")
fi

# Build all arches and push as one multi-arch manifest
echo "==> publish $image  [$platform]${version:+  (+ :$version)}"
docker buildx build --pull --push --platform "$platform" \
  --provenance=false --sbom=false \
  "${args[@]}" \
  --file "$context/Dockerfile" "$context"
