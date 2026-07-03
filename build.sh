#!/usr/bin/env bash
#
# Build one Hub workflow's image for this machine's architecture and load it
# into the local Docker, so ./verify.sh and the engine (pull: missing) use it
# without pulling from a registry. Push all arches with ./publish.sh; set up
# the host once with ./prepare.sh.
#
# Usage:
#   ./build.sh <workflow>    # e.g. ./build.sh fastqc
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

# Target image this folder builds, from the json "image" field (the yaml may
# reference more images, but only this one is ours to build)
json="$(awk '/^```json/{flag=1; next} /^```/{if (flag) exit} flag' "$dir/index.md")"
re='"image"[[:space:]]*:[[:space:]]*"([^"]+)"'
[[ "$json" =~ $re ]] || { echo "no \"image\" in ${dir#"$HUB_DIR"/}/index.md json" >&2; exit 1; }
image="${BASH_REMATCH[1]}"

# Build for this machine's arch and load it into the local Docker
echo "==> build $image  (local, $(uname -m))"
docker buildx build --load --tag "$image" --file "$context/Dockerfile" "$context"
echo "==> loaded $image  (run ./verify.sh $workflow, or ./publish.sh $workflow)"
