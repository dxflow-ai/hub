#!/usr/bin/env bash
set -euo pipefail

# Set the runner up for the steps that follow: a buildx builder that exports both to
# the local docker (./build.sh) and to the registry (./push.sh), and the dxflow CLI
# that ./verify.sh drives. Idempotent — safe to re-run.
builder="dxflow"

# Without the plugin, docker parses `buildx ...` as its own arguments and reports a
# flag it has never heard of instead of a missing command
docker buildx version > /dev/null 2>&1 || {
    echo "::error::docker buildx is required — see https://github.com/docker/buildx#installing"
    exit 1
}

# The default docker driver cannot push by digest, so build on a docker-container one
if ! docker buildx inspect "$builder" > /dev/null 2>&1; then
    docker buildx create --name "$builder" --driver docker-container > /dev/null
fi

docker buildx use "$builder"
docker buildx inspect --bootstrap "$builder" > /dev/null

case "$(uname -m)" in
    x86_64 | amd64) arch="amd64" ;;
    aarch64 | arm64) arch="arm64" ;;
    *) echo "::error::unsupported arch: $(uname -m)"; exit 1 ;;
esac

# The engine API is version-sensitive, so take the CLI from the latest release
curl -fsSL "https://github.com/dxflow-ai/community/releases/latest/download/dxflow_linux_$arch.tar.gz" |
    sudo tar -xz -C /usr/local/bin dxflow
sudo chmod 0755 /usr/local/bin/dxflow

docker buildx version
dxflow --version
