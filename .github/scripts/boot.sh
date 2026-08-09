#!/usr/bin/env bash
set -euo pipefail

# Boot the engine ./verify.sh and ./run.sh drive, rooted in its volume directory:
# the engine hands volume paths to `docker run -v` verbatim, so a workflow only sees
# the uploaded fixtures when that directory is the engine's own working directory.
# Idempotent — a reachable engine is left alone. Expects $RUNNER_TEMP in the env.
if dxflow ping --count 1 > /dev/null 2>&1; then
    echo "engine already up"
    exit 0
fi

volume="$HOME/.dxflow/volume"
mkdir -p "$volume"

log="${RUNNER_TEMP:-/tmp}/engine.log"
(cd "$volume" && nohup dxflow boot up --http > "$log" 2>&1 &)

# Hand over only once it answers on its socket
for _ in $(seq 30); do
    if dxflow ping --count 1 > /dev/null 2>&1; then
        echo "engine up (volume $volume)"
        exit 0
    fi
    sleep 2
done

cat "$log"
echo "::error::engine did not answer within 60s"
exit 1
