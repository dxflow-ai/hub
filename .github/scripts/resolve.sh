#!/usr/bin/env bash

# Shared lookups for the scripts next to it — sourced, never run. Sourcing moves to
# the repository root, so every entry path below is relative and the scripts work
# from any directory.
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# Report to the Actions log and stop.
fail() {
    echo "::error::$*"
    exit 1
}

# Print a fenced block of the entry's index.md, e.g. `block json`.
block() {
    awk -v tag="$1" '
        $0 == "```" tag { flag = 1; next }
        /^```/ { if (flag) exit }
        flag
    ' "$dir/index.md"
}

# Print a string field of the entry's json block, e.g. `field image`.
field() {
    sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" <<< "$json"
}

# Print the arches the entry targets.
arches() {
    sed -n 's/.*"arch"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p' <<< "$json" | grep -oE 'amd64|arm64' | sort -u
}

# Print every step image the entry's workflow yaml runs.
images() {
    block yaml | grep -oE 'image:[[:space:]]*[^[:space:]]+' | sed 's/image:[[:space:]]*//' | sort -u
}

# Print every publishable entry's key, in the order the hub lists them.
publishable() {
    local candidate name
    for candidate in */*/; do
        [[ -f "$candidate/build/Dockerfile" ]] || continue
        [[ -f "$candidate/verify/check.sh" ]] || continue
        name="$(basename "$candidate")"
        echo "${name#*.}"
    done
}

# Print the entries whose Dockerfile builds directly on this one.
children_of() {
    local candidate name
    for candidate in */*/; do
        [[ -f "$candidate/build/Dockerfile" ]] || continue
        grep -qE "^FROM[[:space:]]+ghcr\.io/dxflow-ai/$1[:[:space:]]" "$candidate/build/Dockerfile" || continue
        name="$(basename "$candidate")"
        echo "${name#*.}"
    done
}

# Print the wave an entry sits in, from the table plan() leaves in $levels.
wave_of() {
    awk -v key="$1" '$1 == key { print $2 }' <<< "$levels"
}

# Print the keys plan() put in the given wave.
wave_keys() {
    awk -v want="$1" '$2 == want { print $1 }' <<< "$levels"
}

# Print the deepest wave plan() reached.
deepest_wave() {
    awk '{ if ($2 > deepest) deepest = $2 } END { print deepest + 0 }' <<< "$levels"
}

# Order the given keys and everything built on top of them into waves, leaving
# $levels set to a "<key> <wave>" table. An entry lands in the deepest wave that
# reaches it, so a base is always published before anything standing on it is
# rebuilt. Pass "false" as the second argument to keep to the keys themselves.
plan() {
    local roots="$1" dependents="${2:-true}" key parent child wave current guard=0
    local queue=()

    levels=""
    for key in ${roots//,/ }; do
        levels+="$key 0"$'\n'
        queue+=("$key")
    done

    [[ "${#queue[@]}" -gt 0 ]] || fail "no workflow given"
    [[ "$dependents" == "true" ]] || return 0

    while [[ "${#queue[@]}" -gt 0 ]]; do
        parent="${queue[0]}"
        queue=("${queue[@]:1}")

        guard=$((guard + 1))
        [[ "$guard" -le 200 ]] || fail "dependency loop around $parent"

        wave=$(($(wave_of "$parent") + 1))
        for child in $(children_of "$parent"); do
            current="$(wave_of "$child")"
            if [[ -n "$current" ]] && [[ "$current" -ge "$wave" ]]; then
                continue
            fi

            levels="$(grep -v "^$child " <<< "$levels"; echo "$child $wave")"
            queue+=("$child")
        done
    done
}

# Print a stable engine identity for this entry under the given prefix — the engine
# takes ^[a-z]{2}[a-z0-9]{6,10}$, so pad and clip the key to fit.
identity() {
    local value
    value="$1$(printf '%s' "$WORKFLOW" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')"
    while [[ "${#value}" -lt 8 ]]; do value="${value}0"; done

    printf '%s' "${value:0:12}"
}

# Locate the entry $WORKFLOW names and read what its index.md declares, leaving
# $dir, $json, $image, $version, and $context set.
resolve() {
    [[ -n "${WORKFLOW:-}" ]] || fail "no workflow given — set \$WORKFLOW or pass the key as the first argument"

    dir=""
    for candidate in */*/; do
        name="$(basename "$candidate")"
        if [[ "${name#*.}" == "$WORKFLOW" ]]; then
            dir="${candidate%/}"
            break
        fi
    done

    [[ -n "$dir" ]] || fail "unknown workflow: $WORKFLOW"
    [[ -f "$dir/index.md" ]] || fail "no index.md in $dir"

    json="$(block json)"
    [[ -n "$json" ]] || fail "$WORKFLOW is a draft — its index.md has no json block"

    image="$(field image)"
    version="$(field version)"

    [[ -n "$image" ]] || fail "no \"image\" in $dir/index.md json"

    # The build context is the Dockerfile's own directory
    context="$dir/build"
    [[ -f "$context/Dockerfile" ]] || context="$dir"
}
