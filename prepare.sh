#!/usr/bin/env bash
#
# Set up a build host for ./build.sh and ./publish.sh. Idempotent — run anytime.
#
# Ensures: docker + buildx, a multi-arch buildx builder ("dxflow"), QEMU binfmt
# emulators (cross-arch builds), and skopeo (publishing).
#
# Usage:
#   ./prepare.sh
#
set -euo pipefail

# Name of the dedicated buildx builder this script manages
builder="dxflow"

# 1. docker + buildx
command -v docker >/dev/null 2>&1 || { echo "docker not installed — see https://docs.docker.com/engine/install/" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "docker daemon not reachable — start Docker and check your user's access" >&2; exit 1; }
docker buildx version >/dev/null 2>&1 || { echo "docker buildx not available — see https://github.com/docker/buildx#installing" >&2; exit 1; }
echo "==> docker + buildx ok"

# 2. multi-arch buildx builder (docker-container driver — the default driver cannot emit multi-arch OCI)
if docker buildx inspect "$builder" >/dev/null 2>&1; then
  echo "==> buildx builder '$builder' already exists"
else
  echo "==> create buildx builder '$builder'"
  docker buildx create --name "$builder" --driver docker-container >/dev/null
fi

# Make it the active builder and start it
docker buildx use "$builder"
docker buildx inspect --bootstrap "$builder" >/dev/null

# 3. QEMU emulators for cross-arch builds
echo "==> install QEMU binfmt emulators"
docker run --privileged --rm tonistiigi/binfmt --install all >/dev/null

# 4. skopeo (for publishing)
if command -v skopeo >/dev/null 2>&1; then
  echo "==> skopeo ok"
else
  echo "==> install skopeo"
  if command -v apt-get >/dev/null 2>&1; then sudo apt-get update -qq && sudo apt-get install -y -qq skopeo
  elif command -v dnf >/dev/null 2>&1; then sudo dnf install -y -q skopeo
  elif command -v yum >/dev/null 2>&1; then sudo yum install -y -q skopeo
  elif command -v brew >/dev/null 2>&1; then brew install skopeo
  else echo "no known package manager — install skopeo manually: https://github.com/containers/skopeo/blob/main/install.md" >&2; exit 1
  fi
fi

echo "==> ready — run ./build.sh <workflow> then ./publish.sh <workflow>"
