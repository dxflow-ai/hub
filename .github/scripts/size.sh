#!/usr/bin/env bash
set -euo pipefail

# Ask the registry how big the entry's published image is today and bring the
# "size" of its index.md json block in line with it. Reports by default; --apply
# writes. Sizes drift on every rebuild — a base image moving underneath an entry
# changes it without the version ever changing — so this is a sweep to re-run after
# a publish, not something an entry declares by hand.
#
# The size recorded is what the registry reports: the compressed download, summed
# over the config blob and every layer, per arch. That is the only size a registry
# can answer without pulling the image, and it is what GitHub shows on the package
# page. On disk the unpacked image is larger — "minimum".storage covers that.
#
# An entry gets one reading per arch it declares, keyed the same way:
#
#     "size": {
#         "amd64": "1.1G",
#         "arm64": "1.0G"
#     },
#
# An arch the entry declares but the registry has no manifest for is reported as a
# miss and left out, rather than written as a guess.
#
# ghcr reads go out anonymously — public packages need no account. A signed-in gh
# is borrowed when $GITHUB_TOKEN is not already set, which also reaches a package
# that has been pushed but not yet made public.
#
# Usage: size.sh                     # ask which, from the entries that publish
#        size.sh <key> [--apply]     # one entry
#        size.sh --all [--apply]     # every entry that has an image to measure
# shellcheck disable=SC1090,SC1091
. "$(dirname "$0")/resolve.sh"

command -v jq >/dev/null 2>&1 || fail "jq is required — brew install jq"

# Borrow the token a workstation already has, so a package still held private
# answers rather than 404s.
if [[ -z "${GITHUB_TOKEN:-}" ]] && command -v gh >/dev/null 2>&1; then
    GITHUB_TOKEN="$(gh auth token 2>/dev/null || true)"
    export GITHUB_TOKEN
fi

apply="false"
target=""
for argument in "$@"; do
    case "$argument" in
        --apply) apply="true" ;;
        --all) target="*" ;;
        -*) fail "unknown option: $argument" ;;
        *) target="$argument" ;;
    esac
done
target="${target:-${WORKFLOW:-}}"

# Ask which entry, the way ./version.sh asks which to check.
choose() {
    local options=("all") key choice
    while IFS= read -r key; do
        options+=("$key")
    done < <(publishable)

    PS3="measure which workflow? (number, or q to quit) "
    select choice in "${options[@]}"; do
        if [[ -n "$choice" ]]; then
            printf '%s' "$choice"
            return 0
        fi
        if [[ "$REPLY" == "q" ]]; then
            return 0
        fi
    done
}

if [[ -z "$target" ]]; then
    # A run with nowhere to ask — a hook, a pipe, Actions — is told rather than hung
    if [[ ! -t 0 ]]; then
        fail "no workflow given — pass a key or --all"
    fi

    target="$(choose)"
    if [[ -z "$target" ]]; then
        echo "Cancelled."
        exit 0
    fi
    if [[ "$target" == "all" ]]; then
        target="*"
    fi
fi

# A pull token for one ghcr repository. Anonymous unless the environment carries a
# GitHub token, which ghcr takes as the password of a basic-auth pair.
ghcr_token() {
    local auth=()
    [[ -z "${GITHUB_TOKEN:-}" ]] || auth=(--user "x:$GITHUB_TOKEN")

    curl -fsSL --retry 3 --retry-delay 2 --max-time 45 \
        --header "User-Agent: dxflow-hub" ${auth[@]+"${auth[@]}"} \
        "https://ghcr.io/token?scope=repository:$1:pull&service=ghcr.io" | jq -r '.token // empty'
}

# GET a manifest or blob by tag or digest. Both manifest media types are asked for,
# so a registry handing back a single-arch manifest is not refused.
ghcr_get() {
    curl -fsSL --retry 3 --retry-delay 2 --max-time 45 \
        --header "User-Agent: dxflow-hub" \
        --header "Authorization: Bearer $token" \
        --header "Accept: application/vnd.oci.image.index.v1+json" \
        --header "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
        --header "Accept: application/vnd.oci.image.manifest.v1+json" \
        --header "Accept: application/vnd.docker.distribution.manifest.v2+json" \
        "https://ghcr.io/v2/$repo/$1/$2"
}

# Bytes as the json block writes them — whole megabytes below a gigabyte, one
# decimal above, the same units "minimum" is read in.
human() {
    awk -v bytes="$1" 'BEGIN {
        if (bytes >= 1073741824) printf "%.1fG\n", bytes / 1073741824
        else printf "%dM\n", int(bytes / 1048576 + 0.5)
    }'
}

# The compressed size of one image manifest: its config blob plus every layer.
weigh() {
    ghcr_get manifests "$1" | jq '[.config.size] + [.layers[].size] | add'
}

