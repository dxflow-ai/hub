#!/usr/bin/env bash
set -euo pipefail

# Deploy an entry and leave it running, to drive by hand — the interactive
# counterpart to ./verify.sh, which tears everything down when its checks finish.
# Needs ./prepare.sh, ./build.sh, and ./boot.sh first. Expects $WORKFLOW in the
# env, or the key as the first argument.
#
# Usage:
#   ./run.sh <workflow>         # (re)deploy and start; print the published endpoints
#   ./run.sh <workflow> logs    # follow the running workflow's logs
#   ./run.sh <workflow> down    # stop and remove the workflow
# shellcheck disable=SC1091
. "$(dirname "$0")/resolve.sh"

WORKFLOW="${WORKFLOW:-${1:-}}"
action="${2:-up}"
resolve

identity="$(identity rn)"

case "$action" in
    logs)
        exec dxflow workflow logs "$identity"
        ;;
    down)
        dxflow workflow remove "$identity" > /dev/null 2>&1 || true
        echo "==> removed $identity"
        exit 0
        ;;
    up) ;;
    *) fail "unknown action: $action (use up, logs, or down)" ;;
esac

# Keep the .yml name — the CLI keys off the extension to treat it as a workflow file
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
yaml="$workdir/workflow.yml"
block yaml > "$yaml"
[[ -s "$yaml" ]] || fail "no yaml config block in $dir/index.md"

# A locally-built image (./build.sh) lets the engine run pull: missing without a
# registry, and it pulls anything else on start — so a missing image is only a note
while IFS= read -r step; do
    docker image inspect "$step" > /dev/null 2>&1 ||
        echo "==> image not local: $step  (the engine will pull it)"
done < <(images)

# Redeploy from scratch so edits to index.md take effect on every run
dxflow workflow remove "$identity" > /dev/null 2>&1 || true

echo "==> create $identity"
dxflow workflow create --identity "$identity" "$yaml"

# Seed the input volume with the tool's fixtures — handy for exercising a batch tool
if [[ -d "$dir/verify/input" ]]; then
    echo "==> upload verify/input → input/"
    for file in "$dir/verify/input"/*; do
        [[ -e "$file" ]] || continue
        dxflow artifact upload "$file" "input/"
    done
fi

echo "==> start $identity"
dxflow workflow start "$identity"
dxflow workflow steps "$identity" || true

# Published host endpoints come from the yaml ports block. Port `host:` values are
# quoted numbers; volume `host:` values are unquoted paths, so they do not match.
ports="$(grep -oE 'host:[[:space:]]*"[0-9]+"' "$yaml" | grep -oE '[0-9]+' || true)"
if [[ -n "$ports" ]]; then
    echo "==> endpoints:"
    while IFS= read -r port; do
        echo "    localhost:$port"
    done <<< "$ports"
fi

echo "==> running — logs: ./run.sh $WORKFLOW logs   |   stop: ./run.sh $WORKFLOW down"
