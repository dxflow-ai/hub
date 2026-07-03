#!/usr/bin/env bash
#
# Set up a host for ./build.sh, ./publish.sh, and ./verify.sh. Idempotent — run anytime.
#
# Installs whatever is missing: docker + buildx, a multi-arch buildx builder
# ("dxflow"), QEMU binfmt emulators (cross-arch builds), and the dxflow CLI
# (verify). Meant for a fresh Linux build host (e.g. EC2).
# It does NOT start the dxflow engine — verify needs a running engine, which is a
# stateful daemon you start yourself.
#
# Usage:
#   ./prepare.sh          # run as root, or as a user with sudo
#
set -euo pipefail

# Name of the dedicated buildx builder this script manages
builder="dxflow"

have() { command -v "$1" >/dev/null 2>&1; }
log() { echo "==> $*"; }
die() { echo "$*" >&2; exit 1; }

# Run a command as root: directly if we already are, otherwise via sudo
root() { if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi; }

# Normalized architecture (amd64 / arm64) for release downloads
arch() {
  case "$(uname -m)" in
    x86_64 | amd64) echo amd64 ;;
    aarch64 | arm64) echo arm64 ;;
    *) return 1 ;;
  esac
}

[ "$(uname -s)" = "Linux" ] || die "this script targets a Linux build host"

# 0. curl (needed to fetch installers below)
if ! have curl; then
  log "install curl"
  if have apt-get; then root apt-get update -qq && root apt-get install -y -qq curl
  elif have dnf; then root dnf install -y -q curl
  elif have yum; then root yum install -y -q curl
  else die "curl is required — install it and re-run"
  fi
fi

# 1. docker
if have docker; then
  log "docker ok"
else
  log "install docker"
  curl -fsSL https://get.docker.com | root sh
fi

# Make sure the daemon is running
if ! docker info >/dev/null 2>&1; then
  log "start docker daemon"
  root systemctl enable --now docker >/dev/null 2>&1 || root service docker start >/dev/null 2>&1 || true
  docker info >/dev/null 2>&1 || die "docker daemon not reachable — start it and re-run"
fi

# 2. buildx plugin (the Docker CLI plugin multi-arch builds need)
if docker buildx version >/dev/null 2>&1; then
  log "buildx ok"
else
  a="$(arch)" || die "unknown arch $(uname -m) — install buildx manually: https://github.com/docker/buildx#installing"
  log "install docker buildx plugin (linux/$a)"
  # Resolve the latest tag from the full response (a piped grep -m1 would
  # SIGPIPE curl and trip pipefail before we ever download)
  release="$(curl -fsSL https://api.github.com/repos/docker/buildx/releases/latest)"
  re='"tag_name":[[:space:]]*"([^"]+)"'
  [[ "$release" =~ $re ]] || die "could not resolve the latest buildx version"
  version="${BASH_REMATCH[1]}"
  # Download, then install into the Docker CLI-plugins dir
  tmp="$(mktemp)"
  curl -fSL "https://github.com/docker/buildx/releases/download/${version}/buildx-${version}.linux-${a}" -o "$tmp" || die "failed to download buildx"
  root install -D -m 0755 "$tmp" /usr/local/lib/docker/cli-plugins/docker-buildx
  rm -f "$tmp"
  docker buildx version >/dev/null 2>&1 || die "buildx install failed — see https://github.com/docker/buildx#installing"
fi

# 3. multi-arch buildx builder (docker-container driver — the default driver cannot emit multi-arch OCI)
if docker buildx inspect "$builder" >/dev/null 2>&1; then
  log "buildx builder '$builder' already exists"
else
  log "create buildx builder '$builder'"
  docker buildx create --name "$builder" --driver docker-container >/dev/null
fi

# Make it the active builder and start it
docker buildx use "$builder"
docker buildx inspect --bootstrap "$builder" >/dev/null

# 4. QEMU emulators for cross-arch builds
log "install QEMU binfmt emulators"
docker run --privileged --rm tonistiigi/binfmt --install all >/dev/null

# 5. dxflow CLI (for ./verify.sh) — the engine binary; verify drives it and boots against it
if have dxflow; then
  log "dxflow CLI ok"
else
  a="$(arch)" || die "unknown arch $(uname -m) — install dxflow manually: https://github.com/dxflow-ai/community/releases/latest"
  log "install dxflow CLI (linux/$a)"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL "https://github.com/dxflow-ai/community/releases/latest/download/dxflow_linux_$a.tar.gz" | tar -xz -C "$tmp"
  root mv "$tmp/dxflow" /usr/local/bin/
fi

log "ready — ./build.sh, ./publish.sh, ./verify.sh <workflow>"
