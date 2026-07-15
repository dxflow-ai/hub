#!/usr/bin/env bash
#
# Run a Hub workflow through the dxflow engine and leave it running, so you can
# open it in a browser and use it by hand — the interactive counterpart to the
# automated ./verify.sh (which tears everything down when its checks finish).
# Build every step's image with ./build.sh first, and have a reachable dxflow
# engine plus the `dxflow` CLI on PATH.
#
# Usage:
#   ./run.sh <workflow>          # (re)deploy and start; print the published endpoints
#   ./run.sh <workflow> logs     # follow the running workflow's logs
#   ./run.sh <workflow> down     # stop and remove the workflow
#
set -euo pipefail

HUB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

have() { command -v "$1" >/dev/null 2>&1; }
log() { echo "==> $*"; }
die() { echo "$*" >&2; exit 1; }

workflow="${1:-}"
action="${2:-up}"
[ -n "$workflow" ] || die "usage: $0 <workflow> [up|logs|down]"

have dxflow || die "dxflow CLI not found on PATH"
have docker || die "docker not found on PATH"

# Find the workflow folder by matching the part after the NN. prefix
dir=""
while IFS= read -r d; do
  name="$(basename "$d")"
  if [ "${name#*.}" = "$workflow" ]; then dir="$d"; break; fi
done < <(find "$HUB_DIR" -mindepth 2 -maxdepth 2 -type d -not -path '*/.*' | sort)

[ -n "$dir" ] || die "unknown workflow: $workflow"
[ -f "$dir/index.md" ] || die "no index.md in ${dir#"$HUB_DIR"/}"

identity="run-$workflow"

# Secondary actions operate on the already-running workflow.
case "$action" in
  logs)
    exec dxflow workflow logs "$identity"
    ;;
  down | stop | remove)
    log "remove $identity"
    dxflow workflow remove "$identity" >/dev/null 2>&1 || true
    log "removed $identity"
    exit 0
    ;;
  up) ;;
  *) die "unknown action: $action (use up|logs|down)" ;;
esac

# Extract the workflow YAML (first ```yaml block under ## Configuration).
# Keep the .yml name — the CLI keys off the extension to treat it as a workflow.
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
yaml="$workdir/workflow.yml"
awk '/^```yaml/{flag=1; next} /^```/{if (flag) exit} flag' "$dir/index.md" >"$yaml"
[ -s "$yaml" ] || die "no yaml config block in ${dir#"$HUB_DIR"/}/index.md"

# Locally-built images (./build.sh) let the engine run pull: missing without a
# registry. Public images are pulled by the engine on start. So a missing image
# is only a warning here — the engine will pull it, or fail loudly if it can't.
images="$(grep -oE 'image:[[:space:]]*[^[:space:]]+' "$yaml" | sed 's/image:[[:space:]]*//')"
[ -n "$images" ] || die "no image in the workflow yaml"
while IFS= read -r img; do
  docker image inspect "$img" >/dev/null 2>&1 ||
    log "image not local: $img  (engine will pull it; if it is a Hub image, ./build.sh $workflow first)"
done <<< "$images"

# Redeploy from scratch so edits to index.md take effect on every run.
dxflow workflow remove "$identity" >/dev/null 2>&1 || true

log "create $identity"
dxflow workflow create --identity "$identity" "$yaml"

# Seed the input volume with the tool's verify fixtures when present — handy for
# exercising a batch tool by hand.
if [ -d "$dir/verify/input" ]; then
  log "upload verify/input -> input/"
  for f in "$dir/verify/input"/*; do
    [ -e "$f" ] || continue
    dxflow artifact upload "$f" "input/"
  done
fi

log "start $identity"
dxflow workflow start "$identity"

dxflow workflow steps "$identity" || true

# Published host endpoints come from the yaml ports block. Port `host:` values are
# quoted numbers; volume `host:` values are unquoted paths, so they don't match.
ports="$(grep -oE 'host:[[:space:]]*"[0-9]+"' "$yaml" | grep -oE '[0-9]+' || true)"
if [ -n "$ports" ]; then
  echo
  log "endpoints:"
  while IFS= read -r p; do
    echo "    localhost:$p"
  done <<< "$ports"
fi

echo
log "running — logs: ./run.sh $workflow logs   |   stop: ./run.sh $workflow down"
