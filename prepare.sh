#!/usr/bin/env bash
#
# Set up a host for ./build.sh, ./publish.sh, and ./verify.sh. Idempotent — run anytime.
#
# Ensures: docker + buildx, a multi-arch buildx builder ("dxflow"), QEMU binfmt
# emulators (cross-arch builds), skopeo (publishing), and the dxflow CLI (verify).
# It does NOT start the dxflow engine — verify needs a running engine, which is a
# stateful daemon you start yourself (see the "ready" message at the end).
#
# Usage:
#   ./prepare.sh
#
set -euo pipefail

# Name of the dedicated buildx builder this script manages
builder="dxflow"

have() { command -v "$1" >/dev/null 2>&1; }
log() { echo "==> $*"; }
die() { echo "$*" >&2; exit 1; }

# 1. docker + buildx
have docker || die "docker not installed — see https://docs.docker.com/engine/install/"
docker info >/dev/null 2>&1 || die "docker daemon not reachable — start Docker and check your user's access"
docker buildx version >/dev/null 2>&1 || die "docker buildx not available — see https://github.com/docker/buildx#installing"
log "docker + buildx ok"

# 2. multi-arch buildx builder (docker-container driver — the default driver cannot emit multi-arch OCI)
if docker buildx inspect "$builder" >/dev/null 2>&1; then
  log "buildx builder '$builder' already exists"
else
  log "create buildx builder '$builder'"
  docker buildx create --name "$builder" --driver docker-container >/dev/null
fi

# Make it the active builder and start it
docker buildx use "$builder"
docker buildx inspect --bootstrap "$builder" >/dev/null

# 3. QEMU emulators for cross-arch builds
log "install QEMU binfmt emulators"
docker run --privileged --rm tonistiigi/binfmt --install all >/dev/null

# 4. skopeo (for publishing)
if have skopeo; then
  log "skopeo ok"
else
  log "install skopeo"
  if have apt-get; then sudo apt-get update -qq && sudo apt-get install -y -qq skopeo
  elif have dnf; then sudo dnf install -y -q skopeo
  elif have yum; then sudo yum install -y -q skopeo
  elif have brew; then brew install skopeo
  else die "no known package manager — install skopeo manually: https://github.com/containers/skopeo/blob/main/install.md"
  fi
fi

# 5. dxflow CLI (for ./verify.sh) — the engine binary; verify drives it and boots against it
if have dxflow; then
  log "dxflow CLI ok"
elif [ "$(uname -s)" = "Linux" ]; then
  case "$(uname -m)" in
    x86_64 | amd64) asset="amd64" ;;
    aarch64 | arm64) asset="arm64" ;;
    *) die "unknown arch $(uname -m) — install dxflow manually: https://github.com/dxflow-ai/community/releases/latest" ;;
  esac
  log "install dxflow CLI (linux/$asset)"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL "https://github.com/dxflow-ai/community/releases/latest/download/dxflow_linux_$asset.tar.gz" | tar -xz -C "$tmp"
  sudo mv "$tmp/dxflow" /usr/local/bin/
else
  die "install dxflow manually: https://github.com/dxflow-ai/community/releases/latest"
fi

log "ready — ./build.sh, ./publish.sh, ./verify.sh <workflow>"