# Read the registry for $image, leaving $measured set to an "<arch> <bytes>" table.
# A multi-arch index is walked platform by platform; buildx's attestation manifests
# carry no architecture and are skipped. A lone manifest names its arch only in its
# config blob, so that is where it is read from.
measure() {
    local reference="${image##*:}" root platforms architecture digest bytes
    repo="${image%:*}"
    repo="${repo#ghcr.io/}"

    measured=""
    token="$(ghcr_token "$repo")" || return 1
    [[ -n "$token" ]] || return 1
    root="$(ghcr_get manifests "$reference")" || return 1

    platforms="$(jq -r '
        if .manifests then
            .manifests[]
            | select(.platform.architecture and .platform.architecture != "unknown")
            | "\(.platform.architecture) \(.digest)"
        else
            empty
        end' <<< "$root")"

    if [[ -z "$platforms" ]]; then
        architecture="$(ghcr_get blobs "$(jq -r '.config.digest' <<< "$root")" | jq -r '.architecture // empty')"
        [[ -n "$architecture" ]] || return 1
        bytes="$(jq '[.config.size] + [.layers[].size] | add' <<< "$root")"
        measured="$architecture $bytes"
        return 0
    fi

    while read -r architecture digest; do
        bytes="$(weigh "$digest")" || return 1
        measured+="$architecture $bytes"$'\n'
    done <<< "$platforms"
}

# The bytes measure() found for one arch, empty when the registry has no manifest
# for it.
bytes_of() {
    awk -v want="$1" '$1 == want { print $2 }' <<< "$measured"
}

# The size the index.md json block currently records for one arch.
recorded() {
    jq -r --arg arch "$1" '.size[$arch] // empty' <<< "$json" 2>/dev/null
}

# Swap the "size" of the index.md json block for a freshly rendered one — only that
# block, and only that key, so the rest of the page is left alone. The new block
# goes in behind "version", where it sits today; any old one is dropped on the way
# past.
restamp() {
    # Through the environment rather than -v, which mangles a multi-line value
    SIZE_BLOCK="$1" awk '
        BEGIN { block = ENVIRON["SIZE_BLOCK"] }
        $0 == "```json" { inside = 1 }
        inside && /"size"[[:space:]]*:[[:space:]]*\{/ { dropping = 1; next }
        dropping { if ($0 ~ /^[[:space:]]*\},?[[:space:]]*$/) dropping = 0; next }
        inside && !stamped && /"version"[[:space:]]*:/ { print; print block; stamped = 1; next }
        inside && $0 == "```" { inside = 0 }
        { print }
    ' "$dir/index.md" > "$dir/index.md.new"
    mv "$dir/index.md.new" "$dir/index.md"
}

keys=()
if [[ "$target" == "*" ]]; then
    while IFS= read -r key; do
        keys+=("$key")
    done < <(publishable)
else
    keys=("$target")
fi

drifted=0
missed=0
written=0
for key in "${keys[@]}"; do
    WORKFLOW="$key"
    resolve

    echo "==> $key"
    before=$((drifted + missed))

    if ! measure; then
        printf '    %-17s %-16s %s\n' "index.md" "size" "$image — registry lookup failed"
        missed=$((missed + 1))
        continue
    fi

    # Rendered as the json block indents it, one line per declared arch, so a
    # partial reading still leaves valid json behind
    rendered=""
    for architecture in $(arches); do
        latest="$(bytes_of "$architecture")"
        current="$(recorded "$architecture")"

        if [[ -z "$latest" ]]; then
            printf '    %-17s %-16s %s\n' "index.md" "size.$architecture" "${current:-none} — no $architecture manifest"
            missed=$((missed + 1))
            continue
        fi

        latest="$(human "$latest")"
        [[ -n "$rendered" ]] && rendered+=$',\n'
        rendered+="        \"$architecture\": \"$latest\""

        [[ "$current" != "$latest" ]] || continue
        printf '    %-17s %-16s %s → %s\n' "index.md" "size.$architecture" "${current:-none}" "$latest"
        drifted=$((drifted + 1))
    done

    if [[ $((drifted + missed)) -le "$before" ]]; then
        echo "    up to date"
        continue
    fi

    if [[ "$apply" == "true" && -n "$rendered" ]]; then
        # "size" goes in behind "version", so an entry without one has nowhere to
        # put it — caught before the old block is dropped, not after
        [[ -n "$version" ]] || fail "no \"version\" in $dir/index.md json to anchor \"size\" to"

        restamp "    \"size\": {"$'\n'"$rendered"$'\n'"    },"
        written=$((written + 1))
    fi
done

echo
if [[ "$apply" == "true" ]]; then
    echo "==> $written updated, $missed missed"
else
    echo "==> $drifted behind, $missed missed  (--apply to write)"
fi

[[ "$missed" -eq 0 ]] || exit 1
exit 0
