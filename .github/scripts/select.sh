#!/usr/bin/env bash
set -euo pipefail

# Plan the run: take the requested keys, add everything built on top of them, and
# order the lot into waves that publish.yml chains — a wave publishes only once the
# wave it builds on has, so a child always picks up its rebuilt base from the
# registry. Each wave becomes a matrix of one entry per workflow and target arch
# (from its index.md json "arch"), paired with the runner that builds that arch
# natively. Expects $INPUT, $DEPENDENTS, and $GITHUB_OUTPUT in the env.
# shellcheck disable=SC1091
. "$(dirname "$0")/resolve.sh"

# How many wave jobs publish.yml chains together — as deep as the hub goes today,
# an entry built on a base. A chain past this is refused rather than half-published,
# so a new level means adding a wave job and raising this.
WAVES=2

# The runner an arch builds on without emulation
runner_for() {
    case "$1" in
        amd64) echo "ubuntu-latest" ;;
        arm64) echo "ubuntu-24.04-arm" ;;
        *) fail "unsupported arch: $1" ;;
    esac
}

plan "$INPUT" "${DEPENDENTS:-true}"

deepest="$(deepest_wave)"
[[ "$deepest" -lt "$WAVES" ]] || fail "dependency chain is $((deepest + 1)) deep — add a wave to publish.yml"

# Turn each wave into its matrix, rejecting a draft here rather than on a runner
for wave in $(seq 0 $((WAVES - 1))); do
    keys=()
    builds=()
    for WORKFLOW in $(wave_keys "$wave"); do
        resolve

        [[ -f "$context/Dockerfile" ]] || fail "$WORKFLOW has no build/Dockerfile — it is a draft"
        [[ -f "$dir/verify/check.sh" ]] || fail "$WORKFLOW has no verify/check.sh — it is a draft"

        target="$(arches)"
        [[ -n "$target" ]] || fail "no \"arch\" in $dir/index.md json"

        keys+=("$WORKFLOW")
        for arch in $target; do
            builds+=("$WORKFLOW $arch $(runner_for "$arch")")
        done
    done

    # Named for the wave job in publish.yml that consumes them, e.g. wave2_builds
    name="wave$((wave + 1))"
    if [[ "${#keys[@]}" -eq 0 ]]; then
        echo "${name}_builds=" >> "$GITHUB_OUTPUT"
        echo "${name}_workflows=" >> "$GITHUB_OUTPUT"
        continue
    fi

    matrix="$(printf '%s\n' "${builds[@]}" | jq -Rc 'split(" ") | {workflow: .[0], arch: .[1], runner: .[2]}' | jq -sc '{include: .}')"
    workflows="$(printf '%s\n' "${keys[@]}" | jq -Rc . | jq -sc 'unique')"

    echo "${name}_builds=$matrix" >> "$GITHUB_OUTPUT"
    echo "${name}_workflows=$workflows" >> "$GITHUB_OUTPUT"
    echo "$name: ${keys[*]}"
done
